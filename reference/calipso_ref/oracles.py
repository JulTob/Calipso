"""Mirror of Calipso.Oracles: the contract of any "brain".

An oracle answers a single question:

    "Looking at what is around, which letter do you think goes in this cell?"

and answers with a distribution (an opinion with doubts, not a letter).

The collapse engine only knows this contract. One brain is a count table;
another one learns its numbers. The engine does not change.
"""

from . import canvases
from . import distributions


class Oracle:

    def Alphabet_Size(self) -> int:
        raise NotImplementedError

    def Reach(self) -> int:
        #-- How many cells away a letter can influence the opinion about another.
        raise NotImplementedError

    def Opinion(
            self,
            board: canvases.Canvas,
            position: int
            ) -> distributions.Distribution:
        #-- Opinion about cell `position` looking ONLY at its neighbours, never at the cell itself.
        raise NotImplementedError
