"""Experimentos de la idea de colapso, con cifras.

Uso:
    python3 referencia/experimentos.py CORPUS [ENSAYOS]

El corpus se parte en dos: el primer 90 % para aprender y el último 10 %
para examinar (texto que el modelo no ha visto nunca).

  E1. ¿Ayuda mirar a los dos lados?        (adivinar una letra tapada)
  E2. ¿Importa el orden de colapso?        (puntos ciegos al azar)
  E3. ¿Aterriza el texto en el final dado? (puente entre dos trozos)
  E4. ¿Sirve dejar crecer el texto?        (hueco demasiado corto)
"""

import sys

import ciegos

from colapso_ref import alphabets
from colapso_ref import canvases
from colapso_ref import collapsing
from colapso_ref import counting_oracles
from colapso_ref import distributions
from colapso_ref import random_sources
from colapso_ref import repairing
from colapso_ref import templates
from colapso_ref import texts

DEFAULT_TRIALS = 60
MARGIN = 60
#-- Letras de texto real que se dejan a cada lado de un hueco.


class Laboratory:
    #-- Todo lo que comparten los experimentos.

    def __init__(self):
        self.letters = None
        self.model = None
        self.exam = None
        self.vocabulary = None


def Prepared(
        corpus_name: str
        ) -> Laboratory:
    lab = Laboratory()
    lab.letters = alphabets.Alphabet()
    texts.Learn_Alphabet(corpus_name, lab.letters)
    corpus = texts.Read_Symbols(corpus_name, lab.letters)
    cut = (len(corpus) * 9) // 10
    lessons = texts.Part(corpus, 0, cut - 1)
    lab.exam = texts.Part(corpus, cut, len(corpus) - 1)
    lab.model = counting_oracles.Counting_Oracle()
    counting_oracles.Train(lab.model, lessons, alphabets.Size(lab.letters))
    lab.vocabulary = Words_In(texts.Decoded(lessons, lab.letters))
    print(f"Corpus: {len(corpus)} letras. Aprende de {len(lessons)}, examina con {len(lab.exam)}.")
    print(f"Alfabeto: {alphabets.Size(lab.letters)} símbolos. Ventana más ancha: {lab.model.longest} letras.")
    return lab


def Word_List(
        plain: str
        ) -> list:
    #-- Lista de (inicio, fin, palabra) con cada tira de letras seguidas.
    words = []
    start = -1
    for position in range(0, len(plain) + 1):
        inside = position < len(plain) and plain[position].isalpha()
        if inside and start < 0:
            start = position
        if not inside and start >= 0:
            words.append((start, position, plain[start:position].lower()))
            start = -1
    return words


def Words_In(
        plain: str
        ) -> set:
    vocabulary = set()
    for _, _, word in Word_List(plain):
        vocabulary.add(word)
    return vocabulary


def Touches_A_Guess(
        board: canvases.Canvas,
        first: int,
        last: int
        ) -> bool:
    for position in range(first, last):
        if canvases.State_At(board, position) == canvases.GUESSED:
            return True
    return False


def Word_Validity(
        lab: Laboratory,
        board: canvases.Canvas
        ) -> tuple:
    #-- De las palabras que el modelo ha tocado, cuántas existen en el texto aprendido.
    plain = templates.Rendered(board, lab.letters)
    valid = 0
    total = 0
    for first, last, word in Word_List(plain):
        if Touches_A_Guess(board, first, last):
            total = total + 1
            if word in lab.vocabulary:
                valid = valid + 1
    return valid, total


def Random_Start(
        lab: Laboratory,
        dice: random_sources.Generator,
        length: int
        ) -> int:
    room = len(lab.exam) - length
    return random_sources.Draw_Index(dice, room)


def Percent(
        part: int,
        whole: int
        ) -> str:
    if whole == 0:
        return "  n/d"
    return f"{100.0 * part / whole:5.1f}"


def Median(
        values: list
        ) -> float:
    ordered = sorted(values)
    return ordered[len(ordered) // 2]


def Peak_Surprise(
        lab: Laboratory,
        board: canvases.Canvas
        ) -> float:
    worst = repairing.Most_Surprising_Cell(board, lab.model)
    if worst < 0:
        return 0.0
    return repairing.Surprise_At(board, lab.model, worst)


#-- E1 ----------------------------------------------------------------------


def Experiment_Two_Sides(
        lab: Laboratory,
        trials: int
        ) -> None:
    print()
    print("E1. Adivinar UNA letra tapada en texto nunca visto")
    reach = lab.model.Reach()
    span = 2 * reach + 1
    dice = random_sources.Seeded(101)
    names = ["solo izquierda", "solo derecha  ", "los dos lados "]
    hits = [0, 0, 0]
    surprise = [0.0, 0.0, 0.0]
    samples = trials * 50
    for _ in range(0, samples):
        start = Random_Start(lab, dice, span)
        original = templates.From_Text(lab.exam, start, span)
        actual = canvases.Symbol_At(original, reach)
        for view in range(0, 3):
            board = canvases.Copy(original)
            canvases.Hide(board, reach)
            if view == 0:
                for position in range(reach + 1, span):
                    canvases.Hide(board, position)
            if view == 1:
                for position in range(0, reach):
                    canvases.Hide(board, position)
            belief = lab.model.Opinion(board, reach)
            surprise[view] = surprise[view] + distributions.Surprise_Of(belief, actual)
            if distributions.Most_Likely(belief) == actual:
                hits[view] = hits[view] + 1
    for view in range(0, 3):
        print(f"  {names[view]}: acierta {Percent(hits[view], samples)} %   sorpresa media {surprise[view] / samples:.3f} nats")


#-- E2 ----------------------------------------------------------------------


def Experiment_Blind_Spots(
        lab: Laboratory,
        trials: int
        ) -> None:
    #-- El mismo experimento que referencia/ciegos.py y apps/colapso_ciegos.adb.
    print()
    print("E2. Puntos ciegos al azar: % de letras tapadas que se recuperan")
    print("    (trozos de 300 letras; se elige siempre la letra más probable)")
    for rate, percent in ciegos.RATE_CASES:
        for order in ciegos.ORDERS:
            total = ciegos.Measure(lab.model, lab.exam, rate, order, trials)
            print(f"  tapado {percent} %  {ciegos.Order_Name(order)}: {Percent(total.recovered, total.hidden)} %   ({total.hidden} letras)")


#-- E3 ----------------------------------------------------------------------


def Gap_Board(
        lab: Laboratory,
        dice: random_sources.Generator,
        removed: int,
        cells: int
        ) -> canvases.Canvas:
    #-- Texto real al que se le quitan `removed` letras del centro y se dejan `cells` huecos.
    start = Random_Start(lab, dice, MARGIN + removed + MARGIN)
    board = templates.From_Text(lab.exam, start, MARGIN)
    for _ in range(0, cells):
        canvases.Append_Blank(board)
    for position in range(start + MARGIN + removed, start + MARGIN + removed + MARGIN):
        canvases.Append_Given(board, lab.exam[position])
    return board


def Experiment_Bridge(
        lab: Laboratory,
        trials: int
        ) -> None:
    print()
    print("E3. Puente: rellenar un hueco entre dos trozos reales (sin reparar)")
    orders = [
        (collapsing.MOST_CERTAIN_FIRST, "menos dudas primero"),
        (collapsing.LEFT_TO_RIGHT, "izquierda a derecha"),
        ]
    for gap in (10, 20, 40):
        for order, name in orders:
            valid = 0
            total = 0
            peaks = []
            example = ""
            for trial in range(0, trials):
                dice = random_sources.Seeded(303 + trial)
                board = Gap_Board(lab, dice, gap, gap)
                collapsing.Collapse_All(board, lab.model, dice, order)
                trial_valid, trial_total = Word_Validity(lab, board)
                valid = valid + trial_valid
                total = total + trial_total
                peaks.append(Peak_Surprise(lab, board))
                if trial == 0:
                    example = Example_Of(lab, board)
            print(f"  hueco {gap:2d}  {name}: palabras válidas {Percent(valid, total)} %   peor sorpresa (mediana) {Median(peaks):5.2f} nats")
            print(f"      {example}")


def Example_Of(
        lab: Laboratory,
        board: canvases.Canvas
        ) -> str:
    marked = templates.Rendered(board, lab.letters, mark_guesses=True)
    opening = marked.find("[")
    closing = marked.find("]")
    first = max(0, opening - 28)
    last = min(len(marked), closing + 29)
    return marked[first:last].replace("\n", "\\n")


#-- E4 ----------------------------------------------------------------------


def Experiment_Growth(
        lab: Laboratory,
        trials: int
        ) -> None:
    print()
    print("E4. Hueco demasiado corto: se quitan 30 letras y solo se dejan K celdas")
    modes = ["sin reparar      ", "reabrir          ", "reabrir + crecer "]
    for cells in (1, 3, 8):
        for mode in range(0, 3):
            options = repairing.Settings()
            options.can_grow = (mode == 2)
            valid = 0
            total = 0
            relaxed = 0
            length = 0
            example = ""
            for trial in range(0, trials):
                dice = random_sources.Seeded(404 + trial)
                #-- Misma semilla por ensayo: los tres modos parten del mismo lienzo ya colapsado.
                board = Gap_Board(lab, dice, 30, cells)
                collapsing.Collapse_All(board, lab.model, dice)
                if mode > 0:
                    repairing.Relax(board, lab.model, dice, options)
                if repairing.Tension(board, lab.model, options.tolerance) <= 0.0:
                    relaxed = relaxed + 1
                trial_valid, trial_total = Word_Validity(lab, board)
                valid = valid + trial_valid
                total = total + trial_total
                length = length + canvases.Guess_Count(board)
                if trial == 1:
                    example = Example_Of(lab, board)
            print(f"  K={cells}  {modes[mode]}: sin tensión {relaxed:2d}/{trials}   palabras válidas {Percent(valid, total)} %   largo medio {length / trials:4.1f}")
            print(f"      {example}")


def Main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    trials = DEFAULT_TRIALS
    if len(sys.argv) >= 3:
        trials = int(sys.argv[2])
    try:
        lab = Prepared(sys.argv[1])
    except texts.Reading_Error as problem:
        print(f"Error: {problem}")
        sys.exit(2)
    Experiment_Two_Sides(lab, trials)
    Experiment_Blind_Spots(lab, trials)
    Experiment_Bridge(lab, trials)
    Experiment_Growth(lab, trials)


if __name__ == "__main__":
    Main()
