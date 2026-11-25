"""Mirror of Calipso.Web_Sources: a source that reads pages from the web.

It keeps a list of addresses to visit. For each one, in order:

   1. ask the site's rules (robots.txt) whether the address may be fetched
   2. wait, if the last request was too recent
   3. fetch it, and check what really arrived
   4. take its words, to hand out in pieces
   5. take its links: new ones go to the end of the list

The next page is fetched only when the words of this one have been handed
out. So the brain studies a whole page before the next request is made:
studying IS the pause between requests.

Nothing is fetched twice. An address that is linked again is not listed
again; it only gets one more "mention", a count of how many links point to it.

Everything has a fixed size, chosen in the settings, so that a long walk
never needs more memory than a short one:

   the waiting list : the addresses still to visit. When it is full, new
                      links are left out until there is room again.
   the seen table   : which addresses are already known, and their mentions.
                      It works like the bounded memory of the brain: each
                      address has one place, with a check number saying whose
                      it is, and a newcomer wears the owner down before taking
                      the place. An address forgotten this way may be read again.

What is not a page is not thrown away: its address is filed under its kind
(writing, picture, video, sound...), ready for the brain of that kind.
"""

import time

from . import alphabets
from . import fetchers
from . import pages
from . import robots
from . import sources
from . import texts
from . import web_addresses

LINE_FEED = "\n"
ROBOTS_PATH = "/robots.txt"
HASH_PRIME = 16777619
HASH_MASK = (1 << 32) - 1
PLACE_START = 2166136261
CHECK_START = 3141592653
#-- The same scrambling recipe as the count table of the brain (FNV-1a), from
#-- two starting numbers: one gives the place of an address, the other its check number.


class Settings:

    def __init__(self):
        self.piece_length = 64
        self.page_limit = 20
        #-- The most pages it will ask for, in all.
        self.links_per_page = 20
        #-- The most new addresses it takes from one page.
        self.pause_seconds = 1.0
        #-- The least time between two requests.
        self.same_site_only = True
        #-- Follow only links that stay on the site of the page they are in.
        self.stay_under = ""
        #-- Follow only links whose path starts like this, for example "/wiki/". Empty = any path.
        self.list_size = 1024
        #-- The most addresses that wait for a visit at once. Also the most
        #-- addresses filed under each kind of thing that is not a page.
        self.seen_size = 65536
        #-- How many addresses it can remember having seen.
        self.time_limit = 0.0
        #-- Seconds after which no new page is asked for. 0 = no limit.


class Tally:
    #-- What happened, in numbers.

    def __init__(self):
        self.asked = 0
        #-- Pages asked for.
        self.read = 0
        #-- Pages whose words were taken.
        self.letters = 0
        self.refused = 0
        #-- Not asked for, because the site's rules say no.
        self.not_text = 0
        #-- Asked for, but what arrived was not a page.
        self.failed = 0
        self.left_out = 0
        #-- Links not kept because a list was full or their place was taken.


class Web_Source(sources.Source):

    def __init__(self):
        self.fetcher = None
        self.letters = None
        self.settings = Settings()
        self.work_file = ""
        self.waiting = []
        #-- The waiting list: a ring of list_size places.
        self.first = 0
        #-- The place of the address that has waited longest.
        self.count = 0
        #-- How many addresses are waiting.
        self.seen_checks = []
        self.seen_counts = []
        #-- The seen table: for each place, whose it is and how many mentions it has.
        self.started = 0.0
        self.finds = {}
        #-- kind -> addresses of that kind that were found.
        for kind in web_addresses.ALL_KINDS:
            self.finds[kind] = []
        self.rules_by_site = {}
        self.buffer = []
        #-- Symbols read from pages and not handed out yet.
        self.tally = Tally()
        self.has_asked = False
        self.last_request = 0.0

    def Next_Piece(self) -> tuple:
        length = self.settings.piece_length
        while len(self.buffer) < length and Can_Read_More(self):
            Read_Next_Page(self)
        if len(self.buffer) < length:
            return [], False
            #-- What is left is shorter than a piece: it is dropped.
        piece = self.buffer[:length]
        self.buffer = self.buffer[length:]
        return piece, True


def Open(
        source: Web_Source,
        fetcher: fetchers.Fetcher,
        letters: alphabets.Alphabet,
        settings: Settings,
        work_file: str
        ) -> None:
    #-- work_file: where each fetched page is put while it is being read.
    source.__init__()
    #-- Starts from blank: an empty list, nothing seen, nothing counted.
    source.fetcher = fetcher
    source.letters = letters
    source.settings = settings
    source.work_file = work_file
    source.waiting = [""] * settings.list_size
    source.seen_checks = [0] * settings.seen_size
    source.seen_counts = [0] * settings.seen_size
    source.started = time.monotonic()


def Scrambled(
        text: str,
        start: int
        ) -> int:
    result = start
    for char in text:
        result = result ^ ord(char)
        result = (result * HASH_PRIME) & HASH_MASK
    return result


def Place_Of(
        source: Web_Source,
        address: str
        ) -> int:
    return Scrambled(address, PLACE_START) % source.settings.seen_size


def Is_Known(
        source: Web_Source,
        address: str
        ) -> bool:
    place = Place_Of(source, address)
    if source.seen_counts[place] == 0:
        return False
    return source.seen_checks[place] == Scrambled(address, CHECK_START)


def Remember(
        source: Web_Source,
        address: str
        ) -> bool:
    #-- Gives a new address its place in the seen table. False if the place is
    #-- taken by another address that still has mentions: then the newcomer only
    #-- wears the owner down, and is not remembered this time.
    place = Place_Of(source, address)
    check = Scrambled(address, CHECK_START)
    if source.seen_counts[place] > 1:
        source.seen_counts[place] = source.seen_counts[place] - 1
        return False
    source.seen_checks[place] = check
    source.seen_counts[place] = 1
    return True


def Add_Mention(
        source: Web_Source,
        address: str
        ) -> None:
    place = Place_Of(source, address)
    source.seen_counts[place] = source.seen_counts[place] + 1


def Mentions_Of(
        source: Web_Source,
        address: str
        ) -> int:
    if not Is_Known(source, address):
        return 0
    return source.seen_counts[Place_Of(source, address)]


def Waiting_Count(
        source: Web_Source
        ) -> int:
    return source.count


def Put_In_Line(
        source: Web_Source,
        address: str
        ) -> None:
    place = (source.first + source.count) % source.settings.list_size
    source.waiting[place] = address
    source.count = source.count + 1


def Taken_From_Line(
        source: Web_Source
        ) -> str:
    address = source.waiting[source.first]
    source.first = (source.first + 1) % source.settings.list_size
    source.count = source.count - 1
    return address


def Has_Room(
        source: Web_Source,
        kind: str
        ) -> bool:
    #-- Is there room in the list where an address of this kind would go?
    if kind == web_addresses.PAGE:
        return source.count < source.settings.list_size
    return len(source.finds[kind]) < source.settings.list_size


def Add_Address(
        source: Web_Source,
        address: str
        ) -> None:
    #-- Lists one address to visit, as if a page had pointed to it.
    Note_Link(source, web_addresses.Resolved(address, address))


def Note_Link(
        source: Web_Source,
        target: str
        ) -> bool:
    #-- Files one full address. True if it was new and is now listed for a visit.
    if target == "":
        return False
    if Is_Known(source, target):
        Add_Mention(source, target)
        return False
    kind = web_addresses.Kind_By_Name(target)
    if not Has_Room(source, kind):
        source.tally.left_out = source.tally.left_out + 1
        return False
        #-- Nothing is remembered about it, so a later link can list it when there is room.
    if not Remember(source, target):
        source.tally.left_out = source.tally.left_out + 1
        return False
    if kind != web_addresses.PAGE:
        source.finds[kind].append(target)
        return False
        #-- First guard: by its name it is not a page, so it is never asked for.
    if not Is_Welcome(source, target):
        source.tally.refused = source.tally.refused + 1
        return False
        #-- The door: an address the rules of its site close never takes a seat in the list.
    Put_In_Line(source, target)
    return True


def Is_Welcome(
        source: Web_Source,
        address: str
        ) -> bool:
    #-- Do the rules of its site let our robot ask for this address?
    #-- The first time a site is met, this asks the site for its rules.
    rules = Rules_For(source, web_addresses.Site_Of(address))
    return robots.Allows(rules, web_addresses.Path_Of(address))


def Out_Of_Time(
        source: Web_Source
        ) -> bool:
    if source.settings.time_limit <= 0.0:
        return False
    return time.monotonic() - source.started > source.settings.time_limit


def Can_Read_More(
        source: Web_Source
        ) -> bool:
    if source.tally.asked >= source.settings.page_limit:
        return False
    if Out_Of_Time(source):
        return False
    return source.count > 0


def Wait_For_Turn(
        source: Web_Source,
        least_pause: float
        ) -> None:
    #-- Sleeps what is left of the pause since the last request.
    if source.has_asked:
        waited = time.monotonic() - source.last_request
        if waited < least_pause:
            time.sleep(least_pause - waited)
    source.has_asked = True
    source.last_request = time.monotonic()


def Fetched_Rules(
        source: Web_Source,
        site: str
        ) -> robots.Rule_Set:
    Wait_For_Turn(source, source.settings.pause_seconds)
    answer = source.fetcher.Fetch(site + ROBOTS_PATH, source.work_file)
    if answer.outcome == fetchers.MISSING:
        return robots.Allow_Everything()
    if answer.outcome != fetchers.FETCHED:
        return robots.Allow_Nothing()
    try:
        return robots.Parsed(texts.Whole_Text(source.work_file), fetchers.AGENT_NAME)
    except texts.Reading_Error:
        return robots.Allow_Nothing()


def Rules_For(
        source: Web_Source,
        site: str
        ) -> robots.Rule_Set:
    #-- The rules of a site are fetched once and remembered.
    if site not in source.rules_by_site:
        source.rules_by_site[site] = Fetched_Rules(source, site)
    return source.rules_by_site[site]


def Take_Words(
        source: Web_Source,
        content: pages.Page_Content
        ) -> None:
    words = pages.Text_Of(content)
    for char in words:
        source.buffer.append(alphabets.Symbol_Of(source.letters, char))
    source.tally.letters = source.tally.letters + len(words)


def Stays_Close(
        source: Web_Source,
        address: str,
        target: str
        ) -> bool:
    #-- May a link written in the page `address` be followed to `target`?
    if source.settings.same_site_only and not Is_Same_Site(address, target):
        return False
    return Is_Under(target, source.settings.stay_under)


def Is_Same_Site(
        address: str,
        target: str
        ) -> bool:
    return web_addresses.Host_Of(target) == web_addresses.Host_Of(address)


def Is_Under(
        target: str,
        folder: str
        ) -> bool:
    #-- Does the path of `target` start with `folder`? An empty folder holds every path.
    return web_addresses.Path_Of(target).startswith(folder)


def Would_Be_Listed(
        source: Web_Source,
        target: str
        ) -> bool:
    #-- Is it a page never seen before? Those are the ones that lengthen the list.
    if target == "" or Is_Known(source, target):
        return False
    return web_addresses.Kind_By_Name(target) == web_addresses.PAGE


def Take_Links(
        source: Web_Source,
        address: str,
        content: pages.Page_Content
        ) -> None:
    taken = 0
    for link in content.links:
        target = web_addresses.Resolved(address, link)
        if not Stays_Close(source, address, target):
            continue
        if taken >= source.settings.links_per_page and Would_Be_Listed(source, target):
            continue
            #-- This page has already given its share of new addresses.
        if Note_Link(source, target):
            taken = taken + 1


def Take_Media(
        source: Web_Source,
        address: str,
        content: pages.Page_Content
        ) -> None:
    #-- Pictures, videos and sounds shown in the page are filed too.
    for block in content.blocks:
        if block.kind in [pages.PICTURE, pages.VIDEO, pages.SOUND]:
            Note_Link(source, web_addresses.Resolved(address, block.text))


def Read_Page(
        source: Web_Source,
        address: str
        ) -> None:
    try:
        markup = texts.Whole_Text(source.work_file)
    except texts.Reading_Error:
        source.tally.failed = source.tally.failed + 1
        return
    content = pages.Read(markup)
    Take_Words(source, content)
    Take_Links(source, address, content)
    Take_Media(source, address, content)
    source.tally.read = source.tally.read + 1


def Read_Next_Page(
        source: Web_Source
        ) -> None:
    address = Taken_From_Line(source)
    rules = Rules_For(source, web_addresses.Site_Of(address))
    if not robots.Allows(rules, web_addresses.Path_Of(address)):
        source.tally.refused = source.tally.refused + 1
        return
    Wait_For_Turn(source, max(source.settings.pause_seconds, robots.Delay_Of(rules)))
    answer = source.fetcher.Fetch(address, source.work_file)
    source.tally.asked = source.tally.asked + 1
    if answer.outcome == fetchers.MOVED:
        target = web_addresses.Resolved(address, answer.moved_to)
        if Stays_Close(source, address, target):
            Note_Link(source, target)
        return
        #-- The page has moved: its new address is treated like any other link.
    if answer.outcome != fetchers.FETCHED:
        source.tally.failed = source.tally.failed + 1
        return
    kind = web_addresses.Kind_By_Label(answer.label)
    if kind != web_addresses.PAGE:
        if Has_Room(source, kind):
            source.finds[kind].append(address)
        source.tally.not_text = source.tally.not_text + 1
        return
        #-- Second guard: it looked like a page by name, but the server says otherwise.
    Read_Page(source, address)
