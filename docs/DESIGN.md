# Calipso design

This document explains **why** the project is the way it is. It goes from the
idea to the pieces, and writes down the decisions so that they can be argued
with.

## 1. The idea and its proper name

The starting proposal:

> Instead of predicting letter by letter, look at the whole text and complete
> it. Give the ending and have the model write something that leads to it.
> Without fixing the length beforehand. Train by hiding pieces at random.

Three points of vocabulary, because they help when searching and thinking:

**It is not retrocausal: it is conditioning.** Nothing travels back in time.
The ending is *fixed evidence*, just as the beginning could be. The question
is: "of all possible texts, which ones are compatible with what is already
written?". Whether the evidence sits on the right or on the left makes no
difference.

**Wave function collapse is a good picture.** The *Wave Function Collapse*
algorithm (Maxim Gumin, 2016, `mxgmn/WaveFunctionCollapse`) generates maps
like this: every tile starts out able to be any piece; the tile with the
fewest possibilities is chosen and fixed, and the consequence is propagated to
its neighbours. Calipso does exactly that with letters.

**The idea exists and is alive in research.** It is called a *masked
diffusion language model*. These models train by hiding positions at random
and learning to fill them in, which is the "blind spots" proposal. Their
known weak point is precisely the other wish: **fixed length**. There are
papers from 2025 and 2026 devoted just to that (see Reading). That is good
news twice over: the idea is sound, and the free-length part is still open.

## 2. The four pieces

### Canvas (`Calipso.Canvases`)

A row of cells. Each cell is in one of three states:

| State | What it is | Can it change? |
|---|---|---|
| `Blank` | a hole: it can still be any letter | yes, by collapsing it |
| `Given` | a letter the person gave | **never** |
| `Guessed` | a letter the model decided | yes: it can be reopened |

Telling `Given` apart from `Guessed` is what allows correcting without
touching what the person fixed.

### Oracle (`Calipso.Oracles`)

A contract with a single question:

> Looking at what is around, which letter do you think goes in this cell?

The answer is not a letter: it is a **distribution**, an opinion with doubts.
The oracle looks only at the neighbours, never at the cell itself. That is why
the same question serves two purposes: filling a hole, and examining a letter
already placed ("if I hide you, would they have guessed you?").

It also declares its **reach**: how many cells away a letter can influence
another. The engine needs it to propagate.

### Engine (`Calipso.Collapsing`)

```
while holes are left:
    Observe   : choose the hole with the least entropy (least doubt)
    Collapse  : draw its letter from the oracle's opinion
    Propagate : mark the opinions within reach as out of date
```

**Entropy** is the measure of the doubt in a distribution. It is 0 when one
letter is certain, and grows as more letters are possible. It is measured in
*nats*.

### Repair (`Calipso.Repairing`)

After collapsing, every letter is examined:

- **Surprise** of a letter: how strange it looks to its neighbours. It is
  `-ln(p)`, where `p` is the probability they gave it. Surprise 0: it was
  expected. Surprise 4: it happened 1 time in 55.
- **Tension** of the canvas: the sum of the surprise that goes over what is
  tolerable, in the zone the model has touched. Tension 0 means "everything
  fits".

Relaxing means repeating:

1. Find the letter that surprises the most.
2. **Reopen**: turn the model's letters nearby back into holes, and collapse
   again. If the tension goes down, keep it.
3. If it does not, **widen**: put new cells in at that point and collapse
   again. If the tension goes down, keep it.

This is how the free-length wish is met: the text grows only where it is
needed and only if growing improves the fit. `Given` letters never change, and
the final tension is never higher than the initial one.

## 3. The first brain: counting

`Calipso.Counting_Oracles` learns nothing sophisticated. Its memory is a
table: *small piece of text → times I have seen it* (`Calipso.Fragment_Counts`).

To give an opinion on a hole:

1. It starts without looking at anything: all letters equally possible.
2. It looks at a **window** around the hole and asks the table: "of the times
   I saw this window, which letter was in the place of the hole?".
3. It widens the window one neighbour at a time, alternating left and right,
   up to 7 letters or until the window has never been seen.

Each window corrects the opinion of the previous one with a single rule:

```
new opinion = Normalize( Evidence + Variety × previous opinion )
```

- **Evidence**: the counts for this window, letter by letter.
- **Variety**: how many different letters were seen in this window.

Variety acts as a brake. If the same letter always followed a context,
variety is 1: I trust it a lot. If all sorts of letters followed it, variety
is high: I trust what I already thought more. There is no magic number to
tune.

In Ada it is one line, thanks to the operators of the distribution algebra:

```ada
Mixed : constant Distribution := Clue + Prior_Strength * Belief;
```

### One table serves both sides

With a single table of small pieces one can look left (`"cas" + ?`), right
(`? + "asa"`) or at both sides (`"ca" + ? + "a "`). So there are not two
models, one forwards and one backwards: there is one.

### "Training by hiding" is an exam here

With this brain, training is just counting. The blind-spot game
(`Calipso.Blind_Spots`) is used to **measure**: hide letters of real text,
ask about them, count hits.

## 4. Brains made of neurons

A **neuron** (`Calipso.Neurons`) is one way of looking at the surroundings of
a hole. It does not answer with a letter. It gives **points** for or against
each candidate letter. Points simply add up, so neurons of different kinds can
sit in the same brain:

```
points of the brain = sum over its neurons of (weight x points of the neuron)
```

A **brain** (`Calipso.Brains`) is a list of neurons with their weights. It
turns the total points into probabilities, so it fulfils the Oracle contract:
the engine, the repair and the exam use it without knowing what is inside.

A brain is described by a **recipe**: neuron names joined by `+`, for example
`counting+bias+position`. The catalogue is `Calipso.Neuron_Kinds`; a new kind
of neuron is a new package plus one line there.

| Name | What it looks at | Where the idea comes from |
|---|---|---|
| `bias` | Nothing. One number per letter: how common it is. | |
| `position` | Which letter is at each exact distance. "What is 3 cells to my left?" | One curve per distance. |
| `presence` | Which letters are around, wherever they are. It ignores position altogether. | The flat curve of the next one, alone. |
| `harmonic` | The neighbours weighed by waves over distance: a flat one, then cosines and sines with 1, 2, 3... cycles across the window. | A **Fourier** series. |
| `decay` | The neighbours weighed by curves that fade with distance, at several speeds. Fast fading sees only the next letter; slow fading sees far, blurred. | A **Laplace** transform. |
| `counting` | The table of fragment counts of section 3, as one neuron. | |
| `memory` | The same table with a fixed number of counters. | |

A name can carry **sizes**: `position:24`, `harmonic:16:6`, `decay:24:8`,
`counting:9`, `memory:16777216:9`. The first size is how far the neuron looks
(or, for the counting kinds, the longest fragment or the number of counters);
the second is how many waves or fading speeds. A size left out takes its usual
value, and a brain says its recipe back with the sizes that are not the usual
ones. This is how a larger brain is built to fit a larger machine: no code
changes, only the recipe.

`position`, `presence`, `harmonic` and `decay` are one package
(`Calipso.Basis_Neurons`): they differ only in the set of curves over distance
(the "basis") by which a neighbour's vote is weighed.

### Read, calculate, write

A brain's memory works in three steps on every hidden letter
(`Brains.Learn_Cell`):

1. **read** the surroundings of the hole,
2. **calculate** an opinion, and see how much the real letter surprises,
3. **write**: every neuron corrects its numbers a little, against the error.

The score is taken at step 2, before anything is corrected. So every lesson is
also an honest test: `Brains.Study` returns the test score of the lessons it
has just learned from. Nothing is written when a brain is used to generate.

Neurons learn in two ways. `bias` and the basis neurons learn from the error
(step 3). `counting` and `memory` learn from text: after a lesson they read
the piece and count its fragments.

## 5. Which hole collapses next

`Calipso.Criteria` makes the order of collapse a module of its own. A
criterion looks at one hole and says how **ready** it is, from 0 to 1. The
engine (`Collapsing.Collapse_By`) always collapses the readiest hole.

| Criterion | Ready means |
|---|---|
| `Certainty` | The opinion has little doubt: 1 minus doubt, as a fraction of the most doubt possible. 1 = one letter is certain, 0 = all letters equally possible. This is the "collapse index". |
| `Agreement` | The neurons of the brain, each asked alone, place their bets on the same letters. |
| `Leftmost` | It is further left. This reproduces writing left to right, and is here to compare against. |
| `Mixed` | A weighted mean of other criteria. |

Neither `Certainty` nor `Agreement` looks at where the hole is. The order
comes from the content, not from the position.

## 6. Where text comes from

A **source** (`Calipso.Sources`) hands out text one piece at a time. The brain
never needs the whole text at once, so a source can be far bigger than memory.

| Source | What it reads |
|---|---|
| `Calipso.Memory_Sources` | Pieces taken at random from a text held in memory. |
| `Calipso.File_Sources` | A file from start to end, never loaded whole. |
| `Calipso.Web_Sources` | Pages from the web: the scraper. |

### The scraper

`Calipso.Web_Sources` keeps a list of addresses to visit. For each one:

1. it asks the site's rules (`Calipso.Robots`, the site's `robots.txt`)
   whether the address may be fetched. This is asked twice: **at the door**,
   before the address takes a seat in the list, and again when its turn comes.
   The rules of a site are fetched once and remembered, so the second question
   is free. An address the rules close never waits in the list;
2. it waits, if the last request was too recent;
3. it fetches the address (`Calipso.Fetchers`) and checks what really arrived;
4. it takes the words of the page (`Calipso.Pages`) to hand out in pieces;
5. it takes the links: new ones go to the end of the list.

The next page is fetched only when the words of this one have been handed out.
So the brain studies a whole page before the next request: **studying is the
pause** between requests, on top of a minimum of one second (more if the site
asks for more).

Two guards keep it from reading what is not text:

- **before asking**, by the name: an address ending in `.png` or `.mp4` is
  never requested;
- **after asking**, by the label the server sends: if it says the file is not
  a page, the content is dropped.

What is not a page is not thrown away. Its address is filed under its kind
(writing, picture, video, sound, document), ready for the brain of that kind.

An address is never listed twice. When it is linked again it gains a
**mention**, a count of how many links point to it.

**Fixed sizes.** Everything the scraper remembers has a size chosen in its
settings, so a long walk needs no more memory than a short one:

- the **waiting list** of addresses to visit is a ring of `List_Size` places
  (1,024 unless said). When it is full, new links are left out; a later link
  to the same address can list it once there is room;
- the **seen table**, which says which addresses are known and counts their
  mentions, has `Seen_Size` places and works like the bounded memory of the
  brain: each address has one place, with a check number saying whose it is,
  and a newcomer wears the owner down before taking the place. An address
  forgotten this way may be read again;
- a **time limit** stops it asking for new pages after so many minutes.

A size that is a power of two makes no measurable difference to speed here: a
page costs about a second of waiting, and a step on the list costs a millionth
of that. What a fixed size buys is memory that stays put.

Redirections are not followed blindly: the new address is treated like any
other link, so it passes the same checks.

Fetching is a contract with two implementations: `Calipso.Curl_Fetchers` runs
the program `curl` (already on macOS and most Linux systems), because secure
connections (`https`) need an encryption library that standard Ada does not
carry; `Calipso.Folder_Fetchers` pretends a folder is a site, for tests.

**Limits to know.** `robots.txt` says what may be *fetched*. It says nothing
about what the text may be *used* for; that stays a decision of the person
running the program. Pages that build their text with scripts look empty to
this reader. For Wikipedia, the published dumps are the considerate way to get
a lot of text; the scraper is for looking at a few pages.

## 7. Brain files

A saved brain is a `.brn` file (`Calipso.Records`). It holds everything the
brain needs: its alphabet, its recipe, its numbers and how many lessons it has
studied in its whole life. Load it, study more, save it: it carries on. Copy
it to another computer: it carries on there.

Everything is written, in order, onto a **tape**: a list of short words and a
list of numbers. The file that keeps a tape is two things at once:

- **data**: Calipso reads it line by line when a brain is loaded
  (`Brains.Load`). No compiler is involved, and the brain can go on learning
  and be saved again;
- **Ada**: the same file is the specification of a package with two constants,
  `Words` and `Numbers`. It can be compiled into a program, and the brain is
  then inside the program itself (`Brains.Thaw`).

```ada
with Calipso.Records;

package Page_Brain is

    Words : constant Calipso.Records.Word_List := (
          "calipso-tape    "
        , "calipso-brain   "
        , "bias            "
        , "end             "
        );

    Numbers : constant Calipso.Records.Number_List := (
          1.0
        , 1.0
        , 144.0
        ...
```

The project file tells the compiler which file holds the package, so the file
keeps its `.brn` name (see `tests/frozen/frozen.gpr`):

```
package Naming is
    for Spec ("Page_Brain") use "page.brn";
end Naming;
```

**Which way in to use.** Once a brain is in memory it works at the same speed
however it got there. The difference is only the moment of starting. Measured
on a brain of 102,501 numbers (a 2.3 MB file): 33 ms from the file, 3.5 ms
from inside the program. A compiled brain cannot change: use the file while a
brain is learning, and compile it in to ship a finished one. A very large
brain is a very large source file, and the compiler is slow on it.

A program can have both. `Brains.Take_Freshest` starts from the brain compiled
in, unless the file beside it has studied more lessons: then it takes the
file. So a rebuilt program never forgets what the file learned, and an old
build never hides newer learning. To keep the file close to what is in
memory, `calipso_crawl` saves its brain after every 50 lessons and the panel
after every training.

### Packed brains

A tape can also be kept packed, in a `.zmb` file: the same words and numbers
as raw bytes. A count takes as few bytes as it needs (7 bits in each byte, and
the top bit says "there is more"); any other number is the 8 bytes of the real
as the machine keeps it, lowest byte first. Nothing is lost. Measured: a brain
of 4.06 MB as text is 0.99 MB packed, and one of 3.11 MB is 0.55 MB.

This is packing, not general compression of the kind a zip file does: that
needs a library standard Ada does not carry. The `.brn` form is for reading
and compiling; the `.zmb` form is for storing and sending. `Records.Save`
chooses by the ending of the name, `Records.Load` by the first four bytes of
the file, and `calipso_brain copy` turns one into the other.

### Bounded memory

The `memory` neuron keeps its counts in a fixed number of counters, however
much text it reads. Each fragment has one counter where it may live, chosen
by a scrambled number worked out from its letters.

The first version shared counters blindly, and measuring it showed a fault: a
fragment *never seen* was read as whichever fragment owned its counter, and
the brain fell from 68 % to 27 % of hidden letters right (E7). Each counter
now also keeps a **check number** saying whose it is, so an unseen fragment
reads 0. When a newcomer finds its counter taken, it knocks one off the
owner's count, and takes the counter when that count reaches 0. What is seen
often stays; what was seen once, long ago, makes room.

## 8. The panel

`calipso_panel` is a supervised browser for training. It starts a small web
server (`Calipso.Web_Servers`) that answers only this same computer, and the
panel is a page in the browser you already have.

It shows a page the way the robot reads it (`Calipso.Panels`):

- the page as plain pieces: paragraphs, and the places of pictures and films;
- the site's `robots.txt`, as it was just read, and what it says about this
  address. If the rules forbid it, nothing is fetched and there is no training;
- every link, with the kind of thing it points to;
- **Train on this page**: the brain of that kind of file studies it and saves
  itself;
- **hide**: a paragraph becomes a hole and the brain builds something in its
  place from the text around it, shown next to what was really there. This is
  a writing test. **hide half** hides half of its letters by chance; with
  something to hold on to, this is a recovery test, and its score means more.

There is one brain per kind of file, kept in the brain folder: `page.brn` for
web pages, and one per ending for other files that are text inside (`txt.brn`,
`py.brn`, `svg.brn`...), because each is its own language.

Pictures, films and sounds have no brain yet. Their files are compressed, and
compressed bytes look like noise: they would have to be unpacked into pixels
or sound samples first.

### Training on GitHub

The workflow `.github/workflows/train.yml` ("Train a brain") runs the scraper
and a brain on GitHub's machines. It is started by hand from the Actions tab
with an address, a name for the brain, a number of minutes, and the sizes.
It takes the brain of that name from the release called `brains` if there is
one, trains, and puts it back, so each run carries on from the last. Brains
are kept as release files and not committed, because a file of megabytes
committed on every run would stay in the history of the repository for good.

When the workflow file itself changes in a pull request it does a trial run on
the little test site and keeps nothing.

## 9. Decisions taken, and why

| Decision | Alternative rejected | Reason |
|---|---|---|
| One centred window that grows | Multiply the opinion of a forward model by that of a backward model | Measured with the same smoothing: 0.74 nats of mean surprise against 0.95 (window of 7). And it is a single mechanism. |
| Brake by variety | A constant tuned by hand | Measured: 0.665 nats and 85.5 % hits, against 0.659 and 83.4 % for the best constant I tried. Practically the same, with nothing to tune. |
| Collapse the most certain hole first | Left to right, or random order | Measured: it recovers more letters at every level of hiding (E2). |
| Tension = surprise above a threshold | Mean surprise | The mean rewards filling with easy, repetitive text. The threshold does not: once everything fits, it stops. |
| Measure tension on nearby given letters too | Only on the model's letters | A bad seam shows on both sides. Without this the engine did not see broken words. |
| Our own random generator (`Random_Sources`) | The standard library generator | This way Ada and the reference give the same numbers and any result can be repeated. |
| Letters as the unit | Words or pieces of words | The simplest thing that works. It can be changed without touching the engine: the alphabet is a table. |
| Each vote is corrected in proportion to how loudly it spoke | Share one correction among all the votes that spoke, by their energy | Measured (E6): the plain rule learns more with the same lessons, and the shared one was unstable on the `decay` neuron. |
| A check number in every bounded counter | Counters shared blindly | Measured (E7): 67 % against 27 % of hidden letters right with the same counters. |
| Brain files are data first, and also Ada | Weights built into the program | A program cannot rewrite its own code, so a brain that learns must be data. The same file compiles when a finished brain is to be shipped. |
| The panel is a page in the usual browser | A window toolkit | Buttons, forms and layout come for free, on any system, and the server is a few hundred lines of Ada. |
| `curl` for fetching | A secure-connection library bound into Ada | One small program that is already installed, behind a contract. A fetcher in pure Ada can replace it without touching the scraper. |

The "measured" figures in the first two rows come from exploratory runs on the
English text of 558,000 letters; the others come from
[EXPERIMENTS.md](EXPERIMENTS.md).

## 10. What these brains cannot do

All of them see only letters near the hole (12 on each side at most), and none
understands them. So:

- Words come out well formed and join up with the given ending.
- **There is no global meaning.** They cannot write a paragraph that
  *justifies* "y por eso debes lavarte los dientes": they do not know what
  the ending is about.
- Tension only detects local faults. An absurd sentence made of correct words
  has tension 0.
- Free length works as "grow until it joins", not "grow until it makes sense".
- The neurons that learn from errors are still far behind plain counting (E5).
  Their numbers are single votes of one neighbour for one letter; they cannot
  say "this letter, *given those two together*".

None of this is a defect of the engine. It is the limit of the brains. For
global meaning a neuron is needed that combines what it sees over a long
distance.

## 11. What comes next

- **Neurons that combine.** A neuron where every cell *consults* the others
  (attention), so that the answer depends on combinations of what they hold.
  The corrections for such a neuron are best worked out automatically, with a
  small algebra of "values that remember how they were computed".
- **Fuzzy collapse.** Today a cell is either a hole or a letter. A cell that
  keeps a whole opinion, sharpened step by step, is a second collapse policy
  that the criteria already leave room for.
- **More senses.** One canvas per kind of content, with neurons that look
  across canvases, so that text can condition a drawing and the reverse.
- **Using the mentions.** The scraper counts how often each page is linked.
  That count could decide which pages are read first, or read twice.
- **Measuring the criteria.** `Agreement` and `Mixed` work and are tested, but
  they have not been compared with `Certainty` on a large text yet.

## 12. How the Ada is checked

There is no Ada compiler where the code is written, so it is checked in two
ways.

**A mirror for the numeric core.** `reference/calipso_ref/` has one Python
module per core package, with the same functions and the same steps in the
same order (even the order of the additions). `tests/calipso_tests.adb` and
`reference/tests.py` run the same tests on the same tiny corpus, and the
expected numbers in the Ada tests come from the mirror. It is a checking tool:
nothing in `src/` or `apps/` needs it, and the library builds and runs with
`gprbuild` alone.

**GitHub Actions for everything.** Every push is compiled with all warnings on
and contracts checked at run time. Then it runs the tests, runs each program
in Ada and in the mirror and compares the output with `diff`, checks that each
language reads the brain files the other saved, compiles a saved brain into a
program, crawls a small site served by `calipso_serve`, and drives the panel
through its pages.

The tests have two levels. Properties (no holes left, given letters do not
change, tension does not rise) must always hold. Letter-by-letter comparisons
with the mirror only leave a note, because different rounding between
machines can change a draw without anything being wrong.

The web server and the panel exist only in Ada.

## 13. A second method: the pyramid

The flat method sees one level, letters. A window of seven letters knows how
words are spelled but not how a sentence is built.

The pyramid adds a level above. Each level has cells of its own:

| Level | A cell holds | Package |
|---|---|---|
| kinds | the **kind** of one token | `Calipso.Kinds`, `Calipso.Tokens` |
| letters | one letter | everything that was already there |

**Tokens.** `Calipso.Tokens` cuts a text into the pieces a reader takes whole:
words, numbers, single marks, and paragraph breaks (a blank line).

**Kinds.** `Calipso.Kinds` gives every token a kind. A mark is its own kind.
A number is known by how many digits it has. The 120 most usual words are each
their own kind. Any other word is known by its *shape*: capital or not, one of
four sizes, and one of the ten most usual two-letter endings (or none). That
is at most 253 kinds, so **a kind fits in a `Symbol`**. This is the decision
that keeps the design small: canvases, oracles, the collapse engine and the
counting brain work on kinds without one line changed.

**The handover.** A decision of one level is the template of the level below.
`Calipso.Pyramids` collapses a canvas of kinds (the plan), then turns it into a
canvas of letters:

- a mark or a usual word is written as given letters;
- any other word becomes a **box**: holes for its letters, with the ending of
  its kind already given;
- every hole carries a *permission*: small letters only, a capital only,
  digits only.

`Calipso.Boxed_Oracles` is what makes the level below obey. It is an oracle
that asks another oracle for its opinion and removes what the cell does not
allow. The engine does not know it is there.

There are two handovers. **Spell**: the letter brain fills the box. **Pick**:
a word seen in that kind is taken whole, drawn by how often it was seen.

**Either method.** `Calipso.Writers` is the contract: `Write (Dice, Words,
Result)`. `Flat_Writer` and `Pyramid_Writer` both keep it, and a program that
holds a `Writer'Class` does not know which one it has. A third method is one
more type.

What was measured (E11) and what it teaches:

- Deciding the kind first is a real gain when a hidden word must be rebuilt in
  text never studied: from 19 % to 30 % exact.
- **An order from above is only as good as the level below can obey it.** A
  letter brain that writes real words 97 % of the time when free writes them
  far less often inside a box of fixed size and ending.
- Kinds by shape are crude. "becomes" and "Colours" have the same shape and
  are not the same kind of word.

What comes next on this path: kinds learned from the company a word keeps
(two words are the same kind if the same kinds stand around them); a level
above sentences (paragraph, heading, list) so the shape of a page is planned
too; and filling a hole of free length with the pyramid, which needs reading
the surroundings bottom-up before planning top-down.

## 14. The dial: cells that are neither fixed nor empty

A cell used to have two states that matter: **Given** (it cannot change) and
**Blank** (nothing is known about it). The dial puts every position in between.

**One dial, two scales** (`Calipso.Certainties`):

| | surely wrong | no idea | surely right |
|---|---|---|---|
| `Certainty`, a chance | 0 | 1/N | 1 |
| `Signed_Certainty` | -1 | 0 | +1 |

On the first scale "no idea" depends on N, the number of symbols: 0.011 for 91
letters, 0.004 for 253 kinds. On the signed scale it is always 0. That is why
the signed scale is the better one to *declare* a dial with, and the chance is
the better one to *calculate* with. `Certainty_Of` and `Signed_Of` turn one
into the other; each half of the signed scale is a straight line.

**The anchored oracle** (`Calipso.Anchored_Oracles`). A cell remembers the
symbol it had and how sure it was. The memory is turned into weights (the
certainty for the symbol held, the rest shared among the others), multiplied
by the brain's opinion, and scaled to add up to 1. So:

- certainty 1 keeps the symbol whatever the brain says: a Given cell;
- certainty 1/N leaves the opinion as it was: a Blank cell;
- certainty 0 forbids the symbol: "anything but this", which is new.

Given and Blank are the two ends of the dial, not a separate mechanism. In
between, the certainty is a **price**: how strongly the neighbours must
disagree before the cell changes. With 91 symbols a cell held at 0.5 changes
only when the brain finds another symbol about 90 times more likely.

**Settling** (`Calipso.Settling`). The text is read from left to right. Each
cell decides again from its neighbours *as they are now* and from its anchor,
and takes the most likely symbol. The text is read again until a whole reading
changes nothing. That text is a fixed point of the reading. A pinned change is
an anchor that is certain of the new symbol; a cell marked "surely wrong" has
certainty 0. The number of readings is capped (8), so it always ends.

Why not empty the cells and collapse them as usual? Because an empty cell
tells its neighbours nothing. Here every cell keeps speaking to its neighbours
while it waits to be read again, so the old text is context, not only a
preference.

What was measured is in E12. What this does not do yet:

- It works on one level. Settling the *kinds* and writing the letters again
  below them (loose kinds, stiff letters) needs the two levels joined.
- The length never changes. A word cannot become a longer word.
- **A dial of meaning.** "The cat is on the sofa" and "On top of the sofa
  there is a kitten" should point to the same state. Nothing here knows that:
  kinds by shape do not even put "cat" and "kitten" together. It needs kinds
  learned from the company words keep, and then a level whose symbols do not
  care about word order. That level is the real target of the pyramid.
- **Cuts that are not decided.** A level that chunks must choose where the
  cuts go, and a text can be cut in more than one way. Instead of choosing,
  every window of the text can be given a kind, overlapping its neighbours,
  the way the counting brain already looks at every run of letters. No cut is
  ever made; spaces and commas are symbols like the rest, and whether they
  matter is learned.

## Reading

- *Flexible-length Text Infilling for Discrete Diffusion Models* (DDOT):
  <https://arxiv.org/pdf/2506.13579>. Explains masked diffusion well, and why
  fixed length is a problem when filling in.
- *Insertion Language Models*: <https://arxiv.org/pdf/2505.05755>. Models
  that insert at any position.
- *Any-Order Flexible Length Masked Diffusion* (FlexMDM):
  <https://arxiv.org/html/2509.01025v2>. Masked diffusion with free length.
- *Edit Flows*: <https://arxiv.org/pdf/2506.09018>. Generating with edit
  operations: insert, delete, substitute.
- *Beyond Masks: Deletion-Insertion Processes* (DID):
  <https://arxiv.org/html/2603.23507v1>. Replaces hiding and uncovering with
  deleting and inserting.
