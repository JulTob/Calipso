# Diseño de Colapso

Este documento explica **por qué** el proyecto es como es. Va de la idea a las
piezas, y deja escritas las decisiones para que se puedan discutir.

## 1. La idea y su nombre correcto

La propuesta de partida:

> En lugar de predecir letra a letra, ver el texto entero y completarlo.
> Dar el final y que el modelo escriba algo que lleve hasta él.
> Sin fijar el largo de antemano. Entrenar tapando trozos al azar.

Tres aclaraciones de vocabulario, porque ayudan a buscar y a pensar:

**No es retrocausal: es condicionar.** Nada viaja hacia atrás en el tiempo.
El final es *evidencia fija*, igual que podría serlo el principio. La pregunta
es: "de todos los textos posibles, ¿cuáles son compatibles con lo que ya está
escrito?". Que la evidencia esté a la derecha o a la izquierda es indiferente.

**El colapso de onda sí es una buena imagen.** El algoritmo *Wave Function
Collapse* (Maxim Gumin, 2016, `mxgmn/WaveFunctionCollapse`) genera mapas así:
cada casilla empieza pudiendo ser cualquier pieza; se elige la casilla con
menos posibilidades, se fija, y se propaga la consecuencia a las vecinas.
Colapso hace exactamente eso con letras.

**La idea existe y está viva en investigación.** Se llama *modelo de lenguaje
por difusión enmascarada* (masked diffusion language model). Entrenan tapando
posiciones al azar y aprendiendo a rellenarlas, que es la propuesta de los
"puntos ciegos". Su punto débil conocido es justo el otro deseo: **el largo
fijo**. Hay trabajos de 2025 y 2026 dedicados solo a eso (ver Lecturas).
Es buena señal por partida doble: la idea es sólida, y la parte del largo
variable sigue abierta.

## 2. Las cuatro piezas

### Lienzo (`Colapso.Canvases`)

Una fila de celdas. Cada celda está en uno de tres estados:

| Estado | Qué es | ¿Se puede cambiar? |
|---|---|---|
| `Blank` | hueco: aún puede ser cualquier letra | sí, colapsándolo |
| `Given` | letra que dio la persona | **nunca** |
| `Guessed` | letra que decidió el modelo | sí: se puede reabrir |

Distinguir `Given` de `Guessed` es lo que permite corregir sin tocar lo que
la persona fijó.

### Oráculo (`Colapso.Oracles`)

Un contrato con una sola pregunta:

> Mirando lo que hay alrededor, ¿qué letra crees que va en esta celda?

La respuesta no es una letra: es una **distribución**, una opinión con dudas.
El oráculo mira solo a las vecinas, nunca a la celda misma. Por eso la misma
pregunta sirve para dos cosas: rellenar un hueco, y examinar una letra ya
puesta ("si te tapo, ¿te habrían adivinado?").

También declara su **alcance** (`Reach`): a cuántas celdas de distancia puede
influir una letra en otra. El motor lo necesita para propagar.

### Motor (`Colapso.Collapsing`)

```
mientras queden huecos:
    Observar : elegir el hueco con menos entropía (menos dudas)
    Colapsar : sortear su letra según la opinión del oráculo
    Propagar : marcar como caducadas las opiniones al alcance
```

**Entropía** es la medida de la duda de una distribución. Vale 0 si una letra
es segura, y crece cuantas más letras son posibles. Se mide en *nats*.

### Reparación (`Colapso.Repairing`)

Después de colapsar, se examina cada letra:

- **Sorpresa** de una letra: cuánto extraña a sus vecinas. Es `-ln(p)`, donde
  `p` es la probabilidad que le daban. Sorpresa 0: era lo esperado.
  Sorpresa 4: pasaba 1 de cada 55 veces.
- **Tensión** del lienzo: la suma de la sorpresa que pasa de lo tolerable,
  en la zona que el modelo ha tocado. Tensión 0 significa "todo encaja".

Relajar es repetir:

1. Buscar la letra que más sorprende.
2. **Reabrir**: dejar otra vez como huecos las letras del modelo cercanas, y
   volver a colapsar. Si la tensión baja, se queda.
3. Si no baja, **ensanchar**: meter celdas nuevas en ese punto y volver a
   colapsar. Si la tensión baja, se queda.

Así se cumple el deseo del largo libre: el texto crece solo donde hace falta
y solo si crecer mejora el encaje. Las letras `Given` no cambian nunca, y la
tensión final nunca es mayor que la inicial.

## 3. El primer cerebro: contar

`Colapso.Counting_Oracles` no aprende nada sofisticado. Su memoria es una
tabla: *trocito de texto → veces que lo he visto* (`Colapso.Fragment_Counts`).

Para opinar sobre un hueco:

1. Empieza sin mirar nada: todas las letras igual de posibles.
2. Mira una **ventana** alrededor del hueco y pregunta a la tabla: "de las
   veces que vi esta ventana, ¿qué letra había en el sitio del hueco?".
3. Ensancha la ventana una vecina cada vez, alternando izquierda y derecha,
   hasta 7 letras o hasta que la ventana no se haya visto nunca.

Cada ventana corrige la opinión de la anterior con una sola regla:

```
opinión nueva = Normalizar( Evidencia + Variedad × opinión anterior )
```

- **Evidencia**: las cuentas de esta ventana, letra por letra.
- **Variedad**: cuántas letras distintas se vieron en esta ventana.

La variedad hace de freno. Si tras un contexto ha venido siempre la misma
letra, variedad 1: me fío mucho de él. Si ha venido de todo, variedad alta:
me fío más de lo que ya pensaba. No hay ningún número mágico que ajustar.

En Ada es una línea, gracias a los operadores del álgebra de distribuciones:

```ada
Mixed : constant Distribution := Clue + Prior_Strength * Belief;
```

### Una misma tabla sirve para los dos lados

Con una sola tabla de trocitos se puede mirar a la izquierda (`"cas" + ?`),
a la derecha (`? + "asa"`) o a los dos lados (`"ca" + ? + "a "`). Por eso no
hay dos modelos, uno hacia delante y otro hacia atrás: hay uno.

### "Entrenar tapando" aquí es un examen

Con este cerebro, entrenar es solo contar. El juego de los puntos ciegos
(`Colapso.Blind_Spots`) sirve hoy para **medir**: tapo letras de texto real,
relleno, cuento aciertos. Cuando el cerebro sea una red neuronal, ese mismo
juego será el **entrenamiento**: tapar, apostar, destapar y corregir números.

## 4. Decisiones tomadas, con su porqué

| Decisión | Alternativa descartada | Motivo |
|---|---|---|
| Una ventana centrada que crece | Multiplicar la opinión de un modelo hacia delante por la de otro hacia atrás | Medido con el mismo suavizado: 0,74 nats de sorpresa media frente a 0,95 (ventana de 7). Y es un solo mecanismo. |
| Freno por variedad | Una constante ajustada a mano | Medido: 0,665 nats y 85,5 % de acierto, frente a 0,659 y 83,4 % de la mejor constante que probé. Prácticamente igual, sin nada que ajustar. |
| Colapsar primero el hueco más seguro | Izquierda a derecha, o al azar | Medido: recupera más letras en todos los niveles de tapado. |
| Tensión = sorpresa por encima de un umbral | Sorpresa media | La media premia rellenar con texto fácil y repetitivo. El umbral no: cuando todo encaja, se para. |
| Medir la tensión también en las letras dadas cercanas | Solo en las letras del modelo | Una costura mala se nota a los dos lados. Sin esto el motor no veía palabras rotas. |
| Azar propio (`Random_Sources`) | El generador de la biblioteca estándar | Así Ada y Python sacan los mismos números y cualquier resultado se puede repetir. |
| Letras como unidad | Palabras o trozos de palabra | Lo más simple que funciona. Se puede cambiar sin tocar el motor: el alfabeto es una tabla. |

Las cifras "medido" de las dos primeras filas salen de pruebas de exploración
con el texto en inglés de 558 000 letras; las de las demás, de
[EXPERIMENTOS.md](EXPERIMENTOS.md).

## 5. Lo que este cerebro no puede hacer

Solo ve 6 letras de vecindad. Por eso:

- Las palabras salen bien formadas y enlazan con el final dado.
- **No hay sentido global.** No puede escribir un párrafo que *justifique*
  "y por eso debes lavarte los dientes": no sabe de qué habla el final.
- La tensión solo detecta fallos locales. Una frase absurda hecha de palabras
  correctas tiene tensión 0.

Nada de esto es un defecto del motor. Es el límite de un cerebro que solo
cuenta. Para el sentido global hace falta un oráculo con más alcance.

## 6. Siguiente etapa propuesta

**Una capa que aprende**, cumpliendo el mismo contrato `Oracle`:

- Para cada posición vecina (hasta 20 o 30 a cada lado) y cada letra que haya
  ahí, un vector de puntos a favor o en contra de cada letra candidata.
- La opinión es la suma de los vectores de las vecinas conocidas. Las vecinas
  que son huecos simplemente no votan.
- Se entrena con los puntos ciegos: tapar al azar, opinar, mirar la sorpresa
  de la letra real y mover los números para que sorprenda menos.

Es lo bastante simple para escribir sus derivadas a mano, sin maquinaria.
Después vendría el álgebra de derivadas automáticas, y con ella la atención.

## 7. Cómo se comprueba el Ada

`referencia/colapso_ref/` es un espejo: un módulo por paquete, mismas
funciones, mismos pasos en el mismo orden (incluso el orden de las sumas).
`tests/colapso_tests.adb` y `referencia/pruebas.py` hacen las mismas pruebas
con el mismo corpus diminuto. Los números esperados del Ada salen de Python.

Las pruebas tienen dos niveles. Las propiedades (no quedan huecos, las letras
dadas no cambian, la tensión no sube) deben cumplirse siempre. Las
comparaciones letra a letra con la referencia solo avisan, porque un redondeo
distinto entre máquinas puede cambiar un sorteo sin que haya ningún fallo.

## Lecturas

- *Flexible-length Text Infilling for Discrete Diffusion Models* (DDOT):
  <https://arxiv.org/pdf/2506.13579>. Explica bien la difusión enmascarada y
  por qué el largo fijo es un problema al rellenar.
- *Insertion Language Models*: <https://arxiv.org/pdf/2505.05755>. Modelos
  que insertan en cualquier posición.
- *Any-Order Flexible Length Masked Diffusion* (FlexMDM):
  <https://arxiv.org/html/2509.01025v2>. Difusión enmascarada con largo libre.
- *Edit Flows*: <https://arxiv.org/pdf/2506.09018>. Generar con operaciones
  de edición: insertar, borrar, sustituir.
- *Beyond Masks: Deletion-Insertion Processes* (DID):
  <https://arxiv.org/html/2603.23507v1>. Sustituye tapar y destapar por
  borrar e insertar.
