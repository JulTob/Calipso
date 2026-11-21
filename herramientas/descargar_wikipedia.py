"""Descarga artículos de Wikipedia en español como texto plano, para usarlos de corpus.

Uso:
    python3 herramientas/descargar_wikipedia.py CUANTOS SALIDA

Ejemplo (500 artículos al azar, unos pocos megas):
    python3 herramientas/descargar_wikipedia.py 500 corpus/wikipedia.txt

Cada artículo queda en una línea por párrafo. Usa la interfaz pública de
Wikipedia (api.php), que ya devuelve el texto limpio, sin marcas de formato.

AVISO: esta herramienta es un andamio provisional en Python y NO se ha podido
probar en el entorno donde se escribió (no tenía salida a Wikipedia).
Si falla, el arreglo más probable está en `Article_Text`.
"""

import json
import sys
import time
import urllib.parse
import urllib.request

API_ADDRESS = "https://es.wikipedia.org/w/api.php"
USER_AGENT = "Colapso-corpus/0.1 (proyecto educativo; github.com/JulTob/Colapso)"
#-- Wikipedia pide que cada programa se identifique.
BATCH = 10
PAUSE_SECONDS = 0.5
#-- Pausa entre peticiones, por cortesía con el servidor.
SHORTEST_ARTICLE = 500
#-- Los artículos con menos letras que esto se descartan (suelen ser esbozos).


def Asked(
        parameters: dict
        ) -> dict:
    #-- Hace una petición a la interfaz y devuelve la respuesta ya leída.
    query = urllib.parse.urlencode(parameters)
    request = urllib.request.Request(API_ADDRESS + "?" + query)
    request.add_header("User-Agent", USER_AGENT)
    with urllib.request.urlopen(request, timeout=30) as response:
        raw = response.read()
    return json.loads(raw.decode("utf-8"))


def Random_Titles(
        count: int
        ) -> list:
    answer = Asked({
        "action": "query",
        "format": "json",
        "list": "random",
        "rnnamespace": "0",
        "rnlimit": str(count),
        })
    titles = []
    for entry in answer["query"]["random"]:
        titles.append(entry["title"])
    return titles


def Article_Text(
        title: str
        ) -> str:
    answer = Asked({
        "action": "query",
        "format": "json",
        "prop": "extracts",
        "explaintext": "1",
        "exsectionformat": "plain",
        "redirects": "1",
        "titles": title,
        })
    pages = answer["query"]["pages"]
    for page in pages.values():
        return page.get("extract", "")
    return ""


def Cleaned(
        text: str
        ) -> str:
    #-- Un párrafo por línea, sin líneas vacías.
    lines = []
    for line in text.split("\n"):
        stripped = line.strip()
        if len(stripped) > 0:
            lines.append(stripped)
    return "\n".join(lines)


def Main() -> None:
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    wanted = int(sys.argv[1])
    output_name = sys.argv[2]
    saved = 0
    letters = 0
    with open(output_name, "w", encoding="utf-8") as output:
        while saved < wanted:
            for title in Random_Titles(BATCH):
                if saved >= wanted:
                    break
                text = Cleaned(Article_Text(title))
                time.sleep(PAUSE_SECONDS)
                if len(text) < SHORTEST_ARTICLE:
                    continue
                output.write(text + "\n")
                saved = saved + 1
                letters = letters + len(text)
                print(f"{saved}/{wanted}  {title}  ({letters} letras en total)")
    print(f"Guardado en {output_name}")


if __name__ == "__main__":
    try:
        Main()
    except OSError as problem:
        print(f"Error de red o de archivo: {problem}")
        sys.exit(2)
