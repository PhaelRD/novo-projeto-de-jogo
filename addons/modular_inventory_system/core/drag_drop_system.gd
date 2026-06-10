extends Node

signal drag_started(inv: Inventory, data: SlotData, source_idx: int)
signal drag_ended
signal dropped(target_inv: Inventory, target_idx: int, amount: int)

var _drag_button: MouseButton = MOUSE_BUTTON_LEFT
var _is_right_click_drag: bool = false
var is_dragging: bool = false
var source_inv: Inventory
var source_data: SlotData
var source_idx: int = -1
var drag_amount: int = 0
var preview_layer: CanvasLayer
var preview_rect: TextureRect
var preview_label: Label

const DRAG_PREVIEW_SIZE := Vector2(64, 64)

func _ready():
	preview_layer = CanvasLayer.new()
	preview_layer.layer = 100
	preview_layer.scale = Vector2.ONE			
	_update_label_text()
	add_child(preview_layer)

func start_drag(inv: Inventory, data: SlotData, idx: int, button: MouseButton = MOUSE_BUTTON_LEFT, is_right_click: bool = false):
	if is_dragging or not data or data.is_empty():
		return
	source_inv = inv
	source_data = data
	source_idx = idx
	_drag_button = button
	_is_right_click_drag = is_right_click
	
	if is_right_click:
		drag_amount = max(1, int(ceil(float(data.count) / 2.0)))
	else:
		drag_amount = data.count
		
	is_dragging = true
	_create_preview()
	_update_label_text()
	drag_started.emit(inv, data, idx)

func end_drag():
	is_dragging = false
	source_inv = null
	source_data = null
	source_idx = -1
	drag_amount = 0
	_cleanup_preview()
	drag_ended.emit()

func set_drop_target(target_inv: Inventory, target_idx: int):
	if not is_dragging:
		return
	var ctx = {"inventory": target_inv, "slot_index": target_idx}
	if _perform_drop(ctx):
		end_drag()


func _input(event: InputEvent):
	if not is_dragging:
		return
	if event is InputEventMouseMotion:
		_update_preview_position(event.global_position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == _drag_button and not event.pressed:
			var target = _get_drop_target(event.global_position)
			if target:
				set_drop_target(target["inventory"], target["slot_index"])
			else:
				_drop_to_world()
			end_drag()
			get_viewport().set_input_as_handled()
			
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _is_right_click_drag:
			drag_amount = 1
			_update_label_text()
			get_viewport().set_input_as_handled()
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			drag_amount = min(source_data.count, drag_amount + 1)
			_update_label_text()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			drag_amount = max(1, drag_amount - 1)
			_update_label_text()
			get_viewport().set_input_as_handled()
			
func _create_preview():
	if not source_data or not source_data.item or not source_data.item.icon:
		return

	var wrapper = Control.new()
	wrapper.top_level = true
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.size = DRAG_PREVIEW_SIZE
	wrapper.set_anchors_preset(Control.PRESET_TOP_LEFT)
	wrapper.z_index = 100
	preview_layer.add_child(wrapper)

	preview_rect = TextureRect.new()
	preview_rect.texture = source_data.item.icon
	preview_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_rect.stretch_mode = TextureRect.STRETCH_SCALE
	preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(preview_rect)

	preview_label = Label.new()
	preview_label.text = str(drag_amount)
	preview_label.visible = true
	preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_label.top_level = true
	preview_label.z_index = 101
	preview_label.add_theme_color_override("font_color", Color.WHITE)
	preview_label.add_theme_font_size_override("font_size", 16)
	preview_label.add_theme_constant_override("shadow_offset_x", 1)
	preview_label.add_theme_constant_override("shadow_offset_y", 1)
	preview_label.add_theme_color_override("shadow_color", Color.BLACK)
	preview_layer.add_child(preview_label)
	
	if wrapper:
		wrapper.global_position = get_viewport().get_mouse_position() - (DRAG_PREVIEW_SIZE / 2.0)
		
func _update_label_text():
	if not preview_label:
		return
	
	if drag_amount > 1:
		preview_label.text = str(drag_amount)
		preview_label.visible = true
		preview_label.modulate = Color.WHITE
		preview_label.add_theme_font_size_override("font_size", 16)
	else:
		preview_label.visible = false
		
func _update_preview_position(pos: Vector2):
	if preview_rect and preview_rect.get_parent():
		preview_rect.get_parent().global_position = pos - (DRAG_PREVIEW_SIZE / 2.0)
	
	if preview_label:
		preview_label.global_position = pos + Vector2(12, 12)

func _cleanup_preview():
	if preview_rect:
		var parent = preview_rect.get_parent()
		if parent:
			parent.queue_free()
		preview_rect = null
	if preview_label:
		preview_label.queue_free()
		preview_label = null


func _perform_drop(ctx: Dictionary) -> bool:
	if not ctx.has("inventory") or not ctx.has("slot_index"): return false
	
	var target_inv: Inventory = ctx["inventory"]
	var target_idx: int = ctx["slot_index"]
	var amount = clamp(drag_amount, 1, source_data.count if source_data else 1)
	
	var success = InventoryTransfer.drop_to_slot(source_inv, target_inv, source_idx, target_idx, amount)
	if success:
		dropped.emit(target_inv, target_idx, amount)
		return success
	return false
	
func _drop_to_world():
	if not source_inv or not source_data:
		return
	
	var player = _find_player_node()
	if not player:
		# AGORA ELE AVISA SE NÃO ACHAR O JOGADOR!
		push_error("DragDropSystem: Erro - Não encontrou o Jogador! Verifique se o Player está no grupo 'player'.")
		return
	
	var dropped_scene_path = "res://addons/modular_inventory_system/world/dropped_item.tscn"
	var dropped_scene = load(dropped_scene_path)
	if not dropped_scene:
		push_error("DragDropSystem: Erro - Cena não encontrada no caminho: " + dropped_scene_path)
		return
	
	var dropped_item = dropped_scene.instantiate()
	dropped_item.item_ = source_data.item
	dropped_item.count = drag_amount
	
	# Se o item tiver durabilidade
	if source_data.current_durability > 0:
		dropped_item.set_meta("durability", source_data.get_effective_durability())
	
	# Adiciona à cena ANTES de mover a posição
	get_tree().root.add_child(dropped_item)
	
	var forward = -player.global_transform.basis.z.normalized()
	var drop_pos = player.global_position + (forward * 1.5) + Vector3(0, 1.0, 0)
	dropped_item.global_position = drop_pos
	
	if dropped_item is RigidBody3D:
		dropped_item.apply_central_impulse(Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)))
	
	# MENSAGEM DE SUCESSO!
	print("SUCESSO: DragDropSystem dropou " + str(drag_amount) + "x " + source_data.item.display_name + " no mundo!")
	
	# Remove do inventário usando a função nativa segura
	source_inv.remove_item(source_data.item, drag_amount)
func _find_player_node() -> Node3D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	for child in get_tree().root.get_children():
		if child is CharacterBody3D:
			return child
	return null

func _get_drop_target(pos: Vector2) -> Dictionary:
	var targets = get_tree().get_nodes_in_group("inventory_drop_targets")
	for t in targets:
		if t is Control and t.get_global_rect().has_point(pos):
			return {
				"inventory": t.get_meta("inventory"),
				"slot_index": t.get_meta("slot_index")
			}
	return {}
