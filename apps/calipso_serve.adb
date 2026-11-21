--  Serves a folder of this computer as a small web site, for tests.
--
--  Usage:
--     calipso_serve FOLDER [PORT]
--
--  The file FOLDER/sub/c.html is then at http://127.0.0.1:PORT/sub/c.html
--  (port 8765 if not said). Only this same computer can reach it.
--  Asking for the address /__stop ends the program.

with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Calipso.Console;
with Calipso.Web_Addresses;
with Calipso.Web_Servers;

procedure Calipso_Serve is

    use Calipso;
    use Ada.Strings.Unbounded;
    use type Ada.Directories.File_Kind;

    Default_Port : constant Positive := 8_765;
    Stop_Path    : constant String := "/__stop";
    Front_Page   : constant String := "index.html";

    Bad_Argument : exception;

    Folder : Unbounded_String;

    function Is_A_File (
            File_Name : in String
            ) return Boolean is
        begin
        if not Ada.Directories.Exists (File_Name) then
            return False;
            end if;
        return Ada.Directories.Kind (File_Name) = Ada.Directories.Ordinary_File;
        end Is_A_File;

    function File_For (
            Path : in String
            ) return String is
        begin
        if Path'Length > 0 and then Path (Path'Last) = '/' then
            return To_String (Folder) & Path & Front_Page;
            end if;
        return To_String (Folder) & Path;
        end File_For;
    --# A path that ends in a slash means the front page of that folder.

    procedure Handle (
            Asked  : in     Web_Servers.Request;
            Answer :    out Web_Servers.Reply;
            Stop   :    out Boolean
            ) is
        Path      : constant String := To_String (Asked.Path);
        File_Name : constant String := File_For (Path);
        Climbs    : constant Boolean := Ada.Strings.Fixed.Index (Path, "..") > 0;
        --# A path with ".." could climb out of the folder: it is refused.
        begin
        Stop := False;
        Answer := (others => <>);
        if Path = Stop_Path then
            Stop := True;
            Answer.Content := To_Unbounded_String ("Stopped.");
        elsif Climbs or else not Is_A_File (File_Name) then
            Answer.Status := 404;
            Answer.Content := To_Unbounded_String ("Not found.");
        else
            Answer.Label := To_Unbounded_String (Web_Addresses.Label_By_Ending (Web_Addresses.Ending_Of (File_Name)));
            Answer.Content := Web_Servers.File_Content (File_Name);
            end if;
        Console.Put_Line (To_String (Asked.Method) & " " & Path & " -> " & Console.Image (Answer.Status));
        end Handle;

    function Port_Number (
            Word : in String
            ) return Positive is
        begin
        return Positive'Value (Word);
        exception
        when Constraint_Error =>
            raise Bad_Argument with "the port must be a whole number, like 8765";
        end Port_Number;

    Count : constant Natural := Ada.Command_Line.Argument_Count;
    Port  : Positive := Default_Port;

    begin
    if Count = 0 then
        Console.Put_Line ("Usage:");
        Console.Put_Line ("   calipso_serve FOLDER [PORT]");
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        return;
        end if;
    Folder := To_Unbounded_String (Ada.Command_Line.Argument (1));
    if Count >= 2 then
        Port := Port_Number (Ada.Command_Line.Argument (2));
        end if;
    Web_Servers.Serve (Port, Handle'Access);
    exception
    when Problem : Web_Servers.Listening_Error | Bad_Argument =>
        Console.Put_Line ("Error: " & Ada.Exceptions.Exception_Message (Problem));
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
    end Calipso_Serve;
