"""Experiment E11: is the pyramid (kinds of word first, then letters) any good?

Usage, from the top folder of the project:
   python3 reference/experiments/pyramid_exam.py CORPUS [STEP] [SAMPLES]

The first nine tenths of CORPUS are studied; the last tenth is never studied.

Part A, an exam on the tenth never studied. One word in every STEP is hidden and
each method must rebuild it, knowing its length:
   flat   : the letter brain fills the letters of the hole.
   spell  : the level of kinds decides WHICH KIND of word goes there, from the kinds
            around it; then the letter brain fills a box with that kind's rules.
   pick   : the level of kinds decides the kind; then the most usual word of that kind is taken.

Part B, free writing. Each method writes SAMPLES texts; then we count how many of
the words written exist in the studied text, and how many pairs of neighbours do.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from calipso_ref import alphabets, boxed_oracles, canvases, collapsing, counting_oracles
from calipso_ref import distributions, kinds, pyramids, random_sources, texts, tokens, writers

SIDE_LETTERS = 40
SIDE_KINDS = 4
WORDS_PER_TEXT = 22


def Spans_Of(text):
    #-- The same cut as tokens.Split, keeping where each token starts and ends.
    spans = []
    position = 0
    while position < len(text):
        char = text[position]
        if tokens.Is_Letter(char):
            last = tokens.Run_End(text, position, tokens.Is_Letter)
            spans.append((position, last + 1))
        elif tokens.Is_Digit(char):
            last = tokens.Run_End(text, position, tokens.Is_Digit)
            spans.append((position, last + 1))
        elif tokens.Is_Blank(char):
            last = tokens.Run_End(text, position, tokens.Is_Blank)
            if tokens.Feeds_In(text, position, last) >= tokens.FEEDS_IN_A_BREAK:
                spans.append((position, last + 1))
        else:
            last = position
            spans.append((position, position + 1))
        position = last + 1
    return spans


def Token_At(text, span):
    piece = text[span[0]:span[1]]
    if tokens.Is_Blank(piece[0]):
        return tokens.BREAK_TEXT
    return piece


def Rebuilt(speller, letters, dice, left, right, hole_rules, ending):
    #-- Fills a hole between two pieces of known text, always taking the most likely letter.
    board = canvases.Canvas()
    rules = []
    for symbol in texts.Encoded(left, letters):
        canvases.Append_Given(board, symbol)
        rules.append(boxed_oracles.Free_Rule())
    for rule in hole_rules:
        canvases.Append_Blank(board)
        rules.append(rule)
    for symbol in texts.Encoded(ending + right, letters):
        canvases.Append_Given(board, symbol)
        rules.append(boxed_oracles.Free_Rule())
    boxed = boxed_oracles.Boxed_Oracle(speller, rules)
    collapsing.Collapse_All(board, boxed, dice, collapsing.MOST_CERTAIN_FIRST, collapsing.ALWAYS_MOST_LIKELY)
    plain = pyramids.Plain_Text(board, letters)
    return plain[len(left):len(left) + len(hole_rules) + len(ending)]


def Fits(book, kind, length):
    family = kinds.Family_Of(book, kind)
    if family == kinds.WORD_KIND:
        return len(kinds.Text_Of(book, kind)) == length
    if family == kinds.SHAPE_KIND:
        return any(len(member.word) == length for member in book.members.get(kind, []))
    return False


def Percent(part, whole):
    return f"{100.0 * part / max(whole, 1):5.1f} %"


def Hidden_Word_Exam(plan, speller, letters, study_words, unseen, step):
    book = plan.book
    rules = pyramids.Rules_Of(letters)
    spans = Spans_Of(unseen)
    unseen_kinds = [kinds.Kind_Of(book, Token_At(unseen, span)) for span in spans]
    dice = random_sources.Seeded(7)
    count = 0
    right = {"flat": 0, "spell": 0, "pick": 0}
    right_kind = {"flat": 0, "spell": 0, "pick": 0}
    for index in range(SIDE_KINDS, len(spans) - SIDE_KINDS, step):
        truth = Token_At(unseen, spans[index])
        if tokens.Sort_Of(truth) != tokens.WORD:
            continue
        count = count + 1
        length = len(truth)
        left = unseen[max(0, spans[index][0] - SIDE_LETTERS):spans[index][0]]
        after = unseen[spans[index][1]:spans[index][1] + SIDE_LETTERS]
        guesses = {}
        guesses["flat"] = Rebuilt(speller, letters, dice, left, after, [boxed_oracles.Free_Rule()] * length, "")
        board = canvases.Canvas()
        for neighbour in range(index - SIDE_KINDS, index + SIDE_KINDS + 1):
            if neighbour == index:
                canvases.Append_Blank(board)
            else:
                canvases.Append_Given(board, unseen_kinds[neighbour])
        belief = plan.brain.Opinion(board, SIDE_KINDS)
        best_kind = 1
        best_weight = -1.0
        for kind in range(2, kinds.Kind_Count(book) + 1):
            weight = distributions.Weight_Of(belief, kind)
            if Fits(book, kind, length) and weight > best_weight:
                best_kind = kind
                best_weight = weight
        if kinds.Family_Of(book, best_kind) == kinds.WORD_KIND:
            guesses["spell"] = kinds.Text_Of(book, best_kind)
        else:
            ending = kinds.Text_Of(book, best_kind)
            hole = []
            for cell in range(0, length - len(ending)):
                hole.append(rules.capital if (cell == 0 and kinds.Is_Capital(book, best_kind)) else rules.small)
            guesses["spell"] = Rebuilt(speller, letters, dice, left, after, hole, ending)
        best_word = ""
        best_weight = -1.0
        for word, seen in study_words.items():
            if len(word) != length:
                continue
            kind = kinds.Kind_Of(book, word)
            share = 1.0 if kinds.Family_Of(book, kind) == kinds.WORD_KIND else seen / book.totals[kind]
            weight = distributions.Weight_Of(belief, kind) * share
            if weight > best_weight:
                best_word = word
                best_weight = weight
        guesses["pick"] = best_word
        for method in right:
            right[method] += guesses[method] == truth
            is_word = guesses[method] != "" and tokens.Is_Letter(guesses[method][0])
            right_kind[method] += is_word and kinds.Kind_Of(book, guesses[method]) == unseen_kinds[index]
    print(f"Part A. Hidden words rebuilt, in text never studied ({count} words):")
    for method in ("flat", "spell", "pick"):
        print(f"   {method:<6} the exact word {Percent(right[method], count)}   a word of the right kind {Percent(right_kind[method], count)}")


def Word_Figures(written, study_words, study_pairs):
    words = 0
    known = 0
    pairs = 0
    known_pairs = 0
    for text in written:
        found = tokens.Split(text)
        for index in range(0, len(found)):
            if tokens.Sort_Of(found[index]) != tokens.WORD:
                continue
            words += 1
            known += found[index] in study_words
            if index >= 1 and tokens.Sort_Of(found[index - 1]) == tokens.WORD:
                pairs += 1
                known_pairs += (found[index - 1], found[index]) in study_pairs
    return f"words that exist {Percent(known, words)}   pairs of neighbours seen {Percent(known_pairs, pairs)}   ({words} words)"


def Writing_Exam(plan, speller, letters, study_words, study_pairs, unseen, samples):
    print("Part B. Free writing:")
    print("   real text never studied   " + Word_Figures([unseen], study_words, study_pairs))
    authors = [
        ("flat ", writers.Flat_Writer(speller, letters)),
        ("spell", writers.Pyramid_Writer(plan, speller, letters, pyramids.SPELL)),
        ("pick ", writers.Pyramid_Writer(plan, speller, letters, pyramids.PICK)),
        ]
    for name, author in authors:
        written = []
        for sample in range(0, samples):
            written.append(author.Write(random_sources.Seeded(1000 + sample), WORDS_PER_TEXT))
        print(f"   {name}                     " + Word_Figures(written, study_words, study_pairs))
        print("        for example: " + written[0].replace("\n", " / "))


def Main():
    whole = texts.Whole_Text(sys.argv[1])
    step = int(sys.argv[2]) if len(sys.argv) > 2 else 9
    samples = int(sys.argv[3]) if len(sys.argv) > 3 else 60
    cut = (len(whole) * 9) // 10
    study = whole[:cut]
    unseen = whole[cut:]
    letters = alphabets.Alphabet()
    for char in study:
        alphabets.Include(letters, char)
    speller = counting_oracles.Counting_Oracle()
    counting_oracles.Train(speller, texts.Encoded(study, letters), alphabets.Size(letters))
    plan = pyramids.Pyramid()
    pyramids.Study(plan, study)
    found = tokens.Split(study)
    study_words = {}
    for token in found:
        if tokens.Sort_Of(token) == tokens.WORD:
            study_words[token] = study_words.get(token, 0) + 1
    study_pairs = set(zip(found, found[1:]))
    print(f"Studied {len(study)} letters, {len(found)} tokens, {len(study_words)} different words, {kinds.Kind_Count(plan.book)} kinds.")
    Hidden_Word_Exam(plan, speller, letters, study_words, unseen, step)
    Writing_Exam(plan, speller, letters, study_words, study_pairs, unseen, samples)


Main()
