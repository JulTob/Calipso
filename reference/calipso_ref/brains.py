"""Mirror of Calipso.Brains: a brain made of neurons.

A brain is a list of neurons of any kinds, each with a weight. To give an
opinion it adds up the points of all its neurons and turns them into
probabilities. It fulfils the Oracle contract, so the collapse engine, the
repair and the exam work with it unchanged.

Its memory works as read - calculate - write:

    read       look at the surroundings of a hidden letter
    calculate  give an opinion; see how much the real letter surprises
    write      every neuron corrects itself a little

So every test also counts as training (Study returns the test score).
The write step happens ONLY when the real letter is known. When the brain is
used to generate text, nothing is written.

A brain can be saved to a file and loaded back, with its alphabet and the
number of lessons it has studied, to carry on later or to be compared.
"""

from . import alphabets
from . import blind_spots
from . import canvases
from . import distributions
from . import neuron_kinds
from . import neurons
from . import oracles
from . import random_sources
from . import records
from . import sources
from . import templates

FILE_MARK = "calipso-brain"
FILE_VERSION = 1
DEFAULT_LEARNING_RATE = 0.1
RECIPE_SEPARATOR = "+"


class Brain(oracles.Oracle):

    def __init__(self):
        self.letters = alphabets.Alphabet()
        self.neurons = []
        self.weights = []
        self.lessons = 0
        #-- How many lessons it has studied in its whole life, across runs.
        self.learning_rate = DEFAULT_LEARNING_RATE

    def Alphabet_Size(self) -> int:
        return alphabets.Size(self.letters)

    def Reach(self) -> int:
        widest = 0
        for neuron in self.neurons:
            if neuron.Reach() > widest:
                widest = neuron.Reach()
        return widest

    def Opinion(
            self,
            board: canvases.Canvas,
            position: int
            ) -> distributions.Distribution:
        scores = Scores_At(self, board, position)
        return distributions.From_Scores(scores)


def Prepare(
        brain: Brain,
        letters: alphabets.Alphabet
        ) -> None:
    #-- An empty brain over this alphabet: no neurons, no lessons.
    brain.letters = letters
    brain.neurons = []
    brain.weights = []
    brain.lessons = 0
    brain.learning_rate = DEFAULT_LEARNING_RATE


def Add_Neuron(
        brain: Brain,
        neuron: neurons.Neuron,
        weight: float = 1.0
        ) -> None:
    brain.neurons.append(neuron)
    brain.weights.append(weight)


def Add_Recipe(
        brain: Brain,
        recipe: str
        ) -> None:
    #-- A recipe is a list of neuron names joined by "+", for example "bias+position+decay".
    for name in recipe.split(RECIPE_SEPARATOR):
        neuron = neuron_kinds.Made(name, alphabets.Size(brain.letters))
        Add_Neuron(brain, neuron)


def Neuron_Count(
        brain: Brain
        ) -> int:
    return len(brain.neurons)


def Recipe_Of(
        brain: Brain
        ) -> str:
    recipe = ""
    for index in range(0, Neuron_Count(brain)):
        if index > 0:
            recipe = recipe + RECIPE_SEPARATOR
        recipe = recipe + brain.neurons[index].Name()
    return recipe


def Scores_At(
        brain: Brain,
        board: canvases.Canvas,
        position: int
        ) -> list:
    #-- The points of the whole brain for each candidate letter. scores[candidate]; position 0 is not used.
    scores = [0.0] * (alphabets.Size(brain.letters) + 1)
    for index in range(0, Neuron_Count(brain)):
        brain.neurons[index].Add_Scores(board, position, brain.weights[index], scores)
    return scores


def Neuron_Opinion(
        brain: Brain,
        index: int,
        board: canvases.Canvas,
        position: int
        ) -> distributions.Distribution:
    #-- What ONE neuron would say if it were alone. Used to measure how much the neurons agree.
    scores = [0.0] * (alphabets.Size(brain.letters) + 1)
    brain.neurons[index].Add_Scores(board, position, 1.0, scores)
    return distributions.From_Scores(scores)


def Learn_Cell(
        brain: Brain,
        board: canvases.Canvas,
        position: int,
        actual: int,
        result: blind_spots.Exam_Result
        ) -> None:
    #-- Read - calculate - write on one hidden letter. The test score goes into `result`
    #-- BEFORE anything is corrected, so the test is honest.
    belief = brain.Opinion(board, position)
    result.hidden = result.hidden + 1
    result.surprise_sum = result.surprise_sum + distributions.Surprise_Of(belief, actual)
    if distributions.Most_Likely(belief) == actual:
        result.hits = result.hits + 1
    size = alphabets.Size(brain.letters)
    errors = [0.0] * (size + 1)
    for candidate in range(1, size + 1):
        errors[candidate] = distributions.Probability_Of(belief, candidate)
        #-- Each letter loses what was bet on it...
    errors[actual] = errors[actual] - 1.0
    #-- ...and the real letter gets what it was missing to reach 1.
    step = brain.learning_rate / float(Neuron_Count(brain))
    #-- The correction is shared equally among the neurons.
    for index in range(0, Neuron_Count(brain)):
        brain.neurons[index].Learn_From_Cell(board, position, errors, step * brain.weights[index])


def Study_Piece(
        brain: Brain,
        piece: list,
        dice: random_sources.Generator,
        result: blind_spots.Exam_Result
        ) -> None:
    #-- One lesson: hide a random amount of the piece, test and correct on every
    #-- hidden letter, then let the neurons that memorize text read the piece.
    original = templates.From_Text(piece, 0, len(piece))
    board = canvases.Copy(original)
    rate = random_sources.Draw_Unit(dice)
    #-- Each lesson hides a different amount: sometimes almost nothing, sometimes almost everything.
    blind_spots.Hide_At_Random(board, rate, dice)
    for position in range(0, len(piece)):
        if canvases.Is_Blank(board, position):
            actual = canvases.Symbol_At(original, position)
            Learn_Cell(brain, board, position, actual, result)
    for neuron in brain.neurons:
        neuron.Learn_From_Text(piece)
    brain.lessons = brain.lessons + 1


def Study(
        brain: Brain,
        source: sources.Source,
        dice: random_sources.Generator,
        lessons: int
        ) -> blind_spots.Exam_Result:
    #-- Studies up to `lessons` pieces from the source. Stops early if the source runs dry.
    #-- Returns the score of the tests taken along the way.
    result = blind_spots.Exam_Result()
    for _ in range(0, lessons):
        piece, found = source.Next_Piece()
        if not found:
            break
        Study_Piece(brain, piece, dice, result)
    return result


def Save(
        brain: Brain,
        file_name: str
        ) -> None:
    with open(file_name, "w", encoding="utf-8", newline="\n") as out:
        records.Write_Word(out, FILE_MARK)
        records.Write_Count(out, FILE_VERSION)
        size = alphabets.Size(brain.letters)
        records.Write_Count(out, size)
        for symbol in range(1, size + 1):
            records.Write_Count(out, ord(alphabets.Character_Of(brain.letters, symbol)))
            #-- Each letter is saved as its Unicode number.
        records.Write_Count(out, brain.lessons)
        records.Write_Real(out, brain.learning_rate)
        records.Write_Count(out, Neuron_Count(brain))
        for index in range(0, Neuron_Count(brain)):
            records.Write_Word(out, brain.neurons[index].Kind())
            records.Write_Real(out, brain.weights[index])
            brain.neurons[index].Save(out)


def Load(
        brain: Brain,
        file_name: str
        ) -> None:
    try:
        source = open(file_name, encoding="utf-8")
    except OSError as problem:
        raise records.Record_Error(f"cannot open {file_name}: {problem}")
    with source:
        records.Expect_Word(source, FILE_MARK)
        version = records.Read_Count(source)
        if version != FILE_VERSION:
            raise records.Record_Error("this file was saved by a different version")
        size = records.Read_Count(source)
        letters = alphabets.Alphabet()
        records.Read_Count(source)
        #-- Symbol 1 is always the unknown mark: its line is read and set aside.
        for _ in range(2, size + 1):
            alphabets.Include(letters, chr(records.Read_Count(source)))
        Prepare(brain, letters)
        brain.lessons = records.Read_Count(source)
        brain.learning_rate = records.Read_Real(source)
        count = records.Read_Count(source)
        for _ in range(0, count):
            kind = records.Read_Word(source)
            weight = records.Read_Real(source)
            neuron = neuron_kinds.Blank_Of_Kind(kind)
            neuron.Load(source)
            Add_Neuron(brain, neuron, weight)
