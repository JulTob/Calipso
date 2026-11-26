# Experiments

Ten questions about the collapse idea and the machinery around it, with figures.

## How they were run

- **Programs:** `python3 reference/experiments.py CORPUS 60` for E1 to E4
  (60 trials per case) and `python3 reference/brain.py study BRAIN CORPUS 2000
  RECIPE` for E5 to E7 (the Ada program `calipso_brain` takes the same
  arguments and writes the same). E8 and E9 are Ada only, run on GitHub.
  Seeds are fixed: every run can be repeated and gives the same output.
- **Main corpus:** a public-domain book in English, 557,909 letters
  (Newton's *Opticks*; it was the long text at hand). It is not in the
  repository. The model learns from the first 90 % and is examined on the
  last 10 %, which it has never seen.
- **Small corpus:** `data/sample_es.txt`, 9,144 letters in Spanish.
- **Brain:** the counting one, with a window of 7 letters, in E1 to E4.
- Full outputs in [`results/`](results/).

Cautions for reading the figures:

- The large corpus is in **English**. The mechanism does not depend on the
  language, but it has not been repeated on Spanish Wikipedia yet.
- "Valid words" is a crude measure: of the words the model has touched, how
  many exist in the text it learned from. It does not measure meaning.
- 60 trials are enough to see large differences, not to split decimals.

## E1. Does looking at both sides help?

**One** letter of real text is hidden and the most likely one is asked for.

| What the model sees | Right | Mean surprise |
|---|---|---|
| Left side only | 63.2 % | 1.530 nats |
| Right side only | 61.8 % | 1.547 nats |
| Both sides | **86.1 %** | **0.620 nats** |

(3,000 letters per row.)

**Reading.** Looking at one side or the other gives almost the same. Looking
at both at once is much better: the mean doubt drops to less than half. This
is the foundation of the whole idea, and it holds.

On the Spanish sample (only 915 letters to examine with): 55.5 %, 52.8 % and
74.7 %. The same pattern.

## E2. Does the collapse order matter?

The "blind spots": letters are hidden at random in pieces of 300 letters,
filled in always choosing the most likely letter, and counted when they match
the original.

| Hidden | Most certain first | Left to right | Random order |
|---|---|---|---|
| 15 % | **81.5 %** | 77.8 % | 75.1 % |
| 30 % | **71.9 %** | 64.3 % | 59.5 % |
| 50 % | **54.5 %** | 45.2 % | 40.2 % |
| 70 % | **32.3 %** | 24.3 % | 22.7 % |

(All three orders get the same pieces and the same holes.)

**Reading.** Starting with the most certain hole always wins, and the
advantage grows the more is hidden. It makes sense: each sure letter that is
fixed gives clues to the doubtful ones. It is the *Wave Function Collapse*
rule, and it works here too.

On the Spanish sample: 68.5 / 65.0 / 65.0 at 15 % and 49.0 / 41.2 / 37.7 at
50 %. The same order.

## E3. Does the text land on the given ending?

A piece is removed from the middle of a real text and a hole of the same size
is filled in. Here the letter is **drawn by lot**, not taken as the most
likely. There is no repair afterwards. "Worst surprise" is that of the letter
that fits worst: it measures how bad the seam is.

| Hole | Order | Valid words | Worst surprise (median) |
|---|---|---|---|
| 10 | most certain first | **84.7 %** | **3.91 nats** |
| 10 | left to right | 70.1 % | 8.78 nats |
| 20 | most certain first | 86.5 % | **4.23 nats** |
| 20 | left to right | 85.0 % | 7.90 nats |
| 40 | most certain first | 91.6 % | **5.14 nats** |
| 40 | left to right | 90.0 % | 7.30 nats |

The first trial with a hole of 10, the same canvas for both orders (in
brackets, what the model wrote):

```
most certain first:   e height of 60 or 70 Inches,[ and in be]fore acts with a Force which
left to right:        e height of 60 or 70 Inches,[ nor woul ]fore acts with a Force which
```

The first one joins up with what follows (`be` + `fore`). The second leaves
`fore` hanging.

**Reading.** Writing left to right, the text reaches the end of the hole
without knowing what comes next, and crashes. The collapse grows from both
edges and sews in the middle: the seam surprises a good deal less. The
advantage in valid words is clear in short holes and small in long ones.

What this table does **not** measure: meaning. The examples make that plain.
The words join up; the sentence says nothing.

## E4. Does letting the text grow help?

**30** letters are removed from a real text and only **K** cells of hole are
left. That is, the hole is too short on purpose.

| K | Mode | No tension | Valid words | Mean final length |
|---|---|---|---|---|
| 1 | no repair | 14 of 60 | 17.5 % | 1.0 |
| 1 | reopen | 18 of 60 | 16.3 % | 1.0 |
| 1 | reopen + grow | **47 of 60** | **65.0 %** | 3.7 |
| 3 | no repair | 21 of 60 | 41.3 % | 3.0 |
| 3 | reopen | 35 of 60 | 51.6 % | 3.0 |
| 3 | reopen + grow | **47 of 60** | **66.7 %** | 4.5 |
| 8 | no repair | 25 of 60 | 80.2 % | 8.0 |
| 8 | reopen | 47 of 60 | 84.3 % | 8.0 |
| 8 | reopen + grow | 47 of 60 | 84.4 % | 8.4 |

(All three modes start from the same canvas, already collapsed.)

An example with K = 1:

```
no repair:       lose it in a short time. Wh[e] that if many contiguous
reopen + grow:   lose it in a short time. Wh[ich,] that if many contiguous
```

**Reading.**

- With a single cell there is no letter that fixes the seam. Reopening can do
  nothing. Growing can: the hole goes from 1 to 3.7 cells on average and valid
  words rise from 17.5 % to 65 %.
- With 8 cells there is already room. Reopening is enough and growing adds
  nothing.
- The text grows **little**: just enough to close the seam. It does not try to
  recover the 30 letters that were missing, because this brain does not know
  that content is missing: it only notices that two pieces do not join.

That last point is the limit that matters. "Extend until it makes sense"
works today as "extend until it joins".

## E5. Does training with random blind spots work, and which neurons learn most?

Every brain starts knowing nothing and studies 2,000 lessons. A lesson is a
piece of 64 letters with a random amount hidden: the brain is tested on every
hidden letter and then corrected (read, calculate, write). Then all take the
same exam on text they have never seen.

Hidden letters right, and mean surprise in nats (lower is better):

| Recipe | hidden 15 % | hidden 50 % | hidden 85 % |
|---|---|---|---|
| `bias+presence` | 12.4 % · 3.497 | 15.0 % · 3.209 | 16.8 % · 3.128 |
| `bias+harmonic` | 28.8 % · 3.518 | 24.1 % · 3.381 | 17.7 % · 3.212 |
| `bias+decay` | 40.2 % · 2.305 | 30.3 % · 2.587 | 22.5 % · 2.947 |
| `bias+position` | 43.1 % · 2.147 | 34.0 % · 2.458 | 24.1 % · 2.856 |
| `bias+position+decay` | 43.4 % · 2.139 | 34.1 % · 2.425 | 24.4 % · 2.843 |
| `bias+position+harmonic+decay` | 37.8 % · 2.613 | 31.0 % · 2.704 | 22.6 % · 2.934 |
| `counting` | 68.3 % · 1.338 | 41.1 % · 2.198 | 24.2 % · 2.832 |
| `counting+bias+position` | 67.5 % · 1.333 | 42.7 % · 2.142 | 24.7 % · 2.796 |

What it shows:

- **Training by blind spots works.** A brain that knows nothing bets the same
  on every letter (0 % right). After 2,000 lessons the best learning recipe
  gets 43 % of the hidden letters right when few are hidden.
- **Position matters.** `presence` knows which letters are around but not
  where, and learns very little. `position` knows exactly where, and learns
  most. `decay` (Laplace) is close behind with far fewer numbers, because
  "near counts more than far" is most of what position has to say.
- **The waves did not help.** `harmonic` (Fourier) learns less than `decay`,
  and adding it to `position+decay` made the brain worse. Its high surprise
  at 15 % hidden says its corrections overshoot: many waves speak at once for
  the same neighbour. It needs a gentler step, or waves used differently.
- **Counting is still far ahead** when most of the text is known, because it
  remembers whole fragments, where a learning neuron holds only single votes
  of one neighbour for one letter.
- **The mix is the best of all** when half or more is hidden
  (`counting+bias+position`, 42.7 % and 24.7 %): there the counting windows
  break on the holes, and the position votes see through them.

## E6. Which correction rule?

Two ways for a neuron to correct a vote, 1,500 lessons each:

- **plain**: each vote moves against the error, in proportion to how loudly it
  spoke;
- **shared**: the same, but one correction is shared out among all the votes
  that spoke, by their energy.

| Recipe | Rule | hidden 15 % | hidden 50 % | hidden 85 % |
|---|---|---|---|---|
| `bias+position` | plain | 40.2 % | 32.0 % | 24.1 % |
| `bias+position` | shared | 37.3 % | 31.2 % | 23.5 % |
| `bias+decay` | plain | 37.8 % | 29.0 % | 21.3 % |
| `bias+decay` | shared | 29.4 % | 25.2 % | 13.8 % |

The plain rule learns more in every case, and the shared one was unstable on
`decay`. The library uses the plain rule.

## E7. How big must the fixed-size memory be?

One counting neuron, 2,000 lessons. With exact memory it needs 132,431
counters and gets 68.3 % right at 15 % hidden. The `memory` neuron has a
fixed number of counters instead.

| Counters | Shared blindly | With a check number |
|---|---|---|
| 65,536 (half of what is needed) | 10.1 % | 62.2 % |
| 262,144 | 15.6 % | 66.4 % |
| 1,048,576 | 27.2 % | 67.2 % |
| 4,194,304 | 41.3 % | 68.5 % |
| 16,777,216 | 57.9 % | not run |
| exact | 68.3 % | 68.3 % |

The first version failed even with a hundred times more counters than
fragments. The cause was not fragments crowding each other out: it was that a
fragment **never seen** read the count of whoever owned its counter. The
counting brain asks about many fragments that do not exist (one per candidate
letter), so a few false answers were enough to spoil its opinion.

With a check number in each counter an unseen fragment reads 0, and memory
degrades gently: with half the counters it needs, the brain loses 6 points.

## E8. File or compiled in: how long does a brain take to get into memory?

Ada, on GitHub. A `counting+bias+position` brain after 20 lessons: 102,501
numbers, a 2.3 MB `.brn` file of 102,527 lines.

| Way in | Time |
|---|---|
| Read from the file (`Brains.Load`) | 33.3 ms, 26.2 ms |
| Taken from the constants compiled into the program (`Brains.Thaw`) | 3.5 ms, 3.0 ms |

Two runs are shown. Building the test program, the library and the brain file
together took 15 seconds. Both brains gave identical opinions.

So compiling a brain in makes the start ten times faster, and saves three
hundredths of a second. Once in memory there is no difference.

## E9. The scraper and the panel, on a small site

A site of four pages, one forbidden page and some files that are not pages
(`tests/site`), served by `calipso_serve`. All in Ada, on GitHub.

- **The scraper** asked for `robots.txt` first, then five addresses, one a
  second. It read four pages (1,113 letters), was refused the forbidden page
  by the site's rules, and dropped one file that looked like a page by name
  but was not by label. It filed two writings, one picture, one film and one
  sound without asking for any of them.
- **The panel**, after studying three of the pages (13 lessons), was asked to
  rebuild a sentence of the fourth:

| Test | Result |
|---|---|
| The whole sentence hidden | It wrote three lines: "And top you can sea", "The sea takes"tain", "The mountain is high and comer". 6 of 69 letters right. |
| Half of its letters hidden | 17 of 31 hidden letters right (54.8 %). |

With the whole sentence hidden the brain writes pieces of what the site sounds
like, some of them whole phrases it has read, and nothing tells it which
sentence was there. With half the
letters to hold on to, it recovers more than half of the rest. The first is
writing, the second is recall.

## E10. How much smaller is a packed brain?

Ada, on GitHub. The two brains of the build, saved as text (`.brn`) and packed
(`.zmb`) with `calipso_brain copy`.

| Brain | As text | Packed | Times smaller |
|---|---|---|---|
| `bias+position+decay`, 600 lessons | 4,058,352 bytes | 991,841 bytes | 4.1 |
| `counting+bias+harmonic`, 200 lessons | 3,107,483 bytes | 549,809 bytes | 5.7 |

Both forms gave the same exam figures, a brain unpacked again gave the same,
and each language read the packed files the other wrote. The packed files
written by Ada and by the mirror have the same size to the byte.

The brain with a counting neuron packs better because its table is all small
whole numbers, which take one or two bytes each. Votes are real numbers, and
those take eight bytes however they are written.

## E11. The pyramid: kinds of word first, then letters

*Question.* The flat method looks left and right at letters. Can a level above,
that decides the **kind** of each word before any letter, do better?

*How.* `reference/experiments/pyramid_exam.py` on the English book (558,068
letters). The first nine tenths are studied, the last tenth never. The letter
brain is the counting one (windows up to 7 letters). The level of kinds counts
runs of up to 5 kinds. 253 kinds were decided.

**Part A. Rebuild a hidden word in text never studied** (1,082 words, the
length is known, the most likely choice is always taken):

| Method | The exact word | A word of the right kind |
|---|---|---|
| flat: the letter brain fills the letters | 19.4 % | 32.1 % |
| spell: the kind is decided first, then the letter brain fills its box | 29.8 % | 43.6 % |
| pick: the kind is decided first, then its most usual word is taken | 32.2 % | 39.4 % |

**Part B. Free writing** (60 texts each; a word "exists" if it is in the
studied text; a pair is "seen" if those two words stand together in it):

| Who writes | Words that exist | Pairs of neighbours seen |
|---|---|---|
| real text never studied | 92.4 % | 56.2 % |
| flat | 97.3 % | 72.9 % |
| spell | 70.7 % | 45.3 % |
| pick | 100.0 % | 56.1 % |

Examples, same dice:

    flat   bility. / I illuminated with with equal, so as to beyond there emerge, make use of those Proposition of the Colour
    spell  Sthas is much uplained to blue, but those which usuffice for anymon celes, and therefore thered the Paper Ver.
    pick   Flame is much appeared to blue, but those which violence for become edges, and therefore marked the Paper Ray.

*What it says.*

1. **Deciding the kind first helps where it should.** Ten more hidden words in
   every hundred come back exact, and the kind of word is right more often.
2. **The joint between levels is the weak point.** Free, the letter brain
   writes real words 97 % of the time. Ordered to fill a box of fixed size and
   ending, it does so far less ("uplained", "usuffice"). An order from above is
   only as good as the level below can obey it.
3. **Flat writing looks better than it is.** 73 % of its pairs of neighbours
   were seen in the studied text; real text never studied has 56 %. Flat
   writing stitches pieces it remembers. The pyramid that picks words sits at
   56 %, like real text, but its neighbours are odd ("which violence for
   become edges"): the kinds know shape, not meaning.
4. **Kinds by shape are crude.** Size and ending do not tell a verb from a
   noun. The next step is kinds learned from the company a word keeps.

## E12. The dial: can soft cells find and mend a wrong letter?

*Question.* Until now a cell was Given (it cannot change) or Blank (nothing is
known). With a certainty in between, can a text settle around a change, and can
the brain find a wrong letter nobody pointed at?

*How.* `reference/experiments/settling_exam.py` on the English book. 300 pieces
of 80 letters from the tenth never studied; in each, one small letter is
replaced by another. The alphabet has 91 symbols, so "no idea" is a certainty
of 1/91 = 0.011.

**Part A. Nobody says where the wrong letter is.** Every cell gets the same
certainty and the text is read until it settles.

| Signed dial | The same as a chance | Wrong letter mended | Right letters spoiled, in every 100 |
|---|---|---|---|
| 0 (no idea) | 0.011 | 21.0 % | 34.78 |
| 0.5 | 0.506 | 49.7 % | 6.01 |
| 0.9 | 0.901 | 63.0 % | 2.83 |
| 0.99 | 0.990 | 70.0 % | 1.40 |
| 0.999 | 0.999 | 71.7 % | 0.74 |
| 0.9999 | 0.9999 | 70.0 % | 0.36 |

**Part B. The wrong cell is marked, every other cell is certain.**

| How the wrong cell is marked | Right letter back |
|---|---|
| no idea (0): the same as a hole | 85.0 % |
| surely wrong (-1) | 85.0 % |

*What it says.*

1. **The dial works, and it does something the engine could not do before.**
   With every letter held at 0.99 or more, the brain finds and mends about 70 %
   of wrong letters it was never told about, and spoils about one right letter
   in a hundred.
2. **The dial must be set high.** At 0.5 one right letter in seventeen is
   spoiled. A certainty of one half sounds neutral and is not: neutral is 1/91.
   This is the case for the signed scale, where neutral is always 0.
3. **"Surely wrong" added nothing here.** Telling the brain "not this letter"
   is free information only when the brain might have chosen that letter. A
   random wrong letter is never its choice, so -1 and a plain hole give the
   same 85 %. The negative half needs a harder exam: wrong letters that look
   right ("form" for "from").
4. **Part of the "spoiled" letters are words the brain never met.** The text
   is unseen, and a rare word looks like a mistake to a brain that counts.

## E13. Sigmoid or tanh, cosine as truth, and a complex product

*Question.* Four options were on the table: neurons whose votes are bounded by
tanh; kinds decided by the company a word keeps; the cosine as a truth level
from -1 to 1; a complex dot product. Which are worth building?

*How.* Quick prototypes on the English book. The first uses the reference
brain with two steps replaced; the others use a numeric library and are not
in the repository. They are measurements to decide what to build, not
finished code.

**Votes bounded by tanh** (brain `bias+position+decay`, 2000 lessons; each
neuron's vote passes through `bound * tanh (vote / bound)` before the sum):

| Votes | Right at 15 % hidden | at 50 % | at 85 % | Surprise at 15 % |
|---|---|---|---|---|
| plain sum | 43.4 % | 34.1 % | 24.4 % | 2.139 nats |
| tanh, bound 4 nats | 42.6 % | 34.6 % | 24.0 % | 2.123 nats |
| tanh, bound 2 nats | 42.3 % | 33.8 % | 23.3 % | 2.181 nats |

**Kinds by company** (hidden-word exam of E11, the "pick" handover; every word
that is not its own kind is described by 472 counts of the kinds around it,
reduced to its main axes, then grouped):

| Kinds decided by | Hidden word rebuilt exactly |
|---|---|
| shape (what is built) | 32.2 % |
| company, 8 axes | 33.1 % |
| company, 24 axes | 34.3 % |
| company, 60 axes | 36.2 % |
| company, all 472 numbers | 35.5 % |

**The cosine as truth.** Plain cosines between words run from 0 to 1. After
removing the average word, the most opposite words to "Telescope" are
"outmost", "next", "exterior" at -0.23; to "easily" they are "point", "Sine",
"bottom" at -0.30.

**The complex product.** For "thicker" the nearest words by the real part are
"convex", "broader", "larger", "rarer", all at an angle within 4 degrees of 0.
The words with the largest imaginary part sit at 40 to 90 degrees and are of
another kind ("cannot", "know", "It" one way; "grey", "nine", "Bubbles" the
other).

*What it says.*

1. **tanh on the neurons buys nothing here.** With a generous bound the brain
   is the same within noise; with a tight one it is slightly worse. Not built.
2. **Company beats shape by about four points, and 60 axes do as well as all
   472 numbers.** Worth building. On 1,082 words the gap is suggestive, not
   proof.
3. **The cosine is likeness, not truth.** Its negative side means "another
   grammatical role", and opposites in meaning look alike.
4. **The imaginary part separates "replaces" from "stands next to".** The
   pairs are too rare in this book to confirm it by direct counting.

## E14. Kinds by company, with the modules

*Question.* E13 tried kinds by company with borrowed tools. Do the modules
built for it (Company, Axes, Groups, Kind_Makers) give the same gain, and
which settings matter?

*How.* The exam of `Calipso.Word_Exams` on the English book: the first nine
tenths studied, one word in nine of the rest hidden (1,082 words), the answer
is the most usual studied word of that length in the most likely kind. The
figures come from the reference modules with their vector sums done by a
numeric library, because the plain reference would take hours on a whole book
and the Ada cannot be run where this was written. On small texts the build
checks that the Ada program writes exactly what the reference writes.

| Kinds decided by | Hidden word rebuilt exactly |
|---|---|
| shape | 32.2 % |
| company, 8 axes | 32.9 % |
| company, 24 axes | 33.6 % |
| company, 60 axes | **35.9 %** |
| company, every count (no axes) | 35.1 % |
| company, 60 axes, capitals kept apart | 34.9 % |
| company, 60 axes, two tokens each way | 33.5 % |
| company, 60 axes, neighbours as words | 33.1 % |
| company, 60 axes, neighbours as words, two tokens each way | 33.3 % |

Every row by company has 80 groups and 235 kinds in all, the same number of
kinds as the book by shape.

*What it says.*

1. **The modules reproduce the gain**: 35.9 % against 32.2 %, close to the
   36.2 % of E13.
2. **60 numbers do as well as all 472.** The step that shortens the vectors
   costs nothing in quality. With too few axes (8) the gain is lost. The
   default is now 60.
3. **Folding capitals is worth one point.** "The" and "the" keep the same
   company and should be counted together.
4. **Looking further, or counting neighbours as words, does not help this
   exam.** The exam asks for the kind of a word from four neighbours on each
   side, which is a question of grammar, and the nearest neighbour counted as
   a kind answers it best. The finer settings are for groups by meaning, which
   this exam does not reward and this book is too small to show.
5. **The lions.** On five sentences (`tests/data/savanna.txt`) zebras and
   antelopes come out with cosine 1.000, lions and grass with 0, and their
   turn of 90 degrees says they stand on opposite sides of the same word.

## Summary

| Part of the idea | Does it hold? |
|---|---|
| Looking at both sides | Yes, by a wide margin. |
| Collapsing the most certain first | Yes, in every case measured. |
| Giving the ending and landing on it | Yes, at the level of letters and words. |
| Free length | Yes when the hole is short. It grows the minimum. |
| Training with random blind spots | Yes, it learns, and every lesson doubles as a test. Single votes stay well below counting; a mix of both is the best brain so far. |
| Fourier and Laplace as ways of looking | Laplace (fading with distance) comes within 3 or 4 points of exact positions with a third of the numbers. Fourier (waves) did not help as built. |
| Memory of a fixed size | Yes, once each counter knows whose it is. |
| Brains that are small to store and send | Yes: packed, four to six times smaller, nothing lost. |
| A level above the letters (the pyramid) | Partly. Deciding the kind of word first rebuilds a hidden word better (19 % to 30 %). Free writing does not improve yet: the letter level cannot obey its boxes well, and kinds by shape are crude. |
| Cells that are neither fixed nor empty (the dial) | Yes. A text settles around a change, and about 70 % of wrong letters nobody pointed at are mended, at the price of one right letter in a hundred. |
| Kinds from the company a word keeps | Yes, a little: 35.9 % of hidden words against 32.2 % by shape, and 60 numbers a word are enough. |
| Text with meaning | **Not yet.** It is the limit of these brains, not of the engine. |
