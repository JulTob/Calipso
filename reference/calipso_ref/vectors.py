"""Mirror of Calipso.Vectors: lists of numbers with an algebra.

A word can be described by a list of numbers (how often each kind stands beside
it). Then two words can be compared like two arrows:

    dot product   multiply them place by place and add
    length        how long the arrow is
    cosine        the dot product of the two arrows made of length 1:
                  +1 they point the same way, 0 they have nothing in common,
                  -1 they point opposite ways

The complex product is for a vector made of two halves that mean different
things (what stands BEFORE a word, and what stands AFTER it). Each vector is
read as  first half + i * second half :

    real part        the plain dot product: how alike the two are
    imaginary part   first half of one against second half of the other, both
                     ways, subtracted. Swap the two vectors and it changes sign:
                     it holds ORDER, which the plain dot product forgets.
"""

import math


def Added(left: list, right: list) -> list:
    return [left[index] + right[index] for index in range(0, len(left))]


def Subtracted(left: list, right: list) -> list:
    return [left[index] - right[index] for index in range(0, len(left))]


def Scaled(scale: float, item: list) -> list:
    return [scale * value for value in item]


def Dot(left: list, right: list) -> float:
    total = 0.0
    for index in range(0, len(left)):
        total = total + left[index] * right[index]
    return total


def Length(item: list) -> float:
    return math.sqrt(Dot(item, item))


def Unit(item: list) -> list:
    #-- The same direction with length 1. An arrow of length 0 has no direction: it stays as it is.
    length = Length(item)
    if length == 0.0:
        return list(item)
    return Scaled(1.0 / length, item)


def Cosine(left: list, right: list) -> float:
    lengths = Length(left) * Length(right)
    if lengths == 0.0:
        return 0.0
    return max(-1.0, min(1.0, Dot(left, right) / lengths))


def Complex_Product(left: list, right: list) -> complex:
    half = len(left) // 2
    real = Dot(left, right)
    imaginary = Dot(left[:half], right[half:]) - Dot(left[half:], right[:half])
    return complex(real, imaginary)


def Turn(left: list, right: list) -> float:
    #-- The angle of the complex product, in degrees: near 0 the two are alike,
    #-- near +90 or -90 one stands where the other's neighbours stand.
    product = Complex_Product(left, right)
    if product.real == 0.0 and product.imag == 0.0:
        return 0.0
    return math.degrees(math.atan2(product.imag, product.real))
