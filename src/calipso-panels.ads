--  The panel: a supervised browser for training.
--
--  It shows a web page the way the robot sees it, so that a person can look
--  before anything is learned:
--
--     - the page as plain pieces: paragraphs, and the places of pictures and films
--     - the rules of the site (its robots.txt) and what they say about this address
--     - a Train button, which works only when the rules allow the address
--     - "hide": a paragraph becomes a hole and the brain builds something in
--       its place from the text around it, shown next to what was really there
--
--  There is one brain per kind of file ("sense"): page.brn for web pages,
--  py.brn for Python code, svg.brn for drawings written as text... Each is kept
--  in the brain folder, loaded when needed and saved after every training.
--
--  The panel does not know about sockets: it turns one request into one reply.
--  Calipso.Web_Servers carries them to and from the browser.

with Ada.Containers.Indefinite_Holders;
with Ada.Strings.Unbounded;

with Calipso.Brains;
with Calipso.Fetchers;
with Calipso.Pages;
with Calipso.Texts;
with Calipso.Web_Addresses;
with Calipso.Web_Servers;

package Calipso.Panels is

    Default_Recipe : constant String := "counting+bias+position";
    --# The neurons a new brain is made of.

    type Panel is limited private;

    procedure Open (
            Self         : in out Panel;
            Brain_Folder : in     String;
            Using        : in     Fetchers.Fetcher'Class
            );

    procedure Respond (
            Self   : in out Panel;
            Asked  : in     Web_Servers.Request;
            Answer :    out Web_Servers.Reply;
            Stop   :    out Boolean
            );
    --# One request in, one page out.

private

    package Fetcher_Holders is new Ada.Containers.Indefinite_Holders (
            Element_Type => Fetchers.Fetcher'Class,
            "="          => Fetchers.Same
            );

    type Rules_State is (Not_Asked, Present, Absent, Unreadable);

    type Trial is record
        Is_Shown : Boolean := False;
        Block    : Positive := 1;
        --# Which piece of the page was hidden.
        Rebuilt  : Texts.Wide_Text;
        --# What the brain built in its place.
        Hidden   : Natural := 0;
        Right    : Natural := 0;
        Seed     : Natural := 1;
        end record;
    --# The last "hide and rebuild" test.

    type Panel is limited record
        Folder      : Ada.Strings.Unbounded.Unbounded_String;
        Work_File   : Ada.Strings.Unbounded.Unbounded_String;
        Fetcher     : Fetcher_Holders.Holder;
        Address     : Ada.Strings.Unbounded.Unbounded_String;
        --# The address being looked at. Empty at the start.
        Notice      : Ada.Strings.Unbounded.Unbounded_String;
        --# One or two sentences about what just happened.
        Has_Page    : Boolean := False;
        Kind        : Web_Addresses.Content_Kind := Web_Addresses.Page;
        Content     : Pages.Page_Content;
        Rules       : Rules_State := Not_Asked;
        Rules_Text  : Texts.Wide_Text;
        Is_Allowed  : Boolean := False;
        Brain       : Brains.Brain;
        Brain_Sense : Ada.Strings.Unbounded.Unbounded_String;
        --# Which brain is loaded. Empty = none yet.
        Last_Trial  : Trial;
        end record;

    end Calipso.Panels;
