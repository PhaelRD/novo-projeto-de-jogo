class_name InventoryTransfer
extends RefCounted

static func transfer(source: Inventory, target: Inventory, source_slot_index: int, amount: int = 0) -> int:
	if not source or not target or source_slot_index < 0:
		return 0
	
	var src_slot = source.get_slot(source_slot_index)
	if not src_slot or src_slot.is_empty():
		return 0
	
	var item = src_slot.item
	var available = min(amount, src_slot.count) if amount > 0 else src_slot.count
	if available <= 0:
		return 0
	
	var moved = 0
	var remaining = available
	
	for i in target.capacity:
		if remaining <= 0:
			break
		var tgt_slot = target.get_slot(i)
		if tgt_slot and tgt_slot.item == item and not tgt_slot.is_empty():
			var space = item.max_stack_size - tgt_slot.count
			if space > 0 and target.can_accept_at_slot(item, i):
				var to_add = min(space, remaining)
				tgt_slot.count += to_add
				remaining -= to_add
				moved += to_add
				target.slot_changed.emit(i)
	
	for i in target.capacity:
		if remaining <= 0:
			break
		var tgt_slot = target.get_slot(i)
		if tgt_slot and tgt_slot.is_empty() and target.can_accept_at_slot(item, i):
			var to_add = min(item.max_stack_size, remaining)
			tgt_slot.set_value(item, to_add)
			remaining -= to_add
			moved += to_add
			target.slot_changed.emit(i)
	
	if moved > 0:
		src_slot.count -= moved
		if src_slot.count <= 0:
			src_slot.clear()
		source.slot_changed.emit(source_slot_index)
		source.inventory_changed.emit()
		target.inventory_changed.emit()
	
	return moved

static func drop_to_slot(source: Inventory, target: Inventory, source_slot_index: int, target_slot_index: int, amount: int = 0) -> bool:
	if not source or not target: return false
	
	if amount <= 0:
		amount = DragDropSystem.drag_amount
	if amount <= 0: return false
	
	var src_slot = source.get_slot(source_slot_index)
	var tgt_slot = target.get_slot(target_slot_index)
	if not src_slot or src_slot.is_empty(): return false
	
	var src_item = src_slot.item
	var tgt_item = tgt_slot.item
	var src_count = src_slot.count
	
	var is_swap = not tgt_slot.is_empty() and tgt_item != src_item
	
	if is_swap:
		if amount < src_count:
			print("Swap rejected: Must drag full stack to swap items.")
			return false

		var tgt_def = target.slot_definitions[target_slot_index] if target_slot_index < target.slot_definitions.size() else null
		if tgt_def and not tgt_def.can_accept_item(src_item, target_slot_index, target):
			print("Swap failed: Target slot rules reject %s" % src_item.display_name)
			return false
			
		var src_def = source.slot_definitions[source_slot_index] if source_slot_index < source.slot_definitions.size() else null
		if src_def and not src_def.can_accept_item(tgt_item, source_slot_index, source):
			print("Swap failed: Source slot rules reject %s" % tgt_item.display_name)
			return false
			
		var temp_item = tgt_slot.item
		var temp_count = tgt_slot.count
		var temp_dur = tgt_slot.current_durability
		
		tgt_slot.set_value(src_item, src_count, src_slot.current_durability)
		src_slot.set_value(temp_item, temp_count, temp_dur)
		
		_emit_changes(source, target, source_slot_index, target_slot_index)
		print("SWAP SUCCESSFUL")
		return true
		
	else:
		if not target.can_accept_at_slot(src_item, target_slot_index):
			print("Target slot %d rejects %s" % [target_slot_index, src_item.display_name])
			return false

		if tgt_slot.is_empty():
			var durability_to_transfer = src_slot.current_durability
			if src_item.has_durability and src_count > amount:
				durability_to_transfer = max(0, int(src_slot.current_durability * float(amount) / float(src_count)))
			tgt_slot.set_value(src_item, amount, durability_to_transfer)
			src_slot.count -= amount
			if src_slot.count <= 0: src_slot.clear()
			elif src_item.has_durability:
				src_slot.current_durability = max(0, src_slot.current_durability - durability_to_transfer)
			_emit_changes(source, target, source_slot_index, target_slot_index)
			return true
			
		if tgt_item == src_item and src_item.max_stack_size > 1:
			var space = src_item.max_stack_size - tgt_slot.count
			var to_add = min(space, amount)
			if to_add > 0:
				if src_item.has_durability:
					tgt_slot.current_durability = max(tgt_slot.current_durability, src_slot.current_durability)
				tgt_slot.count += to_add
				src_slot.count -= to_add
				if src_slot.count <= 0: src_slot.clear()
				_emit_changes(source, target, source_slot_index, target_slot_index)
				return true
			
	return false

static func _emit_changes(source: Inventory, target: Inventory, src_idx: int, tgt_idx: int) -> void:
	source.slot_changed.emit(src_idx)
	source.inventory_changed.emit()
	if target != source:
		target.slot_changed.emit(tgt_idx)
		target.inventory_changed.emit()

static func quick_move(source: Inventory, target: Inventory, source_slot_index: int) -> bool:
	var src_slot = source.get_slot(source_slot_index)
	if not src_slot or src_slot.is_empty():
		return false
	
	var item = src_slot.item
	var count = src_slot.count
	
	for i in target.capacity:
		if target.can_accept_at_slot(item, i):
			var tgt_slot = target.get_slot(i)
			if tgt_slot.is_empty() or (tgt_slot.item == item and tgt_slot.count < item.max_stack_size):
				if tgt_slot.is_empty():
					tgt_slot.set_value(item, count)
				else:
					var space = item.max_stack_size - tgt_slot.count
					var to_add = min(space, count)
					tgt_slot.count += to_add
					src_slot.count -= to_add
				src_slot.count -= count if tgt_slot.is_empty() else min(count, tgt_slot.count - (tgt_slot.count - count))
				if src_slot.count <= 0:
					src_slot.clear()
				source.slot_changed.emit(source_slot_index)
				target.slot_changed.emit(i)
				source.inventory_changed.emit()
				target.inventory_changed.emit()
				return true
	return false
