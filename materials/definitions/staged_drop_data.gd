@tool
extends Resource
class_name StagedDropData

## Define os drops de um estágio específico de colheita.
## Cada entrada pode conter múltiplos itens via o array 'items'.

@export_group("Estágio de Colheita")
## Em qual estágio de crescimento estes drops ocorrem.
## Use -1 para indicar "apenas no estágio final" (comportamento clássico).
@export var harvest_stage: int = -1

@export_group("Itens Soltos")
## Lista de itens que podem ser soltos neste estágio.
## Cada DropEntry tem seu próprio item, quantidade e chance.
@export var items: Array[DropEntry] = []
