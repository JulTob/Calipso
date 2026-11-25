"""Mirror of Calipso.Robots: the rules a site sets for robots.

A site may publish a file called robots.txt at its top. It says which
paths robots may fetch. It looks like this:

   User-agent: *            <- who the next rules are for (* = every robot)
   Disallow: /private/      <- paths that start like this: do not fetch
   Allow: /private/open/    <- except these
   Crawl-delay: 5           <- wait this many seconds between requests

How the rules are read here:

   - The rules that name us win over the rules for everybody (*).
   - For a path, the LONGEST rule that fits it decides. On a tie, Allow wins.
   - No rule fits: allowed. No robots.txt at all: everything is allowed.
   - In a rule, * stands for any run of letters and a final $ means "ends here".

The rules say what may be FETCHED. They say nothing about what the text may
be used for: that stays a decision of the person running the program.
"""


class Rule:

    def __init__(
            self,
            allowed: bool,
            pattern: str
            ):
        self.allowed = allowed
        self.pattern = pattern


class Rule_Set:

    def __init__(self):
        self.rules = []
        self.delay = 0.0
        #-- Seconds the site asks robots to wait between two requests. 0 = it does not say.


def Allow_Everything() -> Rule_Set:
    return Rule_Set()


def Allow_Nothing() -> Rule_Set:
    #-- For when the rules could not be read: when in doubt, stay out.
    result = Rule_Set()
    result.rules.append(Rule(False, "/"))
    return result


def Lowered(
        text: str
        ) -> str:
    result = ""
    for char in text:
        if "A" <= char <= "Z":
            result = result + chr(ord(char) + 32)
        else:
            result = result + char
    return result


def Trimmed(
        text: str
        ) -> str:
    return text.strip(" \t\r")


def Seconds_Of(
        value: str
        ) -> float:
    #-- A whole number of seconds. Anything else counts as 0.
    if value == "":
        return 0.0
    seconds = 0
    for digit in value:
        if not ("0" <= digit <= "9"):
            return 0.0
        seconds = seconds * 10 + (ord(digit) - ord("0"))
        if seconds > 3600:
            return 3600.0
    return float(seconds)


class Reading:
    #-- The state while reading the file line by line.

    def __init__(
            self,
            agent_name: str
            ):
        self.agent_name = Lowered(agent_name)
        self.ours = Rule_Set()
        #-- The rules of the groups that name us.
        self.everyones = Rule_Set()
        #-- The rules of the groups for every robot.
        self.named_us = False
        self.listing_agents = False
        #-- True while reading the User-agent lines that open a group.
        self.group_is_ours = False
        self.group_is_everyones = False


def Read_Agent(
        reading: Reading,
        value: str
        ) -> None:
    if not reading.listing_agents:
        reading.group_is_ours = False
        reading.group_is_everyones = False
        #-- A User-agent line after rules starts a new group.
    reading.listing_agents = True
    name = Lowered(value)
    if name == "*":
        reading.group_is_everyones = True
    elif name != "" and reading.agent_name.find(name) >= 0:
        reading.group_is_ours = True
        reading.named_us = True


def Read_Rule(
        reading: Reading,
        allowed: bool,
        value: str
        ) -> None:
    reading.listing_agents = False
    if value == "":
        return
        #-- An empty rule forbids nothing and allows nothing new.
    if reading.group_is_ours:
        reading.ours.rules.append(Rule(allowed, value))
    if reading.group_is_everyones:
        reading.everyones.rules.append(Rule(allowed, value))


def Read_Delay(
        reading: Reading,
        value: str
        ) -> None:
    reading.listing_agents = False
    if reading.group_is_ours:
        reading.ours.delay = Seconds_Of(value)
    if reading.group_is_everyones:
        reading.everyones.delay = Seconds_Of(value)


def Read_Line(
        reading: Reading,
        line: str
        ) -> None:
    hash_mark = line.find("#")
    if hash_mark >= 0:
        line = line[:hash_mark]
        #-- What follows # is a comment.
    colon = line.find(":")
    if colon < 0:
        return
    field = Lowered(Trimmed(line[:colon]))
    value = Trimmed(line[colon + 1:])
    if field == "user-agent":
        Read_Agent(reading, value)
    elif field == "allow":
        Read_Rule(reading, True, value)
    elif field == "disallow":
        Read_Rule(reading, False, value)
    elif field == "crawl-delay":
        Read_Delay(reading, value)


def Parsed(
        text: str,
        agent_name: str
        ) -> Rule_Set:
    #-- The rules that apply to the robot called `agent_name`.
    reading = Reading(agent_name)
    start = 0
    while start <= len(text):
        end = text.find("\n", start)
        if end < 0:
            end = len(text)
        Read_Line(reading, text[start:end])
        start = end + 1
    if reading.named_us:
        return reading.ours
    return reading.everyones


def Fits(
        pattern: str,
        path: str
        ) -> bool:
    #-- Does the path start the way the pattern says?
    must_end = pattern.endswith("$")
    if must_end:
        pattern = pattern[:-1]
    position = 0
    #-- How much of the path has been matched so far.
    start = 0
    #-- Where the next piece of the pattern begins.
    is_first = True
    while True:
        star = pattern.find("*", start)
        is_last = star < 0
        if is_last:
            piece = pattern[start:]
        else:
            piece = pattern[start:star]
        if is_first:
            if not path.startswith(piece):
                return False
            position = len(piece)
        elif is_last and must_end:
            if len(path) - len(piece) < position:
                return False
            return path.endswith(piece)
        else:
            found = path.find(piece, position)
            if found < 0:
                return False
            position = found + len(piece)
        if is_last:
            break
        is_first = False
        start = star + 1
    if must_end:
        return position == len(path)
    return True


def Allows(
        rules: Rule_Set,
        path: str
        ) -> bool:
    best_length = -1
    best_allowed = True
    for rule in rules.rules:
        if Fits(rule.pattern, path):
            longer = len(rule.pattern) > best_length
            same_but_kinder = len(rule.pattern) == best_length and rule.allowed
            if longer or same_but_kinder:
                best_length = len(rule.pattern)
                best_allowed = rule.allowed
    return best_allowed


def Delay_Of(
        rules: Rule_Set
        ) -> float:
    return rules.delay
