"""Mirror of apps/calipso_crawl.adb: a brain that studies pages from the web.

Usage:
   python3 reference/crawl.py BRAIN_FILE START_LIST [PAGES] [RECIPE]

START_LIST is a text file with one address per line (lines that start with #
are notes). The robot starts there and follows the links it finds, staying on
the same site, obeying each site's robots.txt, and never asking faster than
once a second. It reads at most PAGES pages (20 if not said).

The brain is loaded from BRAIN_FILE, or made new from RECIPE if the file does
not exist, and saved back at the end. What was found that is not a page
(pictures, films, sounds, other text files) is listed in BRAIN_FILE.finds.txt.
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
HIDING_SEED = 1077
MOST_LESSONS = 1000000
#-- The study goes on until the pages run out; this is only a ceiling.


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


def Run_Crawl(
        brain_name: str,
        list_name: str,
        pages: int,
        recipe: str
        ) -> None:
    brain = Made_Or_Loaded(brain_name, recipe)
    settings = web_sources.Settings()
    settings.page_limit = pages
    work_file = brain_name + ".page"
    source = web_sources.Web_Source()
    web_sources.Open(source, fetchers.Curl_Fetcher(), brain.letters, settings, work_file)
    Add_Start_List(source, list_name)
    dice = random_sources.Seeded(HIDING_SEED + brain.lessons)
    before = brain.lessons
    result = brains.Study(brain, source, dice, MOST_LESSONS)
    Show_Tally(source)
    surprise = blind_spots.Mean_Surprise(result)
    print(f"Studied {brain.lessons - before} lessons. While studying: right {Percent_Image(result.hits, result.hidden)} %, mean surprise {surprise:.3f} nats ({result.hidden} letters)")
    print(f"Lessons so far: {brain.lessons}")
    brains.Save(brain, brain_name)
    print(f"Saved to {brain_name}")
    Write_Finds(source, brain_name + ".finds.txt")
    print(f"Finds listed in {brain_name}.finds.txt")
    if os.path.exists(work_file):
        os.remove(work_file)


def Whole_Number(
        word: str
        ) -> int:
    if not word.isascii() or not word.isdigit():
        raise Bad_Argument("the number of pages must be a whole number, 0 or greater")
    return int(word)


def Show_Usage() -> None:
    print("Usage:")
    print("   calipso_crawl BRAIN_FILE START_LIST [PAGES] [RECIPE]")


def Main() -> None:
    arguments = sys.argv[1:]
    if len(arguments) < 2:
        Show_Usage()
        sys.exit(1)
    try:
        pages = DEFAULT_PAGES
        recipe = DEFAULT_RECIPE
        if len(arguments) >= 3:
            pages = Whole_Number(arguments[2])
        if len(arguments) >= 4:
            recipe = arguments[3]
        Run_Crawl(arguments[0], arguments[1], pages, recipe)
    except (texts.Reading_Error, records.Record_Error, neuron_kinds.Recipe_Error, Bad_Argument) as problem:
        print(f"Error: {problem}")
        sys.exit(1)


if __name__ == "__main__":
    Main()
