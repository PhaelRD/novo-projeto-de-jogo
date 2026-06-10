class_name Inventory
extends Resource

signal inventory_changed
signal slot_changed(slot_index: int)
signal item_added(item: ItemDefinition, count: int)
signal item_removed(item: ItemDefinition, count: int)

@export var capacity: int = 20
@export var slot_definitions: Array[SlotDefinition] = []

var slots: Array[SlotData] = []

func _init(p_capacity: int = 20) -> void:
	capacity = p_capacity
	slots.resize(capacity)
	for i in capacity:
		slots[i] = SlotData.new()
	if slot_definitions.is_empty():
		for i in capacity:
			slot_definitions.append(SlotDefinition.new())

func get_slot(index: int) -> SlotData:
	if index < 0 or index >= capacity: return null
	return slots[index]

func set_slot(index: int, item: ItemDefinition, count: int) -> void:
	if index < 0 or index >= capacity:
		return
	slots[index].set_value(item, count)
	slot_changed.emit(index)
	inventory_changed.emit()

func add_item(item: ItemDefinition, amount: int = 1) -> int:
	if not item or amount <= 0: return amount
	var remaining := amount
	
	for i in capacity:
		if remaining <= 0: break
		var slot := slots[i]
		if slot.item == item and not slot.is_empty():
			var def := _get_slot_def(i)
			if def and not def.can_accept_item(item, i, self): continue
			var space := item.max_stack_size - slot.count
			var to_add := mini(space, remaining)
			slot.count += to_add
			remaining -= to_add
			slot_changed.emit(i)
	
	for i in capacity:
		if remaining <= 0: break
		var slot := slots[i]
		if slot.is_empty():
			var def := _get_slot_def(i)
			if def and not def.can_accept_item(item, i, self): continue
			var to_add := mini(item.max_stack_size, remaining)
			slot.set_value(item, to_add)
			remaining -= to_add
			slot_changed.emit(i)
	
	if remaining < amount:
		item_added.emit(item, amount - remaining)
		inventory_changed.emit()
	return remaining

func remove_item(item: ItemDefinition, amount: int = 1) -> bool:
	if not item or amount <= 0: return false
	var remaining := amount
	for i in capacity:
		if remaining <= 0: break
		var slot := slots[i]
		if slot.item == item and not slot.is_empty():
			var to_remove := mini(slot.count, remaining)
			slot.count -= to_remove
			remaining -= to_remove
			if slot.count <= 0:
				slot.clear()
			slot_changed.emit(i)
	
	if remaining < amount:
		item_removed.emit(item, amount - remaining)
		inventory_changed.emit()
		return true
	return false
	
func can_accept_at_slot(item: ItemDefinition, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= capacity:
		return false
	var slot_def = _get_slot_definition(slot_index)
	if slot_def and not slot_def.can_accept_item(item, slot_index, self):
		return false
	var slot = slots[slot_index]
	if slot.is_empty():
		return true
	if slot.item == item and slot.count + 1 <= item.max_stack_size:
		return true
	return false

func clear() -> void:
	for i in capacity:
		slots[i].clear()
		slot_changed.emit(i)
	inventory_changed.emit()

func _get_slot_def(index: int) -> SlotDefinition:
	return slot_definitions[index] if index < slot_definitions.size() else null

func _get_slot_definition(index: int) -> SlotDefinition:
	if index < 0 or index >= slot_definitions.size():
		return null
	return slot_definitions[index]

func debug_print(label: String = "Inventory") -> void:
	print("Inventory %s capacity %d" % [label, capacity])
	for i in capacity:
		var slot = slots[i]
		var def = _get_slot_definition(i)
		var item_info = "empty" if slot.is_empty() else "%s x%d" % [slot.item.display_name, slot.count]
		var rules_info = "" if not def or def.rules.is_empty() else " [%d rules]" % def.rules.size()
		print("  [%d] %s%s" % [i, item_info, rules_info])

func consume_durability(item: ItemDefinition, slot_index: int, amount: int = 1) -> bool:
	if not item or not item.has_durability: return true
	var slot = get_slot(slot_index)
	if not slot or slot.item != item: return false
	
	slot.current_durability = max(0, slot.current_durability - amount)
	slot_changed.emit(slot_index)
	
	if slot.current_durability <= 0 and item.break_on_zero:
		slot.clear()
		slot_changed.emit(slot_index)
		inventory_changed.emit()
		return true
	return false
