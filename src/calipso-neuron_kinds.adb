with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Calipso.Basis_Neurons;
with Calipso.Bias_Neurons;
with Calipso.Counting_Neurons;
with Calipso.Counting_Oracles;

package body Calipso.Neuron_Kinds is

    use Ada.Strings.Unbounded;

    Most_Digits : constant Positive := 10;

    type Order is record
        Word   : Unbounded_String;
        Count  : Natural := 0;
        --# How many sizes were written: 0, 1 or 2.
        First  : Natural := 0;
        Second : Natural := 0;
        --# A size of 0 means "not written".
        end record;
    --# One name of a recipe, taken apart: "decay:24:8" -> the word decay, sizes 24 and 8.

    function Size_In (
            Word : in String
            ) return Positive is
        Value : Long_Long_Integer := 0;
        begin
        if Word = "" or else Word'Length > Most_Digits then
            raise Recipe_Error with "a size in a recipe must be a whole number, 1 or more: " & Word;
            end if;
        for Digit of Word loop
            if Digit not in '0' .. '9' then
                raise Recipe_Error with "a size in a recipe must be a whole number, 1 or more: " & Word;
                end if;
            Value := Value * 10 + Long_Long_Integer (Character'Pos (Digit) - Character'Pos ('0'));
            end loop;
        if Value = 0 then
            raise Recipe_Error with "a size in a recipe must be a whole number, 1 or more: " & Word;
            end if;
        if Value > Long_Long_Integer (Most_Counters) then
            raise Recipe_Error with "a size is too large: " & Word;
            end if;
        return Positive (Value);
        end Size_In;
    --# The size written in a recipe: a whole number, 1 or more.

    procedure Take_Piece (
            Request : in out Order;
            Part    : in     Natural;
            Piece   : in     String;
            Name    : in     String
            ) is
        begin
        case Part is
            when 0 =>
                Request.Word := To_Unbounded_String (Piece);
            when 1 =>
                Request.First := Size_In (Piece);
            when 2 =>
                Request.Second := Size_In (Piece);
            when others =>
                raise Recipe_Error with "too many sizes for one neuron: " & Name;
            end case;
        end Take_Piece;
    --# Files the piece number Part of a name: the word first, then the sizes.

    function Parsed (
            Name : in String
            ) return Order is
        Request : Order;
        Start   : Positive := Name'First;
        Part    : Natural := 0;
        Colon   : Natural;
        begin
        while Start <= Name'Last + 1 loop
            Colon := 0;
            if Start <= Name'Last then
                Colon := Ada.Strings.Fixed.Index (Name, ":", Start);
                end if;
            if Colon = 0 then
                Colon := Name'Last + 1;
                end if;
            Take_Piece (Request, Part, Name (Start .. Colon - 1), Name);
            Part := Part + 1;
            Start := Colon + 1;
            end loop;
        Request.Count := Part - 1;
        return Request;
        end Parsed;

    procedure Check_Sizes (
            Name        : in String;
            Request     : in Order;
            Most_Sizes  : in Natural;
            Most_First  : in Natural;
            Most_Second : in Natural
            ) is
        begin
        if Request.Count > Most_Sizes then
            raise Recipe_Error with "too many sizes for this kind of neuron: " & Name;
            end if;
        if Request.First > Most_First or else Request.Second > Most_Second then
            raise Recipe_Error with "a size is too large: " & Name;
            end if;
        end Check_Sizes;

    function Chosen (
            Written : in Natural;
            Usual   : in Natural
            ) return Natural is
        begin
        if Written = 0 then
            return Usual;
            end if;
        return Written;
        end Chosen;
    --# The size the recipe wrote, or the usual one if it wrote none.

    function Made_Bias (
            Name         : in String;
            Request      : in Order;
            Letter_Count : in Symbol
            ) return Neurons.Neuron'Class is
        Item : Bias_Neurons.Bias_Neuron;
        begin
        Check_Sizes (Name, Request, 0, 0, 0);
        Bias_Neurons.Prepare (Item, Letter_Count);
        return Item;
        end Made_Bias;

    function Made_Basis (
            Name         : in String;
            Request      : in Order;
            Letter_Count : in Symbol;
            Measure      : in Basis_Neurons.Basis_Kind;
            Most_Sizes   : in Natural;
            Usual_Detail : in Natural
            ) return Neurons.Neuron'Class is
        Item   : Basis_Neurons.Basis_Neuron;
        Reach  : constant Natural := Chosen (Request.First, Basis_Neurons.Default_Reach);
        Detail : constant Natural := Chosen (Request.Second, Usual_Detail);
        begin
        Check_Sizes (Name, Request, Most_Sizes, Most_Reach, Most_Detail);
        Basis_Neurons.Prepare (Item, Letter_Count, Measure, Reach, Detail);
        return Item;
        end Made_Basis;

    function Made_Counting (
            Name         : in String;
            Request      : in Order;
            Letter_Count : in Symbol
            ) return Neurons.Neuron'Class is
        Item    : Counting_Neurons.Counting_Neuron;
        Longest : constant Natural := Chosen (Request.First, Counting_Oracles.Default_Longest);
        begin
        Check_Sizes (Name, Request, 1, Most_Longest, 0);
        Counting_Neurons.Prepare (Item, Letter_Count, Longest, 0);
        return Item;
        end Made_Counting;

    function Made_Memory (
            Name         : in String;
            Request      : in Order;
            Letter_Count : in Symbol
            ) return Neurons.Neuron'Class is
        Item     : Counting_Neurons.Counting_Neuron;
        Counters : constant Natural := Chosen (Request.First, Counting_Neurons.Default_Memory);
        Longest  : constant Natural := Chosen (Request.Second, Counting_Oracles.Default_Longest);
        begin
        Check_Sizes (Name, Request, 2, Most_Counters, Most_Longest);
        Counting_Neurons.Prepare (Item, Letter_Count, Longest, Counters);
        return Item;
        end Made_Memory;

    function Made (
            Name         : in String;
            Letter_Count : in Symbol
            ) return Neurons.Neuron'Class is
        Request : constant Order := Parsed (Name);
        Word    : constant String := To_String (Request.Word);
        begin
        if Word = "bias" then
            return Made_Bias (Name, Request, Letter_Count);
            end if;
        if Word = "position" then
            return Made_Basis (Name, Request, Letter_Count, Basis_Neurons.By_Position, 1, 0);
            end if;
        if Word = "presence" then
            return Made_Basis (Name, Request, Letter_Count, Basis_Neurons.By_Harmonic, 1, 0);
            end if;
        if Word = "harmonic" then
            return Made_Basis (Name, Request, Letter_Count, Basis_Neurons.By_Harmonic, 2, Basis_Neurons.Default_Waves);
            end if;
        if Word = "decay" then
            return Made_Basis (Name, Request, Letter_Count, Basis_Neurons.By_Decay, 2, Basis_Neurons.Default_Speeds);
            end if;
        if Word = "counting" then
            return Made_Counting (Name, Request, Letter_Count);
            end if;
        if Word = "memory" then
            return Made_Memory (Name, Request, Letter_Count);
            end if;
        raise Recipe_Error with "there is no neuron called " & Word;
        end Made;

    function Blank_Of_Kind (
            Kind : in String
            ) return Neurons.Neuron'Class is
        begin
        if Kind = "bias" then
            declare
                Item : Bias_Neurons.Bias_Neuron;
                begin
                return Item;
                end;
            end if;
        if Kind = "basis" then
            declare
                Item : Basis_Neurons.Basis_Neuron;
                begin
                return Item;
                end;
            end if;
        if Kind = "counting" then
            declare
                Item : Counting_Neurons.Counting_Neuron;
                begin
                return Item;
                end;
            end if;
        raise Recipe_Error with "a saved brain names a kind of neuron I do not know: " & Kind;
        end Blank_Of_Kind;

    end Calipso.Neuron_Kinds;
