--  A source that reads pages from the web.
--
--  It keeps a list of addresses to visit. For each one, in order:
--
--     1. ask the site's rules (robots.txt) whether the address may be fetched
--     2. wait, if the last request was too recent
--     3. fetch it, and check what really arrived
--     4. take its words, to hand out in pieces
--     5. take its links: new ones go to the end of the list
--
--  The next page is fetched only when the words of this one have been handed
--  out. So the brain studies a whole page before the next request is made:
--  studying IS the pause between requests.
--
--  Nothing is fetched twice. An address that is linked again is not listed
--  again; it only gets one more "mention", a count of how many links point to it.
--
--  What is not a page is not thrown away: its address is filed under its kind
--  (writing, picture, video, sound...), ready for the brain of that kind.

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Holders;
with Ada.Containers.Indefinite_Vectors;
with Ada.Real_Time;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

with Calipso.Alphabets;
with Calipso.Fetchers;
with Calipso.Robots;
with Calipso.Sources;
with Calipso.Texts;
with Calipso.Web_Addresses;

package Calipso.Web_Sources is

    type Settings is record
        Piece_Length   : Positive := 64;
        Page_Limit     : Natural := 20;
        --# The most pages it will ask for, in all.
        Links_Per_Page : Natural := 20;
        --# The most new addresses it takes from one page.
        Pause          : Duration := 1.0;
        --# The least time between two requests.
        Same_Site_Only : Boolean := True;
        --# Follow only links that stay on the site of the page they are in.
        end record;

    type Tally is record
        Asked    : Natural := 0;
        --# Pages asked for.
        Read     : Natural := 0;
        --# Pages whose words were taken.
        Letters  : Natural := 0;
        Refused  : Natural := 0;
        --# Not asked for, because the site's rules say no.
        Not_Text : Natural := 0;
        --# Asked for, but what arrived was not a page.
        Failed   : Natural := 0;
        end record;
    --# What happened, in numbers.

    type Web_Source is limited new Sources.Source with private;

    procedure Open (
            Self      : in out Web_Source;
            Using     : in     Fetchers.Fetcher'Class;
            Letters   : in     Alphabets.Alphabet;
            Options   : in     Settings;
            Work_File : in     String
            );
    --# Work_File: where each fetched page is put while it is being read.

    procedure Add_Address (
            Self    : in out Web_Source;
            Address : in     String
            );
    --# Lists one address to visit, as if a page had pointed to it.

    function Mentions_Of (
            Self    : in Web_Source;
            Address : in String
            ) return Natural;
    --# How many times this address has been pointed to. 0 = never seen.

    function Tally_Of (
            Self : in Web_Source
            ) return Tally;

    function Find_Count (
            Self : in Web_Source;
            Kind : in Web_Addresses.Content_Kind
            ) return Natural;
    --# How many addresses of this kind were found and filed.

    function Find (
            Self  : in Web_Source;
            Kind  : in Web_Addresses.Content_Kind;
            Index : in Positive
            ) return String
        with Pre => Index <= Find_Count (Self, Kind);

    overriding procedure Next_Piece (
            Self  : in out Web_Source;
            Piece :    out Texts.Symbol_Text;
            Found :    out Boolean
            );
    --# What is left at the end, if it is shorter than a piece, is dropped.

private

    package Fetcher_Holders is new Ada.Containers.Indefinite_Holders (
            Element_Type => Fetchers.Fetcher'Class,
            "="          => Fetchers.Same
            );

    package Address_Lists is new Ada.Containers.Indefinite_Vectors (
            Index_Type   => Positive,
            Element_Type => String
            );

    package Mention_Maps is new Ada.Containers.Indefinite_Hashed_Maps (
            Key_Type        => String,
            Element_Type    => Natural,
            Hash            => Ada.Strings.Hash,
            Equivalent_Keys => "="
            );

    package Rule_Maps is new Ada.Containers.Indefinite_Hashed_Maps (
            Key_Type        => String,
            Element_Type    => Robots.Rule_Set,
            Hash            => Ada.Strings.Hash,
            Equivalent_Keys => "=",
            "="             => Robots."="
            );

    type Find_Lists is array (Web_Addresses.Content_Kind) of Address_Lists.Vector;

    type Web_Source is limited new Sources.Source with record
        Fetcher       : Fetcher_Holders.Holder;
        Letters       : Alphabets.Alphabet;
        Options       : Settings;
        Work_File     : Ada.Strings.Unbounded.Unbounded_String;
        Queue         : Address_Lists.Vector;
        --# Every address listed for a visit, in order.
        Next_In_Queue : Positive := 1;
        Mentions      : Mention_Maps.Map;
        --# address -> how many times it has been pointed to. Also: "have I seen it?"
        Finds         : Find_Lists;
        --# kind -> addresses of that kind that were found.
        Rules_By_Site : Rule_Maps.Map;
        Buffer        : Texts.Symbol_Text;
        --# Symbols read from pages and not handed out yet.
        Counts        : Tally;
        Has_Asked     : Boolean := False;
        Last_Request  : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
        end record;

    end Calipso.Web_Sources;
