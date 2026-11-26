"""Mirror of tests/calipso_tests.adb: the same tests, with the same corpus.

Usage:
    python3 reference/tests.py

The expected values used by the Ada tests come from here.
"""

import os
import sys

from calipso_ref import UNKNOWN
from calipso_ref import alphabets
from calipso_ref import anchored_oracles
from calipso_ref import axes
from calipso_ref import basis_neurons
from calipso_ref import bias_neurons
from calipso_ref import blind_spots
from calipso_ref import boxed_oracles
from calipso_ref import brains
from calipso_ref import canvases
from calipso_ref import certainties
from calipso_ref import collapsing
from calipso_ref import company
from calipso_ref import counting_neurons
from calipso_ref import counting_oracles
from calipso_ref import criteria
from calipso_ref import distributions
from calipso_ref import fetchers
from calipso_ref import fragment_counts
from calipso_ref import groups
from calipso_ref import kind_makers
from calipso_ref import kinds
from calipso_ref import neuron_kinds
from calipso_ref import pages
from calipso_ref import pyramids
from calipso_ref import random_sources
from calipso_ref import records
from calipso_ref import repairing
from calipso_ref import robots
from calipso_ref import settling
from calipso_ref import sources
from calipso_ref import templates
from calipso_ref import texts
from calipso_ref import tokens
from calipso_ref import vectors
from calipso_ref import web_addresses
from calipso_ref import web_sources
from calipso_ref import word_exams
from calipso_ref import writers

CORPUS_TEXT = (
    "la casa de la costa es la casa de la rosa. la rosa de la casa es la cosa de la costa. "
    "el oso de la rosa es el oso de la casa. la casa del oso es la costa."
    )
TEST_LONGEST = 5
SAVED_BRAIN = "brain_test_saved.brn"
SAVED_TAPE = "tape_test_saved.brn"
PACKED_TAPE = "tape_test_saved.zmb"
PACKED_BRAIN = "tests/data/brain_from_python.zmb"
PYTHON_BRAIN = "tests/data/brain_from_python.brn"
SAMPLE_FILE = "data/sample_es.txt"
TEST_SITE = "http://test.site"
SITE_FOLDER = "tests/site"
PAGE_WORK_FILE = "page_test_work.tmp"
PYRAMID_CORPUS = "data/sample_es.txt"
#-- The tests are run from the top folder of the project.
TOLERANCE = 1.0e-9


class Fixture:
    #-- What all the tests share.

    def __init__(self):
        self.letters = alphabets.Alphabet()
        for char in CORPUS_TEXT:
            alphabets.Include(self.letters, char)
        self.corpus = texts.Encoded(CORPUS_TEXT, self.letters)
        self.model = counting_oracles.Counting_Oracle()
        counting_oracles.Train(self.model, self.corpus, alphabets.Size(self.letters), TEST_LONGEST)
        self.failures = 0


def Check(
        fixture: Fixture,
        name: str,
        condition: bool
        ) -> None:
    if condition:
        print("  ok     " + name)
    else:
        print("  FAIL   " + name)
        fixture.failures = fixture.failures + 1


def Check_Close(
        fixture: Fixture,
        name: str,
        actual: float,
        expected: float
        ) -> None:
    difference = abs(actual - expected)
    Check(fixture, name, difference <= TOLERANCE)
    if difference > TOLERANCE:
        print(f"         got {actual!r}")
        print(f"         expected {expected!r}")


def Symbol_For(
        fixture: Fixture,
        char: str
        ) -> int:
    return alphabets.Symbol_Of(fixture.letters, char)


def Seen(
        fixture: Fixture,
        plain: str
        ) -> int:
    piece = bytes(texts.Encoded(plain, fixture.letters))
    return fragment_counts.Count_Of(fixture.model.table, piece)


def Givens_Kept(
        fixture: Fixture,
        board: canvases.Canvas,
        template: str
        ) -> bool:
    #-- Are all the given letters of the template still on the canvas, in the same order?
    original = templates.Parsed(template, fixture.letters)
    cursor = -1
    for position in range(0, canvases.Length(original)):
        if canvases.State_At(original, position) == canvases.GIVEN:
            while True:
                cursor = cursor + 1
                if cursor >= canvases.Length(board):
                    return False
                if canvases.State_At(board, cursor) == canvases.GIVEN:
                    break
            if canvases.Symbol_At(board, cursor) != canvases.Symbol_At(original, position):
                return False
    return True


def Test_Random_Sources(
        fixture: Fixture
        ) -> None:
    dice = random_sources.Seeded(42)
    Check_Close(fixture, "first number from seed 42", random_sources.Draw_Unit(dice), 0.5682303266439076)
    Check_Close(fixture, "second number from seed 42", random_sources.Draw_Unit(dice), 0.2254634289477513)
    Check_Close(fixture, "third number from seed 42", random_sources.Draw_Unit(dice), 0.41283831882951183)
    dice = random_sources.Seeded(7)
    indexes = []
    for _ in range(0, 8):
        indexes.append(random_sources.Draw_Index(dice, 10))
    Check(fixture, "eight indexes from seed 7", indexes == [4, 9, 9, 2, 2, 1, 4, 3])


def Test_Alphabets(
        fixture: Fixture
        ) -> None:
    Check(fixture, "the alphabet has 12 symbols", alphabets.Size(fixture.letters) == 12)
    Check(fixture, "the first letter seen gets symbol 2", Symbol_For(fixture, "l") == 2)
    Check(fixture, "the second letter seen gets symbol 3", Symbol_For(fixture, "a") == 3)
    Check(fixture, "the full stop gets symbol 12", Symbol_For(fixture, ".") == 12)
    Check(fixture, "a letter never seen is unknown", Symbol_For(fixture, "z") == UNKNOWN)
    Check(fixture, "symbol 5 maps back to the letter c", alphabets.Character_Of(fixture.letters, 5) == "c")
    Check(fixture, "encoding and decoding returns the text", texts.Decoded(fixture.corpus, fixture.letters) == CORPUS_TEXT)


def Test_Distributions(
        fixture: Fixture
        ) -> None:
    even = distributions.Uniform(4)
    tally = distributions.Zero(4)
    distributions.Set_Weight(tally, 1, 1.0)
    distributions.Set_Weight(tally, 2, 3.0)
    distributions.Set_Weight(tally, 3, 0.0)
    distributions.Set_Weight(tally, 4, 4.0)
    Check_Close(fixture, "entropy of 4 equal letters = ln 4", distributions.Entropy(even), 1.3862943611198906)
    Check_Close(fixture, "total weight", distributions.Total(tally), 8.0)
    Check(fixture, "variety: 3 letters with weight", distributions.Variety(tally) == 3)
    Check(fixture, "the most likely is letter 4", distributions.Most_Likely(tally) == 4)
    Check_Close(fixture, "entropy of (1, 3, 0, 4)", distributions.Entropy(tally), 0.9743147528693494)
    Check_Close(fixture, "surprise of letter 2", distributions.Surprise_Of(tally, 2), 0.9808292530117262)
    Check_Close(fixture, "surprise of an impossible letter", distributions.Surprise_Of(tally, 3), 690.7755278982137)
    Check(fixture, "dice at 0.000 -> letter 1", distributions.Sampled(tally, 0.0) == 1)
    Check(fixture, "dice at 0.124 -> letter 1", distributions.Sampled(tally, 0.124) == 1)
    Check(fixture, "dice at 0.126 -> letter 2", distributions.Sampled(tally, 0.126) == 2)
    Check(fixture, "dice at 0.490 -> letter 2", distributions.Sampled(tally, 0.49) == 2)
    Check(fixture, "dice at 0.510 -> letter 4 (letter 3 is impossible)", distributions.Sampled(tally, 0.51) == 4)
    Check(fixture, "dice at 0.999 -> letter 4", distributions.Sampled(tally, 0.999) == 4)
    mixed = tally + 2.0 * even
    shares = distributions.Normalized(tally)
    Check_Close(fixture, "algebra: Tally + 2.0 * Even, letter 1", distributions.Weight_Of(mixed, 1), 1.5)
    Check_Close(fixture, "algebra: Tally + 2.0 * Even, letter 3", distributions.Weight_Of(mixed, 3), 0.5)
    Check_Close(fixture, "normalize: letter 2", distributions.Weight_Of(shares, 2), 0.375)
    Check_Close(fixture, "normalize: sums to 1", distributions.Total(shares), 1.0)


def Test_Fragment_Counts(
        fixture: Fixture
        ) -> None:
    Check(fixture, "187 distinct fragments", fragment_counts.Distinct_Fragments(fixture.model.table) == 187)
    Check(fixture, "the letter a appears 29 times", Seen(fixture, "a") == 29)
    Check(fixture, "the fragment la appears 12 times", Seen(fixture, "la") == 12)
    Check(fixture, "the fragment casa appears 5 times", Seen(fixture, "casa") == 5)
    Check(fixture, "the fragment rosa. appears once", Seen(fixture, "rosa.") == 1)
    Check(fixture, "a fragment never seen counts 0", Seen(fixture, "xx") == 0)
    Check(fixture, "a fragment with spaces: 6 times", Seen(fixture, " de l") == 6)


def Test_Opinions(
        fixture: Fixture
        ) -> None:
    both_sides = templates.Parsed("la c_sa de", fixture.letters)
    alone = templates.Parsed("_", fixture.letters)
    left_only = templates.Parsed("la ros_", fixture.letters)
    letter_a = Symbol_For(fixture, "a")
    letter_o = Symbol_For(fixture, "o")
    belief = fixture.model.Opinion(both_sides, 4)
    Check_Close(fixture, "both sides: P(a)", distributions.Probability_Of(belief, letter_a), 0.7633265411439716)
    Check_Close(fixture, "both sides: P(o)", distributions.Probability_Of(belief, letter_o), 0.2355700126736941)
    Check_Close(fixture, "both sides: entropy", distributions.Entropy(belief), 0.556390935921461)
    Check(fixture, "both sides: the most likely is a", distributions.Most_Likely(belief) == letter_a)
    Check_Close(fixture, "the opinion sums to 1", distributions.Total(belief), 1.0)
    belief = fixture.model.Opinion(alone, 0)
    Check_Close(fixture, "no neighbours: P(a)", distributions.Probability_Of(belief, letter_a), 0.18131313131313131)
    Check_Close(fixture, "no neighbours: entropy", distributions.Entropy(belief), 2.1766977283465896)
    belief = fixture.model.Opinion(left_only, 6)
    Check_Close(fixture, "left side only: P(a)", distributions.Probability_Of(belief, letter_a), 0.9628293807641635)


def Test_Templates(
        fixture: Fixture
        ) -> None:
    board = templates.Parsed("la [3]_ [...]fin\\n[x]", fixture.letters)
    plain = templates.Parsed("la casa", fixture.letters)
    Check(fixture, "template: 45 cells", canvases.Length(board) == 45)
    Check(fixture, "template: 34 holes", canvases.Blank_Count(board) == 34)
    Check(fixture, "rendering a template with no holes returns it unchanged", templates.Rendered(plain, fixture.letters) == "la casa")
    Check(fixture, "a bracket without a number is not a hole", canvases.State_At(board, 42) == canvases.GIVEN)


def Test_Collapsing(
        fixture: Fixture
        ) -> None:
    template = "la [12] rosa."
    board = templates.Parsed(template, fixture.letters)
    dice = random_sources.Seeded(1)
    collapsing.Collapse_All(board, fixture.model, dice)
    Check(fixture, "after collapsing no holes are left", canvases.Blank_Count(board) == 0)
    Check(fixture, "after collapsing there are 12 model letters", canvases.Guess_Count(board) == 12)
    Check(fixture, "collapsing does not touch the given letters", Givens_Kept(fixture, board, template))
    Check(fixture, "collapse, seed 1", templates.Rendered(board, fixture.letters, True) == "la [costa. es la] rosa.")

    board = templates.Parsed(template, fixture.letters)
    dice = random_sources.Seeded(1)
    collapsing.Collapse_All(board, fixture.model, dice, collapsing.LEFT_TO_RIGHT, collapsing.ALWAYS_MOST_LIKELY)
    Check(fixture, "left to right without drawing lots", templates.Rendered(board, fixture.letters, True) == "la [casa de la l] rosa.")

    board = templates.Parsed(template, fixture.letters)
    dice = random_sources.Seeded(5)
    collapsing.Collapse_All(board, fixture.model, dice, collapsing.AT_RANDOM)
    Check(fixture, "random order: no holes are left", canvases.Blank_Count(board) == 0)
    Check(fixture, "random order, seed 5", templates.Rendered(board, fixture.letters, True) == "la [olasa. ela o] rosa.")


def Test_Repairing(
        fixture: Fixture
        ) -> None:
    template = "la cos_del oso"
    board = templates.Parsed(template, fixture.letters)
    dice = random_sources.Seeded(3)
    options = repairing.Settings()
    collapsing.Collapse_All(board, fixture.model, dice)
    before = repairing.Tension(board, fixture.model, options.tolerance)
    outcome = repairing.Relax(board, fixture.model, dice, options)
    Check(fixture, "repair never raises the tension", outcome.final_tension <= before)
    Check(fixture, "repair does not touch the given letters", Givens_Kept(fixture, board, template))
    Check(fixture, "after repair no holes are left", canvases.Blank_Count(board) == 0)
    Check_Close(fixture, "the final tension is the tension of the canvas", repairing.Tension(board, fixture.model, options.tolerance), outcome.final_tension)
    Check(fixture, "a hole that is too short grows", templates.Rendered(board, fixture.letters, True) == "la cos[asa ]del oso")
    Check(fixture, "the fix was a widening", outcome.widenings == 1)


def Test_Blind_Spots(
        fixture: Fixture
        ) -> None:
    original = templates.From_Text(fixture.corpus, 0, 60)
    board = canvases.Copy(original)
    dice = random_sources.Seeded(9)
    blind_spots.Hide_At_Random(board, 0.3, dice)
    Check(fixture, "22 letters out of 60 are hidden", canvases.Blank_Count(board) == 22)
    collapsing.Collapse_All(board, fixture.model, dice, collapsing.MOST_CERTAIN_FIRST, collapsing.ALWAYS_MOST_LIKELY)
    result = blind_spots.Scored(board, original)
    Check(fixture, "the 22 hidden letters are scored", result.hidden == 22)
    Check(fixture, "20 out of 22 are recovered", result.recovered == 20)


def Test_Bounded_Memory(
        fixture: Fixture
        ) -> None:
    table = fragment_counts.Count_Table()
    fragment_counts.Limit(table, 1000)
    fragment_counts.Learn(table, fixture.corpus, TEST_LONGEST)
    Check(fixture, "bounded memory: la appears 12 times", fragment_counts.Count_Of(table, bytes(texts.Encoded("la", fixture.letters))) == 12)
    Check(fixture, "bounded memory: casa appears 5 times", fragment_counts.Count_Of(table, bytes(texts.Encoded("casa", fixture.letters))) == 5)
    Check(fixture, "bounded memory: 173 counters in use", fragment_counts.Distinct_Fragments(table) == 173)
    Check(fixture, "bounded memory: the scrambled number of la", fragment_counts.Hash(bytes(texts.Encoded("la", fixture.letters))) == 1585155634)
    Check(fixture, "bounded memory: the check number of la", fragment_counts.Check_Of(bytes(texts.Encoded("la", fixture.letters))) == 1123950074)
    Check(fixture, "bounded memory: a fragment never seen reads 0, even where a counter is taken", fragment_counts.Count_Of(table, bytes(texts.Encoded("laa", fixture.letters))) == 0)


def Test_Basis_Neurons(
        fixture: Fixture
        ) -> None:
    size = alphabets.Size(fixture.letters)
    waves = basis_neurons.Basis_Neuron()
    basis_neurons.Prepare(waves, size, basis_neurons.BY_HARMONIC, 3, 2)
    fading = basis_neurons.Basis_Neuron()
    basis_neurons.Prepare(fading, size, basis_neurons.BY_DECAY, 3, 2)
    exact = basis_neurons.Basis_Neuron()
    basis_neurons.Prepare(exact, size, basis_neurons.BY_POSITION, 3, 0)
    #-- Mirror note: curves count from 0 here and from 1 in Ada.
    Check_Close(fixture, "harmonic: the first curve is flat", basis_neurons.Curve_Height(waves, 0, 2), 1.0)
    Check_Close(fixture, "harmonic: cosine of the first wave", basis_neurons.Curve_Height(waves, 1, 1), 0.6234898018587336)
    Check_Close(fixture, "harmonic: sine of the first wave", basis_neurons.Curve_Height(waves, 2, -2), -0.9749279121818236)
    Check_Close(fixture, "harmonic: cosine of the second wave", basis_neurons.Curve_Height(waves, 3, 3), 0.6234898018587334)
    Check_Close(fixture, "decay: the nearest neighbour counts 1", basis_neurons.Curve_Height(fading, 0, -1), 1.0)
    Check_Close(fixture, "decay: slow fading at distance 3", basis_neurons.Curve_Height(fading, 1, -3), 0.36787944117144233)
    Check_Close(fixture, "decay: a right curve at distance 2", basis_neurons.Curve_Height(fading, 2, 2), 0.36787944117144233)
    Check_Close(fixture, "decay: a left curve ignores the right side", basis_neurons.Curve_Height(fading, 0, 2), 0.0)
    Check_Close(fixture, "position: a curve is 1 at its own distance", basis_neurons.Curve_Height(exact, 3, 1), 1.0)
    Check_Close(fixture, "position: and 0 at any other", basis_neurons.Curve_Height(exact, 3, 2), 0.0)
    Check(fixture, "the presence neuron is a harmonic neuron with no waves", neuron_kinds.Made("presence", size).Name() == "presence")


def Build_Small_Brain(
        fixture: Fixture
        ) -> brains.Brain:
    #-- A brain small enough for the tiny corpus: starting points plus exact distances up to 3.
    size = alphabets.Size(fixture.letters)
    brain = brains.Brain()
    brains.Prepare(brain, fixture.letters)
    bias = bias_neurons.Bias_Neuron()
    bias_neurons.Prepare(bias, size)
    brains.Add_Neuron(brain, bias)
    exact = basis_neurons.Basis_Neuron()
    basis_neurons.Prepare(exact, size, basis_neurons.BY_POSITION, 3, 0)
    brains.Add_Neuron(brain, exact)
    return brain


def Study_From_Corpus(
        fixture: Fixture,
        brain: brains.Brain,
        lessons: int
        ) -> blind_spots.Exam_Result:
    source = sources.Memory_Source()
    sources.Open_Memory(source, fixture.corpus, 24, 7)
    dice = random_sources.Seeded(11)
    return brains.Study(brain, source, dice, lessons)


def Build_Mixed_Brain(
        fixture: Fixture
        ) -> brains.Brain:
    brain = brains.Brain()
    brains.Prepare(brain, fixture.letters)
    brains.Add_Recipe(brain, "bias+presence+harmonic+decay+counting")
    Study_From_Corpus(fixture, brain, 30)
    return brain


def Recipe_Is_Refused(
        fixture: Fixture,
        recipe: str
        ) -> bool:
    brain = brains.Brain()
    brains.Prepare(brain, fixture.letters)
    try:
        brains.Add_Recipe(brain, recipe)
    except neuron_kinds.Recipe_Error:
        return True
    return False


def Opinion_On_A(
        fixture: Fixture,
        model
        ) -> float:
    #-- What the model bets on the letter a in "la c_sa de".
    board = templates.Parsed("la c_sa de", fixture.letters)
    belief = model.Opinion(board, 4)
    return distributions.Probability_Of(belief, Symbol_For(fixture, "a"))


def Test_Brains(
        fixture: Fixture
        ) -> None:
    scores = [0.0, 0.0, 1.0, -1.0, 2.0]
    #-- Position 0 is not used: the scores are (0, 1, -1, 2).
    shares = distributions.From_Scores(scores)
    Check_Close(fixture, "scores to probabilities: letter 1", distributions.Weight_Of(shares, 1), 0.08714431874203257)
    Check_Close(fixture, "scores to probabilities: letter 4", distributions.Weight_Of(shares, 4), 0.6439142598879724)
    Check_Close(fixture, "scores to probabilities: sums to 1", distributions.Total(shares), 1.0)

    brain = Build_Small_Brain(fixture)
    Check_Close(fixture, "untrained: all letters equally likely", Opinion_On_A(fixture, brain), 0.08333333333333333)
    result = Study_From_Corpus(fixture, brain, 60)
    Check(fixture, "studying 60 lessons tests 648 letters and gets 237 right", result.hidden == 648 and result.hits == 237)
    Check_Close(fixture, "studying 60 lessons: mean surprise", blind_spots.Mean_Surprise(result), 1.994014327824858)
    Check_Close(fixture, "after studying: P(a)", Opinion_On_A(fixture, brain), 0.1852612847565514)
    Check(fixture, "the brain knows its recipe", brains.Recipe_Of(brain) == "bias+position:3")
    Check(fixture, "the brain counts its lessons", brain.lessons == 60)
    Check(fixture, "the reach of a brain is that of its widest neuron", brain.Reach() == 3)

    brains.Save(brain, SAVED_BRAIN)
    restored = brains.Brain()
    brains.Load(restored, SAVED_BRAIN)
    os.remove(SAVED_BRAIN)
    Check_Close(fixture, "saved and loaded: the same opinion", Opinion_On_A(fixture, restored), Opinion_On_A(fixture, brain))
    Check(fixture, "saved and loaded: the same recipe and lessons", brains.Recipe_Of(restored) == "bias+position:3" and restored.lessons == 60)

    foreign = brains.Brain()
    brains.Load(foreign, PYTHON_BRAIN)
    Check_Close(fixture, "a brain saved by Python: P(a)", Opinion_On_A(fixture, foreign), 0.1852612847565514)
    Check(fixture, "a brain saved by Python: recipe and lessons", brains.Recipe_Of(foreign) == "bias+position:3" and foreign.lessons == 60)

    unpacked = brains.Brain()
    brains.Load(unpacked, PACKED_BRAIN)
    Check_Close(fixture, "a packed brain saved by Python: P(a)", Opinion_On_A(fixture, unpacked), 0.1852612847565514)

    sized = brains.Brain()
    brains.Prepare(sized, fixture.letters)
    brains.Add_Recipe(sized, "bias+position:5+decay:6:2+memory:4096:5")
    Check(fixture, "a recipe can give sizes, and the brain says them back", brains.Recipe_Of(sized) == "bias+position:5+decay:6:2+memory:4096:5")
    Check(fixture, "the usual sizes are not written", neuron_kinds.Made("harmonic:12:4", alphabets.Size(fixture.letters)).Name() == "harmonic")
    Check(fixture, "the reach of a sized brain", sized.Reach() == 6)
    Check(fixture, "a size of 0 is refused", Recipe_Is_Refused(fixture, "position:0"))
    Check(fixture, "a size where none belongs is refused", Recipe_Is_Refused(fixture, "bias:3"))

    mixed = brains.Brain()
    brains.Prepare(mixed, fixture.letters)
    brains.Add_Recipe(mixed, "bias+presence+harmonic+decay+counting")
    result = Study_From_Corpus(fixture, mixed, 30)
    Check(fixture, "five kinds of neuron in one brain: 142 right out of 326", result.hidden == 326 and result.hits == 142)
    Check_Close(fixture, "five kinds of neuron: mean surprise", blind_spots.Mean_Surprise(result), 1.5310978676143332)
    Check_Close(fixture, "five kinds of neuron: P(a)", Opinion_On_A(fixture, mixed), 0.6032365023141226)
    Check(fixture, "five kinds of neuron: recipe", brains.Recipe_Of(mixed) == "bias+presence+harmonic+decay+counting")

    lone = counting_neurons.Counting_Neuron()
    counting_neurons.Prepare(lone, alphabets.Size(fixture.letters))
    lone.Learn_From_Text(fixture.corpus)
    counter = brains.Brain()
    brains.Prepare(counter, fixture.letters)
    brains.Add_Neuron(counter, lone)
    teacher = counting_oracles.Counting_Oracle()
    counting_oracles.Train(teacher, fixture.corpus, alphabets.Size(fixture.letters))
    Check_Close(fixture, "a brain with only the counting neuron says what the counting oracle says", Opinion_On_A(fixture, counter), Opinion_On_A(fixture, teacher))
    Check(fixture, "a recipe with an unknown name is refused", Recipe_Is_Refused(fixture, "bias+nonsense"))


def Test_Criteria(
        fixture: Fixture
        ) -> None:
    template = "la [12] rosa."
    board = templates.Parsed("la c_sa de", fixture.letters)
    mixed_brain = Build_Mixed_Brain(fixture)
    Check_Close(fixture, "certainty of a hole with both sides known", criteria.Certainty().Readiness(board, fixture.model, 4), 0.7760918157754821)
    Check_Close(fixture, "leftmost: readiness falls with position", criteria.Leftmost().Readiness(board, fixture.model, 4), 0.6)
    Check_Close(fixture, "agreement among the neurons of a brain", criteria.Agreement().Readiness(board, mixed_brain, 4), 0.1481966929575596)
    Check_Close(fixture, "agreement without neurons to compare answers as certainty", criteria.Agreement().Readiness(board, fixture.model, 4), 0.7760918157754821)
    mix = criteria.Mixed()
    criteria.Add_Part(mix, criteria.Certainty(), 3.0)
    criteria.Add_Part(mix, criteria.Leftmost(), 1.0)
    Check_Close(fixture, "a mix of criteria is their weighted mean", mix.Readiness(board, fixture.model, 4), 0.7320688618316117)

    filled = templates.Parsed(template, fixture.letters)
    dice = random_sources.Seeded(1)
    collapsing.Collapse_By(filled, fixture.model, dice, criteria.Certainty())
    Check(fixture, "collapse by certainty: no holes are left", canvases.Blank_Count(filled) == 0)
    Check(fixture, "collapse by certainty is most-certain-first", templates.Rendered(filled, fixture.letters, True) == "la [costa. es la] rosa.")

    filled = templates.Parsed(template, fixture.letters)
    dice = random_sources.Seeded(1)
    collapsing.Collapse_By(filled, fixture.model, dice, criteria.Leftmost(), collapsing.ALWAYS_MOST_LIKELY)
    Check(fixture, "collapse by leftmost is left to right", templates.Rendered(filled, fixture.letters, True) == "la [casa de la l] rosa.")

    filled = templates.Parsed(template, fixture.letters)
    dice = random_sources.Seeded(1)
    collapsing.Collapse_By(filled, mixed_brain, dice, criteria.Agreement())
    Check(fixture, "collapse by agreement: no holes are left", canvases.Blank_Count(filled) == 0)
    Check(fixture, "collapse by agreement, seed 1", templates.Rendered(filled, fixture.letters, True) == "la [coco de roso] rosa.")


def Test_Sources(
        fixture: Fixture
        ) -> None:
    source = sources.Memory_Source()
    sources.Open_Memory(source, fixture.corpus, 24, 7)
    piece, found = source.Next_Piece()
    Check(fixture, "memory source: the first piece of seed 7", found and texts.Decoded(piece, fixture.letters) == " la cosa de la costa. el")

    file_letters = alphabets.Alphabet()
    texts.Learn_Alphabet(SAMPLE_FILE, file_letters)
    whole = texts.Read_Symbols(SAMPLE_FILE, file_letters)
    reader = sources.File_Source()
    sources.Open_File(reader, SAMPLE_FILE, file_letters, 100)
    count = 0
    first_matches = False
    while True:
        piece, found = reader.Next_Piece()
        if not found:
            break
        count = count + 1
        if count == 1:
            first_matches = (piece == texts.Part(whole, 0, 99))
    sources.Close_File(reader)
    Check(fixture, "file source: 91 pieces of 100 letters", count == 91)
    Check(fixture, "file source: the first piece is the start of the file", first_matches)


def Test_Records(
        fixture: Fixture
        ) -> None:
    tape = records.Tape()
    records.Write_Word(tape, "first")
    records.Write_Count(tape, 144)
    records.Write_Real(tape, -0.125)
    records.Write_Reals(tape, [0.0, 2.5, 0.0, -1.0])
    records.Save(tape, SAVED_TAPE)
    back = records.Load(SAVED_TAPE)
    os.remove(SAVED_TAPE)
    Check(fixture, "a word comes back from the file", records.Read_Word(back) == "first")
    Check(fixture, "a whole number comes back", records.Read_Count(back) == 144)
    Check(fixture, "a real number comes back exactly", records.Read_Real(back) == -0.125)
    row = records.Read_Reals(back)
    Check(fixture, "a sparse row comes back with its zeros", len(row) == 4 and row[0] == 0.0 and row[1] == 2.5 and row[3] == -1.0)
    records.Save(tape, PACKED_TAPE)
    packed = records.Load(PACKED_TAPE)
    packed_size = os.path.getsize(PACKED_TAPE)
    os.remove(PACKED_TAPE)
    Check(fixture, "the packed form keeps the same word", records.Read_Word(packed) == "first")
    Check(fixture, "the packed form keeps the same numbers", packed.reals == tape.reals)
    Check(fixture, "the packed form of this tape takes 50 bytes", packed_size == 50)
    Check(fixture, "the package name of a brain file", records.Unit_Name_For("brains/page.brn") == "Page_Brain")
    Check(fixture, "marks in the file name become underlines", records.Unit_Name_For("my-page.2.brn") == "My_Page_2_Brain")


def Test_Web_Addresses(
        fixture: Fixture
        ) -> None:
    base = "http://test.site/sub/c.html?x=1"
    Check(fixture, "a link one folder up", web_addresses.Resolved(base, "../a.html") == "http://test.site/a.html")
    Check(fixture, "a link from the top of the site", web_addresses.Resolved(base, "/index.html") == "http://test.site/index.html")
    Check(fixture, "the part after # is dropped", web_addresses.Resolved(base, "d.html#top") == "http://test.site/sub/d.html")
    Check(fixture, "a link to the same page leads nowhere", web_addresses.Resolved(base, "#top") == "")
    Check(fixture, "a mail link cannot be followed", web_addresses.Resolved(base, "mailto:me@test.site") == "")
    Check(fixture, "a full address gets its final slash", web_addresses.Resolved(base, "http://other.org") == "http://other.org/")
    Check(fixture, "a link that only changes the question", web_addresses.Resolved(base, "?page=2") == "http://test.site/sub/c.html?page=2")
    Check(fixture, "stay-here and go-up parts are worked out", web_addresses.Resolved(base, "./e/../f.html") == "http://test.site/sub/f.html")
    Check(fixture, "going up too far stops at the top", web_addresses.Resolved(base, "../../..") == "http://test.site/")
    Check(fixture, "a link with a space is dropped", web_addresses.Resolved(base, "a b.html") == "")
    Check(fixture, "the host of an address", web_addresses.Host_Of("https://test.site:8080/a/b") == "test.site:8080")
    Check(fixture, "by name: no ending may be a page", web_addresses.Kind_By_Name("http://test.site/wiki/Sea") == web_addresses.PAGE)
    Check(fixture, "by name: a picture, even in capitals", web_addresses.Kind_By_Name("http://test.site/a.PNG?x=1.html") == web_addresses.PICTURE)
    Check(fixture, "by name: a film", web_addresses.Kind_By_Name("http://test.site/clip.mp4") == web_addresses.VIDEO)
    Check(fixture, "by name: program code is writing", web_addresses.Kind_By_Name("http://test.site/tool.py") == web_addresses.WRITING)
    Check(fixture, "by label: a page", web_addresses.Kind_By_Label("Text/HTML; charset=utf-8") == web_addresses.PAGE)
    Check(fixture, "by label: a drawing written as text is writing", web_addresses.Kind_By_Label("image/svg+xml") == web_addresses.WRITING)
    Check(fixture, "by label: unknown bytes are other", web_addresses.Kind_By_Label("application/octet-stream") == web_addresses.OTHER)
    Check(fixture, "the sense of program code is its ending", web_addresses.Sense_Of("http://test.site/tool.py", web_addresses.WRITING) == "py")
    Check(fixture, "the sense of a page is page", web_addresses.Sense_Of("http://test.site/a.html", web_addresses.PAGE) == "page")


PAGE_MARKUP = (
    "<html><head><title>Test &amp; page</title><style>p {color: red}</style>"
    "<script>var a = '<p>not text</p>';</script></head><body><!-- a <b>comment</b> -->"
    "<h1>Hello   world</h1><p>First <a href=\"a.html?x=1&amp;y=2\">link</a> and "
    "<A HREF='b.html'>another</A>&nbsp;one &#233; &bogus; AT&T.</p>"
    "<img alt=\"x\" src=\"pic.png\"><p>Second<br>third <video src=clip.mp4 controls></video> end</p>"
    "<svg><circle/></svg>tail <a>no link</a> <a title=\"href=x\" href = c.html >c</a>"
    )


def Test_Pages(
        fixture: Fixture
        ) -> None:
    content = pages.Read(PAGE_MARKUP)
    Check(fixture, "the page is taken apart into 10 blocks", len(content.blocks) == 10)
    Check(fixture, "the title is the first paragraph", content.blocks[0].kind == pages.WORDS and content.blocks[0].text == "Test & page")
    Check(fixture, "runs of spaces count as one", content.blocks[1].text == "Hello world")
    Check(fixture, "letters written by name or number are read", content.blocks[2].text == "First link and another one " + chr(233) + " &bogus; AT&T.")
    Check(fixture, "a picture keeps its place and its address", content.blocks[3].kind == pages.PICTURE and content.blocks[3].text == "pic.png")
    Check(fixture, "a line break starts a new paragraph", content.blocks[4].text == "Second" and content.blocks[5].text == "third")
    Check(fixture, "a film keeps its place and its address", content.blocks[6].kind == pages.VIDEO and content.blocks[6].text == "clip.mp4")
    Check(fixture, "a drawing inside the page keeps its place", content.blocks[8].kind == pages.DRAWING)
    Check(fixture, "the last paragraph", content.blocks[9].text == "tail no link c")
    Check(fixture, "three links, as written", len(content.links) == 3 and content.links[0] == "a.html?x=1&y=2" and content.links[1] == "b.html" and content.links[2] == "c.html")
    Check(fixture, "the words of the page, one paragraph per line", len(pages.Text_Of(content)) == 99)


RULES_TEXT = (
    "# rules for the test\n"
    "User-agent: otherbot\n"
    "Disallow: /\n"
    "\n"
    "User-agent: *\n"
    "Disallow: /private/\n"
    "Allow: /private/open/\n"
    "Disallow: /*.pdf$\n"
    "Disallow: /search?*q=\n"
    "Crawl-delay: 5\n"
    "Disallow:\n"
    )


def Test_Robots(
        fixture: Fixture
        ) -> None:
    rules = robots.Parsed(RULES_TEXT, "Calipso")
    Check(fixture, "the top of the site is allowed", robots.Allows(rules, "/"))
    Check(fixture, "a forbidden folder", not robots.Allows(rules, "/private/x"))
    Check(fixture, "the longest rule that fits decides", robots.Allows(rules, "/private/open/x"))
    Check(fixture, "a rule with * and $: ends in .pdf", not robots.Allows(rules, "/a/b.pdf"))
    Check(fixture, "a rule with $ does not fit a longer path", robots.Allows(rules, "/a/b.pdfx"))
    Check(fixture, "a rule with * in the middle", not robots.Allows(rules, "/search?a=1&q=2"))
    Check(fixture, "the same rule, when the end is missing", robots.Allows(rules, "/search?a=1"))
    Check(fixture, "the site asks for 5 seconds between requests", robots.Delay_Of(rules) == 5.0)
    named = robots.Parsed(RULES_TEXT + "User-agent: calipso\nDisallow: /only-us/\n", "Calipso")
    Check(fixture, "rules that name us replace the rules for everybody", robots.Allows(named, "/private/x") and not robots.Allows(named, "/only-us/x"))
    Check(fixture, "no rules at all: everything is allowed", robots.Allows(robots.Allow_Everything(), "/x"))
    Check(fixture, "rules that could not be read: nothing is allowed", not robots.Allows(robots.Allow_Nothing(), "/x"))


def Test_Web_Sources(
        fixture: Fixture
        ) -> None:
    letters = alphabets.Common_Letters()
    Check(fixture, "the common alphabet has 144 symbols", alphabets.Size(letters) == 144)
    settings = web_sources.Settings()
    settings.pause_seconds = 0.0
    source = web_sources.Web_Source()
    web_sources.Open(source, fetchers.Folder_Fetcher(TEST_SITE, SITE_FOLDER), letters, settings, PAGE_WORK_FILE)
    web_sources.Add_Address(source, TEST_SITE + "/index.html")
    count = 0
    first_text = ""
    while True:
        piece, found = source.Next_Piece()
        if not found:
            break
        count = count + 1
        if count == 1:
            first_text = texts.Decoded(piece, letters)
    os.remove(PAGE_WORK_FILE)
    tally = source.tally
    Check(fixture, "the site gives 17 pieces of 64 letters", count == 17)
    Check(fixture, "the first piece starts with the title", first_text.startswith("The little test site\nThe little test site\nThis site is small"))
    Check(fixture, "5 pages asked for, 4 read, 1113 letters", tally.asked == 5 and tally.read == 4 and tally.letters == 1113)
    Check(fixture, "the private page is refused by the site's rules", tally.refused == 1)
    Check(fixture, "the file with no ending is asked for, and is not text", tally.not_text == 1 and len(source.finds[web_addresses.OTHER]) == 1)
    Check(fixture, "nothing failed", tally.failed == 0)
    Check(fixture, "files that are not pages are filed by kind, never asked for",
          len(source.finds[web_addresses.WRITING]) == 2 and len(source.finds[web_addresses.PICTURE]) == 1
          and len(source.finds[web_addresses.VIDEO]) == 1 and len(source.finds[web_addresses.SOUND]) == 1)
    Check(fixture, "a page linked again is not listed again: it gets mentions", web_sources.Mentions_Of(source, TEST_SITE + "/index.html") == 4)
    Check(fixture, "the other site was never listed", web_sources.Mentions_Of(source, "http://elsewhere.example/") == 0)

    settings = web_sources.Settings()
    settings.pause_seconds = 0.0
    settings.list_size = 2
    web_sources.Open(source, fetchers.Folder_Fetcher(TEST_SITE, SITE_FOLDER), letters, settings, PAGE_WORK_FILE)
    web_sources.Add_Address(source, TEST_SITE + "/index.html")
    while True:
        piece, found = source.Next_Piece()
        if not found:
            break
    os.remove(PAGE_WORK_FILE)
    tally = source.tally
    Check(fixture, "a waiting list of 2: the 4 pages are still read", tally.asked == 4 and tally.read == 4)
    Check(fixture, "a waiting list of 2: 3 links are left out", tally.left_out == 3 and web_sources.Waiting_Count(source) == 0)

    settings.list_size = 1024
    web_sources.Open(source, fetchers.Folder_Fetcher(TEST_SITE, SITE_FOLDER), letters, settings, PAGE_WORK_FILE)
    web_sources.Add_Address(source, TEST_SITE + "/private/secret.html")
    Check(fixture, "an address the site's rules close is stopped at the door: it never waits in the list",
          source.tally.refused == 1 and web_sources.Waiting_Count(source) == 0)
    web_sources.Add_Address(source, TEST_SITE + "/a.html")
    Check(fixture, "an address the rules allow takes its seat", web_sources.Waiting_Count(source) == 1)
    if os.path.exists(PAGE_WORK_FILE):
        os.remove(PAGE_WORK_FILE)

    settings.stay_under = "/sub/"
    web_sources.Open(source, fetchers.Folder_Fetcher(TEST_SITE, SITE_FOLDER), letters, settings, PAGE_WORK_FILE)
    web_sources.Add_Address(source, TEST_SITE + "/index.html")
    while True:
        piece, found = source.Next_Piece()
        if not found:
            break
    os.remove(PAGE_WORK_FILE)
    tally = source.tally
    Check(fixture, "told to stay under /sub/: only the start page and the page under /sub/ are read",
          tally.asked == 2 and tally.read == 2 and tally.letters == 682)


def Code_Sum(text: str) -> int:
    #-- A number that changes if any letter changes or moves: it lets a test check a whole text.
    total = 0
    place = 1
    for char in text:
        total = (total + place * ord(char)) % 1000003
        place = place + 1
    return total


def Test_Tokens(fixture: Fixture) -> None:
    found = tokens.Split("Hola, mundo (2024).\n\nFin de la  prueba\nfinal.")
    Check(fixture, "a text of 14 tokens", len(found) == 14)
    Check(fixture, "words, marks and numbers are told apart", found[0] == "Hola" and found[1] == "," and found[4] == "2024")
    Check(fixture, "a blank line is a break", found[7] == tokens.BREAK_TEXT and tokens.Sort_Of(found[7]) == tokens.BREAK)
    Check(fixture, "a lone end of line is only a blank", found[11] == "prueba" and found[12] == "final")
    Check(fixture, "an empty text has no tokens", len(tokens.Split("")) == 0)


def Test_Kinds(fixture: Fixture) -> None:
    sample = tokens.Split(texts.Whole_Text(PYRAMID_CORPUS))
    book = kinds.Built(sample)
    shape = kinds.Kind_Of(book, "abcdes")
    dice = random_sources.Seeded(5)
    Check(fixture, "the sample has 1892 tokens and gives 216 kinds", len(sample) == 1892 and kinds.Kind_Count(book) == 216)
    Check(fixture, "a mark is its own kind", kinds.Kind_Of(book, ".") == 2 and kinds.Family_Of(book, 2) == kinds.MARK_KIND)
    Check(fixture, "a number is known by how many digits it has",
          kinds.Kind_Of(book, "7") == 5 and kinds.Kind_Of(book, "1704") == 8
          and kinds.Kind_Of(book, "123456") == 8 and kinds.Figures_Of(book, 8) == 4)
    Check(fixture, "a usual word is its own kind",
          kinds.Kind_Of(book, "de") == 12 and kinds.Text_Of(book, 12) == "de" and kinds.Family_Of(book, 12) == kinds.WORD_KIND)
    Check(fixture, "a word never seen still has a kind: its shape",
          shape == 154 and kinds.Family_Of(book, shape) == kinds.SHAPE_KIND
          and kinds.Text_Of(book, shape) == "es" and not kinds.Is_Capital(book, shape))
    Check(fixture, "a capital letter makes another shape", kinds.Kind_Of(book, "Zaragoza") == 195 and kinds.Is_Capital(book, 195))
    Check(fixture, "a mark never seen is unknown", kinds.Kind_Of(book, "@") == UNKNOWN)
    first = kinds.Draw_Member(book, shape, dice)
    second = kinds.Draw_Member(book, shape, dice)
    third = kinds.Draw_Member(book, shape, dice)
    Check(fixture, "words are drawn from those seen in a shape", first == "lugares" and second == "entonces" and third == "errores")


def Test_Boxed_Oracles(fixture: Fixture) -> None:
    belief = distributions.Zero(4)
    distributions.Set_Weight(belief, 1, 0.1)
    distributions.Set_Weight(belief, 2, 0.5)
    distributions.Set_Weight(belief, 3, 0.3)
    distributions.Set_Weight(belief, 4, 0.1)
    allowed = [False] * 256
    Check(fixture, "a rule that allows nothing is not applied",
          distributions.Weight_Of(boxed_oracles.Kept_Part(belief, allowed), 2) == 0.5)
    allowed[2] = True
    allowed[3] = True
    kept = boxed_oracles.Kept_Part(belief, allowed)
    Check(fixture, "what is not allowed loses all its weight",
          distributions.Weight_Of(kept, 1) == 0.0 and distributions.Weight_Of(kept, 4) == 0.0)
    Check(fixture, "what is allowed keeps its proportions",
          abs(distributions.Weight_Of(kept, 2) - 0.625) < 1.0e-12 and abs(distributions.Weight_Of(kept, 3) - 0.375) < 1.0e-12)
    distributions.Set_Weight(belief, 2, 0.0)
    distributions.Set_Weight(belief, 3, 0.0)
    kept = boxed_oracles.Kept_Part(belief, allowed)
    Check(fixture, "when the brain gives no chance to anything allowed, every allowed symbol is as good as another",
          distributions.Weight_Of(kept, 2) == 0.5 and distributions.Weight_Of(kept, 3) == 0.5)


def Check_Writer(fixture: Fixture, name: str, author: writers.Writer, length: int, checksum: int) -> None:
    #-- Any writer, asked for about 10 words with the same dice, must give the same text as the Ada.
    result = author.Write(random_sources.Seeded(3), 10)
    Check(fixture, name, len(result) == length and Code_Sum(result) == checksum)


def Test_Pyramids(fixture: Fixture) -> None:
    letters = alphabets.Alphabet()
    texts.Learn_Alphabet(PYRAMID_CORPUS, letters)
    speller = counting_oracles.Counting_Oracle()
    counting_oracles.Train(speller, texts.Read_Symbols(PYRAMID_CORPUS, letters), alphabets.Size(letters))
    plan = pyramids.Pyramid()
    pyramids.Study(plan, texts.Whole_Text(PYRAMID_CORPUS))
    Check(fixture, "the pyramid decides 216 kinds from the sample", kinds.Kind_Count(plan.book) == 216)
    Check_Writer(fixture, "the flat writer: one level, letters only", writers.Flat_Writer(speller, letters), 60, 178548)
    Check_Writer(fixture, "the pyramid writer that spells: kinds first, then letters in boxes",
                 writers.Pyramid_Writer(plan, speller, letters, pyramids.SPELL), 44, 90950)
    Check_Writer(fixture, "the pyramid writer that picks: kinds first, then a word seen in that kind",
                 writers.Pyramid_Writer(plan, speller, letters, pyramids.PICK), 44, 94546)


def Test_Certainties(fixture: Fixture) -> None:
    Check(fixture, "on the signed dial, +1 is right, 0 is no idea and -1 is wrong",
          certainties.Certainty_Of(certainties.SURELY_RIGHT, 100) == 1.0
          and certainties.Certainty_Of(certainties.NO_IDEA, 100) == certainties.Chance_Level(100)
          and certainties.Certainty_Of(certainties.SURELY_WRONG, 100) == 0.0)
    Check(fixture, "no idea is one chance in the size of the alphabet", abs(certainties.Chance_Level(100) - 0.01) < 1.0e-12)
    Check(fixture, "half way up the signed dial is half way from no idea to right",
          abs(certainties.Certainty_Of(0.5, 100) - 0.505) < 1.0e-12)
    Check(fixture, "half way down the signed dial is half way from no idea to wrong",
          abs(certainties.Certainty_Of(-0.5, 100) - 0.005) < 1.0e-12)
    Check(fixture, "the two scales turn into each other and back",
          abs(certainties.Signed_Of(0.505, 100) - 0.5) < 1.0e-12 and abs(certainties.Signed_Of(0.005, 100) + 0.5) < 1.0e-12)


def Test_Anchored_Oracles(fixture: Fixture) -> None:
    belief = distributions.Zero(4)
    distributions.Set_Weight(belief, 1, 0.1)
    distributions.Set_Weight(belief, 2, 0.5)
    distributions.Set_Weight(belief, 3, 0.3)
    distributions.Set_Weight(belief, 4, 0.1)
    pulled = anchored_oracles.Pulled

    def weight(anchor, symbol):
        return distributions.Weight_Of(pulled(belief, anchor), symbol)

    Check(fixture, "a sure memory pulls the opinion toward the symbol the cell had",
          abs(weight(anchored_oracles.Anchor_Of(3, 0.9), 3) - 0.9204545454545453) < 1.0e-12)
    Check(fixture, "a certainty of 1 keeps the symbol whatever the brain thinks", weight(anchored_oracles.Anchor_Of(3, 1.0), 3) == 1.0)
    Check(fixture, "a certainty of 0 forbids the symbol and leaves the rest to the brain",
          weight(anchored_oracles.Anchor_Of(3, 0.0), 3) == 0.0
          and abs(weight(anchored_oracles.Anchor_Of(3, 0.0), 2) - 0.7142857142857143) < 1.0e-12)
    Check(fixture, "no idea changes nothing: on the signed dial that is 0",
          abs(weight(anchored_oracles.Signed_Anchor_Of(3, certainties.NO_IDEA, 4), 3) - 0.3) < 1.0e-12)
    Check(fixture, "a free cell passes the opinion untouched", weight(anchored_oracles.Free_Anchor(), 2) == 0.5)
    distributions.Set_Weight(belief, 3, 0.0)
    Check(fixture, "sure of a symbol the brain denies: the memory decides alone", weight(anchored_oracles.Anchor_Of(3, 1.0), 3) == 1.0)


def Settle_Text(speller, letters, symbols, anchors):
    #-- Writes the symbols on a canvas, settles it, and gives back the text and the report.
    board = settling.Written(symbols)
    outcome = settling.Settle(board, speller, anchors)
    final = [canvases.Symbol_At(board, position) for position in range(0, canvases.Length(board))]
    return texts.Decoded(final, letters), outcome


def Test_Settling(fixture: Fixture) -> None:
    letters = alphabets.Alphabet()
    texts.Learn_Alphabet(PYRAMID_CORPUS, letters)
    size = alphabets.Size(letters)
    speller = counting_oracles.Counting_Oracle()
    counting_oracles.Train(speller, texts.Read_Symbols(PYRAMID_CORPUS, letters), size)
    Check(fixture, "the alphabet of the sample has 51 symbols", size == 51)

    symbols = texts.Encoded("En la boca vixen muchas bactemias.", letters)
    result, outcome = Settle_Text(speller, letters, symbols, settling.Even_Anchors(symbols, certainties.Certainty_Of(0.99, size)))
    Check(fixture, "two wrong letters nobody pointed at are found and mended",
          result == "En la boca viven muchas bacterias." and outcome.passes == 2 and outcome.changes == 2 and outcome.is_settled)

    anchors = settling.Even_Anchors(symbols, certainties.Certainty_Of(certainties.NO_IDEA, size))
    result, outcome = Settle_Text(speller, letters, symbols, anchors)
    Check(fixture, "with no idea of any letter the whole text is rewritten",
          result == "ue se hacerse en muchos dos y la v" and outcome.passes == 7 and outcome.changes == 32 and outcome.is_settled)

    symbols = texts.Encoded("En la boca vixen muchas bacterias.", letters)
    anchors = settling.Even_Anchors(symbols, 1.0)
    anchors[13] = anchored_oracles.Signed_Anchor_Of(symbols[13], certainties.SURELY_WRONG, size)
    result, outcome = Settle_Text(speller, letters, symbols, anchors)
    Check(fixture, "a letter marked surely wrong is the only one that changes",
          result == "En la boca viven muchas bacterias." and outcome.changes == 1)

    symbols = texts.Encoded("Los patos duermen mucho.", letters)
    anchors = settling.Even_Anchors(symbols, certainties.Certainty_Of(0.5, size))
    anchors[4] = anchored_oracles.Anchor_Of(symbols[4], 1.0)
    result, outcome = Settle_Text(speller, letters, symbols, anchors)
    Check(fixture, "a pinned letter stays where it was put while a looser neighbour moves",
          result == "Los patos duermen muche." and outcome.changes == 1)


def Test_Evidence(fixture: Fixture) -> None:
    joined = certainties.Joined(0.5, 0.3)
    together = certainties.Evidence_Of_Signed(0.5) + certainties.Evidence_Of_Signed(0.3)
    Check(fixture, "evidence 0 is no idea on every scale",
          certainties.Signed_From(0.0) == certainties.NO_IDEA and abs(certainties.Certainty_From(0.0, 100) - 0.01) < 1.0e-12)
    Check(fixture, "the signed dial is the tanh of half the evidence", abs(certainties.Signed_From(2.0) - 0.7615941559557649) < 1.0e-12)
    Check(fixture, "and back: 0.99 on the signed dial stands for 5.29 nats",
          abs(certainties.Evidence_Of_Signed(0.99) - 5.293304824724491) < 1.0e-9)
    Check(fixture, "a chance of one half among 100 symbols is 4.6 nats above pure chance",
          abs(certainties.Evidence_Of_Certainty(0.5, 100) - 4.59511985013459) < 1.0e-9)
    Check(fixture, "two sources join: their evidence adds, on either scale",
          abs(certainties.Signed_From(together) - joined) < 1.0e-12 and abs(joined - 0.6956521739130435) < 1.0e-12)
    Check(fixture, "joining with no idea changes nothing, and opposite certainties cancel",
          certainties.Joined(0.5, certainties.NO_IDEA) == 0.5 and certainties.Joined(0.5, -0.5) == certainties.NO_IDEA
          and certainties.Joined(certainties.SURELY_RIGHT, certainties.SURELY_WRONG) == certainties.NO_IDEA)
    Check(fixture, "the curved model keeps the three fixed points of the dial",
          certainties.Certainty_By(certainties.SURELY_RIGHT, 100, certainties.CURVED) == 1.0
          and certainties.Certainty_By(certainties.SURELY_WRONG, 100, certainties.CURVED) == 0.0
          and abs(certainties.Certainty_By(certainties.NO_IDEA, 100, certainties.CURVED) - 0.01) < 1.0e-12)
    Check(fixture, "between them the models differ: 0.5 is a chance of 0.505 when straight and 0.029 when curved",
          abs(certainties.Certainty_By(0.5, 100, certainties.STRAIGHT) - 0.505) < 1.0e-12
          and abs(certainties.Certainty_By(0.5, 100, certainties.CURVED) - 0.029411764705882366) < 1.0e-9)


def Test_Vectors(fixture: Fixture) -> None:
    before = [1.0, 0.0, 0.0, 0.0]
    after = [0.0, 0.0, 1.0, 0.0]
    mixed = [1.0, 0.0, 0.0, 1.0]
    other = [1.0, 0.0, 1.0, 0.0]
    low = [1.0, 2.0, 3.0]
    high = [4.0, 5.0, 6.0]
    flat = [3.0, 4.0]
    Check(fixture, "the dot product multiplies place by place and adds", vectors.Dot(low, high) == 32.0)
    Check(fixture, "adding and scaling work place by place",
          vectors.Added(low, vectors.Scaled(2.0, high)) == [9.0, 12.0, 15.0] and vectors.Subtracted(high, low) == [3.0, 3.0, 3.0])
    Check(fixture, "the length of (3, 4) is 5", vectors.Length(flat) == 5.0)
    Check(fixture, "the unit arrow has length 1", abs(vectors.Length(vectors.Unit(flat)) - 1.0) < 1.0e-12)
    Check(fixture, "arrows at a right angle have cosine 0, opposite arrows -1, the same arrow +1",
          vectors.Cosine(before, after) == 0.0
          and abs(vectors.Cosine(flat, vectors.Scaled(-1.0, flat)) + 1.0) < 1.0e-12
          and abs(vectors.Cosine(flat, vectors.Scaled(2.0, flat)) - 1.0) < 1.0e-12)
    Check(fixture, "the complex product: its real part is the dot product",
          vectors.Complex_Product(mixed, other).real == 1.0 and vectors.Complex_Product(mixed, other).imag == 1.0)
    Check(fixture, "its imaginary part changes sign when the two are swapped: it holds order",
          vectors.Complex_Product(before, after).imag == 1.0 and vectors.Complex_Product(after, before).imag == -1.0)
    Check(fixture, "the turn is +90 degrees one way, -90 the other, and 45 half way",
          abs(vectors.Turn(before, after) - 90.0) < 1.0e-9 and abs(vectors.Turn(after, before) + 90.0) < 1.0e-9
          and abs(vectors.Turn(mixed, other) - 45.0) < 1.0e-9)


SAVANNA = "Lions eat zebras. Lions eat antelopes. Zebras eat grass. Antelopes eat grass. Gazelles eat grass."
#-- Five small sentences in which two animals keep exactly the same company.


def Test_Company(fixture: Fixture) -> None:
    sample = tokens.Split(SAVANNA)
    book = kinds.Built(sample)
    options = company.Settings()
    options.every_word = True
    table = company.Built(sample, book, options)

    def cosine(left, right):
        return vectors.Cosine(company.Vector_Of(table, left), company.Vector_Of(table, right))

    Check(fixture, "six words, each described by 44 counts",
          company.Row_Count(table) == 6 and len(company.Vector_At(table, 1)) == 44
          and company.Word_At(table, 1) == "lions" and company.Seen_At(table, 2) == 5)
    Check(fixture, "zebras and antelopes keep the same company: cosine 1", abs(cosine("zebras", "antelopes") - 1.0) < 1.0e-12)
    Check(fixture, "lions and grass keep none in common: cosine 0, and a turn of 90 degrees says they stand on opposite sides",
          cosine("lions", "grass") == 0.0
          and abs(vectors.Turn(company.Vector_Of(table, "lions"), company.Vector_Of(table, "grass")) + 90.0) < 1.0e-9)
    Check(fixture, "a capital does not make another word, and a word seen once looks like the one it was seen like",
          abs(cosine("Gazelles", "Lions") - 0.9753386489714635) < 1.0e-9)
    options = company.Settings()
    options.every_word = True
    options.reach = 2
    options.context = company.AS_WORDS
    table = company.Built(sample, book, options)
    Check(fixture, "looking two words each way, with neighbours counted as words: 1024 counts for each word",
          len(company.Vector_At(table, 1)) == 1024 and abs(cosine("zebras", "antelopes") - 0.75) < 1.0e-9)
    Check(fixture, "the scrambled number of a word", company.Hash_Of("zebras") == 2311424180)


def Test_Axes_And_Groups(fixture: Fixture) -> None:
    sample = tokens.Split(SAVANNA)
    book = kinds.Built(sample)
    options = company.Settings()
    options.every_word = True
    table = company.Built(sample, book, options)
    basis = axes.Found(table.rows, 2)
    points = [axes.Projected(basis, row) for row in table.rows]
    Check(fixture, "two axes of length 1, at right angles",
          len(basis.axes) == 2 and abs(vectors.Length(basis.axes[0]) - 1.0) < 1.0e-9
          and abs(vectors.Length(basis.axes[1]) - 1.0) < 1.0e-9 and abs(vectors.Dot(basis.axes[0], basis.axes[1])) < 1.0e-9)
    Check(fixture, "44 counts become 2 numbers, and words of the same company land on the same spot",
          len(points[0]) == 2 and abs(points[0][0] + 0.39642464446861586) < 1.0e-6
          and abs(points[2][0] - points[3][0]) < 1.0e-9 and abs(points[2][1] - points[3][1]) < 1.0e-9)
    Check(fixture, "three groups from the two numbers: zebras and antelopes together, lions with gazelles",
          groups.Grouped(points, 3) == [1, 3, 2, 2, 3, 1])
    whole = groups.Grouped(table.rows, 3)
    Check(fixture, "three groups from all 44 counts: zebras and antelopes are still together",
          whole[2] == 2 and whole[3] == 2 and whole[4] == 3 and whole[0] == 1)


def Check_Word_Exam(fixture: Fixture, name: str, options: kind_makers.Settings, count: int, right: int) -> None:
    #-- Studies nine tenths of the sample with the kinds decided as `options` says, and gives the exam on the rest.
    whole = texts.Whole_Text(PYRAMID_CORPUS)
    cut = (len(whole) * 9) // 10
    plan = pyramids.Pyramid()
    pyramids.Study(plan, whole[:cut], options)
    outcome = word_exams.Exam(plan, tokens.Split(whole[:cut]), tokens.Split(whole[cut:]), 3)
    Check(fixture, name, kinds.Kind_Count(plan.book) == count and outcome.asked == 56 and outcome.right == right)


def Test_Kind_Makers(fixture: Fixture) -> None:
    options = kind_makers.Settings()
    Check_Word_Exam(fixture, "kinds by shape: 216 kinds, 18 of 56 hidden words rebuilt", options, 216, 18)
    options.way = kind_makers.BY_COMPANY
    options.axes = 4
    options.rounds = 5
    options.groups = 12
    Check_Word_Exam(fixture, "kinds by company, 4 axes and 12 groups: 148 kinds, 17 of 56", options, 148, 17)
    options.axes = 3
    options.rounds = 3
    options.company.reach = 2
    options.company.context = company.AS_WORDS
    options.company.fold_case = False
    Check_Word_Exam(fixture, "neighbours counted as words, two each way, capitals kept: 148 kinds, 17 of 56", options, 148, 17)


def Main() -> None:
    fixture = Fixture()
    groups = [
        ("Repeatable randomness", Test_Random_Sources),
        ("Alphabet", Test_Alphabets),
        ("Distributions", Test_Distributions),
        ("Fragment counts", Test_Fragment_Counts),
        ("Model opinions", Test_Opinions),
        ("Templates", Test_Templates),
        ("Collapse", Test_Collapsing),
        ("Repair and grow", Test_Repairing),
        ("Blind spots", Test_Blind_Spots),
        ("Bounded memory", Test_Bounded_Memory),
        ("Neurons that measure distance", Test_Basis_Neurons),
        ("Brain files", Test_Records),
        ("Brains", Test_Brains),
        ("Criteria", Test_Criteria),
        ("Sources", Test_Sources),
        ("Web addresses", Test_Web_Addresses),
        ("Pages", Test_Pages),
        ("Site rules", Test_Robots),
        ("Web source", Test_Web_Sources),
        ("Tokens", Test_Tokens),
        ("Kinds of token", Test_Kinds),
        ("Boxed oracle", Test_Boxed_Oracles),
        ("Pyramid and writers", Test_Pyramids),
        ("The dial", Test_Certainties),
        ("Anchored oracle", Test_Anchored_Oracles),
        ("Settling", Test_Settling),
        ("Evidence and the curved dial", Test_Evidence),
        ("Vectors", Test_Vectors),
        ("The company a word keeps", Test_Company),
        ("Main axes and groups", Test_Axes_And_Groups),
        ("Ways of deciding kinds", Test_Kind_Makers),
        ]
    for title, group in groups:
        print(title)
        group(fixture)
    print()
    print(f"Failures: {fixture.failures}")
    if fixture.failures > 0:
        sys.exit(1)


if __name__ == "__main__":
    Main()
