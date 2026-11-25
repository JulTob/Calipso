"""Mirror of Calipso.Tokens: a text read as the pieces a reader takes whole.

    Word   : a run of letters             "casa"
    Number : a run of digits              "1704"
    Mark   : one sign, alone              "."  ","  "("
    Break  : the end of a paragraph (a blank line between two lines of text)

Blanks between tokens are not tokens: they are put back when the text is written.
"""

WORD = 0
NUMBER = 1
MARK = 2
BREAK = 3

LINE_FEED = "\n"
BREAK_TEXT = LINE_FEED
#-- How a Break is written as a token.

LAST_BLANK_CODE = 32
NO_BREAK_SPACE_CODE = 160
FEEDS_IN_A_BREAK = 2


def Is_Letter(
        char: str
        ) -> bool:
    return char.isalpha()


def Is_Digit(
        char: str
        ) -> bool:
    return "0" <= char <= "9"


def Is_Blank(
        char: str
        ) -> bool:
    #-- Spaces, tabs and ends of line: what separates tokens.
    return ord(char) <= LAST_BLANK_CODE or ord(char) == NO_BREAK_SPACE_CODE


def Sort_Of(
        token: str
        ) -> int:
    first = token[0]
    if Is_Letter(first):
        return WORD
    if Is_Digit(first):
        return NUMBER
    if first == LINE_FEED:
        return BREAK
    return MARK


def Run_End(
        text: str,
        start: int,
        belongs
        ) -> int:
    #-- The last position of the run of characters of one sort that begins at `start`.
    last = start
    while last + 1 < len(text) and belongs(text[last + 1]):
        last = last + 1
    return last


def Feeds_In(
        text: str,
        first: int,
        last: int
        ) -> int:
    #-- How many line feeds there are from `first` to `last`.
    count = 0
    for position in range(first, last + 1):
        if text[position] == LINE_FEED:
            count = count + 1
    return count


def Split(
        text: str
        ) -> list:
    found = []
    position = 0
    while position < len(text):
        char = text[position]
        if Is_Letter(char):
            last = Run_End(text, position, Is_Letter)
            found.append(text[position:last + 1])
        elif Is_Digit(char):
            last = Run_End(text, position, Is_Digit)
            found.append(text[position:last + 1])
        elif Is_Blank(char):
            last = Run_End(text, position, Is_Blank)
            if Feeds_In(text, position, last) >= FEEDS_IN_A_BREAK:
                found.append(BREAK_TEXT)
        else:
            last = position
            found.append(char)
        position = last + 1
    return found
