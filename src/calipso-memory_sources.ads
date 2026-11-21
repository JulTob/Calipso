--  A source that takes pieces at random from a text held in memory.

with Calipso.Random_Sources;
with Calipso.Sources;
with Calipso.Texts;

package Calipso.Memory_Sources is

    type Memory_Source is limited new Sources.Source with private;

    procedure Open (
            Self         : in out Memory_Source;
            Text         : in     Texts.Symbol_Text;
            Piece_Length : in     Positive;
            Seed         : in     Natural
            )
        with Pre => Natural (Text.Length) > Piece_Length;

    overriding procedure Next_Piece (
            Self  : in out Memory_Source;
            Piece :    out Texts.Symbol_Text;
            Found :    out Boolean
            );
    --# This source never runs dry: it can always draw another piece.

private

    type Memory_Source is limited new Sources.Source with record
        Text         : Texts.Symbol_Text;
        Piece_Length : Positive := 1;
        Dice         : Random_Sources.Generator;
        end record;

    end Calipso.Memory_Sources;
