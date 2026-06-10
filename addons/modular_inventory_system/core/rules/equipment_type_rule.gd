class_name EquipmentTypeRule
extends SlotRule

@export var equipment_type: int = -1

func _init():
	rule_name = "Equipment Type Lock"

func can_accept_item(item: ItemDefinition, slot_index: int, inventory: Inventory) -> bool:
	if not item:
		return true
	
	if not item.has_meta("equipment_type") and not "equipment_type" in item:
		return false
	
	var item_equip_type = item.get("equipment_type") if item.has_method("get") else item.equipment_type
	return int(item_equip_type) == equipment_type

func get_rejection_reason(item: ItemDefinition, slot_index: int) -> String:
	if not item:
		return ""
	var item_type = item.get("equipment_type") if item.has_method("get") else item.equipment_type
	return "Equipment type mismatch: expected %d, got %d" % [equipment_type, item_type]
