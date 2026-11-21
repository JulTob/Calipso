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

## 4. The second brain: votes that learn

`Calipso.Voting_Oracles` is the first brain whose numbers are *learned* with
the blind-spot game, which was the original training proposal.

- Every known neighbour **votes**. A vote is a row of points, for or against
  each candidate letter. There is a different row for each pair (distance to
  the hole, letter found there). "I have a `q` right on your left" gives many
  points to `u`.
- The opinion is the sum of the votes of all known neighbours, turned into
  probabilities. Holes simply do not vote, so this brain can look *through*
  holes, up to 12 cells away on each side.
- At the start every point is 0. Training repeats one small lesson: hide a
  letter, give an opinion, look at the real letter, and move the points of
  every neighbour that voted so that the real letter would surprise less.
- Each lesson hides a different amount of text, from almost nothing to almost
  everything.

The correction for each lesson is simple enough to write by hand:

```
error(letter)  = probability bet on that letter, minus 1 for the real letter
each voter's points for that letter go down by  step × error(letter)
```

It fulfils the same `Oracle` contract, so the engine, the repair and the exam
work with it unchanged.

### What it showed

Training with blind spots **works**: in a few seconds the brain goes from
knowing nothing to a real opinion. But this brain is clearly worse than
counting when the neighbours are known, and only matches it when almost
everything is hidden (figures in [EXPERIMENTS.md](EXPERIMENTS.md), E5).

The reason is its shape, not the training. Each neighbour votes **on its
own**. The brain cannot learn that `t` on the left *together with* `e` on the
right means `h`: it can only add up what `t` says and what `e` says. Counting
does see such combinations, within its 7 letters.

So the next brain needs votes that depend on combinations of neighbours.
That is what stacked layers, and attention in particular, provide.

## 5. Decisions taken, and why

| Decision | Alternative rejected | Reason |
|---|---|---|
| One centred window that grows | Multiply the opinion of a forward model by that of a backward model | Measured with the same smoothing: 0.74 nats of mean surprise against 0.95 (window of 7). And it is a single mechanism. |
| Brake by variety | A constant tuned by hand | Measured: 0.665 nats and 85.5 % hits, against 0.659 and 83.4 % for the best constant I tried. Practically the same, with nothing to tune. |
| Collapse the most certain hole first | Left to right, or random order | Measured: it recovers more letters at every level of hiding. |
| Tension = surprise above a threshold | Mean surprise | The mean rewards filling with easy, repetitive text. The threshold does not: once everything fits, it stops. |
| Measure tension on nearby given letters too | Only on the model's letters | A bad seam shows on both sides. Without this the engine did not see broken words. |
| Our own random generator (`Random_Sources`) | The standard library generator | This way Ada and Python give the same numbers and any result can be repeated. |
| Letters as the unit | Words or pieces of words | The simplest thing that works. It can be changed without touching the engine: the alphabet is a table. |
| The learner shares each correction equally among its voters | A fixed step per voter | A design argument, not a measurement: with a fixed step, a hole with many known neighbours would get many corrections at once and overshoot. Sharing keeps the total correction the same however many neighbours are known. |

The "measured" figures in the first two rows come from exploratory runs on the
English text of 558,000 letters; the others come from
[EXPERIMENTS.md](EXPERIMENTS.md).

## 6. What these brains cannot do

Both see only letters near the hole, and neither understands them. So:

- Words come out well formed and join up with the given ending.
- **There is no global meaning.** They cannot write a paragraph that
  *justifies* "y por eso debes lavarte los dientes": they do not know what
  the ending is about.
- Tension only detects local faults. An absurd sentence made of correct words
  has tension 0.
- Free length works as "grow until it joins", not "grow until it makes sense".

None of this is a defect of the engine. It is the limit of the brains. For
global meaning an oracle is needed that combines what it sees over a long
distance.

## 7. Proposed next stage

**Automatic derivatives in Ada**, then **attention**.

- The voting brain's correction was written by hand. With more than one layer
  that stops being practical: a small algebra of "values that remember how
  they were computed" gives the corrections automatically.
- With that, a brain where every cell *consults* the others (attention) and
  the answer depends on combinations of what they hold.
- The contract, the engine, the repair and the exam stay as they are.

Training speed matters from here on. In GitHub Actions the Ada program that
counts, trains 1,500 lessons and runs the exams takes under half a second; the
Python reference takes about five seconds for the same work.

## 8. How the Ada is checked

`reference/calipso_ref/` is a mirror: one module per package, same functions,
same steps in the same order (even the order of the additions).
`tests/calipso_tests.adb` and `reference/tests.py` run the same tests on the
same tiny corpus. The expected numbers in the Ada tests come from Python.

The tests have two levels. Properties (no holes left, given letters do not
change, tension does not rise) must always hold. Letter-by-letter comparisons
with the reference only leave a note, because different rounding between
machines can change a draw without anything being wrong.

GitHub Actions also runs the three programs in Ada and in Python and compares
their output with `diff`.

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
