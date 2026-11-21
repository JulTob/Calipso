--  The algebra of opinions.
--
--  A distribution shares out "weight" among the letters of the alphabet.
--  If the weights add up to 1 it is a probability; if not, they are raw counts.
--
--  Operations of the algebra:
--     A + B           put two piles of evidence together
--     Factor * A      give an opinion more or less strength
--     Normalized (A)  turn counts into probabilities
--     From_Scores (S) turn scores into probabilities

package Calipso.Distributions is

    subtype Weight is Long_Float range 0.0 .. Long_Float'Last;
    --# A weight is never negative. The type itself watches over that.

    Smallest_Probability : constant := 1.0E-300;
    --# Floor so that we never ask for the logarithm of zero.

    type Distribution (Size : Symbol) is private;
    --# Size is the number of letters of the alphabet the opinion is about.

    type Score_Array is array (Symbol range <>) of Long_Float;
    --# Points per letter: any number, positive or negative. More points = more likely.

    function Zero (
            Size : in Symbol
            ) return Distribution
        with Post => Zero'Result.Size = Size;

    function From_Scores (
            Scores : in Score_Array
            ) return Distribution
        with
            Pre  => Scores'First = 1 and then Scores'Length >= 1,
            Post => From_Scores'Result.Size = Scores'Last;
    --# Turns scores into probabilities (this is called "softmax").

    function Uniform (
            Size : in Symbol
            ) return Distribution
        with Post => Uniform'Result.Size = Size;
    --# All letters equally possible: the opinion of someone who knows nothing.

    function Weight_Of (
            Item  : in Distribution;
            Value : in Symbol
            ) return Weight
        with Pre => Value <= Item.Size;

    procedure Set_Weight (
            Item   : in out Distribution;
            Value  : in     Symbol;
            Amount : in     Weight
            )
        with Pre => Value <= Item.Size;

    function Total (
            Item : in Distribution
            ) return Weight;

    function Variety (
            Item : in Distribution
            ) return Natural;
    --# How many different letters carry some weight.

    function "+" (
            Left  : in Distribution;
            Right : in Distribution
            ) return Distribution
        with Pre => Left.Size = Right.Size;

    function "*" (
            Factor : in Weight;
            Right  : in Distribution
            ) return Distribution;

    function Normalized (
            Item : in Distribution
            ) return Distribution
        with
            Pre  => Total (Item) > 0.0,
            Post => Normalized'Result.Size = Item.Size;

    function Probability_Of (
            Item  : in Distribution;
            Value : in Symbol
            ) return Long_Float
        with Pre => Value <= Item.Size and then Total (Item) > 0.0;

    function Entropy (
            Item : in Distribution
            ) return Long_Float
        with Pre => Total (Item) > 0.0;
    --# Uncertainty, in nats. 0 = completely sure. The higher, the more doubt.

    function Surprise_Of (
            Item  : in Distribution;
            Value : in Symbol
            ) return Long_Float
        with Pre => Value <= Item.Size and then Total (Item) > 0.0;
    --# How surprising it is to see this letter, in nats. 0 = it was exactly what was expected.

    function Most_Likely (
            Item : in Distribution
            ) return Symbol
        with Post => Most_Likely'Result <= Item.Size;

    function Sampled (
            Item : in Distribution;
            Unit : in Long_Float
            ) return Symbol
        with
            Pre  => Total (Item) > 0.0 and then Unit >= 0.0 and then Unit < 1.0,
            Post => Sampled'Result <= Item.Size;
    --# Rolls a loaded dice. Unit is a random number in [0, 1).

private

    type Weight_Array is array (Symbol range <>) of Weight;

    type Distribution (Size : Symbol) is record
        Weights : Weight_Array (1 .. Size) := (others => 0.0);
        end record;

    end Calipso.Distributions;
