"""Mirror of Calipso.Records: write and read saved brains as plain text.

A saved brain is a text file with ONE item per line: a word, a whole number
or a real number. Dull on purpose: any editor can open it, and Ada and
Python read each other's files.

Real numbers are written with 17 significant digits, which is enough to get
back exactly the same number. A long row of numbers is saved "sparse": only
the entries that are not zero, each with its position.
"""


class Record_Error(Exception):
    pass


def Write_Word(
        out,
        word: str
        ) -> None:
    out.write(word + "\n")


def Write_Count(
        out,
        count: int
        ) -> None:
    out.write(str(count) + "\n")


def Write_Real(
        out,
        value: float
        ) -> None:
    out.write(f"{value:.16E}\n")


def Write_Reals(
        out,
        values: list
        ) -> None:
    #-- `values` counts from 0 here; positions are saved counting from 1, as in Ada.
    filled = 0
    for value in values:
        if value != 0.0:
            filled = filled + 1
    Write_Count(out, len(values))
    Write_Count(out, filled)
    for index in range(0, len(values)):
        if values[index] != 0.0:
            Write_Count(out, index + 1)
            Write_Real(out, values[index])


def Read_Word(
        source
        ) -> str:
    line = source.readline()
    if line == "":
        raise Record_Error("the file ends too soon")
    return line.strip()


def Read_Count(
        source
        ) -> int:
    word = Read_Word(source)
    try:
        return int(word)
    except ValueError:
        raise Record_Error("expected a whole number, found: " + word)


def Read_Real(
        source
        ) -> float:
    word = Read_Word(source)
    try:
        return float(word)
    except ValueError:
        raise Record_Error("expected a real number, found: " + word)


def Read_Reals(
        source
        ) -> list:
    length = Read_Count(source)
    filled = Read_Count(source)
    values = [0.0] * length
    for _ in range(0, filled):
        index = Read_Count(source)
        values[index - 1] = Read_Real(source)
    return values


def Expect_Word(
        source,
        wanted: str
        ) -> None:
    found = Read_Word(source)
    if found != wanted:
        raise Record_Error("expected " + wanted + ", found: " + found)
