class_name SlotData
extends Resource

@export var item: ItemDefinition = null
@export var count: int = 0
@export var current_durability: int = -1

func _init(p_item: ItemDefinition = null, p_count: int = 0, p_durability: int = -1):
	item = p_item
	count = p_count
	current_durability = p_durability
	if current_durability < 0 and item and item.has_durability:
		current_durability = item.max_durability

func get_effective_durability() -> int:
	if not item or not item.has_durability:
		return -1
	return current_durability if current_durability >= 0 else item.max_durability

func is_empty() -> bool:
	return item == null or count <= 0

func is_broken() -> bool:
	return item and item.has_durability and get_effective_durability() <= 0

func set_value(p_item: ItemDefinition, p_count: int, p_durability: int = -1):
	item = p_item
	count = p_count
	if p_durability >= 0:
		current_durability = p_durability
	elif item and item.has_durability:
		current_durability = item.max_durability
	else:
		current_durability = -1

func clear():
	item = null
	count = 0
	current_durability = -1

func copy() -> SlotData:
	var new_slot = SlotData.new()
	new_slot.item = item
	new_slot.count = count
	new_slot.current_durability = current_durability
	return new_slot
