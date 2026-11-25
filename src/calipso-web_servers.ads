--  A very small web server, for this computer only.
--
--  A web server waits for requests ("give me the page /view") and sends back
--  replies ("here it is"). This one is as small as it can be:
--
--     - it listens only to this same computer (address 127.0.0.1), never to the network
--     - it answers one request at a time
--     - what to answer is decided by a procedure given by whoever uses it
--
--  It is what lets a program show its own pages in the browser you already have.

with Ada.Strings.Unbounded;

package Calipso.Web_Servers is

    type Request is record
        Method : Ada.Strings.Unbounded.Unbounded_String;
        --# "GET" to ask for a page, "POST" to send a form.
        Path   : Ada.Strings.Unbounded.Unbounded_String;
        --# What is asked for, such as "/view".
        Fields : Ada.Strings.Unbounded.Unbounded_String;
        --# What a form sent, still as it travels: "address=http%3A%2F%2Fexample.org".
        end record;

    type Reply is record
        Status  : Positive := 200;
        --# 200 = here it is. 404 = not found. 400 = the request made no sense.
        Label   : Ada.Strings.Unbounded.Unbounded_String :=
            Ada.Strings.Unbounded.To_Unbounded_String ("text/html; charset=utf-8");
        Content : Ada.Strings.Unbounded.Unbounded_String;
        end record;

    Listening_Error : exception;
    --# The port is taken, or listening is not allowed.

    procedure Serve (
            Port    : in Positive;
            Respond : not null access procedure (
                    Asked  : in     Request;
                    Answer :    out Reply;
                    Stop   :    out Boolean
                    )
            );
    --# Answers requests until Respond says to stop. Raises Listening_Error if it cannot start.

    function Field (
            Fields : in String;
            Name   : in String
            ) return String;
    --# The value a form sent under this name, decoded. "" if it is not there.

    function Encoded (
            Text : in String
            ) return String;
    --# The text written so that it can travel inside an address: "a b" -> "a%20b".

    function Escaped (
            Text : in String
            ) return String;
    --# The text made safe to show inside a page: & < > " are written by name,
    --# so that text coming from outside can never act as tags.

    function File_Content (
            File_Name : in String
            ) return Ada.Strings.Unbounded.Unbounded_String;
    --# The bytes of a file, whatever they are. Raises Listening_Error if it cannot be read.

    end Calipso.Web_Servers;
