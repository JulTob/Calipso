"""Espejo de Colapso.Oracles: el contrato de cualquier "cerebro".

Un oráculo responde a una sola pregunta:

    "Mirando lo que hay alrededor, ¿qué letra crees que va en esta celda?"

y contesta con una distribución (una opinión con dudas, no una letra).

El motor de colapso solo conoce este contrato. Hoy el cerebro es una tabla
de cuentas; mañana será una red neuronal. El motor no cambiará.
"""

from . import canvases
from . import distributions


class Oracle:

    def Alphabet_Size(self) -> int:
        raise NotImplementedError

    def Reach(self) -> int:
        #-- A cuántas celdas de distancia puede influir una letra en la opinión sobre otra.
        raise NotImplementedError

    def Opinion(
            self,
            board: canvases.Canvas,
            position: int
            ) -> distributions.Distribution:
        #-- Opinión sobre la celda `position` mirando SOLO a sus vecinas, nunca a ella misma.
        raise NotImplementedError
