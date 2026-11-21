with Ada.Directories;

with Calipso.Web_Addresses;

package body Calipso.Folder_Fetchers is

    use Ada.Strings.Unbounded;
    use type Ada.Directories.File_Kind;

    Unknown_Label : constant String := "application/octet-stream";

    function Label_Of (
            Ending : in String
            ) return String is
        begin
        if Ending = "html" or else Ending = "htm" then
            return "text/html";
            end if;
        if Ending = "txt" then
            return "text/plain";
            end if;
        if Ending = "css" then
            return "text/css";
            end if;
        if Ending = "py" then
            return "text/x-python";
            end if;
        if Ending = "svg" then
            return "image/svg+xml";
            end if;
        if Ending = "png" then
            return "image/png";
            end if;
        if Ending = "jpg" then
            return "image/jpeg";
            end if;
        if Ending = "mp3" then
            return "audio/mpeg";
            end if;
        if Ending = "mp4" then
            return "video/mp4";
            end if;
        if Ending = "pdf" then
            return "application/pdf";
            end if;
        return Unknown_Label;
        end Label_Of;
    --# The label a real server would send for a file with this ending.

    function Is_A_File (
            File_Name : in String
            ) return Boolean is
        begin
        if not Ada.Directories.Exists (File_Name) then
            return False;
            end if;
        return Ada.Directories.Kind (File_Name) = Ada.Directories.Ordinary_File;
        end Is_A_File;

    procedure Prepare (
            Self   : in out Folder_Fetcher;
            Site   : in     String;
            Folder : in     String
            ) is
        begin
        Self.Site := To_Unbounded_String (Site);
        Self.Folder := To_Unbounded_String (Folder);
        end Prepare;

    overriding function Fetch (
            Self      : in Folder_Fetcher;
            Address   : in String;
            Into_File : in String
            ) return Fetchers.Answer is
        Path      : constant String := Web_Addresses.Without_Question (Web_Addresses.Path_Of (Address));
        File_Name : constant String := To_String (Self.Folder) & Path;
        Result    : Fetchers.Answer;
        begin
        if Web_Addresses.Site_Of (Address) /= To_String (Self.Site) then
            Result.Outcome := Fetchers.Failed;
            return Result;
            end if;
        if not Is_A_File (File_Name) then
            Result.Outcome := Fetchers.Missing;
            return Result;
            end if;
        if Ada.Directories.Exists (Into_File) then
            Ada.Directories.Delete_File (Into_File);
            end if;
        Ada.Directories.Copy_File (File_Name, Into_File);
        Result.Outcome := Fetchers.Fetched;
        Result.Label := To_Unbounded_String (Label_Of (Web_Addresses.Ending_Of (Address)));
        return Result;
        end Fetch;

    end Calipso.Folder_Fetchers;
