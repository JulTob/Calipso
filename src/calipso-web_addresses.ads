--  Web addresses and what they point to.
--
--  An address is kept as plain text, for example
--
--     http://example.org/folder/page.html?view=1
--
--     site : http://example.org           (who is asked)
--     path : /folder/page.html?view=1     (what is asked for)
--
--  Two questions are answered here without asking anybody:
--
--     Resolved     : a link written inside a page, turned into a full address.
--     Kind_By_Name : what an address probably holds, judged by its ending.
--
--  And one after the server has answered:
--
--     Kind_By_Label : what it really holds, judged by the label the server sent.

package Calipso.Web_Addresses is

    type Content_Kind is (Page, Writing, Picture, Video, Sound, Document, Other);
    --# Page    : a web page: text for people, wrapped in tags.
    --# Writing : any other file that is text inside: notes, program code,
    --#           a drawing written as text.

    function Kind_Name (
            Kind : in Content_Kind
            ) return String;
    --# "page", "writing", "picture"...

    function Lowered (
            Text : in String
            ) return String;
    --# Only the letters A to Z are lowered.

    function Starts_With (
            Text   : in String;
            Prefix : in String
            ) return Boolean;

    function Ends_With (
            Text   : in String;
            Suffix : in String
            ) return Boolean;

    function Is_Plain (
            Text : in String
            ) return Boolean;
    --# Only visible characters of the basic set, and no spaces.

    function Narrowed (
            Text : in Wide_Wide_String
            ) return String;
    --# The same text as plain characters. A letter outside the basic set becomes
    --# a mark that no address may contain, so such a link is later dropped.

    function Site_Of (
            Address : in String
            ) return String;
    --# "http://example.org". Empty if the address has no site.

    function Host_Of (
            Address : in String
            ) return String;
    --# "example.org": the site without the "http://" in front.

    function Path_Of (
            Address : in String
            ) return String;
    --# "/folder/page.html?view=1". A site alone has the path "/".

    function Without_Question (
            Path : in String
            ) return String;
    --# The path up to the question mark, if there is one.

    function Ending_Of (
            Address : in String
            ) return String;
    --# What comes after the last dot of the last part of the path, lowered. "" if none.

    function Kind_By_Name (
            Address : in String
            ) return Content_Kind;
    --# No ending, a page ending or an ending never heard of: it may be a page.
    --# The label of the server decides for good, after asking.

    function Kind_By_Label (
            Label : in String
            ) return Content_Kind;
    --# Label: what the server says the file is, like "text/html; charset=utf-8".

    function Label_By_Ending (
            Ending : in String
            ) return String;
    --# The label a server sends for a file with this ending: "html" -> "text/html".

    function Sense_Of (
            Address : in String;
            Kind    : in Content_Kind
            ) return String;
    --# The name of the brain that should read this: one per kind, and for
    --# writing one per ending ("py", "svg", "css"...), because each is its own language.

    function Tidy_Path (
            Path : in String
            ) return String;
    --# Works out the "." (stay here) and ".." (go up one folder) parts of a path.

    function Resolved (
            Base : in String;
            Link : in String
            ) return String;
    --# The full address a link points to, seen from the page (Base) it is written in.
    --# "" when the link cannot be followed (mail, scripts, strange characters).

    end Calipso.Web_Addresses;
