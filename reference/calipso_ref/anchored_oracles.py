"""Mirror of Calipso.Anchored_Oracles: a brain that remembers what the cell had.

A boxed oracle obeys hard rules: a symbol is allowed or it is not. An anchored
oracle obeys a soft one: "this cell had the symbol H, and I am this sure it was
right". The brain's opinion and that memory are multiplied together:

    sure = 1      the cell keeps H whatever the brain thinks      (like a Given cell)
    sure = 1/N    the memory says nothing, the brain decides      (like a Blank cell)
    sure = 0      anything but H                                  ("surely wrong")

In between, the certainty is a price: how strongly the neighbours must disagree
before the cell changes.
"""

from . import UNKNOWN
from . import canvases
from . import certainties
from . import distributions
from . import oracles


class Anchor:

    def __init__(self):
        self.is_free = True
        #-- Free: nothing is remembered for this cell, the opinion passes untouched.
        self.held = UNKNOWN
        #-- The symbol the cell had.
        self.sure = 1.0
        #-- The chance that `held` is right, from 0 to 1.


def Free_Anchor() -> Anchor:
    return Anchor()


def Anchor_Of(
        held: int,
        sure: float
        ) -> Anchor:
    anchor = Anchor()
    anchor.is_free = False
    anchor.held = held
    anchor.sure = sure
    return anchor


def Signed_Anchor_Of(
        held: int,
        signed: float,
        size: int
        ) -> Anchor:
    #-- The same anchor, said on the scale from -1 to 1.
    return Anchor_Of(held, certainties.Certainty_Of(signed, size))


def Memory_Alone(
        toward: Anchor,
        size: int
        ) -> distributions.Distribution:
    #-- What the memory of the cell says, with no brain: `sure` for the held symbol, the rest shared out.
    others = (1.0 - toward.sure) / float(size - 1)
    memory = distributions.Zero(size)
    for symbol in range(1, size + 1):
        if symbol == toward.held:
            distributions.Set_Weight(memory, symbol, toward.sure)
        else:
            distributions.Set_Weight(memory, symbol, others)
    return memory


def Pulled(
        belief: distributions.Distribution,
        toward: Anchor
        ) -> distributions.Distribution:
    #-- The brain's opinion and the memory of the cell, multiplied symbol by symbol.
    if toward.is_free or belief.size < 2:
        return belief
    memory = Memory_Alone(toward, belief.size)
    joined = distributions.Zero(belief.size)
    for symbol in range(1, belief.size + 1):
        distributions.Set_Weight(
            joined,
            symbol,
            distributions.Weight_Of(memory, symbol) * distributions.Weight_Of(belief, symbol)
            )
    if distributions.Total(joined) == 0.0:
        return distributions.Normalized(memory)
        #-- The brain gives no chance to anything the memory allows: the memory decides alone.
    return distributions.Normalized(joined)


class Anchored_Oracle(oracles.Oracle):

    def __init__(
            self,
            inner: oracles.Oracle,
            anchors: list
            ):
        self.inner = inner
        self.anchors = anchors

    def Alphabet_Size(self) -> int:
        return self.inner.Alphabet_Size()

    def Reach(self) -> int:
        return self.inner.Reach()

    def Opinion(
            self,
            board: canvases.Canvas,
            position: int
            ) -> distributions.Distribution:
        belief = self.inner.Opinion(board, position)
        if position >= len(self.anchors):
            return belief
        return Pulled(belief, self.anchors[position])
