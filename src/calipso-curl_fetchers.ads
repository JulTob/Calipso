--  A fetcher that asks the real web, by running the program "curl".
--
--  curl is a small, well-known program that fetches one address. It is already
--  installed on macOS and on most Linux systems. It is used here because it
--  speaks the secure protocol (https) that almost every site requires.
--
--  Redirections are NOT followed here: when a site says "it has moved", the new
--  address goes back to whoever asked, so that it passes the same checks as any
--  other link (same site? allowed by the site's rules? already seen?).

with Calipso.Fetchers;

package Calipso.Curl_Fetchers is

    type Curl_Fetcher is new Fetchers.Fetcher with record
        Most_Bytes   : Positive := 2_000_000;
        --# A file bigger than this is given up.
        Most_Seconds : Positive := 20;
        --# An answer slower than this is given up.
        end record;

    overriding function Fetch (
            Self      : in Curl_Fetcher;
            Address   : in String;
            Into_File : in String
            ) return Fetchers.Answer;

    function Answer_From_Report (
            Code       : in String;
            Label      : in String;
            Moved_To   : in String;
            Into_File  : in String;
            Most_Bytes : in Positive
            ) return Fetchers.Answer;
    --# Reads the three things curl reports: the answer number of the server
    --# (200 = here it is, 404 = not found, 3xx = moved), the label, the new address.

    end Calipso.Curl_Fetchers;
