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


#-- ---------------------------------------------------------------------------
#-- The third scale, and the curved model of the dial.
#--
#--    Evidence   any number, in nats.  0 = no idea.  Positive = for.  Negative = against.
#--               Evidence from two sources that do not depend on each other ADDS.
#--               This is the scale to calculate with.
#--
#-- The other two scales are the evidence, squeezed into a fixed range:
#--
#--    signed certainty = tanh (evidence / 2)                 always between -1 and 1
#--    certainty        = sigmoid (evidence + the evidence of pure chance)   between 0 and 1
#--
#-- tanh and the sigmoid are the same curve drawn on two different rulers.
#-- (Ada overloads names; here each function has a name of its own.)

import math

MOST_EVIDENCE = 36.0
#-- Beyond this a chance cannot be told from 0 or 1 with the numbers the machine keeps.
FLOOR = 1.0e-15

STRAIGHT = 0
CURVED = 1
#-- Two models for reading the signed dial as a chance:
#--   STRAIGHT: each half of the dial is a straight line.
#--   CURVED  : the dial is the tanh of half the evidence.


def Sigmoid(
        value: float
        ) -> float:
    return 1.0 / (1.0 + math.exp(-value))


def Logit(
        chance: float
        ) -> float:
    #-- The sigmoid, backwards: the evidence that gives this chance.
    return math.log(chance / (1.0 - chance))


def Signed_From(
        weight: float
        ) -> float:
    #-- tanh (weight / 2), written with one exponential.
    shrink = math.exp(-Clamped(weight, -MOST_EVIDENCE, MOST_EVIDENCE))
    return Clamped((1.0 - shrink) / (1.0 + shrink), -1.0, 1.0)


def Evidence_Of_Signed(
        signed: float
        ) -> float:
    limit = Signed_From(MOST_EVIDENCE)
    held = Clamped(signed, -limit, limit)
    return math.log((1.0 + held) / (1.0 - held))


def Evidence_Of_Certainty(
        plain: float,
        size: int
        ) -> float:
    #-- How far this chance is from pure chance, as evidence.
    held = Clamped(plain, FLOOR, 1.0 - FLOOR)
    return Clamped(Logit(held) - Logit(Chance_Level(size)), -MOST_EVIDENCE, MOST_EVIDENCE)


def Certainty_From(
        weight: float,
        size: int
        ) -> float:
    held = Clamped(weight, -MOST_EVIDENCE, MOST_EVIDENCE)
    return Clamped(Sigmoid(held + Logit(Chance_Level(size))), 0.0, 1.0)


def Certainty_By(
        signed: float,
        size: int,
        model: int
        ) -> float:
    #-- The signed dial read as a chance, by the model asked for. The two ends are exact in both.
    if model == STRAIGHT:
        return Certainty_Of(signed, size)
    if signed >= SURELY_RIGHT:
        return 1.0
    if signed <= SURELY_WRONG:
        return 0.0
    return Certainty_From(Evidence_Of_Signed(signed), size)


def Joined(
        left: float,
        right: float
        ) -> float:
    #-- Two signed certainties about the same thing, from two sources, made into one.
    #-- It is the sum of their evidence, read back on the signed dial. In Ada this is "&".
    bottom = 1.0 + left * right
    if bottom == 0.0:
        return NO_IDEA
        #-- "Surely right" and "surely wrong" together: they cancel.
    return Clamped((left + right) / bottom, -1.0, 1.0)
