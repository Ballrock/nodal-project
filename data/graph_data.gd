class_name GraphData
extends Resource

## Conteneur racine du graphe nodal. Stocke boîtes, liens et échelle timeline.

@export var boxes: Array[BoxData] = []
@export var links: Array[LinkData] = []
@export var timeline_scale: float = 100.0  # pixels par seconde
