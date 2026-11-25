"""Mirror of Calipso.Certainties: the dial.

How sure are we that a cell already holds the right symbol? There are two ways
of saying it. They are the same dial read on two different scales:

    Certainty          0 .. 1   the chance that the symbol is right.
                                1 = it is right.   0 = it is wrong.
                                "No idea" is 1/N for an alphabet of N symbols:
                                it moves when the alphabet changes size.

    Signed certainty  -1 .. 1   +1 = it is right.  -1 = it is wrong.
                                0 = no idea, whatever the size of the alphabet.

From 0 up, the signed scale walks from "no idea" to "right". From 0 down, it
walks from "no idea" to "wrong". Each half is a straight line.
"""

SURELY_RIGHT = 1.0
NO_IDEA = 0.0
SURELY_WRONG = -1.0


def Clamped(
        value: float,
        lowest: float,
        highest: float
        ) -> float:
    #-- Arithmetic with fractions can land a hair outside the scale. This brings it back.
    return max(lowest, min(highest, value))


def Chance_Level(
        size: int
        ) -> float:
    #-- The certainty that means "no idea": one in `size`.
    return 1.0 / float(size)


def Certainty_Of(
        signed: float,
        size: int
        ) -> float:
    chance = Chance_Level(size)
    if signed >= 0.0:
        return Clamped(chance + signed * (1.0 - chance), 0.0, 1.0)
    return Clamped((1.0 + signed) * chance, 0.0, 1.0)


def Signed_Of(
        plain: float,
        size: int
        ) -> float:
    chance = Chance_Level(size)
    if plain >= chance:
        return Clamped((plain - chance) / (1.0 - chance), -1.0, 1.0)
    return Clamped(plain / chance - 1.0, -1.0, 1.0)
