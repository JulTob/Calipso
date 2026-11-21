"""Mirror of Calipso.Web_Addresses: web addresses and what they point to.

An address is kept as plain text, for example

   http://example.org/folder/page.html?view=1

   site  : http://example.org          (who is asked)
   path  : /folder/page.html?view=1    (what is asked for)

Two questions are answered here without asking anybody:

   Resolved     : a link written inside a page, turned into a full address.
   Kind_By_Name : what an address probably holds, judged by its ending.

And one after the server has answered:

   Kind_By_Label : what it really holds, judged by the label the server sent.
"""

PAGE = "page"
#-- A web page: text for people, wrapped in tags.
WRITING = "writing"
#-- Any other file that is text inside: notes, program code, a drawing written as text.
PICTURE = "picture"
VIDEO = "video"
SOUND = "sound"
DOCUMENT = "document"
OTHER = "other"

ALL_KINDS = [PAGE, WRITING, PICTURE, VIDEO, SOUND, DOCUMENT, OTHER]

PAGE_ENDINGS = ["html", "htm", "xhtml", "php", "asp", "aspx", "jsp"]
WRITING_ENDINGS = [
    "txt", "md", "py", "css", "js", "json", "xml", "svg", "csv", "c", "h", "cpp",
    "java", "rs", "go", "adb", "ads", "sh", "tex", "rst", "yaml", "yml", "toml",
    ]
PICTURE_ENDINGS = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "ico", "tif", "tiff"]
VIDEO_ENDINGS = ["mp4", "webm", "mkv", "avi", "mov", "ogv", "m4v"]
SOUND_ENDINGS = ["mp3", "ogg", "oga", "wav", "flac", "m4a"]
DOCUMENT_ENDINGS = ["pdf", "doc", "docx", "odt", "epub", "ps", "xls", "xlsx", "ppt", "pptx"]
OTHER_ENDINGS = [
    "zip", "gz", "tar", "bz2", "7z", "rar", "exe", "dmg", "iso", "bin",
    "woff", "woff2", "ttf", "otf", "eot", "map", "wasm",
    ]

SITE_MARK = "://"


def Lowered(
        text: str
        ) -> str:
    #-- Only the letters A to Z are lowered, so that both languages do exactly the same.
    result = ""
    for char in text:
        if "A" <= char <= "Z":
            result = result + chr(ord(char) + 32)
        else:
            result = result + char
    return result


def Is_Plain(
        text: str
        ) -> bool:
    #-- Only visible characters of the basic set, and no spaces.
    for char in text:
        if ord(char) < 33 or ord(char) > 126:
            return False
    return True


def Site_Of(
        address: str
        ) -> str:
    #-- "http://example.org". Empty if the address has no site.
    mark = address.find(SITE_MARK)
    if mark < 0:
        return ""
    slash = address.find("/", mark + len(SITE_MARK))
    if slash < 0:
        return address
    return address[:slash]


def Host_Of(
        address: str
        ) -> str:
    #-- "example.org": the site without the "http://" in front.
    site = Site_Of(address)
    mark = site.find(SITE_MARK)
    if mark < 0:
        return ""
    return site[mark + len(SITE_MARK):]


def Path_Of(
        address: str
        ) -> str:
    #-- "/folder/page.html?view=1". A site alone has the path "/".
    site = Site_Of(address)
    if len(site) == len(address):
        return "/"
    return address[len(site):]


def Without_Question(
        path: str
        ) -> str:
    question = path.find("?")
    if question < 0:
        return path
    return path[:question]


def Ending_Of(
        address: str
        ) -> str:
    #-- What comes after the last dot of the last part of the path, lowered. "" if none.
    plain = Without_Question(Path_Of(address))
    slash = plain.rfind("/")
    last_part = plain[slash + 1:]
    dot = last_part.rfind(".")
    if dot < 0:
        return ""
    return Lowered(last_part[dot + 1:])


def Kind_By_Name(
        address: str
        ) -> str:
    ending = Ending_Of(address)
    if ending in WRITING_ENDINGS:
        return WRITING
    if ending in PICTURE_ENDINGS:
        return PICTURE
    if ending in VIDEO_ENDINGS:
        return VIDEO
    if ending in SOUND_ENDINGS:
        return SOUND
    if ending in DOCUMENT_ENDINGS:
        return DOCUMENT
    if ending in OTHER_ENDINGS:
        return OTHER
    return PAGE
    #-- No ending, a page ending or an ending never heard of: it may be a page.
    #-- The label of the server decides for good, after asking.


def Main_Label(
        label: str
        ) -> str:
    #-- "Text/HTML; charset=utf-8" -> "text/html"
    semicolon = label.find(";")
    if semicolon >= 0:
        label = label[:semicolon]
    return Lowered(label.strip(" "))


def Kind_By_Label(
        label: str
        ) -> str:
    main = Main_Label(label)
    if main == "text/html" or main == "application/xhtml+xml":
        return PAGE
    if main.startswith("text/"):
        return WRITING
    if main in ["application/json", "application/xml", "application/javascript", "image/svg+xml"]:
        return WRITING
    if main.startswith("image/"):
        return PICTURE
    if main.startswith("video/"):
        return VIDEO
    if main.startswith("audio/"):
        return SOUND
    if main in ["application/pdf", "application/msword", "application/epub+zip", "application/postscript"]:
        return DOCUMENT
    return OTHER


def Sense_Of(
        address: str,
        kind: str
        ) -> str:
    #-- The name of the brain that should read this: one per kind, and for
    #-- writing one per ending ("py", "svg", "css"...), because each is its own language.
    if kind == WRITING and Ending_Of(address) != "":
        return Ending_Of(address)
    return kind


def Tidy_Path(
        path: str
        ) -> str:
    #-- Works out the "." (stay here) and ".." (go up one folder) parts of a path.
    plain = Without_Question(path)
    question = path[len(plain):]
    kept = []
    ends_in_folder = True
    position = 1
    #-- Position 0 is the leading slash.
    while position < len(plain):
        slash = plain.find("/", position)
        is_last = slash < 0
        if is_last:
            end = len(plain)
        else:
            end = slash
        part = plain[position:end]
        if part == "" or part == ".":
            ends_in_folder = True
        elif part == "..":
            if len(kept) > 0:
                kept.pop()
            ends_in_folder = True
        else:
            kept.append(part)
            ends_in_folder = not is_last
        position = end + 1
    result = ""
    for part in kept:
        result = result + "/" + part
    if ends_in_folder or len(kept) == 0:
        result = result + "/"
    return result + question


def Tidied(
        address: str
        ) -> str:
    return Site_Of(address) + Tidy_Path(Path_Of(address))


def Has_Scheme(
        link: str
        ) -> bool:
    #-- Does it start like "mailto:" or "javascript:"? Letters, then a colon, before any slash.
    for char in link:
        if char == ":":
            return True
        if not ("a" <= char <= "z" or "A" <= char <= "Z"):
            return False
    return False


def Folder_Of(
        path: str
        ) -> str:
    #-- "/folder/page.html?view=1" -> "/folder/"
    plain = Without_Question(path)
    slash = plain.rfind("/")
    return plain[:slash + 1]


def Resolved(
        base: str,
        link: str
        ) -> str:
    #-- The full address a link points to, seen from the page (base) it is written in.
    #-- "" when the link cannot be followed (mail, scripts, strange characters).
    hash_mark = link.find("#")
    if hash_mark >= 0:
        link = link[:hash_mark]
        #-- What follows # is a place inside the same page, not another page.
    link = link.strip(" ")
    if link == "":
        return ""
    if not Is_Plain(link):
        return ""
    if link.startswith("http://") or link.startswith("https://"):
        return Tidied(link)
    site = Site_Of(base)
    if link.startswith("//"):
        return Tidied(base[:base.find(SITE_MARK) + 1] + link)
    if Has_Scheme(link):
        return ""
    if link.startswith("/"):
        return site + Tidy_Path(link)
    if link.startswith("?"):
        return site + Without_Question(Path_Of(base)) + link
    return site + Tidy_Path(Folder_Of(Path_Of(base)) + link)
