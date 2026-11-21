with Ada.Containers;
with Ada.Strings.Wide_Wide_Unbounded;

with Calipso.Pages;

package body Calipso.Web_Sources is

    use Ada.Strings.Unbounded;
    use type Ada.Real_Time.Time;
    use type Fetchers.Outcome_Kind;
    use type Pages.Block_Kind;
    use type Web_Addresses.Content_Kind;

    Robots_Path : constant String := "/robots.txt";

    procedure Open (
            Self      : in out Web_Source;
            Using     : in     Fetchers.Fetcher'Class;
            Letters   : in     Alphabets.Alphabet;
            Options   : in     Settings;
            Work_File : in     String
            ) is
        begin
        Self.Fetcher.Replace_Element (Using);
        Self.Letters := Letters;
        Self.Options := Options;
        Self.Work_File := To_Unbounded_String (Work_File);
        Self.Queue.Clear;
        Self.Next_In_Queue := 1;
        Self.Mentions.Clear;
        for Kind in Web_Addresses.Content_Kind loop
            Self.Finds (Kind).Clear;
            end loop;
        Self.Rules_By_Site.Clear;
        Self.Buffer.Clear;
        Self.Counts := (others => <>);
        Self.Has_Asked := False;
        end Open;
    --# Starts from blank: an empty list, nothing seen, nothing counted.

    procedure Note_Link (
            Self       : in out Web_Source;
            Target     : in     String;
            Was_Listed :    out Boolean
            ) is
        Kind : Web_Addresses.Content_Kind;
        begin
        Was_Listed := False;
        if Target = "" then
            return;
            end if;
        if Self.Mentions.Contains (Target) then
            Self.Mentions.Replace (Target, Self.Mentions.Element (Target) + 1);
            return;
            end if;
        Self.Mentions.Insert (Target, 1);
        Kind := Web_Addresses.Kind_By_Name (Target);
        if Kind /= Web_Addresses.Page then
            Self.Finds (Kind).Append (Target);
            return;
            --# First guard: by its name it is not a page, so it is never asked for.
            end if;
        Self.Queue.Append (Target);
        Was_Listed := True;
        end Note_Link;
    --# Files one full address. Was_Listed: it was new and is now listed for a visit.

    procedure Add_Address (
            Self    : in out Web_Source;
            Address : in     String
            ) is
        Unused : Boolean;
        pragma Unreferenced (Unused);
        begin
        Note_Link (Self, Web_Addresses.Resolved (Address, Address), Unused);
        end Add_Address;

    function Mentions_Of (
            Self    : in Web_Source;
            Address : in String
            ) return Natural is
        begin
        if not Self.Mentions.Contains (Address) then
            return 0;
            end if;
        return Self.Mentions.Element (Address);
        end Mentions_Of;

    function Tally_Of (
            Self : in Web_Source
            ) return Tally is
        begin
        return Self.Counts;
        end Tally_Of;

    function Find_Count (
            Self : in Web_Source;
            Kind : in Web_Addresses.Content_Kind
            ) return Natural is
        begin
        return Natural (Self.Finds (Kind).Length);
        end Find_Count;

    function Find (
            Self  : in Web_Source;
            Kind  : in Web_Addresses.Content_Kind;
            Index : in Positive
            ) return String is
        begin
        return Self.Finds (Kind).Element (Index);
        end Find;

    function Can_Read_More (
            Self : in Web_Source
            ) return Boolean is
        begin
        if Self.Counts.Asked >= Self.Options.Page_Limit then
            return False;
            end if;
        return Self.Next_In_Queue <= Natural (Self.Queue.Length);
        end Can_Read_More;

    procedure Wait_For_Turn (
            Self        : in out Web_Source;
            Least_Pause : in     Duration
            ) is
        Next_Turn : Ada.Real_Time.Time;
        begin
        if Self.Has_Asked then
            Next_Turn := Self.Last_Request + Ada.Real_Time.To_Time_Span (Least_Pause);
            delay until Next_Turn;
            --# If that moment has already passed, this does not wait at all.
            end if;
        Self.Has_Asked := True;
        Self.Last_Request := Ada.Real_Time.Clock;
        end Wait_For_Turn;
    --# Waits what is left of the pause since the last request.

    function Asked (
            Self    : in Web_Source;
            Address : in String
            ) return Fetchers.Answer is
        Engine : constant Fetchers.Fetcher'Class := Self.Fetcher.Element;
        begin
        return Engine.Fetch (Address, To_String (Self.Work_File));
        end Asked;
    --# Fetches one address into the work file.

    procedure Fetch_Rules (
            Self  : in out Web_Source;
            Site  : in     String;
            Rules :    out Robots.Rule_Set
            ) is
        Answer : Fetchers.Answer;
        begin
        Wait_For_Turn (Self, Self.Options.Pause);
        Answer := Asked (Self, Site & Robots_Path);
        if Answer.Outcome = Fetchers.Missing then
            Rules := Robots.Allow_Everything;
        elsif Answer.Outcome /= Fetchers.Fetched then
            Rules := Robots.Allow_Nothing;
        else
            Rules := Robots.Parsed (Texts.Whole_Text (To_String (Self.Work_File)), Fetchers.Agent_Name);
            end if;
        exception
        when Texts.Reading_Error =>
            Rules := Robots.Allow_Nothing;
        end Fetch_Rules;
    --# Asks the site for its rules. No rules file: all is allowed. A rules file
    --# that cannot be fetched or read: nothing is.

    procedure Find_Rules (
            Self  : in out Web_Source;
            Site  : in     String;
            Rules :    out Robots.Rule_Set
            ) is
        begin
        if Self.Rules_By_Site.Contains (Site) then
            Rules := Self.Rules_By_Site.Element (Site);
            return;
            end if;
        Fetch_Rules (Self, Site, Rules);
        Self.Rules_By_Site.Insert (Site, Rules);
        end Find_Rules;
    --# The rules of a site are fetched once and remembered.

    procedure Take_Words (
            Self    : in out Web_Source;
            Content : in     Pages.Page_Content
            ) is
        Words : constant Texts.Wide_Text := Pages.Text_Of (Content);
        Size  : constant Natural := Ada.Strings.Wide_Wide_Unbounded.Length (Words);
        Char  : Wide_Wide_Character;
        begin
        for Position in 1 .. Size loop
            Char := Ada.Strings.Wide_Wide_Unbounded.Element (Words, Position);
            Self.Buffer.Append (Alphabets.Symbol_Of (Self.Letters, Char));
            end loop;
        Self.Counts.Letters := Self.Counts.Letters + Size;
        end Take_Words;

    function Stays_Close (
            Self    : in Web_Source;
            Address : in String;
            Target  : in String
            ) return Boolean is
        begin
        if not Self.Options.Same_Site_Only then
            return True;
            end if;
        return Web_Addresses.Host_Of (Target) = Web_Addresses.Host_Of (Address);
        end Stays_Close;
    --# May a link written in the page Address be followed to Target?

    function Would_Be_Listed (
            Self   : in Web_Source;
            Target : in String
            ) return Boolean is
        begin
        if Target = "" or else Self.Mentions.Contains (Target) then
            return False;
            end if;
        return Web_Addresses.Kind_By_Name (Target) = Web_Addresses.Page;
        end Would_Be_Listed;
    --# Is it a page never seen before? Those are the ones that lengthen the list.

    procedure Take_Links (
            Self    : in out Web_Source;
            Address : in     String;
            Content : in     Pages.Page_Content
            ) is
        Taken      : Natural := 0;
        Was_Listed : Boolean;
        begin
        for Index in 1 .. Natural (Content.Links.Length) loop
            declare
                Link   : constant String := Web_Addresses.Narrowed (Content.Links.Element (Index));
                Target : constant String := Web_Addresses.Resolved (Address, Link);
                Full   : constant Boolean := Taken >= Self.Options.Links_Per_Page;
                --# Full: this page has already given its share of new addresses.
                begin
                if Stays_Close (Self, Address, Target) and then not (Full and then Would_Be_Listed (Self, Target)) then
                    Note_Link (Self, Target, Was_Listed);
                    if Was_Listed then
                        Taken := Taken + 1;
                        end if;
                    end if;
                end;
            end loop;
        end Take_Links;

    procedure Take_Media (
            Self    : in out Web_Source;
            Address : in     String;
            Content : in     Pages.Page_Content
            ) is
        Unused : Boolean;
        pragma Unreferenced (Unused);
        begin
        for Piece of Content.Blocks loop
            if Piece.Kind = Pages.Picture or else Piece.Kind = Pages.Video or else Piece.Kind = Pages.Sound then
                declare
                    Written : constant Wide_Wide_String :=
                        Ada.Strings.Wide_Wide_Unbounded.To_Wide_Wide_String (Piece.Text);
                    Target  : constant String := Web_Addresses.Resolved (Address, Web_Addresses.Narrowed (Written));
                    begin
                    Note_Link (Self, Target, Unused);
                    end;
                end if;
            end loop;
        end Take_Media;
    --# Pictures, videos and sounds shown in the page are filed too.

    procedure Read_Page (
            Self    : in out Web_Source;
            Address : in     String
            ) is
        Content : Pages.Page_Content;
        begin
        Content := Pages.Read (Texts.Whole_Text (To_String (Self.Work_File)));
        Take_Words (Self, Content);
        Take_Links (Self, Address, Content);
        Take_Media (Self, Address, Content);
        Self.Counts.Read := Self.Counts.Read + 1;
        exception
        when Texts.Reading_Error =>
            Self.Counts.Failed := Self.Counts.Failed + 1;
        end Read_Page;

    procedure Follow_Move (
            Self    : in out Web_Source;
            Address : in     String;
            Answer  : in     Fetchers.Answer
            ) is
        Target : constant String := Web_Addresses.Resolved (Address, To_String (Answer.Moved_To));
        Unused : Boolean;
        pragma Unreferenced (Unused);
        begin
        if Stays_Close (Self, Address, Target) then
            Note_Link (Self, Target, Unused);
            end if;
        end Follow_Move;
    --# The page has moved: its new address is treated like any other link.

    procedure Read_Next_Page (
            Self : in out Web_Source
            ) is
        Address : constant String := Self.Queue.Element (Self.Next_In_Queue);
        Rules   : Robots.Rule_Set;
        Answer  : Fetchers.Answer;
        Kind    : Web_Addresses.Content_Kind;
        begin
        Self.Next_In_Queue := Self.Next_In_Queue + 1;
        Find_Rules (Self, Web_Addresses.Site_Of (Address), Rules);
        if not Robots.Allows (Rules, Web_Addresses.Path_Of (Address)) then
            Self.Counts.Refused := Self.Counts.Refused + 1;
            return;
            end if;
        Wait_For_Turn (Self, Duration'Max (Self.Options.Pause, Robots.Delay_Of (Rules)));
        Answer := Asked (Self, Address);
        Self.Counts.Asked := Self.Counts.Asked + 1;
        if Answer.Outcome = Fetchers.Moved then
            Follow_Move (Self, Address, Answer);
            return;
            end if;
        if Answer.Outcome /= Fetchers.Fetched then
            Self.Counts.Failed := Self.Counts.Failed + 1;
            return;
            end if;
        Kind := Web_Addresses.Kind_By_Label (To_String (Answer.Label));
        if Kind /= Web_Addresses.Page then
            Self.Finds (Kind).Append (Address);
            Self.Counts.Not_Text := Self.Counts.Not_Text + 1;
            return;
            --# Second guard: it looked like a page by name, but the server says otherwise.
            end if;
        Read_Page (Self, Address);
        end Read_Next_Page;

    overriding procedure Next_Piece (
            Self  : in out Web_Source;
            Piece :    out Texts.Symbol_Text;
            Found :    out Boolean
            ) is
        Length : constant Positive := Self.Options.Piece_Length;
        begin
        while Natural (Self.Buffer.Length) < Length and then Can_Read_More (Self) loop
            Read_Next_Page (Self);
            end loop;
        if Natural (Self.Buffer.Length) < Length then
            Piece.Clear;
            Found := False;
            return;
            end if;
        Piece := Texts.Part (Self.Buffer, 1, Length);
        Self.Buffer.Delete_First (Ada.Containers.Count_Type (Length));
        Found := True;
        end Next_Piece;

    end Calipso.Web_Sources;
