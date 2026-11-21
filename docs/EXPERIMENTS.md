# Experimentos

Cuatro preguntas sobre la idea de colapso, con cifras.

## Cómo se hicieron

- **Programa:** `python3 referencia/experimentos.py CORPUS 60`
  (60 ensayos por caso, semillas fijas: se puede repetir y da lo mismo).
- **Corpus principal:** un libro en inglés de dominio público, 557 909 letras
  (*Opticks*, de Newton; era el texto largo que había a mano). No va en el
  repositorio. El modelo aprende del primer 90 % y se examina con el último
  10 %, que no ha visto nunca.
- **Corpus pequeño:** `data/muestra.txt`, 9 144 letras en español.
- **Cerebro:** el de conteo, con ventana de 7 letras.
- Salidas completas en [`resultados/`](resultados/).

Avisos para leer las cifras con cuidado:

- El corpus grande está en **inglés**. El mecanismo no depende del idioma,
  pero falta repetirlo con Wikipedia en español.
- "Palabras válidas" es una medida tosca: de las palabras que el modelo ha
  tocado, cuántas existen en el texto aprendido. No mide sentido.
- 60 ensayos dan para ver diferencias grandes, no para afinar decimales.

## E1. ¿Ayuda mirar a los dos lados?

Se tapa **una** letra de texto real y se pide la más probable.

| Qué ve el modelo | Acierta | Sorpresa media |
|---|---|---|
| Solo la izquierda | 63,2 % | 1,530 nats |
| Solo la derecha | 61,8 % | 1,547 nats |
| Los dos lados | **86,1 %** | **0,620 nats** |

(3 000 letras por fila.)

**Lectura.** Mirar a un lado o al otro da casi lo mismo. Mirar a los dos a
la vez es mucho mejor: la duda media baja a menos de la mitad. Esta es la
base de toda la idea, y se cumple.

Con la muestra en español (solo 915 letras de examen): 55,5 %, 52,8 % y 74,7 %.
El mismo patrón.

## E2. ¿Importa el orden de colapso?

Los "puntos ciegos": se tapan letras al azar en trozos de 300 letras, se
rellenan eligiendo siempre la más probable, y se cuenta cuántas coinciden con
el original.

| Tapado | Menos dudas primero | Izquierda a derecha | Al azar |
|---|---|---|---|
| 15 % | **81,5 %** | 77,8 % | 75,1 % |
| 30 % | **71,9 %** | 64,3 % | 59,5 % |
| 50 % | **54,5 %** | 45,2 % | 40,2 % |
| 70 % | **32,3 %** | 24,3 % | 22,7 % |

(Los tres órdenes reciben los mismos trozos y los mismos huecos.)

**Lectura.** Empezar por el hueco más seguro gana siempre, y la ventaja crece
cuanto más se tapa. Tiene sentido: cada letra segura que se fija da pistas a
las dudosas. Es la regla de *Wave Function Collapse*, y aquí también funciona.

Con la muestra en español: 68,5 / 65,0 / 65,0 al 15 % y 49,0 / 41,2 / 37,7
al 50 %. El mismo orden.

## E3. ¿Aterriza el texto en el final dado?

A un texto real se le borra un trozo del centro y se rellena un hueco del
mismo tamaño. Aquí la letra se **sortea**, no se elige la más probable. No se
repara después. "Peor sorpresa" es la de la letra que peor encaja: mide lo
mala que es la costura.

| Hueco | Orden | Palabras válidas | Peor sorpresa (mediana) |
|---|---|---|---|
| 10 | menos dudas primero | **84,7 %** | **3,91 nats** |
| 10 | izquierda a derecha | 70,1 % | 8,78 nats |
| 20 | menos dudas primero | 86,5 % | **4,23 nats** |
| 20 | izquierda a derecha | 85,0 % | 7,90 nats |
| 40 | menos dudas primero | 91,6 % | **5,14 nats** |
| 40 | izquierda a derecha | 90,0 % | 7,30 nats |

El primer ensayo con hueco de 10, el mismo lienzo para los dos órdenes
(entre corchetes, lo que escribió el modelo):

```
menos dudas primero:   e height of 60 or 70 Inches,[ and in be]fore acts with a Force which
izquierda a derecha:   e height of 60 or 70 Inches,[ nor woul ]fore acts with a Force which
```

El primero cose con lo que viene (`be` + `fore`). El segundo deja `fore` suelto.

**Lectura.** Escribiendo de izquierda a derecha el texto llega al final del
hueco sin saber lo que viene, y choca. El colapso crece desde los dos bordes
y cose en el medio: la costura sorprende bastante menos. La ventaja en
palabras válidas es clara en huecos cortos y pequeña en los largos.

Lo que **no** mide esta tabla: sentido. Los ejemplos lo dejan claro. Las
palabras enlazan, la frase no dice nada.

## E4. ¿Sirve dejar crecer el texto?

Se borran **30** letras de un texto real y se dejan solo **K** celdas de
hueco. Es decir, el hueco es demasiado corto a propósito.

| K | Modo | Sin tensión | Palabras válidas | Largo final medio |
|---|---|---|---|---|
| 1 | sin reparar | 14 de 60 | 17,5 % | 1,0 |
| 1 | reabrir | 18 de 60 | 16,3 % | 1,0 |
| 1 | reabrir + crecer | **47 de 60** | **65,0 %** | 3,7 |
| 3 | sin reparar | 21 de 60 | 41,3 % | 3,0 |
| 3 | reabrir | 35 de 60 | 51,6 % | 3,0 |
| 3 | reabrir + crecer | **47 de 60** | **66,7 %** | 4,5 |
| 8 | sin reparar | 25 de 60 | 80,2 % | 8,0 |
| 8 | reabrir | 47 de 60 | 84,3 % | 8,0 |
| 8 | reabrir + crecer | 47 de 60 | 84,4 % | 8,4 |

(Los tres modos parten del mismo lienzo ya colapsado.)

Un ejemplo con K = 1:

```
sin reparar:        lose it in a short time. Wh[e] that if many contiguous
reabrir + crecer:   lose it in a short time. Wh[ich,] that if many contiguous
```

**Lectura.**

- Con una sola celda no hay letra que arregle la costura. Reabrir no puede
  hacer nada. Crecer sí: el hueco pasa de 1 a 3,7 celdas de media y las
  palabras válidas suben del 17,5 % al 65 %.
- Con 8 celdas ya hay sitio. Reabrir basta y crecer no añade nada.
- El texto crece **poco**: lo justo para cerrar la costura. No intenta
  recuperar las 30 letras que faltaban, porque este cerebro no sabe que
  falta contenido: solo nota que dos trozos no enlazan.

Ese último punto es el límite que importa. "Ampliar hasta que tenga sentido"
funciona hoy como "ampliar hasta que enlace". Para que crezca por *sentido*
hace falta un cerebro que entienda más que 7 letras.

## Resumen

| Parte de la idea | ¿Se sostiene? |
|---|---|
| Mirar a los dos lados | Sí, con mucha diferencia. |
| Colapsar primero lo más seguro | Sí, en todos los casos medidos. |
| Dar el final y aterrizar en él | Sí, a nivel de letras y palabras. |
| Largo libre | Sí cuando el hueco es corto. Crece lo mínimo. |
| Texto con sentido | **No todavía.** Es el límite del cerebro de conteo, no del motor. |
