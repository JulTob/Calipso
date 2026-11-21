--  How a brain is written down: the tape, and the brain file.
--
--  Everything a brain knows is written, in order, onto a TAPE: a list of short
--  words ("bias", "position") and a list of numbers. Reading the tape back in
--  the same order gives the same brain.
--
--  A tape can be kept in a file. That file (a ".brn" file) is two things at once:
--
--     data : Calipso reads it line by line when a brain is loaded. No compiler
--            is involved, and the brain can go on learning and be saved again.
--
--     Ada  : the same file is the specification of an Ada package that holds
--            two constants, Words and Numbers. It can be compiled into a
--            program, and the brain is then inside the program itself (Fill).
--
--  The file is written by Calipso in a fixed layout, one item per line, so
--  that reading it as data needs no knowledge of Ada.
--
--  A tape can also be kept PACKED, in a ".zmb" file: the same words and numbers
--  as raw bytes instead of written-out text. It is several times smaller and
--  nothing is lost, but it cannot be read by eye or compiled. Use .brn to read
--  and to compile; use .zmb to store and to send.
--
--     4 bytes       the letters Z M B 1
--     whole number  how many words; then each word: its length, its letters
--     whole number  how many numbers; then each number:
--                      byte 0, then a whole number         (a count)
--                      byte 1, then the 8 bytes of a real  (anything else)
--
--  A whole number takes as few bytes as it needs: 7 bits in each byte, lowest
--  first, and the top bit of a byte says "there is more". The 8 bytes of a real
--  are the number as the machine keeps it (IEEE 754), lowest byte first.

with Ada.Containers.Indefinite_Vectors;

with Calipso.Numbers;

package Calipso.Records is

    Record_Error : exception;
    --# The file is missing, ends too soon, or does not hold what was expected.

    Word_Length : constant := 16;

    subtype Word is String (1 .. Word_Length);
    --# A word of the tape, with spaces after it up to its fixed length.

    type Word_List is array (Positive range <>) of Word;
    type Number_List is array (Positive range <>) of Long_Float;
    --# The shapes of the two constants a brain file declares.

    type Tape is private;
    --# A newly declared tape is empty.

    procedure Write_Word (
            Onto : in out Tape;
            Item : in     String
            )
        with Pre => Item'Length in 1 .. Word_Length;

    procedure Write_Count (
            Onto  : in out Tape;
            Count : in     Natural
            );

    procedure Write_Real (
            Onto  : in out Tape;
            Value : in     Long_Float
            );

    procedure Write_Reals (
            Onto   : in out Tape;
            Values : in     Numbers.Real_Row
            );
    --# A long row is written "sparse": only the entries that are not zero,
    --# each with its position.

    function Read_Word (
            From : in out Tape
            ) return String;
    --# The reading operations are functions for convenience, although each one
    --# moves the tape forward. Use one per statement.

    function Read_Count (
            From : in out Tape
            ) return Natural;

    function Read_Real (
            From : in out Tape
            ) return Long_Float;

    function Read_Reals (
            From : in out Tape
            ) return Numbers.Real_Row;

    procedure Expect_Word (
            From   : in out Tape;
            Wanted : in     String
            );

    procedure Save (
            Self      : in Tape;
            File_Name : in String
            );
    --# Writes the tape as a brain file: packed if the name ends in .zmb, and as
    --# text that is also Ada for any other name.
    --# Raises Record_Error if it cannot be written.

    procedure Load (
            Self      :    out Tape;
            File_Name : in     String
            );
    --# Reads a brain file as data, text or packed: its first four bytes say which.
    --# Raises Record_Error if it is missing or damaged.

    function Is_Packed_Name (
            File_Name : in String
            ) return Boolean;
    --# Does the name end in .zmb?

    procedure Fill (
            Self         :    out Tape;
            From_Words   : in     Word_List;
            From_Numbers : in     Number_List
            );
    --# Takes the tape from the two constants of a brain file that was compiled
    --# into the program.

    function Unit_Name_For (
            File_Name : in String
            ) return String;
    --# The name of the Ada package a brain file declares: "brains/page.brn" -> "Page_Brain".

private

    package Word_Vectors is new Ada.Containers.Indefinite_Vectors (
            Index_Type   => Positive,
            Element_Type => String
            );

    type Tape is record
        Words     : Word_Vectors.Vector;
        Reals     : Numbers.Real_Row;
        Next_Word : Positive := 1;
        Next_Real : Positive := 1;
        --# Where the next reading takes from.
        end record;

    end Calipso.Records;
