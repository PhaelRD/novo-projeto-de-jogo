@tool
extends InventoryUI
class_name ModularInventoryPanel

@export var grid_container: GridContainer
@export var slot_scene: PackedScene = preload("res://addons/modular_inventory_system/ui/slot_ui.tscn")
@export var tooltip: ItemTooltip
var slot_uis: Array[SlotUI] = []

func _ready():
	super._ready()
	add_to_group("modular_inventory_panel")
	if not tooltip:
		tooltip = _auto_find_tooltip()
		
func _on_inventory_attached(inv: Inventory):
	_setup_slots(inv)

func _refresh_all():
	for i in slot_uis.size():
		_refresh_slot(i)

func _refresh_slot(local_idx: int):
	var slot_ui = slot_uis[local_idx]
	var global_idx = slot_ui.get_meta("slot_index", -1)
	if global_idx >= 0 and _inventory:
		slot_ui.set_slot_data(_inventory.get_slot(global_idx), global_idx)

func _setup_slots(inv: Inventory):
	_clear_slots()
	if not grid_container or not slot_scene: return
	
	for i in inv.capacity:
		var slot_ui = slot_scene.instantiate() as SlotUI
		grid_container.add_child(slot_ui)
		slot_uis.append(slot_ui)
		slot_ui.set_meta("inventory", inv)
		slot_ui.set_meta("slot_index", i)
		slot_ui.add_to_group("inventory_drop_targets")
		slot_ui.slot_input_event.connect(_on_slot_input.bind(i))
		slot_ui.tooltip_requested.connect(_on_tooltip_requested)
		slot_ui.tooltip_hidden.connect(_on_tooltip_hidden)
		_refresh_slot(i)

func _clear_slots():
	for s in slot_uis: if is_instance_valid(s): s.queue_free()
	slot_uis.clear()

func _on_slot_input(event: InputEvent, local_idx: int):
	var global_idx = local_idx
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			pass
			
func _on_tooltip_requested(slot_data: SlotData, pos: Vector2):
	if tooltip: tooltip.show_tooltip(slot_data, pos)

func _on_tooltip_hidden():
	if tooltip: tooltip.hide_tooltip()

func _auto_find_tooltip() -> ItemTooltip:
	for node in get_tree().get_nodes_in_group("item_tooltip"):
		if node is ItemTooltip: return node as ItemTooltip
	var canvas = get_node_or_null("../../CanvasLayer") as CanvasLayer
	if canvas:
		for child in canvas.find_children("", "ItemTooltip", true, false):
			return child as ItemTooltip
	return null
