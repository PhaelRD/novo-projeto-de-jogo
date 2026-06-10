class_name MaxOneRule
extends SlotRule

func _init():
	rule_name = "Max Stack: 1"

func can_accept_item(item: ItemDefinition, slot_index: int, inventory: Inventory) -> bool:
	if not item:
		return true
	var slot = inventory.get_slot(slot_index)
	if slot and not slot.is_empty():
		return slot.item == item and slot.count + 1 <= item.max_stack_size
	return item.max_stack_size <= 1

func get_rejection_reason(item: ItemDefinition, slot_index: int) -> String:
	if item and item.max_stack_size > 1:
		return "This slot does not allow stacking"
	return ""
