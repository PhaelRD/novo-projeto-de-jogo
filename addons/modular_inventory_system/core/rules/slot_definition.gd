class_name SlotDefinition
extends Resource

@export var display_name: String = ""
@export var icon_placeholder: Texture2D = null
@export var rules: Array[SlotRule] = []
@export var allow_drag_out: bool = true
@export var allow_right_click: bool = true
@export var custom_data: Dictionary = {}

func can_accept_item(item: ItemDefinition, slot_index: int, inventory: Inventory) -> bool:
	for rule in rules:
		if rule and not rule.can_accept_item(item, slot_index, inventory):
			return false
	return true

func get_rejection_reason(item: ItemDefinition, slot_index: int) -> String:
	for rule in rules:
		if rule:
			var reason = rule.get_rejection_reason(item, slot_index)
			if reason != "":
				return reason
	return ""

func is_locked() -> bool:
	for rule in rules:
		if rule is ItemTagRule and (rule as ItemTagRule).required_tags.is_empty() == false:
			continue
	return false
