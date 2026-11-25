"""Mirror of Calipso.Boxed_Oracles: a brain that obeys the level above.

The level above does not choose letters. It says, cell by cell, which letters
are ALLOWED ("only small letters here", "only digits there"). This oracle asks
another one for its opinion and removes what is not allowed.
"""

from . import MAX_SYMBOLS
from . import canvases
from . import distributions
from . import oracles


class Cell_Rule:

    def __init__(self):
        self.is_free = True
        #-- Free: no rule for this cell, the opinion passes untouched.
        self.allowed = [False] * (MAX_SYMBOLS + 1)
        #-- allowed[symbol]. Position 0 is not used.


def Free_Rule() -> Cell_Rule:
    return Cell_Rule()


def Rule_Of(
        allowed: list
        ) -> Cell_Rule:
    rule = Cell_Rule()
    rule.is_free = False
    rule.allowed = list(allowed)
    return rule


def Kept_Part(
        belief: distributions.Distribution,
        allowed: list
        ) -> distributions.Distribution:
    kept = distributions.Zero(belief.size)
    for symbol in range(1, belief.size + 1):
        if allowed[symbol]:
            distributions.Set_Weight(kept, symbol, distributions.Weight_Of(belief, symbol))
    if distributions.Total(kept) == 0.0:
        for symbol in range(1, belief.size + 1):
            if allowed[symbol]:
                distributions.Set_Weight(kept, symbol, 1.0)
        #-- The brain gave no chance to anything allowed: every allowed letter is as good as another.
    if distributions.Total(kept) == 0.0:
        return belief
        #-- Nothing at all is allowed here: the rule cannot be obeyed, so it is not applied.
    return distributions.Normalized(kept)


class Boxed_Oracle(oracles.Oracle):

    def __init__(
            self,
            inner: oracles.Oracle,
            rules: list
            ):
        self.inner = inner
        self.rules = rules

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
        if position >= len(self.rules):
            return belief
        rule = self.rules[position]
        if rule.is_free:
            return belief
        return Kept_Part(belief, rule.allowed)
