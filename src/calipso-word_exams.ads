--  An exam for the level of kinds.
--
--  In a text never studied, one word in every few is hidden. The level of kinds
--  looks at the kinds of the four tokens on each side and gives its opinion of
--  the kind of the hidden word. Then the most usual studied word of that length,
--  in the most likely kind, is the answer. The exam counts how often it is the
--  word that was hidden.
--
--  It measures the kinds, not the letters: a better way of deciding kinds scores higher.
--
--  It mirrors reference/calipso_ref/word_exams.py.

with Calipso.Pyramids;
with Calipso.Tokens;

package Calipso.Word_Exams is

    Default_Step : constant Positive := 9;
    Side         : constant Positive := 4;
    --# How many tokens on each side of the hidden word are shown.

    type Result is record
        Asked : Natural := 0;
        Right : Natural := 0;
        end record;

    function Exam (
            Plan    : in Pyramids.Pyramid;
            Studied : in Tokens.Token_List;
            Unseen  : in Tokens.Token_List;
            Step    : in Positive := Default_Step
            ) return Result;
    --# Studied is the text Plan learned from; Unseen is the text of the exam.

    end Calipso.Word_Exams;
