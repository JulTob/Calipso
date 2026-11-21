"""Executable reference for Calipso.

Each module in this folder mirrors one Ada package of `src/`:
same name, same functions, same steps in the same order.
It serves two purposes:

  1. Test the idea quickly (the experiments run here).
  2. Check the Ada: with the same seed, both must give the same result.
"""

MAX_SYMBOLS = 255
#-- A symbol is a small number (1 .. 255) that stands for a letter.

UNKNOWN = 1
#-- Symbol 1 is reserved for "a letter I do not know".
