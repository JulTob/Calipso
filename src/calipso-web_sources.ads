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
--  Everything has a fixed size, chosen in the settings, so that a long walk
--  never needs more memory than a short one:
--
--     the waiting list : the addresses still to visit. When it is full, new
--                        links are left out until there is room again.
--     the seen table   : which addresses are already known, and their mentions.
--                        It works like the bounded memory of the brain: each
--                        address has one place, with a check number saying
--                        whose it is, and a newcomer wears the owner down
--                        before taking the place. An address forgotten this
--                        way may be read again.
--
--  What is not a page is not thrown away: its address is filed under its kind
--  (writing, picture, video, sound...), ready for the brain of that kind.

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Holders;
with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
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
        List_Size      : Positive := 1_024;
        --# The most addresses that wait for a visit at once. Also the most
        --# addresses filed under each kind of thing that is not a page.
        Seen_Size      : Positive := 65_536;
        --# How many addresses it can remember having seen.
        Time_Limit     : Duration := 0.0;
        --# After this long, no new page is asked for. 0 = no limit.
        Stay_Under     : Ada.Strings.Unbounded.Unbounded_String := Ada.Strings.Unbounded.Null_Unbounded_String;
        --# Follow only links whose path starts like this, for example "/wiki/". Empty = any path.
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
        Left_Out : Natural := 0;
        --# Links not kept because a list was full or their place was taken.
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

    function Waiting_Count (
            Self : in Web_Source
            ) return Natural;
    --# How many addresses are waiting for a visit.

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

    package Waiting_Lists is new Ada.Containers.Vectors (
            Index_Type   => Natural,
            Element_Type => Ada.Strings.Unbounded.Unbounded_String,
            "="          => Ada.Strings.Unbounded."="
            );

    package Check_Lists is new Ada.Containers.Vectors (
            Index_Type   => Natural,
            Element_Type => Ada.Containers.Hash_Type,
            "="          => Ada.Containers."="
            );

    package Count_Lists is new Ada.Containers.Vectors (
            Index_Type   => Natural,
            Element_Type => Natural
            );
    --# These three count their places from 0, so that "next place" is a remainder.

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
        Waiting       : Waiting_Lists.Vector;
        --# The waiting list: a ring of List_Size places.
        First         : Natural := 0;
        --# The place of the address that has waited longest.
        Count         : Natural := 0;
        --# How many addresses are waiting.
        Seen_Checks   : Check_Lists.Vector;
        Seen_Counts   : Count_Lists.Vector;
        --# The seen table: for each place, whose it is and how many mentions it has.
        Started       : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
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
