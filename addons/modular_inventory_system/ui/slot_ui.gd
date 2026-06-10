extends Control
class_name SlotUI
signal drag_started(slot_index: int, button: MouseButton, is_right_click: bool)
signal drag_ended(slot_index: int)
signal slot_input_event(event: InputEvent)
signal tooltip_requested(slot_data: SlotData, global_pos: Vector2)
signal tooltip_hidden()

@export_node_path("TextureRect") var icon_path: NodePath = ^"Icon"
@export_node_path("Label") var count_label_path: NodePath = ^"CountLabel"
@export_node_path("TextureRect") var placeholder_path: NodePath = ^"Placeholder"
@export_node_path("Control") var durability_bar_path: NodePath = ^"DurabilityBar"
@export_node_path("ColorRect") var durability_fill_path: NodePath = ^"DurabilityFill"

var icon_rect: TextureRect
var count_label: Label
var placeholder: TextureRect
var durability_bar: Control
var durability_fill: ColorRect

var slot_index: int = -1
var _current_slot_data: SlotData = null

@export var enable_tooltip: bool = true
@export var tooltip_delay: float = 0.3
var _tooltip_timer: Timer
var _is_hovering: bool = false

var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_started: bool = false
const DRAG_THRESHOLD: float = 0.5

func _ready() -> void:
	icon_rect = get_node_or_null(icon_path) as TextureRect
	count_label = get_node_or_null(count_label_path) as Label
	placeholder = get_node_or_null(placeholder_path) as TextureRect
	durability_bar = get_node_or_null(durability_bar_path) as Control
	durability_fill = get_node_or_null(durability_fill_path) as ColorRect
	
	if durability_bar:
		durability_bar.visible = false
		
	if enable_tooltip:
		_tooltip_timer = Timer.new()
		_tooltip_timer.one_shot = true
		_tooltip_timer.timeout.connect(_show_tooltip)
		add_child(_tooltip_timer)
		
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		
	if slot_index >= 0:
		_refresh_visuals()

func _gui_input(event: InputEvent) -> void:
	slot_input_event.emit(event)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.shift_pressed:
					var inv = get_meta("inventory", null) as Inventory
					var idx = get_meta("slot_index", -1) as int
					if inv and idx >= 0:
						var target = _find_other_open_inventory(inv)
						if target:
							InventoryTransfer.transfer(inv, target, idx, 0)
					accept_event()
				else:
					_drag_start_pos = event.global_position
					_drag_started = true
					accept_event()
			else:
				_drag_started = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if _current_slot_data and not _current_slot_data.is_empty():
					_handle_right_click_move()
			accept_event()
	elif event is InputEventMouseMotion and _drag_started and not DragDropSystem.is_dragging:
			if event.global_position.distance_to(_drag_start_pos) > DRAG_THRESHOLD:
				var inv = get_meta("inventory", null) as Inventory
				var idx = get_meta("slot_index", -1) as int
				if inv and idx >= 0 and _current_slot_data and not _current_slot_data.is_empty():
					DragDropSystem.start_drag(inv, _current_slot_data, idx, MOUSE_BUTTON_LEFT, false)
					_drag_started = false

func _handle_right_click_move() -> void:
	var source_inv = get_meta("inventory", null) as Inventory
	var source_idx = get_meta("slot_index", -1) as int
	
	if not source_inv or source_idx < 0:
		return
	
	var target_inv = _find_other_open_inventory(source_inv)
	
	if target_inv:
		InventoryTransfer.transfer(source_inv, target_inv, source_idx, 1)
		
func _find_other_open_inventory(current_inv: Inventory) -> Inventory:
	for panel in get_tree().get_nodes_in_group("modular_inventory_panel"):
		if panel is ModularInventoryPanel and panel.visible:
			var panel_inv = panel._inventory
			if panel_inv and panel_inv != current_inv:
				return panel_inv
	return null
	
func _on_mouse_entered() -> void:
	_is_hovering = true
	if enable_tooltip and _current_slot_data and not _current_slot_data.is_empty():
		if _tooltip_timer:
			_tooltip_timer.start(tooltip_delay)

func _on_mouse_exited() -> void:
	_is_hovering = false
	if _tooltip_timer:
		_tooltip_timer.stop()
	tooltip_hidden.emit()

func _show_tooltip() -> void:
	if _is_hovering and _current_slot_data and not _current_slot_data.is_empty():
		tooltip_requested.emit(_current_slot_data, get_global_mouse_position())

func set_slot_data(slot_data: SlotData, index: int) -> void:
	slot_index = index
	_current_slot_data = slot_data
	_refresh_visuals()

func _refresh_visuals() -> void:
	var slot_data: SlotData = _get_slot_data_from_meta()
	_current_slot_data = slot_data
	if slot_data == null or slot_data.is_empty():
		if icon_rect:
			icon_rect.texture = null
			icon_rect.visible = false
		if count_label:
			count_label.visible = false
		if durability_bar:
			durability_bar.visible = false
		_update_placeholder(true)
		return

	if icon_rect:
		var has_icon = slot_data.item and slot_data.item.icon
		icon_rect.texture = slot_data.item.icon if has_icon else null
		icon_rect.visible = has_icon

	if count_label:
		count_label.visible = slot_data.count > 1
		count_label.text = str(slot_data.count)

	_update_durability_display(slot_data)
	_update_placeholder(slot_data == null or slot_data.is_empty())

func _update_placeholder(show: bool) -> void:
	if placeholder:
		placeholder.visible = show and (not icon_rect or not icon_rect.visible)

func _update_durability_display(slot_data: SlotData) -> void:
	if not durability_bar or not durability_fill or not slot_data.item: return
	if not slot_data.item.has_durability:
		durability_bar.visible = false
		return
		
	var current = slot_data.get_effective_durability()
	var max = slot_data.item.max_durability
	var percent = clamp(float(current) / float(max), 0.0, 1.0)
	
	durability_bar.visible = true
	durability_fill.size.x = durability_bar.size.x * percent
	durability_fill.color = Color.GREEN if percent > 0.5 else Color.YELLOW if percent > 0.25 else Color.RED
	durability_fill.modulate.a = 0.3 if current <= 0 else 1.0

func _get_slot_data_from_meta() -> SlotData:
	var inv = get_meta("inventory", null) as Inventory
	var idx = get_meta("slot_index", -1) as int
	if inv and idx >= 0 and idx < inv.capacity:
		return inv.get_slot(idx)
	return null

func set_drop_valid(is_valid: bool) -> void:
	var style = get_theme_stylebox("panel", "SlotUI")
	if style and style is StyleBoxFlat:
		style.border_color = Color.GREEN if is_valid else Color.RED

static func generate_tooltip_text(slot_data: SlotData) -> String:
	if not slot_data or not slot_data.item: return ""
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]" % slot_data.item.display_name)
	if slot_data.item.description: lines.append(slot_data.item.description)
	lines.append("")
	if slot_data.item.max_stack_size > 1:
		lines.append("Stack: %d / %d" % [slot_data.count, slot_data.item.max_stack_size])
	if slot_data.item.has_durability:
		var current = slot_data.get_effective_durability()
		var max = slot_data.item.max_durability
		var percent = int((float(current) / float(max)) * 100)
		var status = "Broken" if current <= 0 else "%d%%" % percent
		lines.append("Durability: [color=%s]%s[/color]" % ["red" if current <= 0 else "yellow" if current < max * 0.3 else "green", "%d / %d (%s)" % [current, max, status]])
	if slot_data.item.weight > 0:
		lines.append("Weight: %.1f" % slot_data.item.weight)
	if not slot_data.item.tags.is_empty():
		lines.append("Tags: " + ", ".join(slot_data.item.tags))
	return "\n".join(lines)
