with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;

with GNAT.Sockets;

with Calipso.Web_Addresses;

package body Calipso.Web_Servers is

    use Ada.Strings.Unbounded;

    Line_End     : constant String := ASCII.CR & ASCII.LF;
    Head_End     : constant String := Line_End & Line_End;
    Longest_Head : constant Natural := 16_384;
    Longest_Body : constant Natural := 200_000;
    Patience     : constant Duration := 5.0;
    --# How long a visitor may stay silent before it is dropped.
    Hex_Figures  : constant String := "0123456789ABCDEF";
    Length_Field : constant String := "content-length:";

    Bad_Request : exception;

    function Image (
            Value : in Natural
            ) return String is
        begin
        return Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left);
        end Image;

    function Reason_Of (
            Status : in Positive
            ) return String is
        begin
        case Status is
            when 200 =>
                return "OK";
            when 400 =>
                return "Bad Request";
            when 404 =>
                return "Not Found";
            when others =>
                return "Other";
            end case;
        end Reason_Of;

    function Hex_Value (
            Figure : in Character
            ) return Natural is
        begin
        if Figure in '0' .. '9' then
            return Character'Pos (Figure) - Character'Pos ('0');
            end if;
        if Figure in 'A' .. 'F' then
            return Character'Pos (Figure) - Character'Pos ('A') + 10;
            end if;
        if Figure in 'a' .. 'f' then
            return Character'Pos (Figure) - Character'Pos ('a') + 10;
            end if;
        return 16;
        end Hex_Value;
    --# 0 to 15 for a hexadecimal figure; 16 for anything else.

    function Decoded (
            Text : in String
            ) return String is
        Result   : Unbounded_String;
        Position : Positive := Text'First;
        High     : Natural;
        Low      : Natural;
        begin
        while Position <= Text'Last loop
            if Text (Position) = '+' then
                Append (Result, ' ');
                Position := Position + 1;
            elsif Text (Position) = '%' and then Position + 2 <= Text'Last then
                High := Hex_Value (Text (Position + 1));
                Low := Hex_Value (Text (Position + 2));
                if High < 16 and then Low < 16 then
                    Append (Result, Character'Val (High * 16 + Low));
                    Position := Position + 3;
                else
                    Append (Result, '%');
                    Position := Position + 1;
                    end if;
            else
                Append (Result, Text (Position));
                Position := Position + 1;
                end if;
            end loop;
        return To_String (Result);
        end Decoded;
    --# Undoes the way a form writes its values: + is a space, %41 is the letter A.

    function Field (
            Fields : in String;
            Name   : in String
            ) return String is
        Start : Positive := Fields'First;
        Stop  : Natural;
        Equal : Natural;
        begin
        while Start <= Fields'Last loop
            Stop := Ada.Strings.Fixed.Index (Fields, "&", Start);
            if Stop = 0 then
                Stop := Fields'Last + 1;
                end if;
            Equal := Ada.Strings.Fixed.Index (Fields (Start .. Stop - 1), "=");
            if Equal > 0 and then Fields (Start .. Equal - 1) = Name then
                return Decoded (Fields (Equal + 1 .. Stop - 1));
                end if;
            Start := Stop + 1;
            end loop;
        return "";
        end Field;

    function Encoded (
            Text : in String
            ) return String is
        Result : Unbounded_String;
        Number : Natural;
        begin
        for Char of Text loop
            if Char in 'A' .. 'Z' or else Char in 'a' .. 'z' or else Char in '0' .. '9'
                    or else Char = '-' or else Char = '_' or else Char = '.' or else Char = '~' then
                Append (Result, Char);
            else
                Number := Character'Pos (Char);
                Append (Result, '%');
                Append (Result, Hex_Figures (Number / 16 + 1));
                Append (Result, Hex_Figures (Number mod 16 + 1));
                end if;
            end loop;
        return To_String (Result);
        end Encoded;

    function Escaped (
            Text : in String
            ) return String is
        Result : Unbounded_String;
        begin
        for Char of Text loop
            case Char is
                when '&' =>
                    Append (Result, "&amp;");
                when '<' =>
                    Append (Result, "&lt;");
                when '>' =>
                    Append (Result, "&gt;");
                when '"' =>
                    Append (Result, "&quot;");
                when others =>
                    Append (Result, Char);
                end case;
            end loop;
        return To_String (Result);
        end Escaped;

    function File_Content (
            File_Name : in String
            ) return Unbounded_String is
        use Ada.Streams;
        File    : Stream_IO.File_Type;
        Buffer  : Stream_Element_Array (1 .. 4_096);
        Last    : Stream_Element_Offset;
        Content : Unbounded_String;
        begin
        Stream_IO.Open (File, Stream_IO.In_File, File_Name);
        loop
            Stream_IO.Read (File, Buffer, Last);
            for Index in 1 .. Last loop
                Append (Content, Character'Val (Buffer (Index)));
                end loop;
            exit when Last < Buffer'Last;
            end loop;
        Stream_IO.Close (File);
        return Content;
        exception
        when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
            raise Listening_Error with "cannot read the file " & File_Name;
        end File_Content;

    function Ends_Head (
            Head : in Unbounded_String
            ) return Boolean is
        Size : constant Natural := Length (Head);
        begin
        if Size < Head_End'Length then
            return False;
            end if;
        return Slice (Head, Size - Head_End'Length + 1, Size) = Head_End;
        end Ends_Head;
    --# The head of a request ends with an empty line.

    procedure Read_Head (
            Channel : in     GNAT.Sockets.Stream_Access;
            Head    :    out Unbounded_String
            ) is
        Char : Character;
        begin
        Head := Null_Unbounded_String;
        loop
            Character'Read (Channel, Char);
            Append (Head, Char);
            exit when Ends_Head (Head);
            if Length (Head) > Longest_Head then
                raise Bad_Request with "the head of the request is too long";
                end if;
            end loop;
        end Read_Head;

    function Word_Of (
            Line   : in String;
            Wanted : in Positive
            ) return String is
        Start : Positive := Line'First;
        Stop  : Natural;
        begin
        for Number in 1 .. Wanted loop
            if Start > Line'Last then
                return "";
                end if;
            Stop := Ada.Strings.Fixed.Index (Line, " ", Start);
            if Stop = 0 then
                Stop := Line'Last + 1;
                end if;
            if Number = Wanted then
                return Line (Start .. Stop - 1);
                end if;
            Start := Stop + 1;
            end loop;
        return "";
        end Word_Of;
    --# The word number Wanted of a line whose words are separated by one space.

    function Body_Length (
            Head : in String
            ) return Natural is
        Lowered : constant String := Web_Addresses.Lowered (Head);
        Place   : constant Natural := Ada.Strings.Fixed.Index (Lowered, Length_Field);
        Size    : Natural := 0;
        begin
        if Place = 0 then
            return 0;
            end if;
        for Position in Place + Length_Field'Length .. Lowered'Last loop
            exit when Lowered (Position) = ASCII.CR;
            if Lowered (Position) in '0' .. '9' then
                Size := Size * 10 + (Character'Pos (Lowered (Position)) - Character'Pos ('0'));
                end if;
            if Size > Longest_Body then
                raise Bad_Request with "the body of the request is too long";
                end if;
            end loop;
        return Size;
        end Body_Length;
    --# How many bytes follow the head, as the head itself announces.

    procedure Read_Request (
            Channel : in     GNAT.Sockets.Stream_Access;
            Asked   :    out Request
            ) is
        Head : Unbounded_String;
        Form : Unbounded_String;
        Char : Character;
        begin
        Read_Head (Channel, Head);
        declare
            Text       : constant String := To_String (Head);
            First_End  : constant Natural := Ada.Strings.Fixed.Index (Text, Line_End);
            First_Line : constant String := Text (Text'First .. First_End - 1);
            Target     : constant String := Word_Of (First_Line, 2);
            Question   : constant Natural := Ada.Strings.Fixed.Index (Target, "?");
            begin
            Asked.Method := To_Unbounded_String (Word_Of (First_Line, 1));
            if Question = 0 then
                Asked.Path := To_Unbounded_String (Target);
                Asked.Fields := Null_Unbounded_String;
            else
                Asked.Path := To_Unbounded_String (Target (Target'First .. Question - 1));
                Asked.Fields := To_Unbounded_String (Target (Question + 1 .. Target'Last));
                end if;
            for Count in 1 .. Body_Length (Text) loop
                Character'Read (Channel, Char);
                Append (Form, Char);
                end loop;
            end;
        if Asked.Method = "POST" then
            Asked.Fields := Form;
            end if;
        end Read_Request;

    procedure Write_Reply (
            Channel : in GNAT.Sockets.Stream_Access;
            Answer  : in Reply
            ) is
        Content : constant String := To_String (Answer.Content);
        Head    : constant String :=
            "HTTP/1.0 " & Image (Answer.Status) & " " & Reason_Of (Answer.Status) & Line_End
            & "Content-Type: " & To_String (Answer.Label) & Line_End
            & "Content-Length: " & Image (Content'Length) & Line_End
            & "Connection: close" & Line_End
            & Line_End;
        begin
        String'Write (Channel, Head);
        String'Write (Channel, Content);
        end Write_Reply;

    procedure Answer_One (
            Client  : in     GNAT.Sockets.Socket_Type;
            Respond : not null access procedure (
                    Asked  : in     Request;
                    Answer :    out Reply;
                    Stop   :    out Boolean
                    );
            Stop    :    out Boolean
            ) is
        Channel : GNAT.Sockets.Stream_Access := GNAT.Sockets.Stream (Client);
        Asked   : Request;
        Answer  : Reply;
        begin
        Stop := False;
        begin
            Read_Request (Channel, Asked);
            Respond (Asked, Answer, Stop);
            Write_Reply (Channel, Answer);
            exception
            when Bad_Request =>
                Answer := (Status => 400, Content => To_Unbounded_String ("Bad request."), others => <>);
                Write_Reply (Channel, Answer);
            end;
        GNAT.Sockets.Free (Channel);
        exception
        when Ada.IO_Exceptions.End_Error | GNAT.Sockets.Socket_Error =>
            GNAT.Sockets.Free (Channel);
            --# The visitor hung up or stayed silent: it is dropped, and the server goes on.
        end Answer_One;

    procedure Open_Listener (
            Server : out GNAT.Sockets.Socket_Type;
            Port   : in  Positive
            ) is
        use GNAT.Sockets;
        Here : Sock_Addr_Type;
        begin
        Create_Socket (Server);
        Set_Socket_Option (Server, Socket_Level, (Reuse_Address, True));
        Here.Addr := Loopback_Inet_Addr;
        --# Only this same computer can reach the server.
        Here.Port := Port_Type (Port);
        Bind_Socket (Server, Here);
        Listen_Socket (Server);
        exception
        when Socket_Error =>
            raise Listening_Error with "cannot listen on port " & Image (Port);
        end Open_Listener;

    procedure Serve (
            Port    : in Positive;
            Respond : not null access procedure (
                    Asked  : in     Request;
                    Answer :    out Reply;
                    Stop   :    out Boolean
                    )
            ) is
        use GNAT.Sockets;
        Server : Socket_Type;
        Client : Socket_Type;
        Peer   : Sock_Addr_Type;
        Stop   : Boolean := False;
        begin
        Open_Listener (Server, Port);
        while not Stop loop
            Accept_Socket (Server, Client, Peer);
            Set_Socket_Option (Client, Socket_Level, (Receive_Timeout, Patience));
            Answer_One (Client, Respond, Stop);
            Close_Socket (Client);
            end loop;
        Close_Socket (Server);
        end Serve;

    end Calipso.Web_Servers;
