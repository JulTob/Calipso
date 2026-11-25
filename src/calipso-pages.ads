--  What is inside a web page.
--
--  A page arrives as "markup": text for people mixed with tags for the browser,
--  like <p>, <a href="...">, <img src="...">. Reading a page means taking it
--  apart into:
--
--     blocks : the page as a list of pieces, in order. A piece is a paragraph
--              of words, or the place where a picture, video or sound goes.
--     links  : every address the page points to, as it was written.
--
--  The reader is simple on purpose. It does not run scripts and it does not
--  understand layout: it sees a page the way a very old phone browser did.

with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;

with Calipso.Texts;

package Calipso.Pages is

    type Block_Kind is (Words, Picture, Video, Sound, Drawing);
    --# Drawing: a drawing written inside the page itself (an <svg> tag).

    type Block is record
        Kind : Block_Kind := Words;
        Text : Texts.Wide_Text;
        --# For a paragraph, its words. For a picture, video or sound, its address as written.
        end record;

    package Block_Lists is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Block
            );

    package Link_Lists is new Ada.Containers.Indefinite_Vectors (
            Index_Type   => Positive,
            Element_Type => Wide_Wide_String
            );

    type Page_Content is record
        Blocks : Block_Lists.Vector;
        Links  : Link_Lists.Vector;
        end record;

    function Read (
            Markup : in Texts.Wide_Text
            ) return Page_Content;

    function Text_Of (
            Content : in Page_Content
            ) return Texts.Wide_Text;
    --# The words of the page: one paragraph per line.

    end Calipso.Pages;
