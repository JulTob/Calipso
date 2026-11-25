with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

package body Calipso.Curl_Fetchers is

    use type Ada.Directories.File_Size;

    Program_Name   : constant String := "curl";
    Report_Request : constant String := "%{http_code}\n%{content_type}\n%{redirect_url}\n";
    --# What curl is asked to report, one item per line.

    function Image (
            Value : in Positive
            ) return String is
        begin
        return Ada.Strings.Fixed.Trim (Positive'Image (Value), Ada.Strings.Left);
        end Image;

    function Answer_From_Report (
            Code       : in String;
            Label      : in String;
            Moved_To   : in String;
            Into_File  : in String;
            Most_Bytes : in Positive
            ) return Fetchers.Answer is
        Result : Fetchers.Answer;
        begin
        if Code = "200" then
            if not Ada.Directories.Exists (Into_File) then
                return Result;
                end if;
            if Ada.Directories.Size (Into_File) > Ada.Directories.File_Size (Most_Bytes) then
                return Result;
                end if;
            Result.Outcome := Fetchers.Fetched;
            Result.Label := Ada.Strings.Unbounded.To_Unbounded_String (Label);
            return Result;
            end if;
        if Code = "404" or else Code = "410" then
            Result.Outcome := Fetchers.Missing;
            return Result;
            end if;
        if Code'Length > 0 and then Code (Code'First) = '3' and then Moved_To /= "" then
            Result.Outcome := Fetchers.Moved;
            Result.Moved_To := Ada.Strings.Unbounded.To_Unbounded_String (Moved_To);
            return Result;
            end if;
        return Result;
        --# A newly declared answer says "failed".
        end Answer_From_Report;

    procedure Run_Curl (
            Self        : in     Curl_Fetcher;
            Address     : in     String;
            Into_File   : in     String;
            Report_File : in     String;
            Worked      :    out Boolean
            ) is
        use GNAT.OS_Lib;
        Program     : String_Access := Locate_Exec_On_Path (Program_Name);
        Arguments   : Argument_List := (
            new String'("--silent"),
            new String'("--proto"),
            new String'("=http,https"),
            new String'("--max-time"),
            new String'(Image (Self.Most_Seconds)),
            new String'("--max-filesize"),
            new String'(Image (Self.Most_Bytes)),
            new String'("--user-agent"),
            new String'(Fetchers.Agent_Line),
            new String'("--output"),
            new String'(Into_File),
            new String'("--write-out"),
            new String'(Report_Request),
            new String'(Address)
            );
        Success     : Boolean := False;
        Return_Code : Integer := -1;
        begin
        if Program /= null then
            Spawn (Program.all, Arguments, Report_File, Success, Return_Code, Err_To_Out => False);
            end if;
        Worked := Success and then Return_Code = 0;
        for Argument of Arguments loop
            Free (Argument);
            end loop;
        Free (Program);
        end Run_Curl;
    --# Runs curl once. Its report goes to Report_File, what it fetched to Into_File.
    --# The run-time library wants the arguments as pointers to text; they are
    --# made here and given back here, and nothing outside sees them.

    function Next_Line (
            File : in Ada.Text_IO.File_Type
            ) return String is
        begin
        if Ada.Text_IO.End_Of_File (File) then
            return "";
            end if;
        return Ada.Text_IO.Get_Line (File);
        end Next_Line;

    function Answer_In (
            Report_File : in String;
            Into_File   : in String;
            Most_Bytes  : in Positive
            ) return Fetchers.Answer is
        File   : Ada.Text_IO.File_Type;
        Result : Fetchers.Answer;
        begin
        Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Report_File);
        declare
            Code     : constant String := Next_Line (File);
            Label    : constant String := Next_Line (File);
            Moved_To : constant String := Next_Line (File);
            begin
            Result := Answer_From_Report (Code, Label, Moved_To, Into_File, Most_Bytes);
            end;
        Ada.Text_IO.Close (File);
        return Result;
        exception
        when Ada.Text_IO.Name_Error | Ada.Text_IO.Use_Error =>
            return Result;
        end Answer_In;

    procedure Remove (
            File_Name : in String
            ) is
        begin
        if Ada.Directories.Exists (File_Name) then
            Ada.Directories.Delete_File (File_Name);
            end if;
        end Remove;

    overriding function Fetch (
            Self      : in Curl_Fetcher;
            Address   : in String;
            Into_File : in String
            ) return Fetchers.Answer is
        Report_File : constant String := Into_File & ".report";
        Worked      : Boolean;
        Result      : Fetchers.Answer;
        begin
        Remove (Into_File);
        Run_Curl (Self, Address, Into_File, Report_File, Worked);
        if Worked then
            Result := Answer_In (Report_File, Into_File, Self.Most_Bytes);
            end if;
        Remove (Report_File);
        return Result;
        end Fetch;

    end Calipso.Curl_Fetchers;
