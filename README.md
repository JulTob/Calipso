# Calipso

Text generation by **collapse**, in Ada.

Most text generators write from left to right: each letter is chosen knowing
only what comes before. Calipso looks at the whole text at once, with its
holes, and fills them in using what is on **both sides**.

## The idea, in short

1. The text is a **canvas** of cells. Some hold a letter that was given;
   others are **holes**.
2. A **brain** looks at one hole and its neighbours, on the left and on the
   right, and gives an opinion: how likely each letter is there.
3. The engine picks the hole it has **least doubt** about, decides its letter,
   and asks again about the holes nearby, because their neighbourhood has
   changed. It repeats until no holes are left.

This is the loop of the *Wave Function Collapse* algorithm (observe, collapse,
propagate), applied to text. Because the brain looks both ways, you can give
the **ending** and ask for what leads to it:

```
El azúcar [40] y por eso debes lavarte los dientes.
```

`[40]` is a hole of 40 letters. If it turns out too short for the two sides to
join, the engine notices the bad seam and lets the hole grow.

Brains learn by the same game played backwards: take real text, hide letters
at random, bet on each hidden letter, uncover it and correct. Every lesson is
also a test.

## What is here

| Part | State |
|---|---|
| Canvas, collapse engine, repair with free length | Working, tested |
| Brains made of neurons of several kinds, mixed by a recipe | Working, tested |
| Brain files (`.brn`) that carry on between runs and between computers, and also compile as Ada | Working, tested |
| Scraper that obeys `robots.txt`, as a source of text | Working, tested on a small site |
| Panel: a supervised browser to look, check the rules, train, hide and rebuild | Working, tested on a small site |
| Text with meaning | **Not yet.** See "Limits" |

Everything in `src/` and `apps/` is Ada 2012. It builds with GNAT and GPRbuild
and nothing else.

## Build and run

```
gprbuild -p -P calipso.gpr
./bin/calipso_tests
```

With [Alire](https://alire.ada.dev): `alr build`.

| Program | What it does |
|---|---|
| `calipso_demo CORPUS "TEMPLATE" SEED` | Fills the holes of a template and draws the collapse step by step. |
| `calipso_exam CORPUS` | Hides letters of real text and counts how many the counting brain recovers. |
| `calipso_brain study BRAIN CORPUS [LESSONS] [RECIPE]` | Loads a brain (or makes a new one), studies more lessons, examines it, saves it. Run it again and it carries on. |
| `calipso_brain compare CORPUS BRAIN...` | Gives the same exam to several saved brains. |
| `calipso_crawl BRAIN START_LIST [PAGES] [RECIPE]` | A brain studies pages from the web, starting from a list of addresses. |
| `calipso_panel [BRAIN_FOLDER] [PORT]` | The panel. Open `http://127.0.0.1:8080` in your browser. |
| `calipso_serve FOLDER [PORT]` | Serves a folder as a small site, for tests. |

A first try:

```
./bin/calipso_demo data/sample_es.txt "El azúcar [40] y por eso debes lavarte los dientes." 3
./bin/calipso_brain study my.brn data/sample_es.txt 500 counting+bias+position
./bin/calipso_brain study my.brn data/sample_es.txt 500
./bin/calipso_panel brains
```

### How to write a template

| You write | It means |
|---|---|
| `_` | one hole |
| `[25]` | a hole of 25 letters |
| `[...]` | a hole of the default length |
| `\n` | a line break |

## Brains and recipes

A brain is a list of **neurons**. Each neuron is one way of looking at the
surroundings of a hole, and gives points for or against each letter. Points
add up, so kinds can be mixed. A **recipe** names the neurons, joined by `+`.

| Name | What it looks at |
|---|---|
| `bias` | Nothing: how common each letter is. |
| `position` | Which letter is at each exact distance. |
| `presence` | Which letters are around, wherever they are. |
| `harmonic` | The neighbours weighed by waves over distance (Fourier). |
| `decay` | The neighbours weighed by curves that fade with distance (Laplace). |
| `counting` | A table of how often each short piece of text was seen. |
| `memory` | The same table with a fixed number of counters. |

The order in which holes collapse is a module too (`Calipso.Criteria`): by
certainty, by agreement among the neurons, left to right, or a weighted mix.

## Brain files

A brain saves itself to one `.brn` file: its letters, its recipe, its numbers
and how many lessons it has studied in its whole life. The file is plain text.
Copy it to another computer and it carries on there.

The same file is also Ada source: the specification of a package with two
constants. So a finished brain can be compiled into a program:

```ada
with Calipso.Brains;
with Page_Brain;
...
Calipso.Brains.Thaw (Brain, Page_Brain.Words, Page_Brain.Numbers);
```

with this in the project file, so that the file keeps its name:

```
package Naming is
    for Spec ("Page_Brain") use "page.brn";
end Naming;
```

`tests/frozen` is a complete example. Use the file while a brain is learning
(a program cannot rewrite its own code), and compile it in to ship a finished
one. Once in memory both work at the same speed.

## The panel

```
./bin/calipso_panel brains
```

Then open `http://127.0.0.1:8080`. Type an address and press **Look**:

- you see the page as the robot reads it: paragraphs, the places of pictures
  and films, and every link with its kind;
- you see the site's `robots.txt` and what it says about that address. If the
  rules forbid it, nothing is fetched and it cannot be trained on;
- **Train on this page** makes the brain of that kind of file study it and
  save itself (`brains/page.brn`, `brains/txt.brn`, `brains/py.brn`...);
- **hide** turns a paragraph into a hole and shows what the brain builds in
  its place, next to what was really there. **hide half** hides half of its
  letters, which tests recall instead of invention.

The panel answers only your own computer.

## The scraper's manners

- It reads each site's `robots.txt` first and obeys it.
- It waits at least a second between requests, more if the site asks, and it
  studies a whole page before asking for the next.
- It never asks for the same address twice, and stays on the site it was sent to.
- It introduces itself by name to every site.
- It does not download pictures, films or sounds: it files their addresses.

`robots.txt` says what may be fetched. Whether the text may be used is your
decision. Fetching uses the program `curl`, which is already on macOS.

## What has been measured

On a text of 558,000 letters, examined on a part never seen. Details and
cautions in [docs/EXPERIMENTS.md](docs/EXPERIMENTS.md).

| Question | Answer |
|---|---|
| Does looking at both sides help? | Yes: 86 % of hidden letters right, against 62 to 63 % looking at one side only. |
| Does collapsing the surest hole first help? | Yes, at every level of hiding: for example 54 % against 45 % left to right with half the letters hidden. |
| Does the text land on the given ending? | Yes: the seam is as natural as real text. Written left to right, it is not. |
| Does letting the hole grow help? | Yes when it is too short: valid words go from 17 % to 65 %. |
| Does training by blind spots work? | Yes. From nothing to 43 % right in 2,000 lessons. Plain counting gets 68 %; the mix of both is the best brain when much is hidden. |
| Do the Fourier and Laplace neurons help? | Laplace comes within 3 or 4 points of exact positions with a third of the numbers. Fourier did not help as built. |
| Can memory have a fixed size? | Yes: 67 % against 68 % for exact memory, after a fault found by measuring was fixed. |
| File or compiled in? | 33 ms against 3.5 ms to start, for a brain of 100,000 numbers. No difference after that. |

## Limits

The brains see only the letters near a hole and do not understand them. Words
come out well formed and join up with the given ending, but **there is no
global meaning yet**: no brain here can write a paragraph that justifies its
ending. That needs neurons that combine what they see over a long distance.
See [docs/DESIGN.md](docs/DESIGN.md), sections 10 and 11.

## Project map

```
src/      the library, one package per idea
apps/     the programs
tests/    the tests, a small test site, and the compiled-brain example
data/     a small Spanish sample text
docs/     DESIGN.md (how and why), EXPERIMENTS.md (what was measured)
reference/  a Python mirror of the numeric core, used only to check the Ada
```

```
The game        Canvases  Templates  Oracles  Collapsing  Criteria  Repairing  Blind_Spots
The brains      Brains  Neurons  Neuron_Kinds  Bias_Neurons  Basis_Neurons  Counting_Neurons
                Counting_Oracles  Fragment_Counts  Records
The text        Alphabets  Texts  Sources  Memory_Sources  File_Sources
The web         Web_Addresses  Pages  Robots  Fetchers  Curl_Fetchers  Folder_Fetchers
                Web_Sources  Web_Servers  Panels
Small tools     Distributions  Numbers  Random_Sources  Console
```

## How the code is checked

There is no Ada compiler where this code is written, so GitHub Actions is the
workbench: every push is compiled with all warnings on and contracts checked,
then tested. For the numeric core there is also a mirror in Python
(`reference/`), with the same steps in the same order; the two must print the
same. The mirror is a checking tool. The library does not need it.

## Code style

- One package per idea. One subprogram, one task. One line, one step.
- Contracts (`Pre`, `Post`) say what each operation needs and gives.
- Errors are expected and handled; each border with the outside has its own
  exception.
- The algebra of opinions is built with operators: `Normalized (Clue + Variety (Clue) * Belief)`.
- Comments that explain go after what they explain, marked `--#`.
- Plain names, no clever code.
