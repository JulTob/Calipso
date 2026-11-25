--  A brain that can only count.
--
--  Idea: to give an opinion on a hole, I look at a "window" of known letters
--  around it and ask the count table:
--
--     "Of all the times I saw this window in the corpus,
--      which letter was in the place of the hole?"
--
--  I start with an empty window (just how frequent each letter is) and
--  widen it one neighbour at a time, alternating left and right. Each
--  wider window corrects the opinion of the previous one.


with Calipso.Canvases;
with Calipso.Distributions;
with Calipso.Fragment_Counts;
with Calipso.Oracles;
with Calipso.Records;
with Calipso.Texts;

package Calipso.Counting_Oracles is

    Default_Longest : constant Positive := 7;
    --# Default widest window: the hole plus 6 neighbours.

    type Counting_Oracle is new Oracles.Oracle with private;

    procedure Prepare (
            Self         : in out Counting_Oracle;
            Letter_Count : in     Symbol;
            Longest      : in     Positive := Default_Longest;
            Capacity     : in     Natural := 0
            );
    --# Leaves the brain blank. Capacity 0 = exact memory; more = bounded memory.

    procedure Study (
            Self : in out Counting_Oracle;
            Text : in     Texts.Symbol_Text
            );
    --# Adds what this text teaches to what the brain already knew.

    function Capacity (
            Self : in Counting_Oracle
            ) return Natural;

    function Longest_Of (
            Self : in Counting_Oracle
            ) return Positive;
    --# The longest fragment it counts: its window.

    procedure Save (
            Self : in     Counting_Oracle;
            Tape : in out Records.Tape
            );

    procedure Load (
            Self : in out Counting_Oracle;
            Tape : in out Records.Tape
            );

    procedure Train (
            Self         : in out Counting_Oracle;
            Text         : in     Texts.Symbol_Text;
            Letter_Count : in     Symbol;
            Longest      : in     Positive := Default_Longest
            );
    --# "Training" this brain is just counting fragments: Prepare, then Study.

    function Fragment_Total (
            Self : in Counting_Oracle
            ) return Natural;
    --# How many distinct fragments it remembers. Useful to report its size.

    overriding function Alphabet_Size (
            Self : in Counting_Oracle
            ) return Symbol;

    overriding function Reach (
            Self : in Counting_Oracle
            ) return Natural;

    overriding function Opinion (
            Self     : in Counting_Oracle;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution;

private

    type Counting_Oracle is new Oracles.Oracle with record
        Letter_Count : Symbol := 1;
        Longest      : Positive := Default_Longest;
        Table        : Fragment_Counts.Count_Table;
        end record;

    end Calipso.Counting_Oracles;
