"""Mirror of Calipso.Criteria: how to decide which hole collapses next.

A criterion looks at one hole and says how READY it is to collapse, from
0 (not at all) to 1 (completely). The engine always collapses the readiest
hole. None of the first two criteria cares where the hole is: the order of
collapse comes from the content, not from the position.

  Certainty : 1 minus the doubt of the opinion. This is the "collapse index":
              1 = one letter is certain, 0 = all letters equally possible.
  Agreement : how much the neurons of a brain, each asked alone, share the
              same bets. 1 = they all say the same, 0 = nothing in common.
  Leftmost  : readier the further left. It reproduces writing left to right,
              and is here to compare against.
  Mixed     : several criteria, each with a weight.
"""

import math

from . import brains
from . import canvases
from . import distributions
from . import oracles


class Criterion:

    def Readiness(
            self,
            board: canvases.Canvas,
            model: oracles.Oracle,
            position: int
            ) -> float:
        raise NotImplementedError


class Certainty(Criterion):

    def Readiness(
            self,
            board: canvases.Canvas,
            model: oracles.Oracle,
            position: int
            ) -> float:
        size = model.Alphabet_Size()
        if size <= 1:
            return 1.0
        belief = model.Opinion(board, position)
        most_doubt = math.log(float(size))
        return 1.0 - distributions.Entropy(belief) / most_doubt


class Agreement(Criterion):

    def Readiness(
            self,
            board: canvases.Canvas,
            model: oracles.Oracle,
            position: int
            ) -> float:
        if not isinstance(model, brains.Brain):
            return Certainty().Readiness(board, model, position)
            #-- A model that is not a brain has no neurons to compare.
        if Looking_Count(model) < 2:
            return Certainty().Readiness(board, model, position)
        return Shared_Bets(model, board, position)


def Looks_Around(
        model: brains.Brain,
        index: int
        ) -> bool:
    #-- Neurons that look at nothing (reach 0) always say the same; they are left out.
    return model.neurons[index].Reach() > 0


def Looking_Count(
        model: brains.Brain
        ) -> int:
    count = 0
    for index in range(0, brains.Neuron_Count(model)):
        if Looks_Around(model, index):
            count = count + 1
    return count


def Shared_Bets(
        model: brains.Brain,
        board: canvases.Canvas,
        position: int
        ) -> float:
    #-- For each letter, the smallest bet any neuron places on it; then the sum.
    #-- It is the part of their bets that all the neurons have in common.
    size = model.Alphabet_Size()
    lowest = [1.0] * (size + 1)
    for index in range(0, brains.Neuron_Count(model)):
        if Looks_Around(model, index):
            belief = brains.Neuron_Opinion(model, index, board, position)
            for candidate in range(1, size + 1):
                share = distributions.Probability_Of(belief, candidate)
                if share < lowest[candidate]:
                    lowest[candidate] = share
    shared = 0.0
    for candidate in range(1, size + 1):
        shared = shared + lowest[candidate]
    return shared


class Leftmost(Criterion):

    def Readiness(
            self,
            board: canvases.Canvas,
            model: oracles.Oracle,
            position: int
            ) -> float:
        return 1.0 - float(position) / float(canvases.Length(board))
        #-- Mirror note: in Ada positions start at 1, so it is (Position - 1) / Length.


class Mixed(Criterion):

    def __init__(self):
        self.parts = []
        self.weights = []

    def Readiness(
            self,
            board: canvases.Canvas,
            model: oracles.Oracle,
            position: int
            ) -> float:
        total = 0.0
        weight_sum = 0.0
        for index in range(0, len(self.parts)):
            readiness = self.parts[index].Readiness(board, model, position)
            total = total + self.weights[index] * readiness
            weight_sum = weight_sum + self.weights[index]
        if weight_sum <= 0.0:
            return 0.0
        return total / weight_sum


def Add_Part(
        mix: Mixed,
        part: Criterion,
        weight: float = 1.0
        ) -> None:
    mix.parts.append(part)
    mix.weights.append(weight)
