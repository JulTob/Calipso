"""Mirror of Calipso.Distributions: the algebra of opinions.

A distribution shares out "weight" among the letters of the alphabet.
If the weights add up to 1 it is a probability; if not, they are raw counts.
"""

import math

SMALLEST_PROBABILITY = 1.0e-300
#-- Floor so that we never ask for the logarithm of zero.


class Distribution:

    def __init__(
            self,
            size: int
            ):
        self.size = size
        self.weights = [0.0] * (size + 1)
        #-- weights[symbol]. Position 0 is not used.

    def __add__(
            self,
            other: "Distribution"
            ) -> "Distribution":
        #-- Adding = putting two piles of evidence together.
        if self.size != other.size:
            raise ValueError("different sizes")
        result = Distribution(self.size)
        for symbol in range(1, self.size + 1):
            result.weights[symbol] = self.weights[symbol] + other.weights[symbol]
        return result

    def __rmul__(
            self,
            factor: float
            ) -> "Distribution":
        #-- Scaling = giving an opinion more or less strength.
        if factor < 0.0:
            raise ValueError("negative factor")
        result = Distribution(self.size)
        for symbol in range(1, self.size + 1):
            result.weights[symbol] = factor * self.weights[symbol]
        return result


def Zero(
        size: int
        ) -> Distribution:
    return Distribution(size)


def Uniform(
        size: int
        ) -> Distribution:
    result = Distribution(size)
    share = 1.0 / float(size)
    for symbol in range(1, size + 1):
        result.weights[symbol] = share
    return result


def From_Scores(
        scores: list
        ) -> Distribution:
    #-- Turns scores (any number, positive or negative) into probabilities.
    #-- More points = more likely. This is called "softmax".
    #-- `scores[symbol]`; position 0 is not used.
    size = len(scores) - 1
    highest = scores[1]
    for symbol in range(2, size + 1):
        if scores[symbol] > highest:
            highest = scores[symbol]
    raw = Distribution(size)
    for symbol in range(1, size + 1):
        raw.weights[symbol] = math.exp(scores[symbol] - highest)
        #-- Subtracting the maximum does not change the result and avoids huge numbers.
    return Normalized(raw)


def Weight_Of(
        item: Distribution,
        symbol: int
        ) -> float:
    return item.weights[symbol]


def Set_Weight(
        item: Distribution,
        symbol: int,
        weight: float
        ) -> None:
    if weight < 0.0:
        raise ValueError("negative weight")
    item.weights[symbol] = weight


def Total(
        item: Distribution
        ) -> float:
    #-- Summed by hand, left to right: the same order as in Ada.
    result = 0.0
    for symbol in range(1, item.size + 1):
        result = result + item.weights[symbol]
    return result


def Variety(
        item: Distribution
        ) -> int:
    #-- How many different letters carry some weight.
    result = 0
    for symbol in range(1, item.size + 1):
        if item.weights[symbol] > 0.0:
            result = result + 1
    return result


def Normalized(
        item: Distribution
        ) -> Distribution:
    total = Total(item)
    if total <= 0.0:
        raise ValueError("an empty distribution cannot be normalized")
    result = Distribution(item.size)
    for symbol in range(1, item.size + 1):
        result.weights[symbol] = item.weights[symbol] / total
    return result


def Probability_Of(
        item: Distribution,
        symbol: int
        ) -> float:
    total = Total(item)
    if total <= 0.0:
        raise ValueError("empty distribution")
    return item.weights[symbol] / total


def Entropy(
        item: Distribution
        ) -> float:
    #-- Uncertainty, in nats. 0 = completely sure. The higher, the more doubt.
    total = Total(item)
    if total <= 0.0:
        raise ValueError("empty distribution")
    result = 0.0
    for symbol in range(1, item.size + 1):
        share = item.weights[symbol] / total
        if share > 0.0:
            result = result - share * math.log(share)
    return result


def Surprise_Of(
        item: Distribution,
        symbol: int
        ) -> float:
    #-- How surprising it is to see this letter, in nats. 0 = it was expected.
    share = Probability_Of(item, symbol)
    floored = max(share, SMALLEST_PROBABILITY)
    return -math.log(floored)


def Most_Likely(
        item: Distribution
        ) -> int:
    best = 1
    for symbol in range(2, item.size + 1):
        if item.weights[symbol] > item.weights[best]:
            best = symbol
    return best


def Sampled(
        item: Distribution,
        unit: float
        ) -> int:
    #-- Rolls a loaded dice. `unit` is a random number in [0, 1).
    total = Total(item)
    if total <= 0.0:
        raise ValueError("empty distribution")
    target = unit * total
    running = 0.0
    last_possible = 1
    for symbol in range(1, item.size + 1):
        if item.weights[symbol] > 0.0:
            last_possible = symbol
            running = running + item.weights[symbol]
            if target < running:
                return symbol
    return last_possible
    #-- We only get here because of rounding: return the last possible letter.
