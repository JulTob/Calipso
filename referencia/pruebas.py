"""Espejo de tests/colapso_tests.adb: las mismas pruebas, con el mismo corpus.

Uso:
    python3 referencia/pruebas.py

De aquí salen los valores esperados que usan las pruebas en Ada.
"""

import sys

from colapso_ref import UNKNOWN
from colapso_ref import alphabets
from colapso_ref import blind_spots
from colapso_ref import canvases
from colapso_ref import collapsing
from colapso_ref import counting_oracles
from colapso_ref import distributions
from colapso_ref import fragment_counts
from colapso_ref import random_sources
from colapso_ref import repairing
from colapso_ref import templates
from colapso_ref import texts

CORPUS_TEXT = (
    "la casa de la costa es la casa de la rosa. la rosa de la casa es la cosa de la costa. "
    "el oso de la rosa es el oso de la casa. la casa del oso es la costa."
    )
TEST_LONGEST = 5
TOLERANCE = 1.0e-9


class Fixture:
    #-- Lo que comparten todas las pruebas.

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
        print("  FALLO  " + name)
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
        print(f"         obtenido {actual!r}")
        print(f"         esperado {expected!r}")


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
    #-- ¿Siguen en el lienzo, en el mismo orden, todas las letras dadas de la plantilla?
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
    Check_Close(fixture, "primer número de la semilla 42", random_sources.Draw_Unit(dice), 0.5682303266439076)
    Check_Close(fixture, "segundo número de la semilla 42", random_sources.Draw_Unit(dice), 0.2254634289477513)
    Check_Close(fixture, "tercer número de la semilla 42", random_sources.Draw_Unit(dice), 0.41283831882951183)
    dice = random_sources.Seeded(7)
    indexes = []
    for _ in range(0, 8):
        indexes.append(random_sources.Draw_Index(dice, 10))
    Check(fixture, "ocho índices de la semilla 7", indexes == [4, 9, 9, 2, 2, 1, 4, 3])


def Test_Alphabets(
        fixture: Fixture
        ) -> None:
    Check(fixture, "el alfabeto tiene 12 símbolos", alphabets.Size(fixture.letters) == 12)
    Check(fixture, "la primera letra vista recibe el símbolo 2", Symbol_For(fixture, "l") == 2)
    Check(fixture, "la segunda letra vista recibe el símbolo 3", Symbol_For(fixture, "a") == 3)
    Check(fixture, "el punto recibe el símbolo 12", Symbol_For(fixture, ".") == 12)
    Check(fixture, "una letra nunca vista es desconocida", Symbol_For(fixture, "z") == UNKNOWN)
    Check(fixture, "del símbolo 5 se vuelve a la letra c", alphabets.Character_Of(fixture.letters, 5) == "c")
    Check(fixture, "codificar y descodificar devuelve el texto", texts.Decoded(fixture.corpus, fixture.letters) == CORPUS_TEXT)


def Test_Distributions(
        fixture: Fixture
        ) -> None:
    even = distributions.Uniform(4)
    tally = distributions.Zero(4)
    distributions.Set_Weight(tally, 1, 1.0)
    distributions.Set_Weight(tally, 2, 3.0)
    distributions.Set_Weight(tally, 3, 0.0)
    distributions.Set_Weight(tally, 4, 4.0)
    Check_Close(fixture, "entropía de 4 letras iguales = ln 4", distributions.Entropy(even), 1.3862943611198906)
    Check_Close(fixture, "total de pesos", distributions.Total(tally), 8.0)
    Check(fixture, "variedad: 3 letras con peso", distributions.Variety(tally) == 3)
    Check(fixture, "la más probable es la 4", distributions.Most_Likely(tally) == 4)
    Check_Close(fixture, "entropía de (1, 3, 0, 4)", distributions.Entropy(tally), 0.9743147528693494)
    Check_Close(fixture, "sorpresa de la letra 2", distributions.Surprise_Of(tally, 2), 0.9808292530117262)
    Check_Close(fixture, "sorpresa de una letra imposible", distributions.Surprise_Of(tally, 3), 690.7755278982137)
    Check(fixture, "dado en 0.000 -> letra 1", distributions.Sampled(tally, 0.0) == 1)
    Check(fixture, "dado en 0.124 -> letra 1", distributions.Sampled(tally, 0.124) == 1)
    Check(fixture, "dado en 0.126 -> letra 2", distributions.Sampled(tally, 0.126) == 2)
    Check(fixture, "dado en 0.490 -> letra 2", distributions.Sampled(tally, 0.49) == 2)
    Check(fixture, "dado en 0.510 -> letra 4 (la 3 es imposible)", distributions.Sampled(tally, 0.51) == 4)
    Check(fixture, "dado en 0.999 -> letra 4", distributions.Sampled(tally, 0.999) == 4)
    mixed = tally + 2.0 * even
    shares = distributions.Normalized(tally)
    Check_Close(fixture, "álgebra: Tally + 2.0 * Even, letra 1", distributions.Weight_Of(mixed, 1), 1.5)
    Check_Close(fixture, "álgebra: Tally + 2.0 * Even, letra 3", distributions.Weight_Of(mixed, 3), 0.5)
    Check_Close(fixture, "normalizar: letra 2", distributions.Weight_Of(shares, 2), 0.375)
    Check_Close(fixture, "normalizar: suma 1", distributions.Total(shares), 1.0)


def Test_Fragment_Counts(
        fixture: Fixture
        ) -> None:
    Check(fixture, "187 fragmentos distintos", fragment_counts.Distinct_Fragments(fixture.model.table) == 187)
    Check(fixture, "la letra a aparece 29 veces", Seen(fixture, "a") == 29)
    Check(fixture, "el fragmento la aparece 12 veces", Seen(fixture, "la") == 12)
    Check(fixture, "el fragmento casa aparece 5 veces", Seen(fixture, "casa") == 5)
    Check(fixture, "el fragmento rosa. aparece 1 vez", Seen(fixture, "rosa.") == 1)
    Check(fixture, "un fragmento nunca visto cuenta 0", Seen(fixture, "xx") == 0)
    Check(fixture, "un fragmento con espacios: 6 veces", Seen(fixture, " de l") == 6)


def Test_Opinions(
        fixture: Fixture
        ) -> None:
    both_sides = templates.Parsed("la c_sa de", fixture.letters)
    alone = templates.Parsed("_", fixture.letters)
    left_only = templates.Parsed("la ros_", fixture.letters)
    letter_a = Symbol_For(fixture, "a")
    letter_o = Symbol_For(fixture, "o")
    belief = fixture.model.Opinion(both_sides, 4)
    Check_Close(fixture, "dos lados: P(a)", distributions.Probability_Of(belief, letter_a), 0.7633265411439716)
    Check_Close(fixture, "dos lados: P(o)", distributions.Probability_Of(belief, letter_o), 0.2355700126736941)
    Check_Close(fixture, "dos lados: entropía", distributions.Entropy(belief), 0.556390935921461)
    Check(fixture, "dos lados: la más probable es a", distributions.Most_Likely(belief) == letter_a)
    Check_Close(fixture, "la opinión suma 1", distributions.Total(belief), 1.0)
    belief = fixture.model.Opinion(alone, 0)
    Check_Close(fixture, "sin vecinas: P(a)", distributions.Probability_Of(belief, letter_a), 0.18131313131313131)
    Check_Close(fixture, "sin vecinas: entropía", distributions.Entropy(belief), 2.1766977283465896)
    belief = fixture.model.Opinion(left_only, 6)
    Check_Close(fixture, "solo izquierda: P(a)", distributions.Probability_Of(belief, letter_a), 0.9628293807641635)


def Test_Templates(
        fixture: Fixture
        ) -> None:
    board = templates.Parsed("la [3]_ [...]fin\\n[x]", fixture.letters)
    plain = templates.Parsed("la casa", fixture.letters)
    Check(fixture, "plantilla: 45 celdas", canvases.Length(board) == 45)
    Check(fixture, "plantilla: 34 huecos", canvases.Blank_Count(board) == 34)
    Check(fixture, "pintar una plantilla sin huecos la devuelve igual", templates.Rendered(plain, fixture.letters) == "la casa")
    Check(fixture, "un corchete sin número no es un hueco", canvases.State_At(board, 42) == canvases.GIVEN)


def Test_Collapsing(
        fixture: Fixture
        ) -> None:
    template = "la [12] rosa."
    board = templates.Parsed(template, fixture.letters)
    dice = random_sources.Seeded(1)
    collapsing.Collapse_All(board, fixture.model, dice)
    Check(fixture, "tras colapsar no quedan huecos", canvases.Blank_Count(board) == 0)
    Check(fixture, "tras colapsar hay 12 letras del modelo", canvases.Guess_Count(board) == 12)
    Check(fixture, "colapsar no toca las letras dadas", Givens_Kept(fixture, board, template))
    Check(fixture, "colapso, semilla 1", templates.Rendered(board, fixture.letters, True) == "la [costa. es la] rosa.")

    board = templates.Parsed(template, fixture.letters)
    dice = random_sources.Seeded(1)
    collapsing.Collapse_All(board, fixture.model, dice, collapsing.LEFT_TO_RIGHT, collapsing.ALWAYS_MOST_LIKELY)
    Check(fixture, "izquierda a derecha sin sorteo", templates.Rendered(board, fixture.letters, True) == "la [casa de la l] rosa.")

    board = templates.Parsed(template, fixture.letters)
    dice = random_sources.Seeded(5)
    collapsing.Collapse_All(board, fixture.model, dice, collapsing.AT_RANDOM)
    Check(fixture, "orden al azar: no quedan huecos", canvases.Blank_Count(board) == 0)
    Check(fixture, "orden al azar, semilla 5", templates.Rendered(board, fixture.letters, True) == "la [olasa. ela o] rosa.")


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
    Check(fixture, "reparar nunca sube la tensión", outcome.final_tension <= before)
    Check(fixture, "reparar no toca las letras dadas", Givens_Kept(fixture, board, template))
    Check(fixture, "tras reparar no quedan huecos", canvases.Blank_Count(board) == 0)
    Check_Close(fixture, "la tensión final es la del lienzo", repairing.Tension(board, fixture.model, options.tolerance), outcome.final_tension)
    Check(fixture, "un hueco demasiado corto crece", templates.Rendered(board, fixture.letters, True) == "la cos[asa ]del oso")
    Check(fixture, "el arreglo fue un ensanche", outcome.widenings == 1)


def Test_Blind_Spots(
        fixture: Fixture
        ) -> None:
    original = templates.From_Text(fixture.corpus, 0, 60)
    board = canvases.Copy(original)
    dice = random_sources.Seeded(9)
    blind_spots.Hide_At_Random(board, 0.3, dice)
    Check(fixture, "se tapan 22 letras de 60", canvases.Blank_Count(board) == 22)
    collapsing.Collapse_All(board, fixture.model, dice, collapsing.MOST_CERTAIN_FIRST, collapsing.ALWAYS_MOST_LIKELY)
    result = blind_spots.Scored(board, original)
    Check(fixture, "se puntúan las 22 letras tapadas", result.hidden == 22)
    Check(fixture, "se recuperan 20 de 22", result.recovered == 20)


def Main() -> None:
    fixture = Fixture()
    groups = [
        ("Azar repetible", Test_Random_Sources),
        ("Alfabeto", Test_Alphabets),
        ("Distribuciones", Test_Distributions),
        ("Cuenta de fragmentos", Test_Fragment_Counts),
        ("Opiniones del modelo", Test_Opinions),
        ("Plantillas", Test_Templates),
        ("Colapso", Test_Collapsing),
        ("Reparar y crecer", Test_Repairing),
        ("Puntos ciegos", Test_Blind_Spots),
        ]
    for title, group in groups:
        print(title)
        group(fixture)
    print()
    print(f"Fallos: {fixture.failures}")
    if fixture.failures > 0:
        sys.exit(1)


if __name__ == "__main__":
    Main()
