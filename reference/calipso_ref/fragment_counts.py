"""Mirror of Calipso.Fragment_Counts: how many times each small piece appears.

A fragment is a short piece of text (a few letters in a row).
The whole "memory" of the counting model is this table:
fragment -> number of times it was seen in the corpus.
"""


from . import records

HASH_START = 2166136261
HASH_PRIME = 16777619
HASH_MASK = (1 << 32) - 1
#-- FNV-1a recipe: a short, well-known way of turning a row
#-- of numbers into a single "scrambled" number for the table.
CHECK_START = 3141592653
#-- The same recipe from another starting number gives a second, different
#-- scrambled number: the "check number" of a fragment.


class Count_Table:

    def __init__(self):
        self.counts = {}
        #-- Exact memory. Key: the fragment as `bytes` (one byte per symbol). Value: times seen.
        self.capacity = 0
        #-- 0 = exact memory, which grows with the text. More than 0 = bounded memory:
        #-- a fixed number of counters, however much text is read.
        self.slots = []
        #-- Bounded memory: the count kept in each counter.
        self.checks = []
        #-- Bounded memory: the check number of the fragment each counter belongs to.


def Scrambled(
        piece: bytes,
        start: int
        ) -> int:
    result = start
    for value in piece:
        result = result ^ value
        result = (result * HASH_PRIME) & HASH_MASK
    return result


def Hash(
        piece: bytes
        ) -> int:
    return Scrambled(piece, HASH_START)


def Check_Of(
        piece: bytes
        ) -> int:
    return Scrambled(piece, CHECK_START)


def Limit(
        table: Count_Table,
        capacity: int
        ) -> None:
    #-- Empties the table and fixes its size.
    #--
    #-- With bounded memory each fragment has ONE counter where it may live,
    #-- chosen by its scrambled number. The counter also keeps the check number
    #-- of its owner, so that a fragment never seen is not mistaken for the
    #-- owner: it reads as 0, as it should.
    #--
    #-- When a newcomer finds its counter taken by another fragment, it knocks
    #-- one off the owner's count; when that count reaches 0 the newcomer takes
    #-- the counter. So what is seen often stays, and what was seen once, long
    #-- ago, makes room: the memory forgets instead of filling up.
    table.counts = {}
    table.capacity = capacity
    table.slots = [0] * capacity
    table.checks = [0] * capacity


def Slot_Of(
        table: Count_Table,
        piece: bytes
        ) -> int:
    return Hash(piece) % table.capacity


def Add_One_Bounded(
        table: Count_Table,
        piece: bytes
        ) -> None:
    slot = Slot_Of(table, piece)
    check = Check_Of(piece)
    if table.slots[slot] == 0:
        table.checks[slot] = check
        table.slots[slot] = 1
    elif table.checks[slot] == check:
        table.slots[slot] = table.slots[slot] + 1
    else:
        table.slots[slot] = table.slots[slot] - 1
        if table.slots[slot] == 0:
            table.checks[slot] = check
            table.slots[slot] = 1


def Count_Bounded(
        table: Count_Table,
        piece: bytes
        ) -> int:
    slot = Slot_Of(table, piece)
    if table.checks[slot] != Check_Of(piece):
        return 0
    return table.slots[slot]


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
    if table.capacity > 0:
        Add_One_Bounded(table, piece)
        return
    seen = table.counts.get(piece, 0)
    table.counts[piece] = seen + 1


def Count_Of(
        table: Count_Table,
        piece: bytes
        ) -> int:
    if table.capacity > 0:
        return Count_Bounded(table, piece)
    return table.counts.get(piece, 0)


def Distinct_Fragments(
        table: Count_Table
        ) -> int:
    #-- With bounded memory: how many counters are in use.
    if table.capacity > 0:
        used = 0
        for count in table.slots:
            if count > 0:
                used = used + 1
        return used
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


def Save(
        table: Count_Table,
        out
        ) -> None:
    #-- Bounded memory: the counters in use, each with its place, its check number and its count.
    #-- Exact memory: every fragment (its length, its symbols) and its count.
    records.Write_Count(out, table.capacity)
    if table.capacity > 0:
        records.Write_Count(out, Distinct_Fragments(table))
        for slot in range(0, table.capacity):
            if table.slots[slot] > 0:
                records.Write_Count(out, slot + 1)
                records.Write_Count(out, table.checks[slot])
                records.Write_Count(out, table.slots[slot])
        return
    records.Write_Count(out, len(table.counts))
    for piece, count in table.counts.items():
        records.Write_Count(out, len(piece))
        for value in piece:
            records.Write_Count(out, value)
        records.Write_Count(out, count)


def Load(
        table: Count_Table,
        source
        ) -> None:
    capacity = records.Read_Count(source)
    Limit(table, capacity)
    entries = records.Read_Count(source)
    for _ in range(0, entries):
        if capacity > 0:
            slot = records.Read_Count(source)
            table.checks[slot - 1] = records.Read_Count(source)
            table.slots[slot - 1] = records.Read_Count(source)
        else:
            length = records.Read_Count(source)
            values = []
            for _ in range(0, length):
                values.append(records.Read_Count(source))
            table.counts[bytes(values)] = records.Read_Count(source)
