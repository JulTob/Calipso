"""Mirror of Calipso.Pages: what is inside a web page.

A page arrives as "markup": text for people mixed with tags for the browser,
like <p>, <a href="...">, <img src="...">. Reading a page means taking it
apart into:

   blocks : the page as a list of pieces, in order. A piece is a paragraph
            of words, or the place where a picture, video or sound goes.
   links  : every address the page points to, as it was written.

The reader is simple on purpose. It does not run scripts and it does not
understand layout: it sees a page the way a very old phone browser did.
"""

WORDS = "words"
PICTURE = "picture"
VIDEO = "video"
SOUND = "sound"
DRAWING = "drawing"
#-- A drawing written inside the page itself (an <svg> tag).

BLOCK_TAGS = [
    "p", "br", "div", "li", "ul", "ol", "h1", "h2", "h3", "h4", "h5", "h6",
    "tr", "table", "section", "article", "header", "footer", "nav", "aside",
    "blockquote", "pre", "title", "hr", "dt", "dd", "form", "body", "head",
    ]
#-- Tags that start a new paragraph.

SKIPPED_TAGS = ["script", "style"]
#-- Tags whose inside is not text for people.

LINE_FEED = "\n"
NO_BREAK_SPACE = chr(160)
LARGEST_LETTER = 1114111
ENTITY_REACH = 10
#-- An entity like &amp; is never longer than this.


class Block:

    def __init__(
            self,
            kind: str,
            words: str
            ):
        self.kind = kind
        self.text = words
        #-- For a paragraph, its words. For a picture, video or sound, its address as written.


class Page_Content:

    def __init__(self):
        self.blocks = []
        self.links = []


class Scan:
    #-- The state of one reading: where we are, and what has been gathered.

    def __init__(
            self,
            markup: str
            ):
        self.markup = markup
        self.position = 0
        self.paragraph = ""
        self.content = Page_Content()


def Lowered_Letter(
        char: str
        ) -> str:
    if "A" <= char <= "Z":
        return chr(ord(char) + 32)
    return char


def Is_Space(
        char: str
        ) -> bool:
    return char in [" ", "\t", "\n", "\r", "\f", NO_BREAK_SPACE]


def Matches_At(
        text: str,
        position: int,
        word: str
        ) -> bool:
    #-- Is `word` written at this position? Capital letters count as small ones.
    if position + len(word) > len(text):
        return False
    for index in range(len(word)):
        if Lowered_Letter(text[position + index]) != word[index]:
            return False
    return True


def Found_At(
        text: str,
        word: str,
        start: int
        ) -> int:
    #-- The first position, from `start` on, where `word` is written. -1 if nowhere.
    for position in range(start, len(text) - len(word) + 1):
        if Matches_At(text, position, word):
            return position
    return -1


def Close_Paragraph(
        scan: Scan
        ) -> None:
    words = scan.paragraph.strip(" ")
    if words != "":
        scan.content.blocks.append(Block(WORDS, words))
    scan.paragraph = ""


def Add_Letter(
        scan: Scan,
        char: str
        ) -> None:
    #-- Any run of spaces and line breaks counts as one space.
    if not Is_Space(char):
        scan.paragraph = scan.paragraph + char
        return
    if scan.paragraph == "":
        return
    if scan.paragraph.endswith(" "):
        return
    scan.paragraph = scan.paragraph + " "


def Number_Letter(
        digits: str,
        base: int
        ) -> str:
    #-- The letter with this number, or "" if it is not the number of a letter.
    if digits == "":
        return ""
    value = 0
    for digit in digits:
        place = "0123456789abcdef".find(Lowered_Letter(digit))
        if place < 0 or place >= base:
            return ""
        value = value * base + place
        if value > LARGEST_LETTER:
            return ""
    if value == 0:
        return ""
    if 55296 <= value <= 57343:
        return ""
        #-- These numbers are not letters (they are halves of a pair).
    return chr(value)


def Entity_Letter(
        name: str
        ) -> str:
    #-- "amp" -> "&". "" if the name is not known.
    if name == "amp":
        return "&"
    if name == "lt":
        return "<"
    if name == "gt":
        return ">"
    if name == "quot":
        return '"'
    if name == "apos":
        return "'"
    if name == "nbsp":
        return " "
    if name.startswith("#x") or name.startswith("#X"):
        return Number_Letter(name[2:], 16)
    if name.startswith("#"):
        return Number_Letter(name[1:], 10)
    return ""


def Read_Entity(
        scan: Scan
        ) -> None:
    #-- At an "&": a letter written by name, like &amp; or &#233;
    limit = min(len(scan.markup), scan.position + ENTITY_REACH)
    end = scan.markup.find(";", scan.position, limit)
    letter = ""
    if end >= 0:
        letter = Entity_Letter(scan.markup[scan.position + 1:end])
    if letter == "":
        Add_Letter(scan, "&")
        scan.position = scan.position + 1
        return
    Add_Letter(scan, letter)
    scan.position = end + 1


def Tag_Name(
        inside: str
        ) -> str:
    #-- "/DIV class=x" -> "div"
    name = ""
    start = 0
    if inside.startswith("/"):
        start = 1
    for index in range(start, len(inside)):
        char = Lowered_Letter(inside[index])
        if not ("a" <= char <= "z" or "0" <= char <= "9"):
            break
        name = name + char
    return name


def Value_From(
        inside: str,
        start: int
        ) -> str:
    #-- The value that starts at this position: up to the matching quote, or up to the next space.
    if start >= len(inside):
        return ""
    quote = inside[start]
    if quote == '"' or quote == "'":
        end = inside.find(quote, start + 1)
        if end < 0:
            end = len(inside)
        return inside[start + 1:end]
    end = start
    while end < len(inside) and not Is_Space(inside[end]):
        end = end + 1
    return inside[start:end]


def Attribute(
        inside: str,
        name: str
        ) -> str:
    #-- The value of name="value" inside a tag. "" if it is not there.
    position = Found_At(inside, name, 1)
    while position >= 0:
        after = position + len(name)
        while after < len(inside) and Is_Space(inside[after]):
            after = after + 1
        starts_word = Is_Space(inside[position - 1])
        if starts_word and after < len(inside) and inside[after] == "=":
            after = after + 1
            while after < len(inside) and Is_Space(inside[after]):
                after = after + 1
            return Value_From(inside, after).replace("&amp;", "&")
        position = Found_At(inside, name, position + 1)
    return ""


def Skip_Past_Closing(
        scan: Scan,
        name: str
        ) -> None:
    #-- Jumps to just after </name>. If it never closes, to the end of the page.
    closing = Found_At(scan.markup, "</" + name, scan.position)
    if closing < 0:
        scan.position = len(scan.markup)
        return
    end = scan.markup.find(">", closing)
    if end < 0:
        scan.position = len(scan.markup)
        return
    scan.position = end + 1


def Add_Media(
        scan: Scan,
        kind: str,
        address: str
        ) -> None:
    Close_Paragraph(scan)
    scan.content.blocks.append(Block(kind, address))


def Read_Opening_Tag(
        scan: Scan,
        name: str,
        inside: str
        ) -> None:
    if name in SKIPPED_TAGS:
        Skip_Past_Closing(scan, name)
    elif name == "svg":
        Add_Media(scan, DRAWING, "")
        Skip_Past_Closing(scan, name)
    elif name == "a":
        link = Attribute(inside, "href")
        if link != "":
            scan.content.links.append(link)
    elif name == "img":
        Add_Media(scan, PICTURE, Attribute(inside, "src"))
    elif name == "video":
        Add_Media(scan, VIDEO, Attribute(inside, "src"))
    elif name == "audio":
        Add_Media(scan, SOUND, Attribute(inside, "src"))


def Read_Tag(
        scan: Scan
        ) -> None:
    #-- At a "<": a tag, or a comment.
    if scan.markup.startswith("<!--", scan.position):
        end = scan.markup.find("-->", scan.position)
        if end < 0:
            scan.position = len(scan.markup)
        else:
            scan.position = end + 3
        return
    close = scan.markup.find(">", scan.position)
    if close < 0:
        scan.position = len(scan.markup)
        return
        #-- A tag that never closes: the rest of the page is dropped.
    inside = scan.markup[scan.position + 1:close]
    name = Tag_Name(inside)
    scan.position = close + 1
    if name in BLOCK_TAGS:
        Close_Paragraph(scan)
    if not inside.startswith("/"):
        Read_Opening_Tag(scan, name, inside)


def Read(
        markup: str
        ) -> Page_Content:
    scan = Scan(markup)
    while scan.position < len(markup):
        char = markup[scan.position]
        if char == "<":
            Read_Tag(scan)
        elif char == "&":
            Read_Entity(scan)
        else:
            Add_Letter(scan, char)
            scan.position = scan.position + 1
    Close_Paragraph(scan)
    return scan.content


def Text_Of(
        content: Page_Content
        ) -> str:
    #-- The words of the page: one paragraph per line.
    text = ""
    for block in content.blocks:
        if block.kind == WORDS:
            text = text + block.text + LINE_FEED
    return text
