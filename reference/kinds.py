"""A program to try the ways of deciding kinds. It mirrors apps/calipso_kinds.adb.

Usage:
   python3 reference/kinds.py alike CORPUS WORD OTHER... [reach=N] [context=kinds|words] [case=fold|keep]
   python3 reference/kinds.py exam CORPUS [kinds=shape|company] [reach=N] [context=kinds|words]
                              [case=fold|keep] [axes=N] [rounds=N] [groups=N] [step=N]

alike : describes every word of CORPUS by the company it keeps and says how alike
        WORD is to each OTHER (cosine: 1 the same company, 0 nothing in common;
        turn: near 0 they replace each other, near 90 one stands beside the other).
exam  : studies the first nine tenths of CORPUS, hides one word in every STEP of
        the last tenth, and counts how often the level of kinds gets it back.

   kinds=shape|company   how kinds are decided (shape if not said)
   reach=N               tokens looked at on each side of a word (1)
   context=kinds|words   what a neighbour counts as (kinds)
   case=fold|keep        whether "Zebras" and "zebras" are one word (fold)
   axes=N                numbers kept for each word; 0 keeps them all (60)
   rounds=N              how long each axis is searched for (30)
   groups=N              how many groups of words are made (80)
   step=N                one word in every N is hidden (9)
"""

import sys

from calipso_ref import axes
from calipso_ref import company
from calipso_ref import kind_makers
from calipso_ref import kinds
from calipso_ref import pyramids
from calipso_ref import texts
from calipso_ref import tokens
from calipso_ref import vectors
from calipso_ref import word_exams

MOST_DIGITS = 9


class Bad_Argument(Exception):
    pass


class Choices:
    #-- What the command line asked for.

    def __init__(self):
        self.making = kind_makers.Settings()
        self.step = word_exams.DEFAULT_STEP
        self.plain = []
        #-- The arguments that are not options, in order.


def Whole_Number(
        word: str,
        least: int
        ) -> int:
    if word == "" or len(word) > MOST_DIGITS or not all("0" <= char <= "9" for char in word):
        raise Bad_Argument("a whole number was expected. Found: " + word)
    value = int(word)
    if value < least:
        raise Bad_Argument(f"the number must be {least} or more. Found: " + word)
    return value


def Take_Option(
        wanted: Choices,
        name: str,
        value: str
        ) -> None:
    making = wanted.making
    if name == "kinds" and value == "shape":
        making.way = kind_makers.BY_SHAPE
    elif name == "kinds" and value == "company":
        making.way = kind_makers.BY_COMPANY
    elif name == "context" and value == "kinds":
        making.company.context = company.AS_KINDS
    elif name == "context" and value == "words":
        making.company.context = company.AS_WORDS
    elif name == "case" and value == "fold":
        making.company.fold_case = True
    elif name == "case" and value == "keep":
        making.company.fold_case = False
    elif name == "reach":
        making.company.reach = Whole_Number(value, 1)
    elif name == "axes":
        making.axes = Whole_Number(value, 0)
    elif name == "rounds":
        making.rounds = Whole_Number(value, 1)
    elif name == "groups":
        making.groups = Whole_Number(value, 1)
    elif name == "step":
        wanted.step = Whole_Number(value, 1)
    else:
        raise Bad_Argument("this option is not understood: " + name + "=" + value)


def Take_Argument(
        wanted: Choices,
        word: str
        ) -> None:
    #-- name=value is an option; anything else is kept in order.
    equal = word.find("=")
    if equal < 0:
        wanted.plain.append(word)
    else:
        Take_Option(wanted, word[:equal], word[equal + 1:])


def Company_Words(
        options: company.Settings
        ) -> str:
    context = "kinds" if options.context == company.AS_KINDS else "words"
    capitals = "folded" if options.fold_case else "kept"
    return f"reach {options.reach}, neighbours as {context}, capitals {capitals}"


def Alike(
        corpus_name: str,
        wanted: Choices
        ) -> None:
    if len(wanted.plain) < 2:
        raise Bad_Argument("alike needs a word and at least one other word")
    sample = tokens.Split(texts.Whole_Text(corpus_name))
    options = wanted.making.company
    options.every_word = True
    table = company.Built(sample, kinds.Built(sample), options)
    width = len(company.Vector_At(table, 1)) if company.Row_Count(table) > 0 else 0
    print(f"Company: {Company_Words(options)}. {company.Row_Count(table)} words, each described by {width} counts.")
    word = wanted.plain[0]
    if not company.Has_Word(table, word):
        print(word + " is not in the text.")
        return
    mine = company.Vector_Of(table, word)
    for other in wanted.plain[1:]:
        if not company.Has_Word(table, other):
            print(other + " is not in the text.")
        else:
            theirs = company.Vector_Of(table, other)
            cosine = vectors.Cosine(mine, theirs) + 0.0
            turn = vectors.Turn(mine, theirs) + 0.0
            print(f"{word} / {other}: cosine {cosine:.3f}, turn {turn:.1f} degrees")


def Making_Words(
        making: kind_makers.Settings
        ) -> str:
    if making.way == kind_makers.BY_SHAPE:
        return "by shape"
    return f"by company ({Company_Words(making.company)}, {making.axes} axes, {making.groups} groups)"


def Exam(
        corpus_name: str,
        wanted: Choices
        ) -> None:
    whole = texts.Whole_Text(corpus_name)
    cut = (len(whole) * 9) // 10
    plan = pyramids.Pyramid()
    pyramids.Study(plan, whole[:cut], wanted.making)
    result = word_exams.Exam(plan, tokens.Split(whole[:cut]), tokens.Split(whole[cut:]), wanted.step)
    share = 100.0 * float(result.right) / float(result.asked) if result.asked > 0 else 0.0
    print(f"Kinds: {Making_Words(wanted.making)}. {kinds.Kind_Count(plan.book)} kinds.")
    print(f"Hidden words: {result.asked}. Rebuilt exactly: {result.right} ({share:.1f} %).")


def Show_Usage() -> None:
    print("Usage:")
    print("   calipso_kinds alike CORPUS WORD OTHER... [reach=N] [context=kinds|words] [case=fold|keep]")
    print("   calipso_kinds exam CORPUS [kinds=shape|company] [reach=N] [context=kinds|words] [case=fold|keep]")
    print("                      [axes=N] [rounds=N] [groups=N] [step=N]")


def Main() -> None:
    arguments = sys.argv[1:]
    if len(arguments) < 2 or arguments[0] not in ("alike", "exam"):
        Show_Usage()
        sys.exit(1)
    wanted = Choices()
    try:
        for word in arguments[2:]:
            Take_Argument(wanted, word)
        if arguments[0] == "alike":
            Alike(arguments[1], wanted)
        else:
            Exam(arguments[1], wanted)
    except Bad_Argument as problem:
        print("Error: " + str(problem))
        sys.exit(1)
    except texts.Reading_Error as problem:
        print("Error: " + str(problem))
        sys.exit(1)


Main()
