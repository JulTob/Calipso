"""Mirror of Calipso.Texts: go from a text file to a row of symbols."""

from . import alphabets

LINE_FEED = "\n"
CARRIAGE_RETURN = "\r"


class Reading_Error(Exception):
    pass


def For_Each_Character(
        file_name: str,
        visit
        ) -> None:
    #-- Walks the file letter by letter and calls `visit` with each one.
    #-- Every line ends in a line feed, the last one too.
    try:
        with open(file_name, encoding="utf-8", newline="") as file:
            content = file.read()
    except OSError as problem:
        raise Reading_Error(f"cannot open {file_name}: {problem}")
    except UnicodeDecodeError as problem:
        raise Reading_Error(f"{file_name} is not valid UTF-8: {problem}")
    lines = content.split(LINE_FEED)
    if len(lines) > 0 and lines[-1] == "":
        lines.pop()
    if len(lines) > 0 and lines[-1] == "":
        lines.pop()
        #-- Mirror note: Ada.Text_IO does not read one empty line at the very end of a file.
    for line in lines:
        for char in line:
            if char != CARRIAGE_RETURN:
                visit(char)
        visit(LINE_FEED)


def Learn_Alphabet(
        file_name: str,
        letters: alphabets.Alphabet
        ) -> None:
    #-- First pass: note every new letter, in order of appearance.
    def Note_Character(char):
        alphabets.Include(letters, char)

    For_Each_Character(file_name, Note_Character)


def Read_Symbols(
        file_name: str,
        letters: alphabets.Alphabet
        ) -> list:
    #-- Second pass: translate every letter into its symbol.
    text = []

    def Store_Character(char):
        symbol = alphabets.Symbol_Of(letters, char)
        text.append(symbol)

    For_Each_Character(file_name, Store_Character)
    return text


def Part(
        text: list,
        first: int,
        last: int
        ) -> list:
    #-- The piece of the text from `first` to `last` (both included), as a new text.
    return text[first:last + 1]


def Encoded(
        plain: str,
        letters: alphabets.Alphabet
        ) -> list:
    text = []
    for char in plain:
        symbol = alphabets.Symbol_Of(letters, char)
        text.append(symbol)
    return text


def Decoded(
        text: list,
        letters: alphabets.Alphabet
        ) -> str:
    plain = ""
    for symbol in text:
        plain = plain + alphabets.Character_Of(letters, symbol)
    return plain
