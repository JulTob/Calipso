--  The rules a site sets for robots.
--
--  A site may publish a file called robots.txt at its top. It says which
--  paths robots may fetch. It looks like this:
--
--     User-agent: *            <- who the next rules are for (* = every robot)
--     Disallow: /private/      <- paths that start like this: do not fetch
--     Allow: /private/open/    <- except these
--     Crawl-delay: 5           <- wait this many seconds between requests
--
--  How the rules are read here:
--
--     - The rules that name us win over the rules for everybody (*).
--     - For a path, the LONGEST rule that fits it decides. On a tie, Allow wins.
--     - No rule fits: allowed. No robots.txt at all: everything is allowed.
--     - In a rule, * stands for any run of letters and a final $ means "ends here".
--
--  The rules say what may be FETCHED. They say nothing about what the text may
--  be used for: that stays a decision of the person running the program.

with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;

with Calipso.Texts;

package Calipso.Robots is

    type Rule_Set is private;
    --# A newly declared set has no rules: everything is allowed.

    function Allow_Everything return Rule_Set;

    function Allow_Nothing return Rule_Set;
    --# For when the rules could not be read: when in doubt, stay out.

    function Parsed (
            Text       : in Texts.Wide_Text;
            Agent_Name : in String
            ) return Rule_Set;
    --# The rules that apply to the robot called Agent_Name.

    function Allows (
            Rules : in Rule_Set;
            Path  : in String
            ) return Boolean;

    function Delay_Of (
            Rules : in Rule_Set
            ) return Duration;
    --# Seconds the site asks robots to wait between two requests. 0 = it does not say.

    function Fits (
            Pattern : in String;
            Path    : in String
            ) return Boolean;
    --# Does the path start the way the pattern says?

private

    package Pattern_Lists is new Ada.Containers.Indefinite_Vectors (
            Index_Type   => Positive,
            Element_Type => String
            );

    package Verdict_Lists is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Boolean
            );

    type Rule_Set is record
        Patterns : Pattern_Lists.Vector;
        Verdicts : Verdict_Lists.Vector;
        --# Verdicts (N): True if rule N allows, False if it forbids.
        Pause    : Duration := 0.0;
        end record;

    end Calipso.Robots;
