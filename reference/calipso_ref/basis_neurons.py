"""Mirror of Calipso.Basis_Neurons: neurons that weigh neighbours by distance.

Every known neighbour votes with a row of points that depends on the letter
it holds. What changes from one kind to another is HOW the distance to the
hole is measured. Each way of measuring is a small set of curves over
distance (a "basis"), and there is one table of votes per curve:

  BY_POSITION : one curve per exact distance. "What is 3 cells to my left?"
             Sharp, but knows nothing about "somewhere nearby".

  BY_HARMONIC : waves over the window, as in a Fourier series. The first curve
             is flat: it ignores position altogether ("this letter is around").
             Each further pair of waves adds a finer sense of where.
             With no waves at all it is the "presence" neuron: no position.

  BY_DECAY    : curves that fade with distance, at several speeds, as in a
             Laplace transform. Fast fading sees only the next letter; slow
             fading sees far, blurred. One set looks left, one looks right.
"""

import math

from . import canvases
from . import neurons
from . import records

BY_POSITION = 0
BY_HARMONIC = 1
BY_DECAY = 2
KIND_WORDS = ["position", "harmonic", "decay"]

TWO_PI = 2.0 * math.pi


class Basis_Neuron(neurons.Neuron):

    def __init__(self):
        self.letter_count = 1
        self.reach = 1
        self.kind = BY_POSITION
        self.detail = 0
        #-- BY_HARMONIC: how many pairs of waves. BY_DECAY: how many fading speeds. BY_POSITION: not used.
        self.basis_count = 0
        self.basis = []
        #-- basis[curve, distance]: the height of each curve at each distance. See Basis_Slot.
        self.votes = []
        #-- votes[curve, neighbour letter, candidate letter], all in one long row. See Vote_Slot.

    def Name(self) -> str:
        if self.kind == BY_HARMONIC and self.detail == 0:
            return "presence"
        return KIND_WORDS[self.kind]

    def Kind(self) -> str:
        return "basis"

    def Reach(self) -> int:
        return self.reach

    def Add_Scores(
            self,
            board: canvases.Canvas,
            position: int,
            strength: float,
            scores: list
            ) -> None:
        for offset in range(-self.reach, self.reach + 1):
            if neurons.Is_Voter(board, position, offset):
                neighbour = canvases.Symbol_At(board, position + offset)
                for curve in range(0, self.basis_count):
                    height = self.basis[Basis_Slot(self, curve, offset)]
                    if height != 0.0:
                        factor = strength * height
                        first = Vote_Slot(self, curve, neighbour, 1)
                        for candidate in range(1, self.letter_count + 1):
                            scores[candidate] = scores[candidate] + factor * self.votes[first + candidate - 1]

    def Learn_From_Cell(
            self,
            board: canvases.Canvas,
            position: int,
            errors: list,
            step: float
            ) -> None:
        for offset in range(-self.reach, self.reach + 1):
            if neurons.Is_Voter(board, position, offset):
                neighbour = canvases.Symbol_At(board, position + offset)
                for curve in range(0, self.basis_count):
                    height = self.basis[Basis_Slot(self, curve, offset)]
                    if height != 0.0:
                        factor = step * height
                        #-- A vote is corrected in proportion to how loudly it spoke.
                        first = Vote_Slot(self, curve, neighbour, 1)
                        for candidate in range(1, self.letter_count + 1):
                            slot = first + candidate - 1
                            self.votes[slot] = self.votes[slot] - factor * errors[candidate]

    def Save(
            self,
            out
            ) -> None:
        records.Write_Word(out, KIND_WORDS[self.kind])
        records.Write_Count(out, self.letter_count)
        records.Write_Count(out, self.reach)
        records.Write_Count(out, self.detail)
        records.Write_Reals(out, self.votes)

    def Load(
            self,
            source
            ) -> None:
        word = records.Read_Word(source)
        if word not in KIND_WORDS:
            raise records.Record_Error("unknown kind of basis: " + word)
        letter_count = records.Read_Count(source)
        reach = records.Read_Count(source)
        detail = records.Read_Count(source)
        Prepare(self, letter_count, KIND_WORDS.index(word), reach, detail)
        self.votes = records.Read_Reals(source)


def Basis_Slot(
        neuron: Basis_Neuron,
        curve: int,
        offset: int
        ) -> int:
    width = 2 * neuron.reach + 1
    return curve * width + (offset + neuron.reach)


def Vote_Slot(
        neuron: Basis_Neuron,
        curve: int,
        neighbour: int,
        candidate: int
        ) -> int:
    #-- Mirror note: curves count from 0 here and from 1 in Ada; the row starts at 0 here and at 1 in Ada.
    row = curve * neuron.letter_count + (neighbour - 1)
    return row * neuron.letter_count + (candidate - 1)


def Curve_Height(
        neuron: Basis_Neuron,
        curve: int,
        offset: int
        ) -> float:
    #-- The height of one curve at one distance. Offered so that the curves can be inspected.
    return neuron.basis[Basis_Slot(neuron, curve, offset)]


def Curve_Count(
        kind: int,
        reach: int,
        detail: int
        ) -> int:
    if kind == BY_POSITION:
        return 2 * reach
    if kind == BY_HARMONIC:
        return 2 * detail + 1
    return 2 * detail


def Fill_Position(
        neuron: Basis_Neuron
        ) -> None:
    #-- Curve number c is 1 at one exact distance and 0 everywhere else.
    for offset in range(-neuron.reach, 0):
        neuron.basis[Basis_Slot(neuron, offset + neuron.reach, offset)] = 1.0
    for offset in range(1, neuron.reach + 1):
        neuron.basis[Basis_Slot(neuron, offset + neuron.reach - 1, offset)] = 1.0


def Fill_Harmonic(
        neuron: Basis_Neuron
        ) -> None:
    #-- Curve 0 is flat. Then, for each wave: a cosine and a sine with that many cycles across the window.
    width = 2 * neuron.reach + 1
    for offset in range(-neuron.reach, neuron.reach + 1):
        neuron.basis[Basis_Slot(neuron, 0, offset)] = 1.0
        for wave in range(1, neuron.detail + 1):
            angle = TWO_PI * float(wave * offset) / float(width)
            neuron.basis[Basis_Slot(neuron, 2 * wave - 1, offset)] = math.cos(angle)
            neuron.basis[Basis_Slot(neuron, 2 * wave, offset)] = math.sin(angle)


def Fill_Decay(
        neuron: Basis_Neuron
        ) -> None:
    #-- Fading speeds 1, 1/2, 1/4... The nearest neighbour always counts 1.
    #-- Curves 0 .. detail-1 look left; curves detail .. 2*detail-1 look right.
    rate = 1.0
    for speed in range(0, neuron.detail):
        for distance in range(1, neuron.reach + 1):
            height = math.exp(-rate * float(distance - 1))
            neuron.basis[Basis_Slot(neuron, speed, -distance)] = height
            neuron.basis[Basis_Slot(neuron, neuron.detail + speed, distance)] = height
        rate = rate / 2.0


def Prepare(
        neuron: Basis_Neuron,
        letter_count: int,
        kind: int,
        reach: int,
        detail: int
        ) -> None:
    #-- Leaves the neuron blank: its curves drawn, all its votes at 0.
    neuron.letter_count = letter_count
    neuron.reach = reach
    neuron.kind = kind
    neuron.detail = detail
    neuron.basis_count = Curve_Count(kind, reach, detail)
    width = 2 * reach + 1
    neuron.basis = [0.0] * (neuron.basis_count * width)
    if kind == BY_POSITION:
        Fill_Position(neuron)
    elif kind == BY_HARMONIC:
        Fill_Harmonic(neuron)
    else:
        Fill_Decay(neuron)
    neuron.votes = [0.0] * (neuron.basis_count * letter_count * letter_count)
