# Calipso

Wave Function Collapse AI models.

Calipso is an Ada library that generates text by *filling holes*, looking at
the context on both sides, instead of writing letter by letter from left to
right.

## The idea, in short

A normal generator writes like this: read what came before, bet on the next
letter, repeat. It never knows where it is going.

Calipso works on a **canvas**: a row of cells. Some already have a letter
(for example, the ending you want). The rest are **holes**. Each hole can
still be any letter. The engine repeats three steps:

1. **Observe.** Find the hole there is least doubt about.
2. **Collapse.** Decide its letter.
3. **Propagate.** That letter changes what can be expected of its neighbours.

It is the same loop as the *Wave Function Collapse* algorithm used to generate
maps, applied to text.

```
Template:  \nEl azúcar [40] y por eso debes lavarte los dientes.\n
Result:    \nEl azúcar [de los una hasta las encías se inflaman,] y por eso debes lavarte los dientes.\n
```

The text **lands** on the given ending. It has no global meaning yet: the
brains built so far only see a few letters around each hole. That is expected
at this stage; the why and the next step are in [docs/DESIGN.md](docs/DESIGN.md).

## Project status

| Part | Status |
|---|---|
| Ada library (`src/`) | Builds with GNAT 14, no warnings. Tests pass on GitHub Actions. |
| Python reference (`reference/`) | A mirror of the Ada code, module per package. With the same seed both write exactly the same output; GitHub Actions compares them on every push. |
| Corpus | A small Spanish sample is included (`data/sample_es.txt`, 9 KB). Not yet tried on Wikipedia. |

The Python reference exists for two reasons: to test ideas quickly, and to
check the Ada.

## Build and run

With GNAT and GPRbuild:

```sh
gprbuild -p -P calipso.gpr
./bin/calipso_tests
./bin/calipso_demo data/sample_es.txt "\nEl azúcar [40] y por eso debes lavarte los dientes.\n" 3
./bin/calipso_exam data/sample_es.txt
./bin/calipso_train data/sample_es.txt
```

With Alire: `alr build`, then the same programs in `bin/`.

| Program | What it does |
|---|---|
| `calipso_demo` | Collapses a template and shows the canvas filling up. |
| `calipso_exam` | Hides letters at random and counts how many are recovered, with three collapse orders. |
| `calipso_train` | Trains the brain that learns, and examines it next to the brain that counts. |
| `calipso_tests` | The test suite. |

The reference needs only Python 3:

```sh
python3 reference/tests.py
python3 reference/demo.py data/sample_es.txt "\nEl azúcar [40] y por eso debes lavarte los dientes.\n" 3
python3 reference/exam.py data/sample_es.txt
python3 reference/train.py data/sample_es.txt
python3 reference/experiments.py data/sample_es.txt
```

### How to write a template

| You write | It means |
|---|---|
| `_` | a hole of one cell |
| `[25]` | a hole of 25 cells |
| `[...]` | a hole of the default size (30) |
| `\n` | a line break: a paragraph boundary |
| anything else | given letters, which are never touched |

The size of a hole is only a starting point: if the text does not fit, the
engine can **widen** the hole on its own.

## What has been measured

On an English text of 558,000 letters (the model learns from 90 % and is
examined on the 10 % it never saw). Details in
[docs/EXPERIMENTS.md](docs/EXPERIMENTS.md).

| Question | Result |
|---|---|
| Does looking at both sides help? | Guessing one hidden letter: 63 % looking only left, **86 %** looking at both sides. |
| Does the collapse order matter? | With 30 % of the text hidden, **72 %** is recovered starting from the most certain hole, 64 % left to right, 60 % in random order. |
| Does it land on the given ending? | Yes. The worst "seam" surprises by 3.9 to 5.1 nats; writing left to right, by 7.3 to 8.8. |
| Does letting the text grow help? | When the hole is too short, yes: valid words go from 17.5 % to **65 %**. When the hole is already roomy, it adds nothing. |
| Does training with random blind spots work? | Yes: the brain that learns goes from knowing nothing (4.5 nats of surprise) to 2.2 nats. But with one layer it is still worse than counting. |

## Project map

Each layer only knows the ones below it.

```
apps/  tests/              programs: demo, exam, train, tests
────────────────────────────────────────────────────────────────────
Calipso.Repairing          measure tension, reopen and widen
Calipso.Collapsing         the engine: observe, collapse, propagate
────────────────────────────────────────────────────────────────────
Calipso.Voting_Oracles     a brain that learns by blind spots
Calipso.Counting_Oracles   a brain that only counts
Calipso.Blind_Spots        hide letters at random; the common exam
Calipso.Oracles            the CONTRACT of any brain
────────────────────────────────────────────────────────────────────
Calipso.Templates          canvas <-> text with holes
Calipso.Canvases           the canvas: Blank / Given / Guessed cells
Calipso.Fragment_Counts    table "small piece -> times seen"
────────────────────────────────────────────────────────────────────
Calipso.Distributions      algebra of opinions:  A + B,  Factor * A
Calipso.Texts              file -> row of symbols
Calipso.Alphabets          letter <-> symbol table
Calipso.Random_Sources     repeatable randomness (same seed, same result)
Calipso.Console            border with the terminal (UTF-8)
Calipso                    common types: Symbol
```

The key piece is `Calipso.Oracles`. The engine does not know which brain is
underneath: it only asks *"which letter do you think goes here?"*. Two brains
answer that question today, and the engine is the same for both.

`reference/calipso_ref/` has one module per package, with the same name and
the same functions.

## Getting a larger corpus

Any UTF-8 text file works. For Wikipedia there is a temporary scaffold:

```sh
python3 tools/download_wikipedia.py es 500 corpus/wikipedia_es.txt
```

Warning: that tool **could not be tested** where it was written (there was no
access to Wikipedia). The `corpus/` folder is not uploaded to the repository.

## Code style

- Cascading tabulation: parameters with double indentation; the closing token
  (`)`, `end`) belongs to the inner level.
- Explanatory comments carry a pin (`--#` in Ada, `#--` in Python) and go
  **after** what they explain.
- One line, one step. One function, one task. Names that explain themselves.
- Contracts (`Pre`, `Post`) on the interface of each package; they are checked
  at run time (`-gnata`).
- Everything in English: identifiers, comments, messages and documents.
- Sources without `-gnatW8`: inside the program text is `Wide_Wide_String`;
  at the borders it is UTF-8 bytes, converted only in `Calipso.Console` and
  `Calipso.Texts`.

## Roadmap

1. **Counting brain** (done): the whole pipeline working end to end.
2. **One layer that learns** (done): a brain whose numbers are adjusted by
   playing the blind-spot game. Training works; one layer is not enough.
3. **Automatic derivatives** in Ada, so that layers can be stacked.
4. **Attention**: let every cell consult all the others. This is where global
   meaning should appear.

No licence yet: that is your decision.
