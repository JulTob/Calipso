"""Mirror of Calipso.Kind_Makers: the ways of deciding the kinds of a text.

    BY_SHAPE    a word's kind is what it looks like: capital, size, ending.
    BY_COMPANY  a word's kind is the group of words that keep the same company:
                  1. every unusual word becomes a vector (Company)
                  2. the vectors are told by a few numbers (Axes); 0 axes skips this step
                  3. near vectors are put into groups (Groups)
                  4. each group becomes a kind of the book (Kinds)

Either way the result is a Book, so nothing above it has to know which way was used.
"""

from . import axes
from . import company
from . import groups
from . import kinds
from . import tokens
from . import vectors

BY_SHAPE = 0
BY_COMPANY = 1
DEFAULT_AXES = 60
DEFAULT_GROUPS = 80


class Settings:

    def __init__(self):
        self.way = BY_SHAPE
        self.company = company.Settings()
        self.axes = DEFAULT_AXES
        self.rounds = axes.DEFAULT_ROUNDS
        self.groups = DEFAULT_GROUPS
        self.passes = groups.DEFAULT_PASSES


def Points_Of(
        table: company.Table,
        options: Settings
        ) -> list:
    #-- What is grouped: the vectors themselves, or their short form along the main axes.
    if options.axes == 0:
        return table.rows
    basis = axes.Found(table.rows, options.axes, options.rounds)
    points = []
    for row in table.rows:
        points.append(vectors.Unit(axes.Projected(basis, row)))
    return points


def Groups_By_Word(
        sample: list,
        table: company.Table,
        numbers: list
        ) -> dict:
    #-- The group of every word of the text that has a row in the table.
    group_of = {}
    for token in sample:
        is_word = tokens.Sort_Of(token) == tokens.WORD
        if is_word and token not in group_of and company.Has_Word(table, token):
            group_of[token] = numbers[company.Row_Of(table, token) - 1]
    return group_of


def Book_Of(
        sample: list,
        options: Settings
        ) -> kinds.Book:
    by_shape = kinds.Built(sample)
    if options.way == BY_SHAPE:
        return by_shape
    table = company.Built(sample, by_shape, options.company)
    if company.Row_Count(table) == 0:
        return by_shape
    numbers = groups.Grouped(Points_Of(table, options), options.groups, options.passes)
    return kinds.Built_By_Groups(sample, Groups_By_Word(sample, table, numbers), options.groups)
