with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

package body Calipso.Web_Addresses is

    use Ada.Strings.Unbounded;

    Site_Mark : constant String := "://";

    Writing_Endings : constant String :=
        " txt md py css js json xml svg csv c h cpp java rs go adb ads sh tex rst yaml yml toml ";
    Picture_Endings : constant String :=
        " png jpg jpeg gif webp bmp ico tif tiff ";
    Video_Endings : constant String :=
        " mp4 webm mkv avi mov ogv m4v ";
    Sound_Endings : constant String :=
        " mp3 ogg oga wav flac m4a ";
    Document_Endings : constant String :=
        " pdf doc docx odt epub ps xls xlsx ppt pptx ";
    Other_Endings : constant String :=
        " zip gz tar bz2 7z rar exe dmg iso bin woff woff2 ttf otf eot map wasm ";
    --# Each list is written with a space around every ending, so that looking
    --# for " png " can never find a piece of another ending.

    Not_Plain_Mark : constant Character := Character'Val (127);

    function Kind_Name (
            Kind : in Content_Kind
            ) return String is
        begin
        case Kind is
            when Page =>
                return "page";
            when Writing =>
                return "writing";
            when Picture =>
                return "picture";
            when Video =>
                return "video";
            when Sound =>
                return "sound";
            when Document =>
                return "document";
            when Other =>
                return "other";
            end case;
        end Kind_Name;

    function Lowered (
            Text : in String
            ) return String is
        Result : String := Text;
        begin
        for Char of Result loop
            if Char in 'A' .. 'Z' then
                Char := Character'Val (Character'Pos (Char) + 32);
                end if;
            end loop;
        return Result;
        end Lowered;

    function Starts_With (
            Text   : in String;
            Prefix : in String
            ) return Boolean is
        begin
        if Text'Length < Prefix'Length then
            return False;
            end if;
        return Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
        end Starts_With;

    function Ends_With (
            Text   : in String;
            Suffix : in String
            ) return Boolean is
        begin
        if Text'Length < Suffix'Length then
            return False;
            end if;
        return Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix;
        end Ends_With;

    function Is_Plain (
            Text : in String
            ) return Boolean is
        begin
        for Char of Text loop
            if Char not in '!' .. '~' then
                return False;
                end if;
            end loop;
        return True;
        end Is_Plain;

    function Narrowed (
            Text : in Wide_Wide_String
            ) return String is
        Result : String (1 .. Text'Length);
        Place  : Natural := 0;
        Number : Natural;
        begin
        for Char of Text loop
            Place := Place + 1;
            Number := Wide_Wide_Character'Pos (Char);
            if Number < 127 then
                Result (Place) := Character'Val (Number);
            else
                Result (Place) := Not_Plain_Mark;
                end if;
            end loop;
        return Result;
        end Narrowed;

    function Site_Of (
            Address : in String
            ) return String is
        Mark  : constant Natural := Ada.Strings.Fixed.Index (Address, Site_Mark);
        After : Positive;
        Slash : Natural;
        begin
        if Mark = 0 then
            return "";
            end if;
        After := Mark + Site_Mark'Length;
        if After > Address'Last then
            return Address;
            end if;
        Slash := Ada.Strings.Fixed.Index (Address, "/", After);
        if Slash = 0 then
            return Address;
            end if;
        return Address (Address'First .. Slash - 1);
        end Site_Of;

    function Host_Of (
            Address : in String
            ) return String is
        Site : constant String := Site_Of (Address);
        Mark : constant Natural := Ada.Strings.Fixed.Index (Site, Site_Mark);
        begin
        if Mark = 0 then
            return "";
            end if;
        return Site (Mark + Site_Mark'Length .. Site'Last);
        end Host_Of;

    function Path_Of (
            Address : in String
            ) return String is
        Site : constant String := Site_Of (Address);
        begin
        if Site'Length = Address'Length then
            return "/";
            end if;
        return Address (Address'First + Site'Length .. Address'Last);
        end Path_Of;

    function Without_Question (
            Path : in String
            ) return String is
        Question : constant Natural := Ada.Strings.Fixed.Index (Path, "?");
        begin
        if Question = 0 then
            return Path;
            end if;
        return Path (Path'First .. Question - 1);
        end Without_Question;

    function After_Last (
            Text : in String;
            Mark : in String
            ) return String is
        Place : constant Natural := Ada.Strings.Fixed.Index (Text, Mark, Ada.Strings.Backward);
        begin
        if Place = 0 then
            return Text;
            end if;
        return Text (Place + 1 .. Text'Last);
        end After_Last;
    --# What follows the last Mark (one character). The whole text if the mark is not there.

    function Ending_Of (
            Address : in String
            ) return String is
        Plain     : constant String := Without_Question (Path_Of (Address));
        Last_Part : constant String := After_Last (Plain, "/");
        Dot       : constant Natural := Ada.Strings.Fixed.Index (Last_Part, ".", Ada.Strings.Backward);
        begin
        if Dot = 0 then
            return "";
            end if;
        return Lowered (Last_Part (Dot + 1 .. Last_Part'Last));
        end Ending_Of;

    function Is_Listed (
            Ending : in String;
            List   : in String
            ) return Boolean is
        begin
        if Ending = "" then
            return False;
            end if;
        return Ada.Strings.Fixed.Index (List, " " & Ending & " ") > 0;
        end Is_Listed;

    function Kind_By_Name (
            Address : in String
            ) return Content_Kind is
        Ending : constant String := Ending_Of (Address);
        begin
        if Is_Listed (Ending, Writing_Endings) then
            return Writing;
            end if;
        if Is_Listed (Ending, Picture_Endings) then
            return Picture;
            end if;
        if Is_Listed (Ending, Video_Endings) then
            return Video;
            end if;
        if Is_Listed (Ending, Sound_Endings) then
            return Sound;
            end if;
        if Is_Listed (Ending, Document_Endings) then
            return Document;
            end if;
        if Is_Listed (Ending, Other_Endings) then
            return Other;
            end if;
        return Page;
        end Kind_By_Name;

    function Main_Label (
            Label : in String
            ) return String is
        Semicolon : constant Natural := Ada.Strings.Fixed.Index (Label, ";");
        begin
        if Semicolon = 0 then
            return Lowered (Ada.Strings.Fixed.Trim (Label, Ada.Strings.Both));
            end if;
        return Lowered (Ada.Strings.Fixed.Trim (Label (Label'First .. Semicolon - 1), Ada.Strings.Both));
        end Main_Label;
    --# "Text/HTML; charset=utf-8" -> "text/html"

    function Kind_By_Label (
            Label : in String
            ) return Content_Kind is
        Main : constant String := Main_Label (Label);
        begin
        if Main = "text/html" or else Main = "application/xhtml+xml" then
            return Page;
            end if;
        if Starts_With (Main, "text/") then
            return Writing;
            end if;
        if Main = "application/json" or else Main = "application/xml"
                or else Main = "application/javascript" or else Main = "image/svg+xml" then
            return Writing;
            end if;
        if Starts_With (Main, "image/") then
            return Picture;
            end if;
        if Starts_With (Main, "video/") then
            return Video;
            end if;
        if Starts_With (Main, "audio/") then
            return Sound;
            end if;
        if Main = "application/pdf" or else Main = "application/msword"
                or else Main = "application/epub+zip" or else Main = "application/postscript" then
            return Document;
            end if;
        return Other;
        end Kind_By_Label;

    Unknown_Label : constant String := "application/octet-stream";

    function Label_By_Ending (
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
        end Label_By_Ending;

    function Sense_Of (
            Address : in String;
            Kind    : in Content_Kind
            ) return String is
        Ending : constant String := Ending_Of (Address);
        begin
        if Kind = Writing and then Ending /= "" then
            return Ending;
            end if;
        return Kind_Name (Kind);
        end Sense_Of;

    procedure Drop_Last_Part (
            Kept : in out Unbounded_String
            ) is
        Slash : constant Natural := Index (Kept, "/", Ada.Strings.Backward);
        begin
        if Slash > 0 then
            Kept := Unbounded_Slice (Kept, 1, Slash - 1);
            end if;
        end Drop_Last_Part;
    --# "/a/b" -> "/a". Nothing to drop: it stays as it is.

    function Tidy_Path (
            Path : in String
            ) return String is
        Plain          : constant String := Without_Question (Path);
        Question       : constant String := Path (Path'First + Plain'Length .. Path'Last);
        Kept           : Unbounded_String;
        --# The parts kept so far, each with its slash in front: "/a/b".
        Ends_In_Folder : Boolean := True;
        Position       : Positive := Plain'First + 1;
        --# The first character is the leading slash.
        Slash          : Natural;
        Stop           : Natural;
        Is_Last        : Boolean;
        begin
        while Position <= Plain'Last loop
            Slash := Ada.Strings.Fixed.Index (Plain, "/", Position);
            Is_Last := Slash = 0;
            if Is_Last then
                Stop := Plain'Last;
            else
                Stop := Slash - 1;
                end if;
            declare
                Part : constant String := Plain (Position .. Stop);
                begin
                if Part = "" or else Part = "." then
                    Ends_In_Folder := True;
                elsif Part = ".." then
                    Drop_Last_Part (Kept);
                    Ends_In_Folder := True;
                else
                    Append (Kept, "/" & Part);
                    Ends_In_Folder := not Is_Last;
                    end if;
                end;
            Position := Stop + 2;
            end loop;
        if Ends_In_Folder or else Length (Kept) = 0 then
            Append (Kept, "/");
            end if;
        return To_String (Kept) & Question;
        end Tidy_Path;

    function Tidied (
            Address : in String
            ) return String is
        begin
        return Site_Of (Address) & Tidy_Path (Path_Of (Address));
        end Tidied;

    function Has_Scheme (
            Link : in String
            ) return Boolean is
        begin
        for Char of Link loop
            if Char = ':' then
                return True;
                end if;
            if Char not in 'a' .. 'z' and then Char not in 'A' .. 'Z' then
                return False;
                end if;
            end loop;
        return False;
        end Has_Scheme;
    --# Does it start like "mailto:" or "javascript:"? Letters, then a colon.

    function Scheme_With_Colon (
            Address : in String
            ) return String is
        Mark : constant Natural := Ada.Strings.Fixed.Index (Address, Site_Mark);
        begin
        if Mark = 0 then
            return "";
            end if;
        return Address (Address'First .. Mark);
        end Scheme_With_Colon;
    --# "http://example.org/x" -> "http:"

    function Folder_Of (
            Path : in String
            ) return String is
        Plain : constant String := Without_Question (Path);
        Slash : constant Natural := Ada.Strings.Fixed.Index (Plain, "/", Ada.Strings.Backward);
        begin
        return Plain (Plain'First .. Slash);
        end Folder_Of;
    --# "/folder/page.html?view=1" -> "/folder/"

    function Without_Place (
            Link : in String
            ) return String is
        Hash_Mark : constant Natural := Ada.Strings.Fixed.Index (Link, "#");
        begin
        if Hash_Mark = 0 then
            return Link;
            end if;
        return Link (Link'First .. Hash_Mark - 1);
        end Without_Place;
    --# What follows # is a place inside the same page, not another page.

    function Resolved (
            Base : in String;
            Link : in String
            ) return String is
        Bare : constant String := Ada.Strings.Fixed.Trim (Without_Place (Link), Ada.Strings.Both);
        Site : constant String := Site_Of (Base);
        begin
        if Bare = "" then
            return "";
            end if;
        if not Is_Plain (Bare) then
            return "";
            end if;
        if Starts_With (Bare, "http://") or else Starts_With (Bare, "https://") then
            return Tidied (Bare);
            end if;
        if Starts_With (Bare, "//") then
            return Tidied (Scheme_With_Colon (Base) & Bare);
            end if;
        if Has_Scheme (Bare) then
            return "";
            end if;
        if Starts_With (Bare, "/") then
            return Site & Tidy_Path (Bare);
            end if;
        if Starts_With (Bare, "?") then
            return Site & Without_Question (Path_Of (Base)) & Bare;
            end if;
        return Site & Tidy_Path (Folder_Of (Path_Of (Base)) & Bare);
        end Resolved;

    end Calipso.Web_Addresses;
