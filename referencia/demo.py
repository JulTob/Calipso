"""Espejo de apps/colapso_demo.adb: colapsar una plantilla.

Uso:
    python3 referencia/demo.py CORPUS "PLANTILLA" [SEMILLA]

Ejemplo:
    python3 referencia/demo.py data/muestra.txt "\\nEl azúcar [40] y por eso debes lavarte los dientes.\\n" 7
"""

import sys

from colapso_ref import alphabets
from colapso_ref import canvases
from colapso_ref import collapsing
from colapso_ref import counting_oracles
from colapso_ref import random_sources
from colapso_ref import repairing
from colapso_ref import templates
from colapso_ref import texts

DEFAULT_SEED = 1
TRACE_EVERY = 8
#-- Cada cuántas letras colapsadas se pinta el lienzo.


def Visible(
        plain: str
        ) -> str:
    #-- Pinta los saltos de línea como "\n" para que el lienzo quepa en una línea.
    return plain.replace("\n", "\\n")


def Run(
        corpus_name: str,
        template: str,
        seed: int
        ) -> None:
    letters = alphabets.Alphabet()
    texts.Learn_Alphabet(corpus_name, letters)
    corpus = texts.Read_Symbols(corpus_name, letters)
    model = counting_oracles.Counting_Oracle()
    counting_oracles.Train(model, corpus, alphabets.Size(letters))
    print(f"Corpus: {len(corpus)} letras, alfabeto de {alphabets.Size(letters)} símbolos.")

    board = templates.Parsed(template, letters)
    dice = random_sources.Seeded(seed)
    print("Plantilla:")
    print("  " + Visible(templates.Rendered(board, letters)))

    steps = [0]

    def Show_Step(current, position):
        steps[0] = steps[0] + 1
        if steps[0] % TRACE_EVERY == 0:
            print("  " + Visible(templates.Rendered(current, letters)))

    print("Colapso:")
    collapsing.Collapse_All(board, model, dice, observer=Show_Step)
    print("  " + Visible(templates.Rendered(board, letters)))

    options = repairing.Settings()
    before = repairing.Tension(board, model, options.tolerance)
    report = repairing.Relax(board, model, dice, options)
    print(f"Tensión antes de reparar: {before:.3f}")
    print(f"Reparación: {report.rounds} rondas, {report.reopenings} reaperturas, {report.widenings} ensanches.")
    print(f"Tensión final: {report.final_tension:.3f}")
    print("Resultado (entre corchetes, lo que escribió el modelo):")
    print("  " + Visible(templates.Rendered(board, letters, mark_guesses=True)))


def Main() -> None:
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    corpus_name = sys.argv[1]
    template = sys.argv[2]
    seed = DEFAULT_SEED
    if len(sys.argv) >= 4:
        seed = int(sys.argv[3])
    try:
        Run(corpus_name, template, seed)
    except texts.Reading_Error as problem:
        print(f"Error: {problem}")
        sys.exit(2)


if __name__ == "__main__":
    Main()
