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
from . import neurons

DEFAULT_REACH = 12
DEFAULT_WAVES = 4
DEFAULT_SPEEDS = 4
DEFAULT_MEMORY = 1048576
#-- How many counters the "memory" neuron has.


class Recipe_Error(Exception):
    pass


def Made(
        name: str,
        letter_count: int
        ) -> neurons.Neuron:
    #-- A blank neuron of the kind this recipe name asks for, with the default settings.
    if name == "bias":
        neuron = bias_neurons.Bias_Neuron()
        bias_neurons.Prepare(neuron, letter_count)
        return neuron
    if name == "position":
        neuron = basis_neurons.Basis_Neuron()
        basis_neurons.Prepare(neuron, letter_count, basis_neurons.BY_POSITION, DEFAULT_REACH, 0)
        return neuron
    if name == "presence":
        neuron = basis_neurons.Basis_Neuron()
        basis_neurons.Prepare(neuron, letter_count, basis_neurons.BY_HARMONIC, DEFAULT_REACH, 0)
        return neuron
    if name == "harmonic":
        neuron = basis_neurons.Basis_Neuron()
        basis_neurons.Prepare(neuron, letter_count, basis_neurons.BY_HARMONIC, DEFAULT_REACH, DEFAULT_WAVES)
        return neuron
    if name == "decay":
        neuron = basis_neurons.Basis_Neuron()
        basis_neurons.Prepare(neuron, letter_count, basis_neurons.BY_DECAY, DEFAULT_REACH, DEFAULT_SPEEDS)
        return neuron
    if name == "counting":
        neuron = counting_neurons.Counting_Neuron()
        counting_neurons.Prepare(neuron, letter_count)
        return neuron
    if name == "memory":
        neuron = counting_neurons.Counting_Neuron()
        counting_neurons.Prepare(neuron, letter_count, capacity=DEFAULT_MEMORY)
        return neuron
    raise Recipe_Error("there is no neuron called " + name)


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
