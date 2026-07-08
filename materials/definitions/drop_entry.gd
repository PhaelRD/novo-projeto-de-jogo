@tool
extends Resource
class_name DropEntry

## Uma entrada individual de drop: um item com quantidade e chance.
## Usado dentro de StagedDropData para definir múltiplos itens por colheita.

## Item que será solto (referência direta).
@export var item: ItemDefinition = null

## Caminho do arquivo .tres do item. Use para SEMENTES para evitar loop circular.
@export_file("*.tres") var item_path: String = ""

## Quantidade solta por colheita.
@export var amount: int = 1

## Probabilidade de soltar este item (0.0 = nunca, 1.0 = sempre).
@export_range(0.0, 1.0) var drop_chance: float = 1.0

func get_item() -> ItemDefinition:
	if item: return item
	if item_path != "": return load(item_path) as ItemDefinition
	return null
