--  Where the text to study comes from.
--
--  A source hands out text one PIECE at a time. The brain never needs the whole
--  text at once, so a source can be far bigger than memory: a huge file today,
--  a list of pages to follow tomorrow.
--
--     Calipso.Memory_Sources : pieces taken at random from a text held in memory.
--     Calipso.File_Sources   : a file read from start to end, never loaded whole.

with Calipso.Texts;

package Calipso.Sources is

    type Source is limited interface;

    procedure Next_Piece (
            Self  : in out Source;
            Piece :    out Texts.Symbol_Text;
            Found :    out Boolean
            ) is abstract;
    --# Found is False when the source has run dry.

    end Calipso.Sources;
