"""Mirror of Calipso.Sources: where the text to study comes from.

A source hands out text one PIECE at a time. The brain never needs the whole
text at once, so a source can be far bigger than memory: a huge file today,
a list of pages to follow tomorrow.

  Memory_Source : pieces taken at random from a text held in memory.
  File_Source   : a file read from start to end, never loaded whole.
"""

from . import alphabets
from . import random_sources
from . import texts

LINE_FEED = "\n"
CARRIAGE_RETURN = "\r"


class Source:

    def Next_Piece(self) -> tuple:
        #-- Returns (piece, found). `found` is False when the source has run dry.
        raise NotImplementedError


class Memory_Source(Source):

    def __init__(self):
        self.text = []
        self.piece_length = 1
        self.dice = random_sources.Seeded(0)

    def Next_Piece(self) -> tuple:
        room = len(self.text) - self.piece_length
        start = random_sources.Draw_Index(self.dice, room)
        piece = texts.Part(self.text, start, start + self.piece_length - 1)
        return piece, True
        #-- This source never runs dry: it can always draw another piece.


def Open_Memory(
        source: Memory_Source,
        text: list,
        piece_length: int,
        seed: int
        ) -> None:
    if len(text) <= piece_length:
        raise ValueError("the text is shorter than one piece")
    source.text = text
    source.piece_length = piece_length
    source.dice = random_sources.Seeded(seed)


class File_Source(Source):

    def __init__(self):
        self.file = None
        self.letters = None
        self.piece_length = 1
        self.buffer = []
        #-- Symbols already read from the file and not handed out yet.
        self.finished = True
        self.waiting = ""
        #-- The next line of the file, read one step ahead.

    def Next_Piece(self) -> tuple:
        while len(self.buffer) < self.piece_length and not self.finished:
            Read_One_Line(self)
        if len(self.buffer) < self.piece_length:
            return [], False
            #-- What is left is shorter than a piece: it is dropped.
        piece = self.buffer[:self.piece_length]
        self.buffer = self.buffer[self.piece_length:]
        return piece, True


def Open_File(
        source: File_Source,
        file_name: str,
        letters: alphabets.Alphabet,
        piece_length: int
        ) -> None:
    try:
        source.file = open(file_name, encoding="utf-8", newline="")
    except OSError as problem:
        raise texts.Reading_Error(f"cannot open {file_name}: {problem}")
    source.letters = letters
    source.piece_length = piece_length
    source.buffer = []
    source.finished = False
    source.waiting = source.file.readline()


def Close_File(
        source: File_Source
        ) -> None:
    if source.file is not None:
        source.file.close()
    source.file = None
    source.finished = True


def Read_One_Line(
        source: File_Source
        ) -> None:
    #-- Moves one line of the file into the buffer, as symbols.
    line = source.waiting
    source.waiting = source.file.readline()
    if line == "":
        source.finished = True
        return
    if line == LINE_FEED and source.waiting == "":
        source.finished = True
        return
        #-- Mirror note: Ada.Text_IO does not read one empty line at the very end of a file.
    for char in line:
        if char != CARRIAGE_RETURN and char != LINE_FEED:
            source.buffer.append(alphabets.Symbol_Of(source.letters, char))
    source.buffer.append(alphabets.Symbol_Of(source.letters, LINE_FEED))
