"""Mirror of Calipso.Records: how a brain is written down.

Everything a brain knows is written, in order, onto a TAPE: a list of short
words ("bias", "position") and a list of numbers. Reading the tape back in
the same order gives the same brain.

A tape can be kept in a file. That file (a ".brn" file) is two things at once:

   data : it is read line by line when a brain is loaded.
   Ada  : the same file is the specification of an Ada package that holds two
          constants, Words and Numbers, so it can be compiled into an Ada program.

Mirror note: Python only uses the file as data.
"""

import math
import os

WORD_LENGTH = 16
TAPE_MARK = "calipso-tape"
END_MARK = "end"
#-- The first and the last word of every brain file.
TAPE_VERSION = 1.0
#-- The first number of every brain file. The last one says how many numbers there are.
LARGEST_WHOLE = 1.0E15
UNIT_ENDING = "_Brain"
QUOTE = '"'


class Record_Error(Exception):
    pass


class Tape:

    def __init__(self):
        self.words = []
        self.reals = []
        self.next_word = 0
        self.next_real = 0
        #-- Where the next reading takes from.


def Write_Word(
        onto: Tape,
        item: str
        ) -> None:
    if len(item) < 1 or len(item) > WORD_LENGTH:
        raise ValueError("a word of the tape must have 1 to 16 letters")
    onto.words.append(item)


def Write_Count(
        onto: Tape,
        count: int
        ) -> None:
    onto.reals.append(float(count))


def Write_Real(
        onto: Tape,
        value: float
        ) -> None:
    onto.reals.append(value)


def Write_Reals(
        onto: Tape,
        values: list
        ) -> None:
    #-- A long row is written "sparse": only the entries that are not zero, each with its position.
    filled = 0
    for value in values:
        if value != 0.0:
            filled = filled + 1
    Write_Count(onto, len(values))
    Write_Count(onto, filled)
    for index in range(0, len(values)):
        if values[index] != 0.0:
            Write_Count(onto, index + 1)
            Write_Real(onto, values[index])


def Read_Word(
        source: Tape
        ) -> str:
    if source.next_word >= len(source.words):
        raise Record_Error("the record ends too soon")
    source.next_word = source.next_word + 1
    return source.words[source.next_word - 1]


def Read_Real(
        source: Tape
        ) -> float:
    if source.next_real >= len(source.reals):
        raise Record_Error("the record ends too soon")
    source.next_real = source.next_real + 1
    return source.reals[source.next_real - 1]


def Is_Whole(
        value: float
        ) -> bool:
    if abs(value) >= LARGEST_WHOLE:
        return False
    return math.floor(value) == value


def Read_Count(
        source: Tape
        ) -> int:
    value = Read_Real(source)
    if value < 0.0 or not Is_Whole(value):
        raise Record_Error("expected a whole number")
    return int(value)


def Read_Reals(
        source: Tape
        ) -> list:
    length = Read_Count(source)
    filled = Read_Count(source)
    values = [0.0] * length
    for _ in range(0, filled):
        index = Read_Count(source)
        value = Read_Real(source)
        if index == 0 or index > length:
            raise Record_Error("a number is filed outside its row")
        values[index - 1] = value
    return values


def Expect_Word(
        source: Tape,
        wanted: str
        ) -> None:
    found = Read_Word(source)
    if found != wanted:
        raise Record_Error(f"expected {wanted}, found: {found}")


def Padded(
        item: str
        ) -> str:
    return item + " " * (WORD_LENGTH - len(item))


def Image(
        value: float
        ) -> str:
    #-- The number as Ada writes it: whole numbers as 144.0, the others with 17
    #-- significant digits, which is enough to get back exactly the same number.
    if math.isnan(value) or math.isinf(value):
        raise Record_Error("the brain holds a number that is not finite")
    if Is_Whole(value):
        if value == 0.0 and math.copysign(1.0, value) < 0.0:
            return "-0.0"
        return f"{int(value)}.0"
    return f"{value:.16E}"


def Unit_Name_For(
        file_name: str
        ) -> str:
    #-- The name of the Ada package a brain file declares: "brains/page.brn" -> "Page_Brain".
    simple = os.path.basename(file_name)
    dot = simple.rfind(".")
    stem = simple
    if dot >= 0:
        stem = simple[:dot]
    name = ""
    new_part = True
    for char in stem:
        if "a" <= char <= "z" or "A" <= char <= "Z":
            if new_part and "a" <= char <= "z":
                name = name + chr(ord(char) - 32)
            else:
                name = name + char
            new_part = False
        elif "0" <= char <= "9" and name != "":
            name = name + char
            new_part = False
        elif not new_part:
            name = name + "_"
            new_part = True
    if name == "":
        return "Saved" + UNIT_ENDING
    if new_part:
        return name[:-1] + UNIT_ENDING
    return name + UNIT_ENDING


def Save(
        tape: Tape,
        file_name: str
        ) -> None:
    unit = Unit_Name_For(file_name)
    lines = [
        "--  A Calipso brain.",
        "--",
        "--  This file is two things at once:",
        "--     data : Calipso reads it line by line when the brain is loaded.",
        "--     Ada  : it is the specification of a package, so it can also be",
        "--            compiled into a program.",
        "--  It is written by Calipso. Do not edit it by hand.",
        "",
        "with Calipso.Records;",
        "",
        f"package {unit} is",
        "",
        "    Words : constant Calipso.Records.Word_List := (",
        ]
    items = [TAPE_MARK] + tape.words + [END_MARK]
    for index in range(0, len(items)):
        lead = "          " if index == 0 else "        , "
        lines.append(lead + QUOTE + Padded(items[index]) + QUOTE)
    lines.append("        );")
    lines.append("")
    lines.append("    Numbers : constant Calipso.Records.Number_List := (")
    figures = [TAPE_VERSION] + tape.reals + [float(len(tape.reals))]
    for index in range(0, len(figures)):
        lead = "          " if index == 0 else "        , "
        lines.append(lead + Image(figures[index]))
    lines.append("        );")
    lines.append("")
    lines.append(f"    end {unit};")
    try:
        with open(file_name, "w", encoding="utf-8", newline="\n") as out:
            out.write("\n".join(lines) + "\n")
    except OSError:
        raise Record_Error(f"cannot write the file {file_name}")


def Take_Line(
        tape: Tape,
        line: str
        ) -> None:
    bare = line.strip(" \t\r")
    if bare == "" or bare.startswith("--"):
        return
        #-- An empty line or a comment.
    item = bare
    if item.startswith(","):
        item = item[1:].strip(" \t\r")
    if item == "":
        return
    first = item[0]
    if first == QUOTE:
        stop = item.rfind(QUOTE)
        if stop <= 0:
            raise Record_Error("a word of the brain file is not closed: " + item)
        tape.words.append(item[1:stop].rstrip(" "))
    elif "0" <= first <= "9" or first == "-":
        try:
            tape.reals.append(float(item))
        except ValueError:
            raise Record_Error("expected a number, found: " + item)
    #-- Any other line belongs to the Ada wrapping and says nothing as data.


def Remove_Frame(
        tape: Tape
        ) -> None:
    #-- Checks the marks that open and close the two lists, and takes them away.
    if len(tape.words) < 2 or len(tape.reals) < 2:
        raise Record_Error("this is not a brain file")
    if tape.words[0] != TAPE_MARK or tape.reals[0] != TAPE_VERSION:
        raise Record_Error("this is not a brain file, or it is of a version I do not know")
    if tape.words[-1] != END_MARK or tape.reals[-1] != float(len(tape.reals) - 2):
        raise Record_Error("the brain file is cut short or damaged")
    tape.words = tape.words[1:-1]
    tape.reals = tape.reals[1:-1]
    tape.next_word = 0
    tape.next_real = 0


def Load(
        file_name: str
        ) -> Tape:
    tape = Tape()
    try:
        with open(file_name, encoding="utf-8") as source:
            for line in source:
                Take_Line(tape, line.rstrip("\n"))
    except OSError:
        raise Record_Error(f"cannot open the file {file_name}")
    Remove_Frame(tape)
    return tape
