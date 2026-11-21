# Experiments

Five questions about the collapse idea, with figures.

## How they were run

- **Programs:** `python3 reference/experiments.py CORPUS 60` for E1 to E4
  (60 trials per case) and `python3 reference/train.py CORPUS` for E5.
  Seeds are fixed: every run can be repeated and gives the same output.
- **Main corpus:** a public-domain book in English, 557,909 letters
  (Newton's *Opticks*; it was the long text at hand). It is not in the
  repository. The model learns from the first 90 % and is examined on the
  last 10 %, which it has never seen.
- **Small corpus:** `data/sample_es.txt`, 9,144 letters in Spanish.
- **Brain:** the counting one, with a window of 7 letters, except in E5.
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

## E5. Does training with random blind spots work?

The voting brain starts with every number at 0 and learns only by playing the
blind-spot game: 4,000 lessons, each one a piece of 64 letters with a random
amount hidden. Then all brains take the same exam: letters are hidden at
random and the brain is asked about each hidden letter, without filling in
the others.

| Hidden | Brain | Right | Mean surprise |
|---|---|---|---|
| 15 % | counting | **72.0 %** | **1.156 nats** |
| 15 % | votes, untrained | 0.0 % | 4.511 nats |
| 15 % | votes, trained | 44.2 % | 2.230 nats |
| 50 % | counting | **41.9 %** | **2.132 nats** |
| 50 % | votes, untrained | 0.0 % | 4.511 nats |
| 50 % | votes, trained | 33.2 % | 2.490 nats |
| 85 % | counting | 24.1 % | 2.828 nats |
| 85 % | votes, untrained | 0.0 % | 4.511 nats |
| 85 % | votes, trained | 24.1 % | 2.829 nats |

(378, 1,264 and 2,131 hidden letters. All brains get the same pieces and the
same holes.)

**Reading.**

- **Training by blind spots works.** The untrained brain bets the same on
  every letter (4.511 nats is the surprise of a blind guess among 91
  symbols). After training its surprise is about half.
- **One layer is not enough.** With few holes, counting is far ahead (72 %
  against 44 %). Each neighbour votes on its own, so this brain cannot use
  *combinations* of neighbours; counting can, within its 7 letters.
- **When almost everything is hidden, they tie.** At 85 % hidden there are few
  neighbours next to each hole. Counting falls back to very short windows;
  the voting brain looks through the holes, and that makes up the difference.

On the Spanish sample: trained votes 41.5 % against 59.8 % for counting at
15 % hidden, and 23.1 % against 23.2 % at 85 %. The same pattern.

Exploratory runs, not in the table: more lessons (6,000), a wider reach (24)
and a larger step did not improve the trained brain. The limit is its shape.

## Summary

| Part of the idea | Does it hold? |
|---|---|
| Looking at both sides | Yes, by a wide margin. |
| Collapsing the most certain first | Yes, in every case measured. |
| Giving the ending and landing on it | Yes, at the level of letters and words. |
| Free length | Yes when the hole is short. It grows the minimum. |
| Training with random blind spots | Yes, it learns. A single layer of independent votes stays below counting. |
| Text with meaning | **Not yet.** It is the limit of these brains, not of the engine. |
