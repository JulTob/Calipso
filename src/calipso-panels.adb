with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Wide_Wide_Unbounded;

with Calipso.Alphabets;
with Calipso.Blind_Spots;
with Calipso.Canvases;
with Calipso.Collapsing;
with Calipso.Console;
with Calipso.Criteria;
with Calipso.Neuron_Kinds;
with Calipso.Random_Sources;
with Calipso.Records;
with Calipso.Robots;
with Calipso.Templates;

package body Calipso.Panels is

    use Ada.Strings.Unbounded;
    use type Pages.Block_Kind;

    package Wide renames Ada.Strings.Wide_Wide_Unbounded;

    package Address_Lists is new Ada.Containers.Indefinite_Vectors (
            Index_Type   => Positive,
            Element_Type => String
            );

    Line_Feed       : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);
    Lesson_Length   : constant Positive := 64;
    Shortest_Lesson : constant Positive := 8;
    Hiding_Seed     : constant Natural := 1_077;
    Margin          : constant Natural := 48;
    --# How many letters around a hidden piece the brain is shown.
    Most_Blocks     : constant Positive := 80;
    Most_Links      : constant Positive := 40;
    Most_Rules      : constant Positive := 3_000;
    --# The most pieces, links and letters of rules that one screen shows.

    ---------------------------------------------------------------
    --  Small helpers
    ---------------------------------------------------------------

    function Image (
            Value : in Natural
            ) return String is
        begin
        return Console.Image (Value);
        end Image;

    function Number_In (
            Word : in String
            ) return Natural is
        Value : Natural := 0;
        begin
        if Word'Length = 0 or else Word'Length > 6 then
            return 0;
            end if;
        for Digit of Word loop
            if Digit not in '0' .. '9' then
                return 0;
                end if;
            Value := Value * 10 + (Character'Pos (Digit) - Character'Pos ('0'));
            end loop;
        return Value;
        end Number_In;
    --# The whole number written in Word. 0 if it is not one.

    function Shown (
            Text : in Texts.Wide_Text
            ) return String is
        begin
        return Web_Servers.Escaped (Console.To_UTF_8 (Wide.To_Wide_Wide_String (Text)));
        end Shown;
    --# Text from a page, made safe to show inside the panel.

    function Sense (
            Self : in Panel
            ) return String is
        begin
        return Web_Addresses.Sense_Of (To_String (Self.Address), Self.Kind);
        end Sense;

    function Brain_File (
            Self : in Panel;
            Name : in String
            ) return String is
        begin
        return To_String (Self.Folder) & "/" & Name & ".brn";
        end Brain_File;

    procedure Say (
            Self : in out Panel;
            Text : in     String
            ) is
        begin
        Self.Notice := To_Unbounded_String (Text);
        end Say;

    ---------------------------------------------------------------
    --  Brains
    ---------------------------------------------------------------

    procedure Find_Brain (
            Self : in out Panel;
            Name : in     String
            ) is
        File_Name : constant String := Brain_File (Self, Name);
        begin
        if To_String (Self.Brain_Sense) = Name then
            return;
            end if;
        if Ada.Directories.Exists (File_Name) then
            Brains.Load (Self.Brain, File_Name);
        else
            Brains.Prepare (Self.Brain, Alphabets.Common_Letters);
            Brains.Add_Recipe (Self.Brain, Default_Recipe);
            end if;
        Self.Brain_Sense := To_Unbounded_String (Name);
        end Find_Brain;
    --# Makes sure the brain of this sense is the one in memory: loaded from its
    --# file if it has one, made new if not.

    function Page_Symbols (
            Self : in Panel
            ) return Texts.Symbol_Text is
        Letters : constant Alphabets.Alphabet := Brains.Letters_Of (Self.Brain);
        Words   : constant Texts.Wide_Text := Pages.Text_Of (Self.Content);
        Symbols : Texts.Symbol_Text;
        begin
        for Position in 1 .. Wide.Length (Words) loop
            Symbols.Append (Alphabets.Symbol_Of (Letters, Wide.Element (Words, Position)));
            end loop;
        return Symbols;
        end Page_Symbols;
    --# The words of the page, as the loaded brain reads them.

    ---------------------------------------------------------------
    --  Looking at an address
    ---------------------------------------------------------------

    procedure Forget_Page (
            Self : in out Panel
            ) is
        begin
        Self.Notice := Null_Unbounded_String;
        Self.Has_Page := False;
        Self.Kind := Web_Addresses.Page;
        Self.Content.Blocks.Clear;
        Self.Content.Links.Clear;
        Self.Rules := Not_Asked;
        Self.Rules_Text := Wide.Null_Unbounded_Wide_Wide_String;
        Self.Is_Allowed := False;
        Self.Last_Trial.Is_Shown := False;
        end Forget_Page;

    function Asked_For (
            Self    : in Panel;
            Address : in String
            ) return Fetchers.Answer is
        Engine : constant Fetchers.Fetcher'Class := Self.Fetcher.Element;
        begin
        return Engine.Fetch (Address, To_String (Self.Work_File));
        end Asked_For;

    procedure Ask_Rules (
            Self   : in out Panel;
            Target : in     String
            ) is
        Answer : constant Fetchers.Answer := Asked_For (Self, Web_Addresses.Site_Of (Target) & "/robots.txt");
        Rules  : Robots.Rule_Set;
        begin
        case Answer.Outcome is
            when Fetchers.Fetched =>
                Self.Rules_Text := Texts.Whole_Text (To_String (Self.Work_File));
                Self.Rules := Present;
                Rules := Robots.Parsed (Self.Rules_Text, Fetchers.Agent_Name);
            when Fetchers.Missing =>
                Self.Rules := Absent;
                Rules := Robots.Allow_Everything;
            when Fetchers.Moved | Fetchers.Failed =>
                Self.Rules := Unreadable;
                Rules := Robots.Allow_Nothing;
            end case;
        Self.Is_Allowed := Robots.Allows (Rules, Web_Addresses.Path_Of (Target));
        exception
        when Texts.Reading_Error =>
            Self.Rules := Unreadable;
            Self.Is_Allowed := False;
        end Ask_Rules;
    --# Fetches the rules of the site and works out what they say about this address.

    function As_Lines (
            Text : in Texts.Wide_Text
            ) return Pages.Page_Content is
        Content : Pages.Page_Content;
        Line    : Texts.Wide_Text;
        Char    : Wide_Wide_Character;
        begin
        for Position in 1 .. Wide.Length (Text) loop
            Char := Wide.Element (Text, Position);
            if Char /= Line_Feed then
                Wide.Append (Line, Char);
            elsif Wide.Length (Line) > 0 then
                Content.Blocks.Append ((Kind => Pages.Words, Text => Line));
                Line := Wide.Null_Unbounded_Wide_Wide_String;
                end if;
            end loop;
        if Wide.Length (Line) > 0 then
            Content.Blocks.Append ((Kind => Pages.Words, Text => Line));
            end if;
        return Content;
        end As_Lines;
    --# A file of plain writing (notes, code), one piece per line.

    procedure Take_Answer (
            Self   : in out Panel;
            Answer : in     Fetchers.Answer
            ) is
        Label : constant String := To_String (Answer.Label);
        begin
        Self.Kind := Web_Addresses.Kind_By_Label (Label);
        case Self.Kind is
            when Web_Addresses.Page =>
                Self.Content := Pages.Read (Texts.Whole_Text (To_String (Self.Work_File)));
                Self.Has_Page := True;
            when Web_Addresses.Writing =>
                Self.Content := As_Lines (Texts.Whole_Text (To_String (Self.Work_File)));
                Self.Has_Page := True;
            when others =>
                Say (
                    Self,
                    "This address holds a " & Web_Addresses.Kind_Name (Self.Kind) & " (the site labels it "
                    & Label & "). There is no brain for that kind of file yet, so there is nothing to read or to train on."
                    );
            end case;
        if Self.Has_Page then
            Find_Brain (Self, Sense (Self));
            end if;
        end Take_Answer;

    procedure Ask_Page (
            Self   : in out Panel;
            Target : in     String
            ) is
        Answer : constant Fetchers.Answer := Asked_For (Self, Target);
        begin
        case Answer.Outcome is
            when Fetchers.Fetched =>
                Take_Answer (Self, Answer);
            when Fetchers.Missing =>
                Say (Self, "The site says there is nothing at this address.");
            when Fetchers.Moved =>
                Say (
                    Self,
                    "The site says this page has moved to " & To_String (Answer.Moved_To)
                    & " . Look at that address to follow it."
                    );
            when Fetchers.Failed =>
                Say (Self, "The page could not be fetched: no answer, an error, or it is too big.");
            end case;
        exception
        when Texts.Reading_Error =>
            Self.Has_Page := False;
            Say (Self, "What arrived is not text that can be read.");
        end Ask_Page;

    procedure Look_At (
            Self  : in out Panel;
            Typed : in     String
            ) is
        Target : constant String := Web_Addresses.Resolved (Typed, Typed);
        begin
        Forget_Page (Self);
        Self.Address := To_Unbounded_String (Typed);
        if Target = "" or else Web_Addresses.Site_Of (Target) = "" then
            Say (Self, "That does not look like a web address. It should start with http:// or https://");
            return;
            end if;
        Self.Address := To_Unbounded_String (Target);
        Ask_Rules (Self, Target);
        if not Self.Is_Allowed then
            Say (
                Self,
                "The rules of this site do not let robots fetch this address. Nothing was fetched, "
                & "and it cannot be used for training."
                );
            return;
            end if;
        Ask_Page (Self, Target);
        end Look_At;

    ---------------------------------------------------------------
    --  Training
    ---------------------------------------------------------------

    function Percent_Image (
            Part  : in Natural;
            Whole : in Natural
            ) return String is
        begin
        if Whole = 0 then
            return "0";
            end if;
        return Console.Image (100.0 * Long_Float (Part) / Long_Float (Whole), 1);
        end Percent_Image;

    procedure Study_Page (
            Self : in out Panel;
            Text : in     Texts.Symbol_Text
            ) is
        Size     : constant Natural := Natural (Text.Length);
        Length   : constant Natural := Natural'Min (Lesson_Length, Size);
        Before   : constant Natural := Brains.Lessons_Studied (Self.Brain);
        Dice     : Random_Sources.Generator := Random_Sources.Seeded (Hiding_Seed + Before);
        Result   : Blind_Spots.Exam_Result;
        Position : Positive := 1;
        File     : constant String := Brain_File (Self, Sense (Self));
        begin
        while Position + Length - 1 <= Size loop
            Brains.Study_Piece (Self.Brain, Texts.Part (Text, Position, Position + Length - 1), Dice, Result);
            Position := Position + Length;
            end loop;
        Brains.Save (Self.Brain, File);
        Say (
            Self,
            "The brain studied " & Image (Brains.Lessons_Studied (Self.Brain) - Before)
            & " lessons from this page. Tested before each correction, it got "
            & Percent_Image (Result.Hits, Result.Hidden) & " % of the hidden letters right (mean surprise "
            & Console.Image (Blind_Spots.Mean_Surprise (Result), 3) & " nats). It has now studied "
            & Image (Brains.Lessons_Studied (Self.Brain)) & " lessons in all. Saved to " & File & "."
            );
        end Study_Page;
    --# One pass over the page, lesson by lesson: hide, test, correct. Then save.

    procedure Train (
            Self : in out Panel
            ) is
        begin
        Self.Last_Trial.Is_Shown := False;
        if not Self.Has_Page or else not Self.Is_Allowed then
            Say (Self, "There is no page to train on. Look at an address that the site's rules allow first.");
            return;
            end if;
        Find_Brain (Self, Sense (Self));
        declare
            Text : constant Texts.Symbol_Text := Page_Symbols (Self);
            begin
            if Natural (Text.Length) < Shortest_Lesson then
                Say (Self, "This page has too little text to learn from.");
                return;
                end if;
            Study_Page (Self, Text);
            end;
        end Train;

    ---------------------------------------------------------------
    --  Hide and rebuild
    ---------------------------------------------------------------

    procedure Locate (
            Self   : in     Panel;
            Number : in     Positive;
            First  :    out Positive;
            Last   :    out Natural
            ) is
        Position : Positive := 1;
        Size     : Natural;
        begin
        First := 1;
        Last := 0;
        for Index in 1 .. Natural (Self.Content.Blocks.Length) loop
            if Self.Content.Blocks.Element (Index).Kind = Pages.Words then
                Size := Wide.Length (Self.Content.Blocks.Element (Index).Text);
                if Index = Number then
                    First := Position;
                    Last := Position + Size - 1;
                    return;
                    end if;
                Position := Position + Size + 1;
                --# Each paragraph is followed by one line feed.
                end if;
            end loop;
        end Locate;
    --# Where the words of piece Number lie inside the text of the whole page.

    procedure Fill_Hole (
            Self   : in out Panel;
            Text   : in     Texts.Symbol_Text;
            Number : in     Positive;
            First  : in     Positive;
            Last   : in     Natural;
            Seed   : in     Natural;
            Half   : in     Boolean
            ) is
        Window_First : constant Positive := Integer'Max (1, First - Margin);
        Window_Last  : constant Natural := Natural'Min (Natural (Text.Length), Last + Margin);
        Shift        : constant Natural := Window_First - 1;
        Original     : constant Canvases.Canvas :=
            Templates.From_Text (Text, Window_First, Window_Last - Window_First + 1);
        Board        : Canvases.Canvas := Original;
        Letters      : constant Alphabets.Alphabet := Brains.Letters_Of (Self.Brain);
        Dice         : Random_Sources.Generator := Random_Sources.Seeded (Seed);
        Guide        : constant Criteria.Certainty := (null record);
        Score        : Blind_Spots.Score;
        Rebuilt      : Texts.Wide_Text;
        Chance       : Random_Sources.Unit_Fraction;
        begin
        for Position in First - Shift .. Last - Shift loop
            Random_Sources.Draw_Unit (Dice, Chance);
            if not Half or else Chance < 0.5 then
                Canvases.Hide (Board, Position);
                end if;
            end loop;
        Collapsing.Collapse_By (Board, Self.Brain, Dice, Guide);
        Score := Blind_Spots.Scored (Board, Original);
        for Position in First - Shift .. Last - Shift loop
            Wide.Append (Rebuilt, Alphabets.Character_Of (Letters, Canvases.Symbol_At (Board, Position)));
            end loop;
        Self.Last_Trial := (
            Is_Shown => True,
            Block    => Number,
            Rebuilt  => Rebuilt,
            Hidden   => Score.Hidden,
            Right    => Score.Recovered,
            Seed     => Seed,
            Half     => Half
            );
        end Fill_Hole;
    --# The brain sees the piece as a hole (or as a text with half its letters
    --# missing), with some text before and after it, and collapses the holes
    --# letter by letter, the surest letter first.

    procedure Rebuild (
            Self   : in out Panel;
            Number : in     Natural;
            Seed   : in     Natural;
            Half   : in     Boolean
            ) is
        First : Positive;
        Last  : Natural;
        begin
        Self.Last_Trial.Is_Shown := False;
        if not Self.Has_Page then
            Say (Self, "Look at an address first.");
            return;
            end if;
        if Number = 0 or else Number > Natural (Self.Content.Blocks.Length) then
            Say (Self, "There is no such piece on this page.");
            return;
            end if;
        if Self.Content.Blocks.Element (Number).Kind /= Pages.Words then
            Say (
                Self,
                "That piece is not text. There is no brain for pictures, films or sounds yet, "
                & "so nothing can be built in its place."
                );
            return;
            end if;
        Find_Brain (Self, Sense (Self));
        Locate (Self, Number, First, Last);
        Fill_Hole (Self, Page_Symbols (Self), Number, First, Last, Seed, Half);
        if Brains.Lessons_Studied (Self.Brain) = 0 then
            Say (Self, "This brain has not studied anything yet, so what it builds is pure chance. Train it and try again.");
        else
            Self.Notice := Null_Unbounded_String;
            end if;
        end Rebuild;

    ---------------------------------------------------------------
    --  Drawing the panel
    ---------------------------------------------------------------

    procedure Put (
            Page : in out Unbounded_String;
            Line : in     String
            ) is
        begin
        Append (Page, Line);
        Append (Page, ASCII.LF);
        end Put;

    procedure Put_Head (
            Page : in out Unbounded_String
            ) is
        begin
        Put (Page, "<!DOCTYPE html>");
        Put (Page, "<html lang=""en""><head><meta charset=""utf-8"">");
        Put (Page, "<meta name=""viewport"" content=""width=device-width, initial-scale=1"">");
        Put (Page, "<title>Calipso panel</title>");
        Put (Page, "<style>");
        Put (Page, "body{font-family:system-ui,sans-serif;margin:0;background:#f4f1ea;color:#22201c;line-height:1.45}");
        Put (Page, "header{background:#22303c;color:#fff;padding:12px 16px;font-weight:600;font-size:18px}");
        Put (Page, "header small{font-weight:400;opacity:.75;margin-left:8px}");
        Put (Page, "main{max-width:760px;margin:0 auto;padding:12px}");
        Put (Page, "section{background:#fff;border:1px solid #d9d4c7;border-radius:8px;padding:12px 14px;margin:12px 0}");
        Put (Page, "h2{font-size:13px;text-transform:uppercase;letter-spacing:.06em;color:#6b6558;margin:0 0 8px}");
        Put (Page, "form.bar{display:flex;gap:8px}");
        Put (Page, "input[type=text]{flex:1;min-width:0;padding:9px;border:1px solid #b9b3a4;border-radius:6px;font-size:15px}");
        Put (Page, "button{padding:9px 14px;border:0;border-radius:6px;background:#22303c;color:#fff;font-size:15px}");
        Put (Page, "button.train{background:#2f6f4f}");
        Put (Page, ".notice{background:#fff8dc;border-color:#e2cf7a}");
        Put (Page, ".yes{color:#1f6b3f;font-weight:600}.no{color:#a12b2b;font-weight:600}");
        Put (Page, "pre{background:#f4f1ea;padding:8px;border-radius:6px;overflow:auto;font-size:12px;margin:8px 0 0}");
        Put (Page, "p.block{margin:0 0 10px}");
        Put (Page, "a.hide{font-size:12px;color:#8a5a00;border:1px solid #d8b56a;border-radius:10px;padding:0 7px;"
            & "text-decoration:none;white-space:nowrap}");
        Put (Page, ".media{border:1px dashed #9a9484;border-radius:6px;padding:10px;margin:0 0 10px;color:#6b6558;font-size:14px}");
        Put (Page, ".trial{border:2px solid #d8b56a;border-radius:8px;padding:10px;margin:0 0 10px;background:#fffdf5}");
        Put (Page, ".label{font-size:11px;text-transform:uppercase;letter-spacing:.06em;color:#6b6558}");
        Put (Page, ".built{font-family:ui-monospace,Menlo,monospace;background:#22303c;color:#f7e9c0;padding:8px;"
            & "border-radius:6px;margin:4px 0 10px;white-space:pre-wrap;word-break:break-word}");
        Put (Page, ".real{margin:4px 0 10px}.score{font-size:14px}");
        Put (Page, "ul{margin:0;padding-left:18px}li{margin:3px 0;word-break:break-all;font-size:14px}");
        Put (Page, ".kind{font-size:11px;background:#e9e4d6;border-radius:8px;padding:0 6px;color:#555}");
        Put (Page, ".small{font-size:13px;color:#6b6558}");
        Put (Page, "</style></head><body>");
        Put (Page, "<header>Calipso panel<small>look first, then train</small></header><main>");
        end Put_Head;

    procedure Put_Address_Bar (
            Self : in     Panel;
            Page : in out Unbounded_String
            ) is
        begin
        Put (Page, "<section><h2>Address</h2>");
        Put (Page, "<form class=""bar"" action=""/view"" method=""get"">");
        Put (Page, "<input type=""text"" name=""address"" placeholder=""https://..."" value="""
            & Web_Servers.Escaped (To_String (Self.Address)) & """>");
        Put (Page, "<button>Look</button></form></section>");
        end Put_Address_Bar;

    procedure Put_Notice (
            Self : in     Panel;
            Page : in out Unbounded_String
            ) is
        begin
        if Length (Self.Notice) > 0 then
            Put (Page, "<section class=""notice"">" & Web_Servers.Escaped (To_String (Self.Notice)) & "</section>");
            end if;
        end Put_Notice;

    procedure Put_Rules (
            Self : in     Panel;
            Page : in out Unbounded_String
            ) is
        Size : constant Natural := Natural'Min (Wide.Length (Self.Rules_Text), Most_Rules);
        begin
        if Self.Rules = Not_Asked then
            return;
            end if;
        Put (Page, "<section><h2>Rules of the site for robots</h2>");
        if Self.Is_Allowed then
            Put (Page, "<p class=""yes"">Allowed: robots may fetch this address.</p>");
        else
            Put (Page, "<p class=""no"">Not allowed: robots may not fetch this address.</p>");
            end if;
        case Self.Rules is
            when Present =>
                Put (Page, "<p class=""small"">This is the site's own robots.txt, as it was just read:</p>");
                Put (Page, "<pre>" & Shown (Wide.Unbounded_Slice (Self.Rules_Text, 1, Size)) & "</pre>");
            when Absent =>
                Put (Page, "<p class=""small"">The site publishes no robots.txt, so nothing is forbidden.</p>");
            when Unreadable | Not_Asked =>
                Put (Page, "<p class=""small"">The rules of the site could not be read. When in doubt, stay out.</p>");
            end case;
        Put (Page, "<p class=""small"">These rules are about fetching. Whether the text may be used is your decision.</p>");
        Put (Page, "</section>");
        end Put_Rules;

    procedure Put_Brain (
            Self : in     Panel;
            Page : in out Unbounded_String
            ) is
        begin
        if not Self.Has_Page then
            return;
            end if;
        Put (Page, "<section><h2>Brain for this kind of file</h2>");
        Put (Page, "<p><b>" & Web_Servers.Escaped (To_String (Self.Brain_Sense)) & ".brn</b> &middot; neurons: "
            & Web_Servers.Escaped (Brains.Recipe_Of (Self.Brain)) & " &middot; "
            & Image (Brains.Lessons_Studied (Self.Brain)) & " lessons studied</p>");
        Put (Page, "<form action=""/train"" method=""post""><button class=""train"">Train on this page</button></form>");
        Put (Page, "</section>");
        end Put_Brain;

    function Hide_Link (
            Number : in Positive;
            Half   : in Boolean;
            Seed   : in Natural;
            Words  : in String
            ) return String is
        Part : constant String := (if Half then "&amp;part=half" else "");
        begin
        return "<a class=""hide"" href=""/hide?block=" & Image (Number) & Part
            & "&amp;seed=" & Image (Seed) & "#trial"">" & Words & "</a>";
        end Hide_Link;
    --# The link that asks the panel to hide piece Number.

    procedure Put_Trial (
            Self   : in     Panel;
            Page   : in out Unbounded_String;
            Number : in     Positive
            ) is
        Shot : constant Trial := Self.Last_Trial;
        begin
        Put (Page, "<div class=""trial"" id=""trial"">");
        if Shot.Half then
            Put (Page, "<div class=""label"">Half of the letters were hidden. The brain filled them in</div>");
        else
            Put (Page, "<div class=""label"">What the brain built in its place</div>");
            end if;
        Put (Page, "<p class=""built"">" & Shown (Shot.Rebuilt) & "</p>");
        Put (Page, "<div class=""label"">What was really there</div>");
        Put (Page, "<p class=""real"">" & Shown (Self.Content.Blocks.Element (Number).Text) & "</p>");
        Put (Page, "<div class=""score"">" & Image (Shot.Right) & " of " & Image (Shot.Hidden)
            & " hidden letters right (" & Percent_Image (Shot.Right, Shot.Hidden) & " %) &middot; "
            & Hide_Link (Number, Shot.Half, Shot.Seed + 1, "try again") & "</div>");
        Put (Page, "</div>");
        end Put_Trial;

    procedure Put_Block (
            Self   : in     Panel;
            Page   : in out Unbounded_String;
            Number : in     Positive
            ) is
        Piece : constant Pages.Block := Self.Content.Blocks.Element (Number);
        Hide  : constant String := " " & Hide_Link (Number, False, 1, "hide");
        Half  : constant String := " " & Hide_Link (Number, True, 1, "hide half");
        begin
        if Self.Last_Trial.Is_Shown and then Self.Last_Trial.Block = Number then
            Put_Trial (Self, Page, Number);
            return;
            end if;
        case Piece.Kind is
            when Pages.Words =>
                Put (Page, "<p class=""block"">" & Shown (Piece.Text) & Hide & Half & "</p>");
            when Pages.Picture =>
                Put (Page, "<div class=""media"">Picture: " & Shown (Piece.Text) & Hide & "</div>");
            when Pages.Video =>
                Put (Page, "<div class=""media"">Film: " & Shown (Piece.Text) & Hide & "</div>");
            when Pages.Sound =>
                Put (Page, "<div class=""media"">Sound: " & Shown (Piece.Text) & Hide & "</div>");
            when Pages.Drawing =>
                Put (Page, "<div class=""media"">A drawing inside the page" & Hide & "</div>");
            end case;
        end Put_Block;

    procedure Put_View (
            Self : in     Panel;
            Page : in out Unbounded_String
            ) is
        Count : constant Natural := Natural (Self.Content.Blocks.Length);
        begin
        if not Self.Has_Page then
            return;
            end if;
        Put (Page, "<section><h2>The page, as the robot reads it</h2>");
        Put (Page, "<p class=""small"">Press <i>hide</i> on a piece: the brain will build something in its place "
            & "from the text around it. <i>hide half</i> hides only half of its letters.</p>");
        for Number in 1 .. Natural'Min (Count, Most_Blocks) loop
            Put_Block (Self, Page, Number);
            end loop;
        if Count > Most_Blocks then
            Put (Page, "<p class=""small"">... and " & Image (Count - Most_Blocks) & " more pieces.</p>");
            end if;
        if Count = 0 then
            Put (Page, "<p class=""small"">The page has no text.</p>");
            end if;
        Put (Page, "</section>");
        end Put_View;

    procedure Put_Link (
            Self   : in     Panel;
            Page   : in out Unbounded_String;
            Target : in     String
            ) is
        Here    : constant String := To_String (Self.Address);
        Kind    : constant Web_Addresses.Content_Kind := Web_Addresses.Kind_By_Name (Target);
        Outside : constant Boolean := Web_Addresses.Host_Of (Target) /= Web_Addresses.Host_Of (Here);
        Line    : Unbounded_String;
        begin
        Append (Line, "<li><a href=""/view?address=" & Web_Servers.Encoded (Target) & """>");
        Append (Line, Web_Servers.Escaped (Target) & "</a> <span class=""kind"">");
        Append (Line, Web_Addresses.Kind_Name (Kind) & "</span>");
        if Outside then
            Append (Line, " <span class=""kind"">another site</span>");
            end if;
        Append (Line, "</li>");
        Put (Page, To_String (Line));
        end Put_Link;

    procedure Put_Links (
            Self : in     Panel;
            Page : in out Unbounded_String
            ) is
        Here : constant String := To_String (Self.Address);
        Seen : Address_Lists.Vector;
        begin
        if not Self.Has_Page or else Self.Content.Links.Is_Empty then
            return;
            end if;
        Put (Page, "<section><h2>Where this page points to</h2><ul>");
        for Index in 1 .. Natural (Self.Content.Links.Length) loop
            declare
                Written : constant String := Web_Addresses.Narrowed (Self.Content.Links.Element (Index));
                Target  : constant String := Web_Addresses.Resolved (Here, Written);
                begin
                if Target /= "" and then not Seen.Contains (Target) and then Natural (Seen.Length) < Most_Links then
                    Seen.Append (Target);
                    Put_Link (Self, Page, Target);
                    end if;
                end;
            end loop;
        Put (Page, "</ul></section>");
        end Put_Links;

    function Rendered (
            Self : in Panel
            ) return Unbounded_String is
        Page : Unbounded_String;
        begin
        Put_Head (Page);
        Put_Address_Bar (Self, Page);
        Put_Notice (Self, Page);
        Put_Rules (Self, Page);
        Put_Brain (Self, Page);
        Put_View (Self, Page);
        Put_Links (Self, Page);
        Put (Page, "</main></body></html>");
        return Page;
        end Rendered;

    ---------------------------------------------------------------
    --  The two doors of the package
    ---------------------------------------------------------------

    procedure Open (
            Self         : in out Panel;
            Brain_Folder : in     String;
            Using        : in     Fetchers.Fetcher'Class
            ) is
        begin
        Self.Folder := To_Unbounded_String (Brain_Folder);
        Self.Work_File := To_Unbounded_String (Brain_Folder & "/panel.page");
        Self.Fetcher.Replace_Element (Using);
        Self.Address := Null_Unbounded_String;
        Self.Brain_Sense := Null_Unbounded_String;
        Forget_Page (Self);
        end Open;

    procedure Act (
            Self   : in out Panel;
            Path   : in     String;
            Fields : in     String
            ) is
        Seed : constant Natural := Number_In (Web_Servers.Field (Fields, "seed"));
        begin
        if Path = "/view" then
            Look_At (Self, Ada.Strings.Fixed.Trim (Web_Servers.Field (Fields, "address"), Ada.Strings.Both));
        elsif Path = "/train" then
            Train (Self);
        elsif Path = "/hide" then
            Rebuild (
                Self,
                Number_In (Web_Servers.Field (Fields, "block")),
                Natural'Max (Seed, 1),
                Web_Servers.Field (Fields, "part") = "half"
                );
            end if;
        exception
        when Problem : Records.Record_Error | Texts.Reading_Error | Neuron_Kinds.Recipe_Error =>
            Say (Self, "Something went wrong: " & Ada.Exceptions.Exception_Message (Problem));
        end Act;
    --# Does what the request asks. Whatever happens, the panel can still be drawn.

    procedure Respond (
            Self   : in out Panel;
            Asked  : in     Web_Servers.Request;
            Answer :    out Web_Servers.Reply;
            Stop   :    out Boolean
            ) is
        Path : constant String := To_String (Asked.Path);
        begin
        Stop := False;
        Answer := (others => <>);
        if Path = "/quit" then
            Stop := True;
            Answer.Content := To_Unbounded_String ("The panel has stopped.");
        elsif Path = "/" or else Path = "/view" or else Path = "/train" or else Path = "/hide" then
            Act (Self, Path, To_String (Asked.Fields));
            Answer.Content := Rendered (Self);
        else
            Answer.Status := 404;
            Answer.Content := To_Unbounded_String ("There is no such page in the panel.");
            end if;
        end Respond;

    end Calipso.Panels;
