# Calipso

Wave Function Collapse AI models.

**Calipso** es el proyecto. Su primera pieza es **Colapso**: una librería en Ada
para generar texto *rellenando huecos*, mirando el contexto a los dos lados,
en vez de escribir letra a letra de izquierda a derecha.

## La idea, en corto

Un generador normal escribe así: lee lo anterior, apuesta la siguiente letra,
y repite. Nunca sabe a dónde va.

Colapso trabaja sobre un **lienzo**: una fila de celdas. Algunas ya tienen
letra (por ejemplo, el final que tú quieres). El resto son **huecos**.
Cada hueco puede ser todavía cualquier letra. El motor repite tres pasos:

1. **Observar.** Buscar el hueco sobre el que hay menos dudas.
2. **Colapsar.** Decidir su letra.
3. **Propagar.** Esa letra cambia lo que se puede esperar de sus vecinas.

Es el mismo bucle del algoritmo *Wave Function Collapse* que se usa para
generar mapas, aplicado a texto.

```
Plantilla:  \nEl azúcar [40] y por eso debes lavarte los dientes.\n
Resultado:  \nEl azúcar [de los una hasta las encías se inflaman,] y por eso debes lavarte los dientes.\n
```

El texto **aterriza** en el final dado. Todavía no tiene sentido global:
el primer "cerebro" solo sabe contar trocitos de 7 letras. Eso es lo esperado
en esta etapa; el porqué y el siguiente paso están en [docs/DISENO.md](docs/DISENO.md).

## Estado del proyecto

| Parte | Estado |
|---|---|
| Referencia en Python (`referencia/`) | Ejecutada. Pruebas en verde. Experimentos hechos. |
| Librería en Ada (`src/`) | Compila con GNAT 14. Pruebas en verde en GitHub Actions. Con la misma semilla escribe exactamente lo mismo que la referencia. |
| Corpus | Incluida una muestra pequeña en español (`data/muestra.txt`, 9 KB). Falta probar con Wikipedia. |

La referencia en Python existe por dos motivos: probar la idea deprisa, y
comprobar el Ada. Con la misma semilla, los dos deben dar lo mismo.

## Compilar y ejecutar

Con GNAT y GPRbuild:

```sh
gprbuild -p -P colapso.gpr
./bin/colapso_tests
./bin/colapso_demo data/muestra.txt "\nEl azúcar [40] y por eso debes lavarte los dientes.\n" 3
./bin/colapso_ciegos data/muestra.txt
```

Con Alire: `alr build` y después los mismos programas de `bin/`.

La referencia, sin instalar nada (solo Python 3):

```sh
python3 referencia/pruebas.py
python3 referencia/demo.py data/muestra.txt "\nEl azúcar [40] y por eso debes lavarte los dientes.\n" 3
python3 referencia/ciegos.py data/muestra.txt
python3 referencia/experimentos.py data/muestra.txt
```

`demo.py` y `ciegos.py` son espejos de los dos programas en Ada: mismos
argumentos, misma salida. GitHub Actions compara las dos salidas en cada subida.

### Cómo se escribe una plantilla

| Escribes | Significa |
|---|---|
| `_` | un hueco de una celda |
| `[25]` | un hueco de 25 celdas |
| `[...]` | un hueco del tamaño por defecto (30) |
| `\n` | un salto de línea: frontera de párrafo |
| cualquier otra cosa | letras dadas, que no se tocan |

El tamaño del hueco es solo un punto de partida: si el texto no encaja,
el motor puede **ensanchar** el hueco por su cuenta.

## Qué se ha medido ya

Con un texto en inglés de 558 000 letras (el modelo aprende del 90 % y se
examina con el 10 % que nunca vio). Detalle en [docs/EXPERIMENTOS.md](docs/EXPERIMENTOS.md).

| Pregunta | Resultado |
|---|---|
| ¿Ayuda mirar a los dos lados? | Adivinar una letra tapada: 63 % mirando solo a la izquierda, **86 %** mirando a los dos lados. |
| ¿Importa el orden de colapso? | Con el 30 % del texto tapado se recupera el **72 %** empezando por el hueco más seguro, 64 % de izquierda a derecha, 60 % al azar. |
| ¿Aterriza en el final dado? | Sí. La peor "costura" sorprende entre 3,9 y 5,1 nats; escribiendo de izquierda a derecha, entre 7,3 y 8,8. |
| ¿Sirve dejar crecer el texto? | Si el hueco es demasiado corto, sí: las palabras válidas pasan del 17,5 % al **65 %**. Si el hueco ya es holgado, no aporta. |

## Mapa del proyecto

Cada capa solo conoce a las de abajo.

```
apps/  tests/          programas: demo, puntos ciegos, pruebas
────────────────────────────────────────────────────────────────
Colapso.Repairing      medir la tensión, reabrir y ensanchar
Colapso.Collapsing     el motor: observar, colapsar, propagar
Colapso.Blind_Spots    tapar letras al azar y contar aciertos
────────────────────────────────────────────────────────────────
Colapso.Counting_Oracles   un cerebro que solo cuenta
Colapso.Oracles            el CONTRATO de cualquier cerebro
────────────────────────────────────────────────────────────────
Colapso.Templates      lienzo <-> texto con huecos
Colapso.Canvases       el lienzo: celdas Blank / Given / Guessed
Colapso.Fragment_Counts    tabla "trocito -> veces visto"
────────────────────────────────────────────────────────────────
Colapso.Distributions  álgebra de opiniones:  A + B,  Factor * A
Colapso.Texts          archivo -> fila de símbolos
Colapso.Alphabets      tabla letra <-> símbolo
Colapso.Random_Sources azar repetible (misma semilla, mismo resultado)
Colapso.Console        frontera con la terminal (UTF-8)
Colapso                tipos comunes: Symbol
```

La pieza clave es `Colapso.Oracles`. El motor no sabe qué cerebro tiene
debajo: solo le pregunta *"¿qué letra crees que va aquí?"*. Hoy contesta una
tabla de cuentas. Cuando llegue la red neuronal, el motor no cambia.

`referencia/colapso_ref/` tiene un módulo por cada paquete, con el mismo
nombre y las mismas funciones.

## Conseguir un corpus más grande

Cualquier archivo de texto en UTF-8 sirve. Para Wikipedia en español hay un
andamio provisional:

```sh
python3 herramientas/descargar_wikipedia.py 500 corpus/wikipedia.txt
```

Aviso: esa herramienta **no se ha podido probar** donde se escribió (no había
salida a Wikipedia). La carpeta `corpus/` no se sube al repositorio.

## Estilo del código

- Tabulación en cascada: parámetros con doble sangría; el cierre (`)`, `end`)
  pertenece al nivel de dentro.
- Los comentarios explicativos llevan marca (`--#` en Ada, `#--` en Python)
  y van **después** de lo que explican.
- Una línea, un paso. Una función, una tarea. Nombres que se explican solos.
- Contratos (`Pre`, `Post`) en la interfaz de cada paquete; se comprueban al
  ejecutar (`-gnata`).
- Identificadores en inglés; comentarios y documentos en español.
- Fuentes sin `-gnatW8`: dentro del programa el texto es `Wide_Wide_String`;
  en las fronteras son bytes UTF-8, y se convierte solo en `Colapso.Console`
  y `Colapso.Texts`.

## Hoja de ruta

1. **Cerebro de conteo** (hecho): toda la tubería funcionando de punta a punta.
2. **Una capa que aprende**: un cerebro con números que se ajustan jugando a
   los puntos ciegos (tapar, apostar, destapar, corregir). Mira más lejos que
   7 letras.
3. **Álgebra de derivadas automáticas** en Ada, para poder apilar capas.
4. **Atención**: que cada celda consulte a todas las demás. Aquí es donde
   debería aparecer el sentido global.

Sin licencia todavía: es una decisión tuya.
