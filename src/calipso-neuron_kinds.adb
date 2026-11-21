with Calipso.Basis_Neurons;
with Calipso.Bias_Neurons;
with Calipso.Counting_Neurons;
with Calipso.Counting_Oracles;

package body Calipso.Neuron_Kinds is

    function Made_Bias (
            Letter_Count : in Symbol
            ) return Neurons.Neuron'Class is
        Item : Bias_Neurons.Bias_Neuron;
        begin
        Bias_Neurons.Prepare (Item, Letter_Count);
        return Item;
        end Made_Bias;

    function Made_Basis (
            Letter_Count : in Symbol;
            Measure      : in Basis_Neurons.Basis_Kind;
            Detail       : in Natural
            ) return Neurons.Neuron'Class is
        Item : Basis_Neurons.Basis_Neuron;
        begin
        Basis_Neurons.Prepare (Item, Letter_Count, Measure, Default_Reach, Detail);
        return Item;
        end Made_Basis;

    function Made_Counting (
            Letter_Count : in Symbol;
            Capacity     : in Natural
            ) return Neurons.Neuron'Class is
        Item : Counting_Neurons.Counting_Neuron;
        begin
        Counting_Neurons.Prepare (Item, Letter_Count, Counting_Oracles.Default_Longest, Capacity);
        return Item;
        end Made_Counting;

    function Made (
            Name         : in String;
            Letter_Count : in Symbol
            ) return Neurons.Neuron'Class is
        begin
        if Name = "bias" then
            return Made_Bias (Letter_Count);
            end if;
        if Name = "position" then
            return Made_Basis (Letter_Count, Basis_Neurons.By_Position, 0);
            end if;
        if Name = "presence" then
            return Made_Basis (Letter_Count, Basis_Neurons.By_Harmonic, 0);
            end if;
        if Name = "harmonic" then
            return Made_Basis (Letter_Count, Basis_Neurons.By_Harmonic, Default_Waves);
            end if;
        if Name = "decay" then
            return Made_Basis (Letter_Count, Basis_Neurons.By_Decay, Default_Speeds);
            end if;
        if Name = "counting" then
            return Made_Counting (Letter_Count, 0);
            end if;
        if Name = "memory" then
            return Made_Counting (Letter_Count, Default_Memory);
            end if;
        raise Recipe_Error with "there is no neuron called " & Name;
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
