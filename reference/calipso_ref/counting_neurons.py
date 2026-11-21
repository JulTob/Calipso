"""Mirror of Calipso.Counting_Neurons: the counting brain, as one neuron.

It wraps a counting oracle so that it can sit in a brain next to neurons
that learn. Its points for a letter are the logarithm of the probability the
count table gives it: that way, alone in a brain, it says exactly what the
counting oracle says; next to other neurons, they correct what it gets wrong.

It learns from text (it counts fragments), not from errors.
"""

import math

from . import canvases
from . import counting_oracles
from . import distributions
from . import fragment_counts
from . import neurons
from . import records


DEFAULT_MEMORY = 1048576
#-- How many counters the "memory" neuron has, unless the recipe says otherwise.


class Counting_Neuron(neurons.Neuron):

    def __init__(self):
        self.oracle = counting_oracles.Counting_Oracle()

    def Name(self) -> str:
        longest = self.oracle.longest
        usual = counting_oracles.DEFAULT_LONGEST
        capacity = self.oracle.table.capacity
        if capacity > 0:
            return neurons.With_Sizes("memory", capacity, DEFAULT_MEMORY, longest, usual)
            #-- The same neuron with bounded memory goes by another name in recipes.
        return neurons.With_Sizes("counting", longest, usual, 0, 0)

    def Kind(self) -> str:
        return "counting"

    def Reach(self) -> int:
        return self.oracle.Reach()

    def Add_Scores(
            self,
            board: canvases.Canvas,
            position: int,
            strength: float,
            scores: list
            ) -> None:
        belief = self.oracle.Opinion(board, position)
        for candidate in range(1, self.oracle.letter_count + 1):
            share = distributions.Probability_Of(belief, candidate)
            floored = max(share, distributions.SMALLEST_PROBABILITY)
            scores[candidate] = scores[candidate] + strength * math.log(floored)

    def Learn_From_Text(
            self,
            piece: list
            ) -> None:
        counting_oracles.Study(self.oracle, piece)

    def Save(
            self,
            out
            ) -> None:
        records.Write_Count(out, self.oracle.letter_count)
        records.Write_Count(out, self.oracle.longest)
        fragment_counts.Save(self.oracle.table, out)

    def Load(
            self,
            source
            ) -> None:
        letter_count = records.Read_Count(source)
        longest = records.Read_Count(source)
        counting_oracles.Prepare(self.oracle, letter_count, longest)
        fragment_counts.Load(self.oracle.table, source)


def Prepare(
        neuron: Counting_Neuron,
        letter_count: int,
        longest: int = counting_oracles.DEFAULT_LONGEST,
        capacity: int = 0
        ) -> None:
    counting_oracles.Prepare(neuron.oracle, letter_count, longest, capacity)
