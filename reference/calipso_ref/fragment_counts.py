"""Mirror of Calipso.Fragment_Counts: how many times each small piece appears.

A fragment is a short piece of text (a few letters in a row).
The whole "memory" of the counting model is this table:
fragment -> number of times it was seen in the corpus.
"""


class Count_Table:

    def __init__(self):
        self.counts = {}
        #-- Key: the fragment as `bytes` (one byte per symbol). Value: times seen.


def Slice(
        text: list,
        first: int,
        length: int
        ) -> bytes:
    #-- The fragment of `length` symbols that starts at `first`.
    piece = text[first:first + length]
    return bytes(piece)


def Add_One(
        table: Count_Table,
        piece: bytes
        ) -> None:
    seen = table.counts.get(piece, 0)
    table.counts[piece] = seen + 1


def Count_Of(
        table: Count_Table,
        piece: bytes
        ) -> int:
    return table.counts.get(piece, 0)


def Distinct_Fragments(
        table: Count_Table
        ) -> int:
    return len(table.counts)


def Learn(
        table: Count_Table,
        text: list,
        longest: int
        ) -> None:
    #-- Walks the text and notes every fragment from 1 to `longest` letters.
    last = len(text) - 1
    for start in range(0, last + 1):
        for length in range(1, longest + 1):
            if start + length - 1 > last:
                break
            piece = Slice(text, start, length)
            Add_One(table, piece)
