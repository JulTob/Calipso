"""Espejo de Colapso.Random_Sources: azar repetible.

Un generador propio y muy simple, para que Ada y Python saquen
exactamente los mismos números con la misma semilla.
"""

MODULUS_MASK = (1 << 64) - 1
MULTIPLIER = 6364136223846793005
INCREMENT = 1442695040888963407
#-- Constantes del generador congruencial lineal de Knuth (MMIX).
#-- Regla: estado nuevo = estado * MULTIPLIER + INCREMENT, sin salir de 64 bits.

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
    #-- Devuelve un número en [0, 1) y avanza el generador.
    product = source.state * MULTIPLIER
    advanced = product + INCREMENT
    source.state = advanced & MODULUS_MASK
    top_bits = source.state >> 11
    #-- Nos quedamos con los 53 bits altos: son los que caben exactos en un real.
    return top_bits / TWO_TO_53


def Draw_Index(
        source: Generator,
        below: int
        ) -> int:
    #-- Devuelve un entero en 0 .. below - 1.
    unit = Draw_Unit(source)
    scaled = unit * float(below)
    index = int(scaled)
    if index >= below:
        index = below - 1
    return index
