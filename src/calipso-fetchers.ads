--  The contract for fetching one address.
--
--  A fetcher is asked for one address. It puts what it got into a file and
--  says how it went. How the asking is done is its own business:
--
--     Calipso.Curl_Fetchers   : asks the real web, by running the program "curl".
--     Calipso.Folder_Fetchers : pretends a folder of this computer is a web site. For tests.

with Ada.Strings.Unbounded;

package Calipso.Fetchers is

    Agent_Name : constant String := "Calipso";
    Agent_Line : constant String :=
        "Calipso/0.2 (text-learning experiment; +https://github.com/JulTob/calipso)";
    --# How the robot introduces itself to every site it asks.

    type Outcome_Kind is (Fetched, Missing, Moved, Failed);
    --# Fetched : the file holds what was asked for.
    --# Missing : the site answered: there is nothing at that address.
    --# Moved   : the site answered: it is at another address now.
    --# Failed  : no answer, an error, or more than the size allowed.

    type Answer is record
        Outcome  : Outcome_Kind := Failed;
        Label    : Ada.Strings.Unbounded.Unbounded_String;
        --# What the server says the file is, for example "text/html; charset=utf-8".
        Moved_To : Ada.Strings.Unbounded.Unbounded_String;
        end record;

    type Fetcher is interface;

    function Fetch (
            Self      : in Fetcher;
            Address   : in String;
            Into_File : in String
            ) return Answer is abstract;
    --# A function for convenience, although it writes a file: the web, like a
    --# file, is outside state by nature.

    function Same (
            Left  : in Fetcher'Class;
            Right : in Fetcher'Class
            ) return Boolean;
    --# Needed by whoever keeps a fetcher of any kind.

    end Calipso.Fetchers;
