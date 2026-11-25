"""Experiment E12: the dial. Can soft cells find and mend a wrong letter?

Usage, from the top folder of the project:
   python3 reference/experiments/settling_exam.py CORPUS [PIECES]

The first nine tenths of CORPUS are studied; pieces of 80 letters are taken from
the last tenth, never studied. In each piece one letter is replaced by a wrong one.

Part A. Nobody says where the wrong letter is. Every cell gets the same certainty
and the text settles. We count how often the wrong letter is mended, and how many
right letters are spoiled, for several positions of the dial.

Part B. The wrong cell is marked "surely wrong" (-1 on the signed scale) and the
others are left alone. We count how often the right letter comes back.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from calipso_ref import alphabets, anchored_oracles, canvases, certainties, counting_oracles
from calipso_ref import random_sources, settling, texts, tokens

PIECE_LENGTH = 80
SIGNED_DIALS = [0.0, 0.5, 0.9, 0.99, 0.999, 0.9999]


def Spoiled(piece, letters, dice):
    #-- The piece with one letter replaced by another small letter. Returns the new piece and the place.
    while True:
        place = random_sources.Draw_Index(dice, len(piece))
        char = alphabets.Character_Of(letters, piece[place])
        if tokens.Is_Letter(char) and not char.isupper():
            break
    while True:
        wrong = 2 + random_sources.Draw_Index(dice, alphabets.Size(letters) - 1)
        wrong_char = alphabets.Character_Of(letters, wrong)
        if wrong != piece[place] and tokens.Is_Letter(wrong_char) and not wrong_char.isupper():
            break
    spoiled = list(piece)
    spoiled[place] = wrong
    return spoiled, place


def Settled_Text(spoiled, speller, anchors):
    board = settling.Written(spoiled)
    settling.Settle(board, speller, anchors)
    return [canvases.Symbol_At(board, position) for position in range(0, canvases.Length(board))]


def Main():
    whole = texts.Whole_Text(sys.argv[1])
    pieces = int(sys.argv[2]) if len(sys.argv) > 2 else 300
    cut = (len(whole) * 9) // 10
    study = whole[:cut]
    unseen = whole[cut:]
    letters = alphabets.Alphabet()
    for char in study:
        alphabets.Include(letters, char)
    size = alphabets.Size(letters)
    speller = counting_oracles.Counting_Oracle()
    counting_oracles.Train(speller, texts.Encoded(study, letters), size)
    unseen_symbols = texts.Encoded(unseen, letters)
    step = (len(unseen_symbols) - PIECE_LENGTH) // pieces
    cases = []
    dice = random_sources.Seeded(12)
    for number in range(0, pieces):
        piece = unseen_symbols[number * step:number * step + PIECE_LENGTH]
        spoiled, place = Spoiled(piece, letters, dice)
        cases.append((piece, spoiled, place))
    print(f"Alphabet of {size} symbols: 'no idea' is a certainty of {certainties.Chance_Level(size):.4f}. {pieces} pieces of {PIECE_LENGTH} letters.")
    print("Part A. Nobody says where the wrong letter is.")
    print("   signed dial   as certainty   wrong letter mended   right letters spoiled, in every 100")
    for signed in SIGNED_DIALS:
        sure = certainties.Certainty_Of(signed, size)
        mended = 0
        harmed = 0
        for piece, spoiled, place in cases:
            result = Settled_Text(spoiled, speller, settling.Even_Anchors(spoiled, sure))
            mended += result[place] == piece[place]
            harmed += sum(1 for position in range(0, PIECE_LENGTH) if position != place and result[position] != piece[position])
        print(f"   {signed:<11}   {sure:<12.4f}   {100.0 * mended / pieces:5.1f} %               {100.0 * harmed / (pieces * (PIECE_LENGTH - 1)):6.2f}")
    print("Part B. The wrong cell is marked; every other cell is sure (1).")
    for name, signed in (("no idea (0): like a hole", certainties.NO_IDEA), ("surely wrong (-1)", certainties.SURELY_WRONG)):
        mended = 0
        for piece, spoiled, place in cases:
            anchors = settling.Even_Anchors(spoiled, 1.0)
            anchors[place] = anchored_oracles.Signed_Anchor_Of(spoiled[place], signed, size)
            result = Settled_Text(spoiled, speller, anchors)
            mended += result[place] == piece[place]
        print(f"   the wrong cell is marked {name:<26} right letter back {100.0 * mended / pieces:5.1f} %")


Main()
