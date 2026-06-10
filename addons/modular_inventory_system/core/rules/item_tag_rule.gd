class_name ItemTagRule
extends SlotRule

@export var required_tags: Array[String] = []
@export var match_any: bool = false

func _init():
	rule_name = "Item Tag Filter"

func can_accept_item(item: ItemDefinition, slot_index: int, inventory: Inventory) -> bool:
	if not item:
		return true
	
	if required_tags.is_empty():
		return true
	
	if match_any:
		for tag in required_tags:
			if _item_has_tag(item, tag):
				return true
		return false
	else:
		for tag in required_tags:
			if not _item_has_tag(item, tag):
				return false
		return true

func _item_has_tag(item: ItemDefinition, tag: String) -> bool:
	if item.has_method("has_tag"):
		return item.has_tag(tag)
	elif item.has_meta("tags") and item.get_meta("tags") is Array:
		return tag in item.get_meta("tags")
	return false

func get_rejection_reason(item: ItemDefinition, slot_index: int) -> String:
	if required_tags.is_empty():
		return ""
	var tag_list = ", ".join(required_tags)
	return "Requires tag: %s" % tag_list
