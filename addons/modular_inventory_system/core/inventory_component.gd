@tool
extends Node
class_name InventoryComponent

signal inventory_ready(inv: Inventory)

@export_group("Inventory Data")
@export var inventory: Inventory:
	set(value):
		if inventory == value: return
		inventory = value

@export var capacity: int = 20
@export var slot_definitions: Array[SlotDefinition] = []

@export_group("Runtime")
@export var create_if_missing: bool = true

func _ready():
	if Engine.is_editor_hint(): return
	_ensure_inventory()

func _ensure_inventory():
	if not inventory and create_if_missing:
		inventory = Inventory.new(capacity)
		if not slot_definitions.is_empty():
			inventory.slot_definitions = slot_definitions.duplicate(true)
	
	if inventory:
		inventory_ready.emit(inventory)


func _on_inv_changed(): pass
func _on_slot_changed(idx: int): pass

func get_inventory() -> Inventory:
	return inventory
