"""Espejo de Colapso.Texts: pasar de un archivo de texto a una fila de símbolos."""

from . import alphabets

LINE_FEED = "\n"
CARRIAGE_RETURN = "\r"


class Reading_Error(Exception):
    pass


def For_Each_Character(
        file_name: str,
        visit
        ) -> None:
    #-- Recorre el archivo letra a letra y llama a `visit` con cada una.
    #-- Cada línea termina en un salto de línea, también la última.
    try:
        with open(file_name, encoding="utf-8", newline="") as file:
            content = file.read()
    except OSError as problem:
        raise Reading_Error(f"no puedo abrir {file_name}: {problem}")
    except UnicodeDecodeError as problem:
        raise Reading_Error(f"{file_name} no es UTF-8 válido: {problem}")
    lines = content.split(LINE_FEED)
    if len(lines) > 0 and lines[-1] == "":
        lines.pop()
    for line in lines:
        for char in line:
            if char != CARRIAGE_RETURN:
                visit(char)
        visit(LINE_FEED)


def Learn_Alphabet(
        file_name: str,
        letters: alphabets.Alphabet
        ) -> None:
    #-- Primera pasada: apuntar cada letra nueva, por orden de aparición.
    def Note_Character(char):
        alphabets.Include(letters, char)

    For_Each_Character(file_name, Note_Character)


def Read_Symbols(
        file_name: str,
        letters: alphabets.Alphabet
        ) -> list:
    #-- Segunda pasada: traducir cada letra a su símbolo.
    text = []

    def Store_Character(char):
        symbol = alphabets.Symbol_Of(letters, char)
        text.append(symbol)

    For_Each_Character(file_name, Store_Character)
    return text


def Part(
        text: list,
        first: int,
        last: int
        ) -> list:
    #-- El trozo del texto que va de `first` a `last` (los dos incluidos), como texto nuevo.
    return text[first:last + 1]


def Encoded(
        plain: str,
        letters: alphabets.Alphabet
        ) -> list:
    text = []
    for char in plain:
        symbol = alphabets.Symbol_Of(letters, char)
        text.append(symbol)
    return text


def Decoded(
        text: list,
        letters: alphabets.Alphabet
        ) -> str:
    plain = ""
    for symbol in text:
        plain = plain + alphabets.Character_Of(letters, symbol)
    return plain
