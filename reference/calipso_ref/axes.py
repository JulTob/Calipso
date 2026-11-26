"""Mirror of Calipso.Axes: the main axes of a cloud of vectors.

Many vectors with hundreds of numbers each mostly differ along a few
directions. Those directions are the main axes: arrows of length 1, at right
angles to each other. A vector can then be told by a few numbers (how far it
goes along each axis) instead of hundreds. That is the compression.

An axis is found by a patient method that needs only sums and products: take
any arrow, stretch it by the cloud, make it of length 1 again, and repeat. It
turns until it lies along the direction in which the cloud is widest. For the
next axis the same is done, each time removing what lies along the axes found.
"""

from . import vectors

DEFAULT_ROUNDS = 30
START_STEP = 7
START_SHIFT = 3
START_CYCLE = 11


class Basis:

    def __init__(self):
        self.centre = []
        #-- The average vector: the axes describe how the others differ from it.
        self.axes = []


def Centre_Of(
        rows: list
        ) -> list:
    total = [0.0] * len(rows[0])
    for row in rows:
        total = vectors.Added(total, row)
    return vectors.Scaled(1.0 / float(len(rows)), total)


def Start_Arrow(
        width: int,
        number: int
        ) -> list:
    #-- Any arrow will do to begin with, as long as it is always the same one.
    arrow = []
    for place in range(1, width + 1):
        arrow.append(float((place * START_STEP + number * START_SHIFT) % START_CYCLE + 1))
    return arrow


def Without(
        arrow: list,
        earlier: list
        ) -> list:
    #-- The arrow with what lies along the axes already found taken away.
    rest = arrow
    for axis in earlier:
        rest = vectors.Subtracted(rest, vectors.Scaled(vectors.Dot(rest, axis), axis))
    return rest


def Stretched(
        rows: list,
        centre: list,
        arrow: list
        ) -> list:
    #-- Every vector pulls the arrow toward itself, as hard as the two agree.
    offset = vectors.Dot(centre, arrow)
    total = [0.0] * len(arrow)
    pull_sum = 0.0
    for row in rows:
        pull = vectors.Dot(row, arrow) - offset
        total = vectors.Added(total, vectors.Scaled(pull, row))
        pull_sum = pull_sum + pull
    return vectors.Subtracted(total, vectors.Scaled(pull_sum, centre))


def One_Axis(
        rows: list,
        centre: list,
        earlier: list,
        number: int,
        rounds: int
        ) -> list:
    arrow = vectors.Unit(Without(Start_Arrow(len(centre), number), earlier))
    for _ in range(0, rounds):
        arrow = vectors.Unit(Without(Stretched(rows, centre, arrow), earlier))
    return arrow


def Found(
        rows: list,
        count: int,
        rounds: int = DEFAULT_ROUNDS
        ) -> Basis:
    basis = Basis()
    if len(rows) == 0:
        return basis
    basis.centre = Centre_Of(rows)
    for number in range(1, count + 1):
        basis.axes.append(One_Axis(rows, basis.centre, basis.axes, number, rounds))
    return basis


def Projected(
        basis: Basis,
        item: list
        ) -> list:
    #-- The vector told by how far it goes along each axis.
    moved = vectors.Subtracted(item, basis.centre)
    short = []
    for axis in basis.axes:
        short.append(vectors.Dot(moved, axis))
    return short
