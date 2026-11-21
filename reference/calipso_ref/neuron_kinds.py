"""Mirror of Calipso.Neuron_Kinds: the catalogue of neuron models.

The one place that knows every kind of neuron. A new kind of neuron is a
new module plus one line here.

Names that can be used in a recipe:

  bias      starting points of each letter; looks at nothing
  position  what letter is at each exact distance
  presence  what letters are around, wherever they are
  harmonic  waves over distance (Fourier)
  decay     fading with distance at several speeds (Laplace)
  counting  the table of fragment counts
  memory    the same table with a fixed size (bounded memory)
"""

from . import basis_neurons
from . import bias_neurons
from . import counting_neurons
from . import counting_oracles
from . import neurons

MOST_REACH = 512
MOST_DETAIL = 64
MOST_LONGEST = 32
MOST_COUNTERS = 2147483647
MOST_DIGITS = 10
#-- The largest sizes a recipe may ask for.


class Recipe_Error(Exception):
    pass


def Size_In(
        word: str
        ) -> int:
    #-- The size written in a recipe: a whole number, 1 or more.
    if word == "" or len(word) > MOST_DIGITS:
        raise Recipe_Error("a size in a recipe must be a whole number, 1 or more: " + word)
    value = 0
    for digit in word:
        if not ("0" <= digit <= "9"):
            raise Recipe_Error("a size in a recipe must be a whole number, 1 or more: " + word)
        value = value * 10 + (ord(digit) - ord("0"))
    if value == 0:
        raise Recipe_Error("a size in a recipe must be a whole number, 1 or more: " + word)
    if value > MOST_COUNTERS:
        raise Recipe_Error("a size is too large: " + word)
    return value


class Order:
    #-- One name of a recipe, taken apart: "decay:24:8" -> the word decay, sizes 24 and 8.

    def __init__(self):
        self.word = ""
        self.count = 0
        #-- How many sizes were written: 0, 1 or 2.
        self.first = 0
        self.second = 0


def Parsed(
        name: str
        ) -> Order:
    order = Order()
    start = 0
    part = 0
    while start <= len(name):
        colon = name.find(":", start)
        if colon < 0:
            colon = len(name)
        piece = name[start:colon]
        if part == 0:
            order.word = piece
        elif part == 1:
            order.first = Size_In(piece)
        elif part == 2:
            order.second = Size_In(piece)
        else:
            raise Recipe_Error("too many sizes for one neuron: " + name)
        part = part + 1
        start = colon + 1
    order.count = part - 1
    return order


def Check_Sizes(
        name: str,
        order: Order,
        most_sizes: int,
        most_first: int,
        most_second: int
        ) -> None:
    if order.count > most_sizes:
        raise Recipe_Error("too many sizes for this kind of neuron: " + name)
    if order.first > most_first or order.second > most_second:
        raise Recipe_Error("a size is too large: " + name)


def Chosen(
        written: int,
        usual: int
        ) -> int:
    #-- The size the recipe wrote, or the usual one if it wrote none.
    if written == 0:
        return usual
    return written


def Made_Basis(
        name: str,
        order: Order,
        letter_count: int,
        kind: int,
        most_sizes: int,
        usual_detail: int
        ) -> neurons.Neuron:
    Check_Sizes(name, order, most_sizes, MOST_REACH, MOST_DETAIL)
    neuron = basis_neurons.Basis_Neuron()
    reach = Chosen(order.first, basis_neurons.DEFAULT_REACH)
    detail = Chosen(order.second, usual_detail)
    basis_neurons.Prepare(neuron, letter_count, kind, reach, detail)
    return neuron


def Made(
        name: str,
        letter_count: int
        ) -> neurons.Neuron:
    #-- A blank neuron of the kind this recipe name asks for.
    #--
    #--    bias
    #--    position:REACH        presence:REACH
    #--    harmonic:REACH:WAVES  decay:REACH:SPEEDS
    #--    counting:LONGEST      memory:COUNTERS:LONGEST
    #--
    #-- Every size can be left out; the usual one is then taken.
    order = Parsed(name)
    if order.word == "bias":
        Check_Sizes(name, order, 0, 0, 0)
        neuron = bias_neurons.Bias_Neuron()
        bias_neurons.Prepare(neuron, letter_count)
        return neuron
    if order.word == "position":
        return Made_Basis(name, order, letter_count, basis_neurons.BY_POSITION, 1, 0)
    if order.word == "presence":
        return Made_Basis(name, order, letter_count, basis_neurons.BY_HARMONIC, 1, 0)
    if order.word == "harmonic":
        return Made_Basis(name, order, letter_count, basis_neurons.BY_HARMONIC, 2, basis_neurons.DEFAULT_WAVES)
    if order.word == "decay":
        return Made_Basis(name, order, letter_count, basis_neurons.BY_DECAY, 2, basis_neurons.DEFAULT_SPEEDS)
    if order.word == "counting":
        Check_Sizes(name, order, 1, MOST_LONGEST, 0)
        neuron = counting_neurons.Counting_Neuron()
        counting_neurons.Prepare(neuron, letter_count, Chosen(order.first, counting_oracles.DEFAULT_LONGEST), 0)
        return neuron
    if order.word == "memory":
        Check_Sizes(name, order, 2, MOST_COUNTERS, MOST_LONGEST)
        neuron = counting_neurons.Counting_Neuron()
        counters = Chosen(order.first, counting_neurons.DEFAULT_MEMORY)
        longest = Chosen(order.second, counting_oracles.DEFAULT_LONGEST)
        counting_neurons.Prepare(neuron, letter_count, longest, counters)
        return neuron
    raise Recipe_Error("there is no neuron called " + order.word)


def Blank_Of_Kind(
        kind: str
        ) -> neurons.Neuron:
    #-- An empty neuron of the module that saved under this word, ready to Load.
    if kind == "bias":
        return bias_neurons.Bias_Neuron()
    if kind == "basis":
        return basis_neurons.Basis_Neuron()
    if kind == "counting":
        return counting_neurons.Counting_Neuron()
    raise Recipe_Error("a saved brain names a kind of neuron I do not know: " + kind)
