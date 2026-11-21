"""Espejo de Colapso.Distributions: el álgebra de las opiniones.

Una distribución reparte "peso" entre las letras del alfabeto.
Si los pesos suman 1 es una probabilidad; si no, son cuentas sin normalizar.
"""

import math

SMALLEST_PROBABILITY = 1.0e-300
#-- Suelo para no pedir nunca el logaritmo de cero.


class Distribution:

    def __init__(
            self,
            size: int
            ):
        self.size = size
        self.weights = [0.0] * (size + 1)
        #-- weights[símbolo]. La posición 0 no se usa.

    def __add__(
            self,
            other: "Distribution"
            ) -> "Distribution":
        #-- Sumar = juntar dos montones de evidencia.
        if self.size != other.size:
            raise ValueError("tamaños distintos")
        result = Distribution(self.size)
        for symbol in range(1, self.size + 1):
            result.weights[symbol] = self.weights[symbol] + other.weights[symbol]
        return result

    def __rmul__(
            self,
            factor: float
            ) -> "Distribution":
        #-- Escalar = darle más o menos fuerza a una opinión.
        if factor < 0.0:
            raise ValueError("factor negativo")
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
    #-- Convierte puntos (cualquier número, positivo o negativo) en probabilidades.
    #-- Más puntos = más probable. Se llama "softmax".
    #-- `scores[símbolo]`; la posición 0 no se usa.
    size = len(scores) - 1
    highest = scores[1]
    for symbol in range(2, size + 1):
        if scores[symbol] > highest:
            highest = scores[symbol]
    raw = Distribution(size)
    for symbol in range(1, size + 1):
        raw.weights[symbol] = math.exp(scores[symbol] - highest)
        #-- Restar el máximo no cambia el resultado y evita números enormes.
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
        raise ValueError("peso negativo")
    item.weights[symbol] = weight


def Total(
        item: Distribution
        ) -> float:
    #-- Suma a mano, de izquierda a derecha: el mismo orden que en Ada.
    result = 0.0
    for symbol in range(1, item.size + 1):
        result = result + item.weights[symbol]
    return result


def Variety(
        item: Distribution
        ) -> int:
    #-- Cuántas letras distintas tienen algo de peso.
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
        raise ValueError("no se puede normalizar una distribución vacía")
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
        raise ValueError("distribución vacía")
    return item.weights[symbol] / total


def Entropy(
        item: Distribution
        ) -> float:
    #-- Incertidumbre, en nats. 0 = seguro del todo. Cuanto mayor, más dudas.
    total = Total(item)
    if total <= 0.0:
        raise ValueError("distribución vacía")
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
    #-- Cuánto sorprende ver esta letra, en nats. 0 = era lo esperado.
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
    #-- Tira un dado cargado. `unit` es un número al azar en [0, 1).
    total = Total(item)
    if total <= 0.0:
        raise ValueError("distribución vacía")
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
    #-- Solo se llega aquí por redondeo: devolvemos la última letra posible.
