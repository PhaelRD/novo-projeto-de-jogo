@tool
class_name ItemLogic extends RefCounted

signal use_started
signal use_ended
signal use_finished(item: ItemDefinition, success: bool)
signal tool_used(item: ItemDefinition, user: Node3D, direction: Vector3, range: float)

var _item: ItemDefinition
var _player: Node
var _is_active: bool = false

func setup(item: ItemDefinition, player: Node) -> void:
	_item = item
	_player = player

func can_use() -> bool:
	return true

func on_primary_use(slot_index: int = -1) -> void:
	pass

func on_secondary_use(slot_index: int = -1) -> void:
	pass

func on_release() -> void:
	_is_active = false

func update(delta: float) -> void:
	pass

func _consume_item_durability(slot_index: int, amount: int = 1) -> bool:
	if not _player or slot_index < 0: return false
	var inv_comp = _player.get_node_or_null("InventoryComponent") as InventoryComponent
	if inv_comp and inv_comp.inventory:
		return inv_comp.inventory.consume_durability(_item, slot_index, amount)
	return false
