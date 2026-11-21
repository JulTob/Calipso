--  A brain that studies pages from the web.
--
--  Usage:
--     calipso_crawl BRAIN_FILE START_LIST [PAGES] [RECIPE]
--
--  START_LIST is a text file with one address per line (lines that start with #
--  are notes). The robot starts there and follows the links it finds, staying on
--  the same site, obeying each site's robots.txt, and never asking faster than
--  once a second. It reads at most PAGES pages (20 if not said).
--
--  The brain is loaded from BRAIN_FILE, or made new from RECIPE if the file does
--  not exist, and saved back at the end. What was found that is not a page
--  (pictures, films, sounds, other text files) is listed in BRAIN_FILE.finds.txt.
--
--  It mirrors reference/crawl.py: with the same arguments it writes the same.

with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Calipso.Alphabets;
with Calipso.Blind_Spots;
with Calipso.Brains;
with Calipso.Console;
with Calipso.Curl_Fetchers;
with Calipso.Neuron_Kinds;
with Calipso.Random_Sources;
with Calipso.Records;
with Calipso.Texts;
with Calipso.Web_Addresses;
with Calipso.Web_Sources;

procedure Calipso_Crawl is

    use Calipso;
    use type Blind_Spots.Exam_Result;
    use type Web_Addresses.Content_Kind;

    Default_Pages  : constant Natural := 20;
    Default_Recipe : constant String := "bias+position";
    Hiding_Seed    : constant Natural := 1_077;
    Save_Every     : constant Positive := 50;
    --# The brain is saved after every stretch of this many lessons, so that
    --# stopping the program half way loses little.

    Blanks : constant Ada.Strings.Maps.Character_Set :=
        Ada.Strings.Maps.To_Set (' ' & ASCII.HT & ASCII.CR);

    Bad_Argument : exception;

    function Percent_Image (
            Part  : in Natural;
            Whole : in Natural
            ) return String is
        Share : Long_Float;
        begin
        if Whole = 0 then
            return "  n/a";
            end if;
        Share := 100.0 * Long_Float (Part) / Long_Float (Whole);
        return Ada.Strings.Fixed.Tail (Console.Image (Share, 1), 5);
        end Percent_Image;

    procedure Make_Or_Load (
            Brain      : in out Brains.Brain;
            Brain_Name : in     String;
            Recipe     : in     String
            ) is
        begin
        if Ada.Directories.Exists (Brain_Name) then
            Brains.Load (Brain, Brain_Name);
            Console.Put_Line (
                "Brain: " & Brains.Recipe_Of (Brain) & " (loaded, "
                & Console.Image (Brains.Lessons_Studied (Brain)) & " lessons so far)"
                );
            return;
            end if;
        Brains.Prepare (Brain, Alphabets.Common_Letters);
        --# The pages are not known beforehand, so a new brain starts with the common letters.
        Brains.Add_Recipe (Brain, Recipe);
        Console.Put_Line ("Brain: " & Brains.Recipe_Of (Brain) & " (new)");
        end Make_Or_Load;

    procedure Add_Start_List (
            Source    : in out Web_Sources.Web_Source;
            List_Name : in     String
            ) is
        File : Ada.Text_IO.File_Type;
        begin
        Ada.Text_IO.Open (File, Ada.Text_IO.In_File, List_Name);
        while not Ada.Text_IO.End_Of_File (File) loop
            declare
                Address : constant String := Ada.Strings.Fixed.Trim (Ada.Text_IO.Get_Line (File), Blanks, Blanks);
                begin
                if Address /= "" and then Address (Address'First) /= '#' then
                    Web_Sources.Add_Address (Source, Address);
                    end if;
                end;
            end loop;
        Ada.Text_IO.Close (File);
        exception
        when Ada.Text_IO.Name_Error | Ada.Text_IO.Use_Error =>
            raise Texts.Reading_Error with "cannot read the list of addresses " & List_Name;
        end Add_Start_List;

    procedure Show_Tally (
            Source : in Web_Sources.Web_Source
            ) is
        use Ada.Strings.Unbounded;
        Counts : constant Web_Sources.Tally := Web_Sources.Tally_Of (Source);
        Line   : Unbounded_String := To_Unbounded_String ("Found and filed:");
        begin
        Console.Put_Line (
            "Pages: asked for " & Console.Image (Counts.Asked)
            & ", read " & Console.Image (Counts.Read)
            & " (" & Console.Image (Counts.Letters) & " letters). "
            & "Refused by the site's rules: " & Console.Image (Counts.Refused)
            & ". Not text after asking: " & Console.Image (Counts.Not_Text)
            & ". Failed: " & Console.Image (Counts.Failed) & "."
            );
        for Kind in Web_Addresses.Content_Kind loop
            if Kind /= Web_Addresses.Page then
                Append (Line, " " & Web_Addresses.Kind_Name (Kind) & " ");
                Append (Line, Console.Image (Web_Sources.Find_Count (Source, Kind)));
                if Kind = Web_Addresses.Content_Kind'Last then
                    Append (Line, ".");
                else
                    Append (Line, ",");
                    end if;
                end if;
            end loop;
        Console.Put_Line (To_String (Line));
        end Show_Tally;

    procedure Write_Finds (
            Source    : in Web_Sources.Web_Source;
            File_Name : in String
            ) is
        File : Ada.Text_IO.File_Type;
        begin
        Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, File_Name);
        for Kind in Web_Addresses.Content_Kind loop
            for Index in 1 .. Web_Sources.Find_Count (Source, Kind) loop
                Ada.Text_IO.Put_Line (File, Web_Addresses.Kind_Name (Kind) & " " & Web_Sources.Find (Source, Kind, Index));
                end loop;
            end loop;
        Ada.Text_IO.Close (File);
        end Write_Finds;

    procedure Study_And_Save (
            Brain      : in out Brains.Brain;
            Brain_Name : in     String;
            Source     : in out Web_Sources.Web_Source;
            Dice       : in out Random_Sources.Generator;
            Result     :    out Blind_Spots.Exam_Result
            ) is
        Stretch : Blind_Spots.Exam_Result;
        Before  : Natural;
        Studied : Natural;
        begin
        Result := (others => <>);
        loop
            Before := Brains.Lessons_Studied (Brain);
            Brains.Study (Brain, Source, Dice, Save_Every, Stretch);
            Studied := Brains.Lessons_Studied (Brain) - Before;
            Result := Result + Stretch;
            Brains.Save (Brain, Brain_Name);
            exit when Studied < Save_Every;
            --# A short stretch means the pages have run out.
            end loop;
        end Study_And_Save;
    --# Studies until the pages run out, saving the brain after every stretch.

    procedure Run_Crawl (
            Brain_Name : in String;
            List_Name  : in String;
            Most_Pages : in Natural;
            Recipe     : in String
            ) is
        Brain     : Brains.Brain;
        Options   : Web_Sources.Settings;
        Fetcher   : Curl_Fetchers.Curl_Fetcher;
        Source    : Web_Sources.Web_Source;
        Dice      : Random_Sources.Generator;
        Result    : Blind_Spots.Exam_Result;
        Before    : Natural;
        Surprise  : Long_Float;
        Work_File : constant String := Brain_Name & ".page";
        begin
        Make_Or_Load (Brain, Brain_Name, Recipe);
        Options.Page_Limit := Most_Pages;
        Web_Sources.Open (Source, Fetcher, Brains.Letters_Of (Brain), Options, Work_File);
        Add_Start_List (Source, List_Name);
        Dice := Random_Sources.Seeded (Hiding_Seed + Brains.Lessons_Studied (Brain));
        Before := Brains.Lessons_Studied (Brain);
        Study_And_Save (Brain, Brain_Name, Source, Dice, Result);
        Show_Tally (Source);
        Surprise := Blind_Spots.Mean_Surprise (Result);
        Console.Put_Line (
            "Studied " & Console.Image (Brains.Lessons_Studied (Brain) - Before) & " lessons. While studying: right "
            & Percent_Image (Result.Hits, Result.Hidden) & " %, mean surprise "
            & Console.Image (Surprise, 3) & " nats (" & Console.Image (Result.Hidden) & " letters)"
            );
        Console.Put_Line ("Lessons so far: " & Console.Image (Brains.Lessons_Studied (Brain)));
        Console.Put_Line ("Saved to " & Brain_Name);
        Write_Finds (Source, Brain_Name & ".finds.txt");
        Console.Put_Line ("Finds listed in " & Brain_Name & ".finds.txt");
        if Ada.Directories.Exists (Work_File) then
            Ada.Directories.Delete_File (Work_File);
            end if;
        end Run_Crawl;

    function Whole_Number (
            Word : in String
            ) return Natural is
        begin
        for Char of Word loop
            if Char not in '0' .. '9' then
                raise Bad_Argument with "the number of pages must be a whole number, 0 or greater";
                end if;
            end loop;
        return Natural'Value (Word);
        exception
        when Constraint_Error =>
            raise Bad_Argument with "the number of pages must be a whole number, 0 or greater";
        end Whole_Number;

    procedure Show_Usage is
        begin
        Console.Put_Line ("Usage:");
        Console.Put_Line ("   calipso_crawl BRAIN_FILE START_LIST [PAGES] [RECIPE]");
        end Show_Usage;

    procedure Crawl_Command is
        Count : constant Natural := Ada.Command_Line.Argument_Count;
        Most_Pages : Natural := Default_Pages;
        begin
        if Count >= 3 then
            Most_Pages := Whole_Number (Ada.Command_Line.Argument (3));
            end if;
        if Count >= 4 then
            Run_Crawl (Ada.Command_Line.Argument (1), Ada.Command_Line.Argument (2), Most_Pages, Ada.Command_Line.Argument (4));
        else
            Run_Crawl (Ada.Command_Line.Argument (1), Ada.Command_Line.Argument (2), Most_Pages, Default_Recipe);
            end if;
        end Crawl_Command;

    begin
    if Ada.Command_Line.Argument_Count >= 2 then
        Crawl_Command;
    else
        Show_Usage;
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        end if;
    exception
    when Problem : Texts.Reading_Error | Records.Record_Error | Neuron_Kinds.Recipe_Error | Bad_Argument =>
        Console.Put_Line ("Error: " & Ada.Exceptions.Exception_Message (Problem));
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
    end Calipso_Crawl;
