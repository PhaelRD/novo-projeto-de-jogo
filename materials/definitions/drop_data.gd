extends Resource
class_name DropData

@export var item: ItemDefinition ## Para itens comuns (Madeira, Maçã)
@export_file("*.tres") var item_path: String ## USE ESTE PARA A SEMENTE! (Previne o erro de Loop Circular)
@export var amount: int = 1
@export_range(0.0, 1.0) var drop_chance: float = 1.0

func get_item() -> ItemDefinition:
	if item: return item
	if item_path != "": return load(item_path) as ItemDefinition
	return null
