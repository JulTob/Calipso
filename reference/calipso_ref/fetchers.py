"""Mirror of Calipso.Fetchers: the contract for fetching one address.

A fetcher is asked for one address. It puts what it got into a file and
says how it went. How the asking is done is its own business:

   Curl_Fetcher   : asks the real web, by running the program "curl".
   Folder_Fetcher : pretends a folder of this computer is a web site. For tests.
"""

import os
import shutil
import subprocess

from . import web_addresses

FETCHED = "fetched"
#-- The file holds what was asked for.
MISSING = "missing"
#-- The site answered: there is nothing at that address.
MOVED = "moved"
#-- The site answered: it is at another address now.
FAILED = "failed"
#-- No answer, an error, or more than the size allowed.

AGENT_NAME = "Calipso"
AGENT_LINE = "Calipso/0.2 (text-learning experiment; +https://github.com/JulTob/calipso)"
#-- How the robot introduces itself to every site it asks.


class Answer:

    def __init__(
            self,
            outcome: str,
            label: str = "",
            moved_to: str = ""
            ):
        self.outcome = outcome
        self.label = label
        #-- What the server says the file is, for example "text/html; charset=utf-8".
        self.moved_to = moved_to


class Fetcher:

    def Fetch(
            self,
            address: str,
            into_file: str
            ) -> Answer:
        raise NotImplementedError


class Curl_Fetcher(Fetcher):

    def __init__(self):
        self.most_bytes = 2000000
        self.most_seconds = 20

    def Fetch(
            self,
            address: str,
            into_file: str
            ) -> Answer:
        command = [
            "curl",
            "--silent",
            "--proto", "=http,https",
            "--max-time", str(self.most_seconds),
            "--max-filesize", str(self.most_bytes),
            "--user-agent", AGENT_LINE,
            "--output", into_file,
            "--write-out", "%{http_code}\\n%{content_type}\\n%{redirect_url}\\n",
            address,
            ]
        #-- Redirections are NOT followed here: a new address goes back to whoever
        #-- asked, so that it passes the same checks as any other link.
        try:
            run = subprocess.run(command, capture_output=True)
        except OSError:
            return Answer(FAILED)
        if run.returncode != 0:
            return Answer(FAILED)
        lines = run.stdout.decode("utf-8", errors="replace").split("\n")
        if len(lines) < 3:
            return Answer(FAILED)
        return Answer_From_Report(lines[0], lines[1], lines[2], into_file, self.most_bytes)


def Answer_From_Report(
        code: str,
        label: str,
        moved_to: str,
        into_file: str,
        most_bytes: int
        ) -> Answer:
    #-- Reads the three lines curl reports: the answer number, the label and the new address.
    if code == "200":
        if not os.path.exists(into_file):
            return Answer(FAILED)
        if os.path.getsize(into_file) > most_bytes:
            return Answer(FAILED)
        return Answer(FETCHED, label)
    if code == "404" or code == "410":
        return Answer(MISSING)
    if code.startswith("3") and moved_to != "":
        return Answer(MOVED, "", moved_to)
    return Answer(FAILED)


LABELS_BY_ENDING = {
    "html": "text/html",
    "htm": "text/html",
    "txt": "text/plain",
    "css": "text/css",
    "py": "text/x-python",
    "svg": "image/svg+xml",
    "png": "image/png",
    "jpg": "image/jpeg",
    "mp3": "audio/mpeg",
    "mp4": "video/mp4",
    "pdf": "application/pdf",
    }
UNKNOWN_LABEL = "application/octet-stream"


class Folder_Fetcher(Fetcher):

    def __init__(
            self,
            site: str,
            folder: str
            ):
        self.site = site
        #-- The made-up site, for example "http://test.site".
        self.folder = folder
        #-- The folder that plays the part of that site.

    def Fetch(
            self,
            address: str,
            into_file: str
            ) -> Answer:
        if web_addresses.Site_Of(address) != self.site:
            return Answer(FAILED)
        path = web_addresses.Without_Question(web_addresses.Path_Of(address))
        file_name = self.folder + path
        if not os.path.isfile(file_name):
            return Answer(MISSING)
        shutil.copyfile(file_name, into_file)
        ending = web_addresses.Ending_Of(address)
        return Answer(FETCHED, LABELS_BY_ENDING.get(ending, UNKNOWN_LABEL))
