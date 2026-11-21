"""Mirror of Calipso.Templates: write and read canvases as text.

Template notation:

  _        a hole of one cell
  [25]     a hole of 25 cells
  [...]    a hole of the default size (the single ellipsis character works too)
  \\n       a line break (paragraph boundary)
  everything else is given letters, as they are
"""

from . import alphabets
from . import canvases

BLANK_MARK = "_"
HOLE_OPENING = "["
HOLE_CLOSING = "]"
ESCAPE_MARK = "\\"
NEW_LINE_LETTER = "n"
LINE_FEED = "\n"
DEFAULT_HOLE = 30
LARGEST_HOLE = 10000


def Is_Digit(
        char: str
        ) -> bool:
    return "0" <= char <= "9"


def Number_In(
        inside: str
        ) -> int:
    #-- Turns "25" into 25. Returns 0 if it is not only digits or if it is too large.
    if len(inside) == 0:
        return 0
    value = 0
    for char in inside:
        if not Is_Digit(char):
            return 0
        value = value * 10 + (ord(char) - ord("0"))
        if value > LARGEST_HOLE:
            return 0
    return value


def Hole_Size(
        inside: str
        ) -> int:
    #-- Size of the hole described by the text between brackets. 0 = it is not a hole.
    if inside == "...":
        return DEFAULT_HOLE
    if inside == "…":
        return DEFAULT_HOLE
    return Number_In(inside)


def Closing_Of(
        template: str,
        opening: int
        ) -> int:
    #-- Position of the closing bracket. -1 if there is none.
    for position in range(opening + 1, len(template)):
        if template[position] == HOLE_CLOSING:
            return position
    return -1


def Append_Blanks(
        board: canvases.Canvas,
        count: int
        ) -> None:
    for _ in range(0, count):
        canvases.Append_Blank(board)


def Append_Letter(
        board: canvases.Canvas,
        letters: alphabets.Alphabet,
        char: str
        ) -> None:
    symbol = alphabets.Symbol_Of(letters, char)
    canvases.Append_Given(board, symbol)


def Is_New_Line_Escape(
        template: str,
        position: int
        ) -> bool:
    if template[position] != ESCAPE_MARK:
        return False
    if position + 1 >= len(template):
        return False
    return template[position + 1] == NEW_LINE_LETTER


def Parsed(
        template: str,
        letters: alphabets.Alphabet
        ) -> canvases.Canvas:
    board = canvases.Canvas()
    position = 0
    while position < len(template):
        char = template[position]
        closing = -1
        size = 0
        if char == HOLE_OPENING:
            closing = Closing_Of(template, position)
        if closing >= 0:
            size = Hole_Size(template[position + 1:closing])
        if size > 0:
            Append_Blanks(board, size)
            position = closing + 1
        elif char == BLANK_MARK:
            canvases.Append_Blank(board)
            position = position + 1
        elif Is_New_Line_Escape(template, position):
            Append_Letter(board, letters, LINE_FEED)
            position = position + 2
        else:
            Append_Letter(board, letters, char)
            position = position + 1
    return board


def From_Text(
        text: list,
        first: int,
        length: int
        ) -> canvases.Canvas:
    #-- A canvas with a piece of real text, all of it as given letters.
    board = canvases.Canvas()
    for position in range(first, first + length):
        canvases.Append_Given(board, text[position])
    return board


def Is_Model_Cell(
        board: canvases.Canvas,
        position: int
        ) -> bool:
    #-- Is this a cell the person did NOT give (a hole or a decided letter)?
    if position < 0:
        return False
    if position >= canvases.Length(board):
        return False
    return canvases.State_At(board, position) != canvases.GIVEN


def Rendered(
        board: canvases.Canvas,
        letters: alphabets.Alphabet,
        mark_guesses: bool = False
        ) -> str:
    #-- With `mark_guesses`, what the model wrote comes out in brackets.
    plain = ""
    for position in range(0, canvases.Length(board)):
        is_model = Is_Model_Cell(board, position)
        before_is_model = Is_Model_Cell(board, position - 1)
        after_is_model = Is_Model_Cell(board, position + 1)
        if mark_guesses and is_model and not before_is_model:
            plain = plain + HOLE_OPENING
        if canvases.Is_Blank(board, position):
            plain = plain + BLANK_MARK
        else:
            symbol = canvases.Symbol_At(board, position)
            plain = plain + alphabets.Character_Of(letters, symbol)
        if mark_guesses and is_model and not after_is_model:
            plain = plain + HOLE_CLOSING
    return plain
