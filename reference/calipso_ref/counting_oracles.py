"""Mirror of Calipso.Counting_Oracles: a brain that can only count.

Idea: to give an opinion on a hole, I look at a "window" of known letters
around it and ask the table:

    "Of all the times I saw this window in the corpus,
     which letter was in the place of the hole?"

I start with an empty window (just how frequent each letter is) and widen
it one neighbour at a time, alternating left and right. Each wider window
corrects the opinion of the previous one.
"""

from . import canvases
from . import distributions
from . import fragment_counts
from . import oracles

DEFAULT_LONGEST = 7
#-- Widest window: the hole plus 6 neighbours.


class Counting_Oracle(oracles.Oracle):

    def __init__(self):
        self.letter_count = 1
        self.longest = DEFAULT_LONGEST
        self.table = fragment_counts.Count_Table()

    def Alphabet_Size(self) -> int:
        return self.letter_count

    def Reach(self) -> int:
        return self.longest - 1

    def Opinion(
            self,
            board: canvases.Canvas,
            position: int
            ) -> distributions.Distribution:
        left_known = Known_Run(board, position, -1, self.longest - 1)
        right_known = Known_Run(board, position, +1, self.longest - 1)
        left_used = 0
        right_used = 0
        belief = distributions.Uniform(self.letter_count)
        #-- Before looking at anything, all letters are equally possible.
        while True:
            clue = Evidence(self, board, position, left_used, right_used)
            if distributions.Total(clue) == 0.0:
                break
                #-- This window was never seen: a wider one was not either. We stop.
            belief = Updated(belief, clue)
            window_length = left_used + 1 + right_used
            if window_length >= self.longest:
                break
            can_left = left_used < left_known
            can_right = right_used < right_known
            if not can_left and not can_right:
                break
            if Should_Widen_Left(can_left, can_right, left_used, right_used):
                left_used = left_used + 1
            else:
                right_used = right_used + 1
        return belief


def Prepare(
        model: Counting_Oracle,
        letter_count: int,
        longest: int = DEFAULT_LONGEST,
        capacity: int = 0
        ) -> None:
    #-- Leaves the brain blank. `capacity` 0 = exact memory; more = bounded memory.
    model.letter_count = letter_count
    model.longest = longest
    model.table = fragment_counts.Count_Table()
    fragment_counts.Limit(model.table, capacity)


def Study(
        model: Counting_Oracle,
        text: list
        ) -> None:
    #-- Adds what this text teaches to what the brain already knew.
    fragment_counts.Learn(model.table, text, model.longest)


def Train(
        model: Counting_Oracle,
        text: list,
        letter_count: int,
        longest: int = DEFAULT_LONGEST
        ) -> None:
    #-- "Training" this brain is just counting fragments.
    Prepare(model, letter_count, longest)
    Study(model, text)


def Known_Run(
        board: canvases.Canvas,
        position: int,
        direction: int,
        limit: int
        ) -> int:
    #-- How many cells with a letter sit right next to the hole, towards one side (-1 left, +1 right).
    run = 0
    while run < limit:
        neighbour = position + direction * (run + 1)
        if neighbour < 0:
            break
        if neighbour >= canvases.Length(board):
            break
        if canvases.Is_Blank(board, neighbour):
            break
        run = run + 1
    return run


def Should_Widen_Left(
        can_left: bool,
        can_right: bool,
        left_used: int,
        right_used: int
        ) -> bool:
    #-- Alternate sides; if only one side is possible, use that one.
    if not can_left:
        return False
    if not can_right:
        return True
    return left_used <= right_used


def Evidence(
        model: Counting_Oracle,
        board: canvases.Canvas,
        position: int,
        left_used: int,
        right_used: int
        ) -> distributions.Distribution:
    #-- For each candidate letter: how many times the window was seen with that letter in the hole.
    left_part = []
    for offset in range(left_used, 0, -1):
        left_part.append(canvases.Symbol_At(board, position - offset))
    right_part = []
    for offset in range(1, right_used + 1):
        right_part.append(canvases.Symbol_At(board, position + offset))
    clue = distributions.Zero(model.letter_count)
    for candidate in range(1, model.letter_count + 1):
        window = bytes(left_part + [candidate] + right_part)
        seen = fragment_counts.Count_Of(model.table, window)
        distributions.Set_Weight(clue, candidate, float(seen))
    return clue


def Updated(
        belief: distributions.Distribution,
        clue: distributions.Distribution
        ) -> distributions.Distribution:
    #-- Mixes the previous opinion with the new evidence.
    #-- The previous opinion is worth as many "observations" as different letters
    #-- were seen in this window: if all sorts of letters followed this context,
    #-- I trust it less and trust what I already thought more.
    prior_strength = float(distributions.Variety(clue))
    mixed = clue + prior_strength * belief
    return distributions.Normalized(mixed)
