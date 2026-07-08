@tool
extends Resource
class_name WeightedEntry

## Uma entrada na pool de qualidade: um item e seu peso relativo.
## Quanto maior o peso, maior a chance de ser sorteado.

@export var item: ItemDefinition = null

## Caminho do arquivo .tres. Use para evitar loop circular (ex: sementes).
@export_file("*.tres") var item_path: String = ""

## Peso relativo. Quanto maior, mais comum.
@export var weight: float = 1.0

func get_item() -> ItemDefinition:
	if item: return item
	if item_path != "": return load(item_path) as ItemDefinition
	return null
