"""Download Wikipedia articles as plain text, to use them as a corpus.

Usage:
    python3 tools/download_wikipedia.py LANGUAGE COUNT OUTPUT

Example (500 random articles in Spanish, a few megabytes):
    python3 tools/download_wikipedia.py es 500 corpus/wikipedia_es.txt

Each article is saved with one paragraph per line. It uses Wikipedia's public
interface (api.php), which already returns clean text, with no markup.

WARNING: this tool is a temporary scaffold in Python and could NOT be tested
in the environment where it was written (it had no access to Wikipedia).
If it fails, the most likely place to fix is `Article_Text`.
"""

import json
import sys
import time
import urllib.parse
import urllib.request

USER_AGENT = "Calipso-corpus/0.1 (educational project; github.com/JulTob/Calipso)"
#-- Wikipedia asks every program to identify itself.
BATCH = 10
PAUSE_SECONDS = 0.5
#-- Pause between requests, out of courtesy to the server.
SHORTEST_ARTICLE = 500
#-- Articles with fewer letters than this are dropped (they are usually stubs).


def Api_Address(
        language: str
        ) -> str:
    return "https://" + language + ".wikipedia.org/w/api.php"


def Asked(
        language: str,
        parameters: dict
        ) -> dict:
    #-- Sends one request to the interface and returns the answer, already parsed.
    query = urllib.parse.urlencode(parameters)
    request = urllib.request.Request(Api_Address(language) + "?" + query)
    request.add_header("User-Agent", USER_AGENT)
    with urllib.request.urlopen(request, timeout=30) as response:
        raw = response.read()
    return json.loads(raw.decode("utf-8"))


def Random_Titles(
        language: str,
        count: int
        ) -> list:
    answer = Asked(language, {
        "action": "query",
        "format": "json",
        "list": "random",
        "rnnamespace": "0",
        "rnlimit": str(count),
        })
    titles = []
    for entry in answer["query"]["random"]:
        titles.append(entry["title"])
    return titles


def Article_Text(
        language: str,
        title: str
        ) -> str:
    answer = Asked(language, {
        "action": "query",
        "format": "json",
        "prop": "extracts",
        "explaintext": "1",
        "exsectionformat": "plain",
        "redirects": "1",
        "titles": title,
        })
    pages = answer["query"]["pages"]
    for page in pages.values():
        return page.get("extract", "")
    return ""


def Cleaned(
        text: str
        ) -> str:
    #-- One paragraph per line, no empty lines.
    lines = []
    for line in text.split("\n"):
        stripped = line.strip()
        if len(stripped) > 0:
            lines.append(stripped)
    return "\n".join(lines)


def Main() -> None:
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    language = sys.argv[1]
    wanted = int(sys.argv[2])
    output_name = sys.argv[3]
    saved = 0
    letters = 0
    with open(output_name, "w", encoding="utf-8") as output:
        while saved < wanted:
            for title in Random_Titles(language, BATCH):
                if saved >= wanted:
                    break
                text = Cleaned(Article_Text(language, title))
                time.sleep(PAUSE_SECONDS)
                if len(text) < SHORTEST_ARTICLE:
                    continue
                output.write(text + "\n")
                saved = saved + 1
                letters = letters + len(text)
                print(f"{saved}/{wanted}  {title}  ({letters} letters so far)")
    print(f"Saved to {output_name}")


if __name__ == "__main__":
    try:
        Main()
    except OSError as problem:
        print(f"Network or file error: {problem}")
        sys.exit(2)
