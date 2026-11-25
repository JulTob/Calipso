with Ada.Directories;

with Calipso.Web_Addresses;

package body Calipso.Folder_Fetchers is

    use Ada.Strings.Unbounded;
    use type Ada.Directories.File_Kind;

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
        Result.Label := To_Unbounded_String (Web_Addresses.Label_By_Ending (Web_Addresses.Ending_Of (Address)));
        return Result;
        end Fetch;

    end Calipso.Folder_Fetchers;
