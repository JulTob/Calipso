--  The panel: look at a web page, check the site's rules, then train.
--
--  Usage:
--     calipso_panel [BRAIN_FOLDER] [PORT]
--
--  It starts a small web server on this computer only and waits. Open
--     http://127.0.0.1:8080
--  in your usual browser to use the panel. Stop the program with Ctrl+C.
--
--  BRAIN_FOLDER (default "brains") is where the brains are kept, one file per
--  kind of content: page.brn, py.brn, svg.brn... Copy the folder to another
--  computer and the brains carry on there.

with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;

with Calipso.Console;
with Calipso.Curl_Fetchers;
with Calipso.Panels;
with Calipso.Web_Servers;

procedure Calipso_Panel is

    use Calipso;

    Default_Folder : constant String := "brains";
    Default_Port   : constant Positive := 8_080;

    Bad_Argument : exception;

    The_Panel : Panels.Panel;

    procedure Handle (
            Asked  : in     Web_Servers.Request;
            Answer :    out Web_Servers.Reply;
            Stop   :    out Boolean
            ) is
        begin
        Panels.Respond (The_Panel, Asked, Answer, Stop);
        end Handle;

    function Port_Number (
            Word : in String
            ) return Positive is
        begin
        return Positive'Value (Word);
        exception
        when Constraint_Error =>
            raise Bad_Argument with "the port must be a whole number, like 8080";
        end Port_Number;

    procedure Run (
            Folder : in String;
            Port   : in Positive
            ) is
        Fetcher : Curl_Fetchers.Curl_Fetcher;
        begin
        Ada.Directories.Create_Path (Folder);
        Panels.Open (The_Panel, Folder, Fetcher);
        Console.Put_Line ("Calipso panel ready. Open http://127.0.0.1:" & Console.Image (Port) & " in your browser.");
        Console.Put_Line ("Brains are kept in the folder " & Folder & ". Stop with Ctrl+C.");
        Web_Servers.Serve (Port, Handle'Access);
        end Run;

    Count : constant Natural := Ada.Command_Line.Argument_Count;

    begin
    if Count = 0 then
        Run (Default_Folder, Default_Port);
    elsif Count = 1 then
        Run (Ada.Command_Line.Argument (1), Default_Port);
    else
        Run (Ada.Command_Line.Argument (1), Port_Number (Ada.Command_Line.Argument (2)));
        end if;
    exception
    when Problem : Web_Servers.Listening_Error | Bad_Argument | Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
        Console.Put_Line ("Error: " & Ada.Exceptions.Exception_Message (Problem));
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
    end Calipso_Panel;
