"""Mirror of tests/calipso_tests.adb: the same tests, with the same corpus.

Usage:
    python3 reference/tests.py

The expected values used by the Ada tests come from here.
"""

import sys

from calipso_ref import UNKNOWN
from calipso_ref import alphabets
from calipso_ref import blind_spots
from calipso_ref import canvases
from calipso_ref import collapsing
from calipso_ref import counting_oracles
from calipso_ref import distributions
from calipso_ref import fragment_counts
from calipso_ref import random_sources
from calipso_ref import repairing
from calipso_ref import templates
from calipso_ref import texts
from calipso_ref import voting_oracles

CORPUS_TEXT = (
    "la casa de la costa es la casa de la rosa. la rosa de la casa es la cosa de la costa. "
    "el oso de la rosa es el oso de la casa. la casa del oso es la costa."
    )
TEST_LONGEST = 5
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


def Test_Voting_Oracles(
        fixture: Fixture
        ) -> None:
    size = alphabets.Size(fixture.letters)
    letter_a = Symbol_For(fixture, "a")
    board = templates.Parsed("la c_sa de", fixture.letters)

    scores = [0.0, 0.0, 1.0, -1.0, 2.0]
    #-- Position 0 is not used: the scores are (0, 1, -1, 2).
    shares = distributions.From_Scores(scores)
    Check_Close(fixture, "scores to probabilities: letter 1", distributions.Weight_Of(shares, 1), 0.08714431874203257)
    Check_Close(fixture, "scores to probabilities: letter 4", distributions.Weight_Of(shares, 4), 0.6439142598879724)
    Check_Close(fixture, "scores to probabilities: sums to 1", distributions.Total(shares), 1.0)

    pupil = voting_oracles.Voting_Oracle()
    voting_oracles.Prepare(pupil, size, 3)
    belief = pupil.Opinion(board, 4)
    Check_Close(fixture, "untrained: all letters equally likely", distributions.Probability_Of(belief, letter_a), 0.08333333333333333)
    surprise = voting_oracles.Learn_Cell(pupil, board, 4, letter_a, 0.5)
    Check_Close(fixture, "first lesson: surprise = ln 12", surprise, 2.4849066497880004)
    belief = pupil.Opinion(board, 4)
    Check_Close(fixture, "after one lesson the real letter is more likely", distributions.Probability_Of(belief, letter_a), 0.13034687344398008)

    pupil = voting_oracles.Voting_Oracle()
    voting_oracles.Prepare(pupil, size, 3)
    plan = voting_oracles.Lesson_Plan()
    plan.lessons = 60
    plan.piece_length = 24
    dice = random_sources.Seeded(11)
    final_surprise = voting_oracles.Train(pupil, fixture.corpus, dice, plan)
    Check_Close(fixture, "training 60 lessons: final surprise", final_surprise, 1.915541972753829)
    belief = pupil.Opinion(board, 4)
    Check_Close(fixture, "trained: P(a)", distributions.Probability_Of(belief, letter_a), 0.797228557731476)
    Check(fixture, "trained: the most likely is a", distributions.Most_Likely(belief) == letter_a)

    dice = random_sources.Seeded(4)
    result = blind_spots.Examine(fixture.model, fixture.corpus, dice, 5, 24, 0.4)
    Check(fixture, "counting exam: 35 hits out of 45", result.hidden == 45 and result.hits == 35)
    Check_Close(fixture, "counting exam: mean surprise", blind_spots.Mean_Surprise(result), 0.6231927485060871)
    dice = random_sources.Seeded(4)
    result = blind_spots.Examine(pupil, fixture.corpus, dice, 5, 24, 0.4)
    Check(fixture, "voting exam: 28 hits out of 45", result.hidden == 45 and result.hits == 28)
    Check_Close(fixture, "voting exam: mean surprise", blind_spots.Mean_Surprise(result), 1.0526600853953112)

    filled = templates.Parsed("la [12] rosa.", fixture.letters)
    dice = random_sources.Seeded(1)
    collapsing.Collapse_All(filled, pupil, dice)
    Check(fixture, "the engine collapses the same with another brain", canvases.Blank_Count(filled) == 0)
    Check(fixture, "collapse with votes, seed 1", templates.Rendered(filled, fixture.letters, True) == "la [casasasde la] rosa.")


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
        ("Voting brain", Test_Voting_Oracles),
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
