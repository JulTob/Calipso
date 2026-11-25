--  A fetcher that pretends a folder of this computer is a web site.
--
--  It lets the scraper be tested with no network at all: the address
--  http://test.site/sub/c.html is answered with the file FOLDER/sub/c.html.

with Ada.Strings.Unbounded;

with Calipso.Fetchers;

package Calipso.Folder_Fetchers is

    type Folder_Fetcher is new Fetchers.Fetcher with private;

    procedure Prepare (
            Self   : in out Folder_Fetcher;
            Site   : in     String;
            Folder : in     String
            );
    --# Site   : the made-up site, for example "http://test.site".
    --# Folder : the folder that plays the part of that site.

    overriding function Fetch (
            Self      : in Folder_Fetcher;
            Address   : in String;
            Into_File : in String
            ) return Fetchers.Answer;

private

    type Folder_Fetcher is new Fetchers.Fetcher with record
        Site   : Ada.Strings.Unbounded.Unbounded_String;
        Folder : Ada.Strings.Unbounded.Unbounded_String;
        end record;

    end Calipso.Folder_Fetchers;
