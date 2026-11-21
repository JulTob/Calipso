"""Mirror of apps/calipso_demo.adb: collapse a template.

Usage:
    python3 reference/demo.py CORPUS "TEMPLATE" [SEED]

Example:
    python3 reference/demo.py data/sample_es.txt "\\nEl azúcar [40] y por eso debes lavarte los dientes.\\n" 7
"""

import sys

from calipso_ref import alphabets
from calipso_ref import canvases
from calipso_ref import collapsing
from calipso_ref import counting_oracles
from calipso_ref import random_sources
from calipso_ref import repairing
from calipso_ref import templates
from calipso_ref import texts

DEFAULT_SEED = 1
TRACE_EVERY = 8
#-- How many collapsed letters between two drawings of the canvas.


def Visible(
        plain: str
        ) -> str:
    #-- Draws line feeds as "\n" so that the canvas fits on one line.
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
    print(f"Corpus: {len(corpus)} letters, alphabet of {alphabets.Size(letters)} symbols.")

    board = templates.Parsed(template, letters)
    dice = random_sources.Seeded(seed)
    print("Template:")
    print("  " + Visible(templates.Rendered(board, letters)))

    steps = [0]

    def Show_Step(current, position):
        steps[0] = steps[0] + 1
        if steps[0] % TRACE_EVERY == 0:
            print("  " + Visible(templates.Rendered(current, letters)))

    print("Collapse:")
    collapsing.Collapse_All(board, model, dice, observer=Show_Step)
    print("  " + Visible(templates.Rendered(board, letters)))

    options = repairing.Settings()
    before = repairing.Tension(board, model, options.tolerance)
    report = repairing.Relax(board, model, dice, options)
    print(f"Tension before repair: {before:.3f}")
    print(f"Repair: {report.rounds} rounds, {report.reopenings} reopenings, {report.widenings} widenings.")
    print(f"Final tension: {report.final_tension:.3f}")
    print("Result (in brackets, what the model wrote):")
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
