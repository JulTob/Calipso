"""Mirror of Calipso.Bias_Neurons: the neuron that looks at nothing.

It holds one number per letter: its starting points, whatever the
surroundings. It learns how frequent each letter is.
"""

from . import canvases
from . import neurons
from . import records


class Bias_Neuron(neurons.Neuron):

    def __init__(self):
        self.letter_count = 1
        self.points = [0.0, 0.0]
        #-- points[candidate]; position 0 is not used.

    def Name(self) -> str:
        return "bias"

    def Kind(self) -> str:
        return "bias"

    def Reach(self) -> int:
        return 0

    def Add_Scores(
            self,
            board: canvases.Canvas,
            position: int,
            strength: float,
            scores: list
            ) -> None:
        for candidate in range(1, self.letter_count + 1):
            scores[candidate] = scores[candidate] + strength * self.points[candidate]

    def Learn_From_Cell(
            self,
            board: canvases.Canvas,
            position: int,
            errors: list,
            step: float
            ) -> None:
        for candidate in range(1, self.letter_count + 1):
            self.points[candidate] = self.points[candidate] - step * errors[candidate]

    def Save(
            self,
            out
            ) -> None:
        records.Write_Count(out, self.letter_count)
        records.Write_Reals(out, self.points[1:])

    def Load(
            self,
            source
            ) -> None:
        self.letter_count = records.Read_Count(source)
        self.points = [0.0] + records.Read_Reals(source)


def Prepare(
        neuron: Bias_Neuron,
        letter_count: int
        ) -> None:
    neuron.letter_count = letter_count
    neuron.points = [0.0] * (letter_count + 1)
