package body Calipso.Memory_Sources is

    procedure Open (
            Self         : in out Memory_Source;
            Text         : in     Texts.Symbol_Text;
            Piece_Length : in     Positive;
            Seed         : in     Natural
            ) is
        begin
        Self.Text := Text;
        Self.Piece_Length := Piece_Length;
        Self.Dice := Random_Sources.Seeded (Seed);
        end Open;

    overriding procedure Next_Piece (
            Self  : in out Memory_Source;
            Piece :    out Texts.Symbol_Text;
            Found :    out Boolean
            ) is
        Room  : constant Positive := Natural (Self.Text.Length) - Self.Piece_Length;
        Start : Natural;
        begin
        Random_Sources.Draw_Index (Self.Dice, Room, Start);
        Piece := Texts.Part (Self.Text, Start + 1, Start + Self.Piece_Length);
        Found := True;
        end Next_Piece;

    end Calipso.Memory_Sources;
