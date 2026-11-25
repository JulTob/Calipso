"""Mirror of Calipso.Neurons: the contract of any neuron.

A neuron is one way of looking at the surroundings of a cell. It does not
answer with a letter: it gives POINTS for or against each candidate letter.
Points simply add up, so neurons of different kinds can sit in one brain:

    points of the brain = sum over its neurons of (weight x points of the neuron)

A neuron can learn in two ways, and each kind uses the one that suits it:

  Learn_From_Cell : it is told how wrong the brain was on one hidden letter
                    ("errors") and corrects its own numbers.
  Learn_From_Text : it is shown a piece of real text and remembers it.
"""

from . import canvases


def Is_Voter(
        board: canvases.Canvas,
        position: int,
        offset: int
        ) -> bool:
    #-- Is there a neighbour with a letter at that distance? (A cell never votes for itself.)
    if offset == 0:
        return False
    neighbour = position + offset
    if neighbour < 0:
        return False
    if neighbour >= canvases.Length(board):
        return False
    return not canvases.Is_Blank(board, neighbour)


class Neuron:

    def Name(self) -> str:
        #-- The name used in recipes: "bias", "position", "harmonic"...
        raise NotImplementedError

    def Kind(self) -> str:
        #-- The word written in a saved brain to say which module must read it back.
        raise NotImplementedError

    def Reach(self) -> int:
        raise NotImplementedError

    def Add_Scores(
            self,
            board: canvases.Canvas,
            position: int,
            strength: float,
            scores: list
            ) -> None:
        #-- Adds `strength` times its own points to `scores`. scores[candidate]; position 0 is not used.
        raise NotImplementedError

    def Learn_From_Cell(
            self,
            board: canvases.Canvas,
            position: int,
            errors: list,
            step: float
            ) -> None:
        #-- errors[candidate] = what was bet on that letter, minus 1 for the real letter.
        #-- Each of the neuron's numbers that took part moves against the error, by `step`.
        pass

    def Learn_From_Text(
            self,
            piece: list
            ) -> None:
        pass

    def Save(
            self,
            out
            ) -> None:
        raise NotImplementedError

    def Load(
            self,
            source
            ) -> None:
        raise NotImplementedError


def With_Sizes(
        word: str,
        first: int,
        usual_first: int,
        second: int,
        usual_second: int
        ) -> str:
    #-- The name of a neuron as a recipe writes it: the word alone when its
    #-- sizes are the usual ones, and "word:first" or "word:first:second" when not.
    if second != usual_second:
        return f"{word}:{first}:{second}"
    if first != usual_first:
        return f"{word}:{first}"
    return word
