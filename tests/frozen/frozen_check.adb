--  Checks that a brain compiled into the program is the same brain as the
--  one loaded from its file, and times both ways of getting it into memory.
--
--  Usage:
--     frozen_check BRAIN_FILE
--
--  BRAIN_FILE must be the same file that was compiled in as Frozen_Brain.

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Real_Time;

with Calipso.Alphabets;
with Calipso.Brains;
with Calipso.Canvases;
with Calipso.Console;
with Calipso.Distributions;
with Calipso.Records;
with Calipso.Templates;

with Frozen_Brain;

procedure Frozen_Check is

    use Calipso;
    use type Ada.Real_Time.Time;

    Probe : constant Wide_Wide_String := "la c_sa de l_ r_sa es l_ c_sta";
    --# A line with holes. Both brains are asked about every hole.

    function Milliseconds (
            Start : in Ada.Real_Time.Time;
            Stop  : in Ada.Real_Time.Time
            ) return String is
        Span : constant Duration := Ada.Real_Time.To_Duration (Stop - Start);
        begin
        return Console.Image (Long_Float (Span) * 1000.0, 1) & " ms";
        end Milliseconds;

    function Same_Opinions (
            Compiled : in Brains.Brain;
            Loaded   : in Brains.Brain
            ) return Boolean is
        Letters : constant Alphabets.Alphabet := Brains.Letters_Of (Loaded);
        Board   : constant Canvases.Canvas := Templates.Parsed (Probe, Letters);
        begin
        for Position in 1 .. Canvases.Length (Board) loop
            if Canvases.Is_Blank (Board, Position) then
                declare
                    From_Program : constant Distributions.Distribution := Compiled.Opinion (Board, Position);
                    From_File    : constant Distributions.Distribution := Loaded.Opinion (Board, Position);
                    begin
                    for Candidate in Symbol range 1 .. From_File.Size loop
                        if Distributions.Probability_Of (From_Program, Candidate)
                                /= Distributions.Probability_Of (From_File, Candidate) then
                            return False;
                            end if;
                        end loop;
                    end;
                end if;
            end loop;
        return True;
        end Same_Opinions;

    procedure Check (
            File_Name : in String
            ) is
        Compiled : Brains.Brain;
        Loaded   : Brains.Brain;
        Start    : Ada.Real_Time.Time;
        Middle   : Ada.Real_Time.Time;
        Stop     : Ada.Real_Time.Time;
        Same     : Boolean;
        begin
        Start := Ada.Real_Time.Clock;
        Brains.Load (Loaded, File_Name);
        Middle := Ada.Real_Time.Clock;
        Brains.Thaw (Compiled, Frozen_Brain.Words, Frozen_Brain.Numbers);
        Stop := Ada.Real_Time.Clock;
        Console.Put_Line (
            "Brain: " & Brains.Recipe_Of (Loaded) & ", " & Console.Image (Brains.Lessons_Studied (Loaded))
            & " lessons, " & Console.Image (Frozen_Brain.Numbers'Length) & " numbers."
            );
        Console.Put_Line ("Into memory from the file:    " & Milliseconds (Start, Middle));
        Console.Put_Line ("Into memory from the program: " & Milliseconds (Middle, Stop));
        Same := Brains.Recipe_Of (Compiled) = Brains.Recipe_Of (Loaded)
            and then Brains.Lessons_Studied (Compiled) = Brains.Lessons_Studied (Loaded)
            and then Same_Opinions (Compiled, Loaded);
        if Same then
            Console.Put_Line ("The brain inside the program and the brain in the file give the same answers.");
        else
            Console.Put_Line ("DIFFERENT: the brain inside the program is not the brain in the file.");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            end if;
        end Check;

    begin
    if Ada.Command_Line.Argument_Count /= 1 then
        Console.Put_Line ("Usage: frozen_check BRAIN_FILE");
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        return;
        end if;
    Check (Ada.Command_Line.Argument (1));
    exception
    when Problem : Records.Record_Error =>
        Console.Put_Line ("Error: " & Ada.Exceptions.Exception_Message (Problem));
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
    end Frozen_Check;
