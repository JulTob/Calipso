"""Mirror of apps/calipso_crawl.adb: a brain that studies pages from the web.

Usage:
   python3 reference/crawl.py BRAIN_FILE START_LIST [pages=N] [minutes=N] [list=N] [recipe=R]

START_LIST is a text file with one address per line (lines that start with #
are notes). The robot starts there and follows the links it finds, staying on
the same site, obeying each site's robots.txt, and never asking faster than
once a second.

   pages=N    read at most N pages (20 if not said)
   minutes=N  stop asking for pages after N minutes (no limit if not said)
   list=N     the size of the waiting list of links (1024 if not said)
   recipe=R   the neurons of a NEW brain (bias+position if not said)

The brain is loaded from BRAIN_FILE, or made new if the file does not exist,
and saved as it studies. What was found that is not a page (pictures, films,
sounds, other text files) is listed in BRAIN_FILE.finds.txt.
"""

import os
import sys

from calipso_ref import alphabets
from calipso_ref import blind_spots
from calipso_ref import brains
from calipso_ref import fetchers
from calipso_ref import neuron_kinds
from calipso_ref import random_sources
from calipso_ref import records
from calipso_ref import texts
from calipso_ref import web_addresses
from calipso_ref import web_sources

DEFAULT_PAGES = 20
DEFAULT_RECIPE = "bias+position"
DEFAULT_LIST = 1024
SEEN_PER_PLACE = 64
#-- The table of seen addresses has this many places for each place in the waiting list.
SECONDS_IN_A_MINUTE = 60.0
HIDING_SEED = 1077
SAVE_EVERY = 50
#-- The brain is saved after every stretch of this many lessons, so that
#-- stopping the program half way loses little.


class Bad_Argument(Exception):
    pass


def Percent_Image(
        part: int,
        whole: int
        ) -> str:
    if whole == 0:
        return "  n/a"
    share = 100.0 * float(part) / float(whole)
    return f"{share:5.1f}"


def Made_Or_Loaded(
        brain_name: str,
        recipe: str
        ) -> brains.Brain:
    brain = brains.Brain()
    if os.path.exists(brain_name):
        brains.Load(brain, brain_name)
        print(f"Brain: {brains.Recipe_Of(brain)} (loaded, {brain.lessons} lessons so far)")
        return brain
    brains.Prepare(brain, alphabets.Common_Letters())
    #-- The pages are not known beforehand, so a new brain starts with the common letters.
    brains.Add_Recipe(brain, recipe)
    print(f"Brain: {brains.Recipe_Of(brain)} (new)")
    return brain


def Add_Start_List(
        source: web_sources.Web_Source,
        list_name: str
        ) -> None:
    try:
        with open(list_name, encoding="utf-8") as file:
            lines = file.read().split("\n")
    except (OSError, UnicodeDecodeError):
        raise texts.Reading_Error(f"cannot read the list of addresses {list_name}")
    for line in lines:
        address = line.strip(" \t\r")
        if address != "" and not address.startswith("#"):
            web_sources.Add_Address(source, address)


def Show_Tally(
        source: web_sources.Web_Source
        ) -> None:
    tally = source.tally
    print(
        f"Pages: asked for {tally.asked}, read {tally.read} ({tally.letters} letters). "
        f"Refused by the site's rules: {tally.refused}. Not text after asking: {tally.not_text}. "
        f"Failed: {tally.failed}."
        )
    print(
        f"Links: {web_sources.Waiting_Count(source)} still waiting, {tally.left_out} left out "
        f"because a list was full (lists of {source.settings.list_size})."
        )
    line = "Found and filed:"
    for kind in web_addresses.ALL_KINDS:
        if kind != web_addresses.PAGE:
            line = line + f" {kind} {len(source.finds[kind])},"
    print(line[:-1] + ".")


def Write_Finds(
        source: web_sources.Web_Source,
        file_name: str
        ) -> None:
    with open(file_name, "w", encoding="utf-8", newline="\n") as file:
        for kind in web_addresses.ALL_KINDS:
            for address in source.finds[kind]:
                file.write(f"{kind} {address}\n")


def Studied_And_Saved(
        brain: brains.Brain,
        brain_name: str,
        source: web_sources.Web_Source,
        dice
        ) -> blind_spots.Exam_Result:
    #-- Studies until the pages run out, saving the brain after every stretch.
    result = blind_spots.Exam_Result()
    while True:
        before = brain.lessons
        stretch = brains.Study(brain, source, dice, SAVE_EVERY)
        studied = brain.lessons - before
        result = blind_spots.Added(result, stretch)
        brains.Save(brain, brain_name)
        if studied < SAVE_EVERY:
            break
            #-- A short stretch means the pages have run out.
    return result


class Options:
    #-- What the command line asked for.

    def __init__(self):
        self.pages = DEFAULT_PAGES
        self.minutes = 0
        self.list_size = DEFAULT_LIST
        self.recipe = DEFAULT_RECIPE


def Run_Crawl(
        brain_name: str,
        list_name: str,
        options: Options
        ) -> None:
    brain = Made_Or_Loaded(brain_name, options.recipe)
    settings = web_sources.Settings()
    settings.page_limit = options.pages
    settings.list_size = options.list_size
    settings.seen_size = options.list_size * SEEN_PER_PLACE
    settings.time_limit = float(options.minutes) * SECONDS_IN_A_MINUTE
    work_file = brain_name + ".page"
    source = web_sources.Web_Source()
    web_sources.Open(source, fetchers.Curl_Fetcher(), brain.letters, settings, work_file)
    Add_Start_List(source, list_name)
    dice = random_sources.Seeded(HIDING_SEED + brain.lessons)
    before = brain.lessons
    result = Studied_And_Saved(brain, brain_name, source, dice)
    Show_Tally(source)
    surprise = blind_spots.Mean_Surprise(result)
    print(f"Studied {brain.lessons - before} lessons. While studying: right {Percent_Image(result.hits, result.hidden)} %, mean surprise {surprise:.3f} nats ({result.hidden} letters)")
    print(f"Lessons so far: {brain.lessons}")
    print(f"Saved to {brain_name}")
    Write_Finds(source, brain_name + ".finds.txt")
    print(f"Finds listed in {brain_name}.finds.txt")
    if os.path.exists(work_file):
        os.remove(work_file)


def Whole_Number(
        word: str,
        least: int
        ) -> int:
    if not word.isascii() or not word.isdigit() or len(word) > 9:
        raise Bad_Argument("a number was expected, found: " + word)
    if int(word) < least:
        raise Bad_Argument("the number is too small: " + word)
    return int(word)


def Take_Option(
        options: Options,
        word: str
        ) -> None:
    #-- One option, written name=value.
    equal = word.find("=")
    if equal < 0:
        raise Bad_Argument("options are written name=value, for example pages=50. Found: " + word)
    name = word[:equal]
    value = word[equal + 1:]
    if name == "pages":
        options.pages = Whole_Number(value, 0)
    elif name == "minutes":
        options.minutes = Whole_Number(value, 0)
    elif name == "list":
        options.list_size = Whole_Number(value, 1)
    elif name == "recipe":
        options.recipe = value
    else:
        raise Bad_Argument("there is no option called " + name)


def Show_Usage() -> None:
    print("Usage:")
    print("   calipso_crawl BRAIN_FILE START_LIST [pages=N] [minutes=N] [list=N] [recipe=R]")


def Main() -> None:
    arguments = sys.argv[1:]
    if len(arguments) < 2:
        Show_Usage()
        sys.exit(1)
    try:
        options = Options()
        for word in arguments[2:]:
            Take_Option(options, word)
        Run_Crawl(arguments[0], arguments[1], options)
    except (texts.Reading_Error, records.Record_Error, neuron_kinds.Recipe_Error, Bad_Argument) as problem:
        print(f"Error: {problem}")
        sys.exit(1)


if __name__ == "__main__":
    Main()
