"""Mirror of Calipso.Random_Sources: repeatable randomness.

A very simple generator of our own, so that Ada and Python give
exactly the same numbers with the same seed.
"""

MODULUS_MASK = (1 << 64) - 1
MULTIPLIER = 6364136223846793005
INCREMENT = 1442695040888963407
#-- Constants of Knuth's linear congruential generator (MMIX).
#-- Rule: new state = state * MULTIPLIER + INCREMENT, staying within 64 bits.

TWO_TO_53 = float(1 << 53)


class Generator:

    def __init__(
            self,
            seed: int
            ):
        self.state = seed & MODULUS_MASK


def Seeded(
        seed: int
        ) -> Generator:
    return Generator(seed)


def Draw_Unit(
        source: Generator
        ) -> float:
    #-- Returns a number in [0, 1) and advances the generator.
    product = source.state * MULTIPLIER
    advanced = product + INCREMENT
    source.state = advanced & MODULUS_MASK
    top_bits = source.state >> 11
    #-- We keep the top 53 bits: those are the ones that fit exactly in a real number.
    return top_bits / TWO_TO_53


def Draw_Index(
        source: Generator,
        below: int
        ) -> int:
    #-- Returns an integer in 0 .. below - 1.
    unit = Draw_Unit(source)
    scaled = unit * float(below)
    index = int(scaled)
    if index >= below:
        index = below - 1
    return index
