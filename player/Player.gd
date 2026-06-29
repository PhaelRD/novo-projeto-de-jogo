extends CharacterBody3D
class_name Player

# --- Exportações ---
@export var starting_axe: ItemDefinition
@export var toggle_action: StringName = &"toggle_inventory"

# --- Componentes e Nós ---
@onready var inventory_panel: ModularInventoryPanel  = $CanvasLayer/ModularInventoryPanel
@onready var hotbar:          ModularHotbar          = $CanvasLayer/ModularHotbar
@onready var inventory_component                     = $InventoryComponent
@onready var crafting_panel:  CraftingPanel          = $CanvasLayer/CraftingPanel
@onready var movement:        MovementComponent      = $MovementComponent
@onready var animations:      AnimationComponent     = $AnimationComponent
@onready var interaction:     InteractionComponent   = $InteractionComponent
@onready var animated_sprite                         = $AnimatedSprite3D
@onready var stamina_bar:     StaminaBar             = $CanvasLayer/StaminaBar

# --- Componentes novos (definidos na cena) ---
@onready var _hotbar_input: HotbarInputComponent     = $HotbarInputComponent
@onready var _placement: PlacementGhostComponent     = $PlacementGhostComponent

# --- Estado ---
var current_interactable: Node3D = null  # Objeto aberto no momento (ex: baú)

# ==========================================
func _ready() -> void:
	add_to_group("persist")
	animations.sprite = animated_sprite
	animations.setup()

	if inventory_panel: inventory_panel.visible = false
	if crafting_panel:  crafting_panel.visible  = false

	# Configura HotbarInputComponent
	_hotbar_input.hotbar = hotbar

	# Configura PlacementGhostComponent
	_placement.interaction         = interaction
	_placement.hotbar              = hotbar
	_placement.inventory_component = inventory_component
	_placement.inventory_panel     = inventory_panel

	# PickupComponent: o sinal já está conectado no .tscn; só passa o inventário
	var pickup = get_node_or_null("PickupComponent") as PickupComponent
	if pickup:
		pickup._inventory_component = inventory_component

	# Inventário
	if inventory_component:
		if inventory_component.inventory != null:
			call_deferred("_on_inventory_ready", inventory_component.inventory)
		else:
			inventory_component.inventory_ready.connect(_on_inventory_ready)

	if hotbar:
		hotbar.selection_changed.connect(_atualizar_visual_hotbar)
		call_deferred("_atualizar_visual_hotbar", hotbar.selected_index)

# ==========================================
func _unhandled_input(event: InputEvent) -> void:
	# --- Abrir/Fechar Inventário ---
	if event.is_action_pressed(toggle_action):
		toggle_inventory()
		get_viewport().set_input_as_handled()
		return

	# --- Hotbar (scroll + teclas 1–9) ---
	if _hotbar_input.handle_input(event):
		get_viewport().set_input_as_handled()
		return

	# --- Interação e Uso de Itens ---
	var is_left_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var is_e_key      = event is InputEventKey      and event.keycode == KEY_E and event.pressed

	if is_left_click or is_e_key:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			var target_info = interaction.get_target_info()
			var body        = target_info.get("collider")

			# Tecla E: interage com objeto ou abre inventário
			if is_e_key:
				if body and body.is_in_group("interactable") and body.has_method("interact"):
					body.interact(self)
				else:
					toggle_inventory()
				get_viewport().set_input_as_handled()
				return

			# Clique esquerdo: usa item, depois tenta interact() se o item não consumiu
			if is_left_click:
				var slot      = _get_held_slot()
				var used_item = false

				if slot and slot.item and slot.item.has_method("use"):
					used_item = slot.item.use(self, target_info)
					if used_item and hotbar:
						_atualizar_visual_hotbar(hotbar.selected_index)

				if not used_item:
					if body and body.is_in_group("interactable") and body.has_method("interact"):
						body.interact(self)

				get_viewport().set_input_as_handled()

# ==========================================
func _physics_process(delta: float) -> void:
	var input_dir = Vector3.ZERO

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input_dir = Vector3(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			0,
			Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
		).normalized()

	var real_move_dir = movement.handle_movement(self, input_dir, delta)
	animations.update_animation(input_dir)
	interaction.update_grid(global_position, real_move_dir)
	_placement.update(global_position)

# ==========================================
func toggle_inventory() -> void:
	if is_instance_valid(current_interactable) and current_interactable.has_method("close_chest"):
		current_interactable.close_chest(self)
		return
	current_interactable = null

	if not inventory_panel: return
	var vai_abrir = not inventory_panel.visible
	inventory_panel.visible = vai_abrir
	if crafting_panel:
		crafting_panel.visible = vai_abrir

	if vai_abrir:
		InputMode.ui()
	else:
		InputMode.game()

# ==========================================
# HELPERS
# ==========================================
func _get_held_slot() -> SlotData:
	if not hotbar or not inventory_component: return null
	var inv: Inventory = inventory_component.get_inventory()
	if not inv: return null
	return inv.get_slot(hotbar.get_selected_global_index())

func _atualizar_visual_hotbar(novo_indice: int) -> void:
	if not hotbar or not hotbar.slots_container: return
	var slots = hotbar.slots_container.get_children()
	for i in range(slots.size()):
		slots[i].modulate = Color(1.2, 1.2, 0.5) if i == novo_indice else Color(1.0, 1.0, 1.0)

func _on_inventory_ready(inv) -> void:
	await get_tree().process_frame
	if starting_axe:
		inv.add_item(starting_axe, 1)

# ==========================================
# SAVE / LOAD
# ==========================================
func get_save_data() -> Dictionary:
	var inv_data = []
	var inv: Inventory = inventory_component.get_inventory()

	if inv:
		for i in range(inv.slots.size()):
			var slot = inv.slots[i]
			if slot and slot.item:
				inv_data.append({
					"index": i,
					"item_path": slot.item.resource_path,
					"count": slot.count
				})

	return {
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"pos_z": global_position.z,
		"inventory": inv_data,
		"stamina": stamina_bar.get_save_data() if stamina_bar else 100
	}

func load_save_data(dados: Dictionary) -> void:
	global_position = Vector3(dados["pos_x"], dados["pos_y"], dados["pos_z"])

	if stamina_bar:
		stamina_bar.load_save_data(dados.get("stamina", stamina_bar.max_stamina))

	if dados.has("inventory"):
		var inv: Inventory = inventory_component.get_inventory()
		if inv:
			inv.clear()
			for item_data in dados["inventory"]:
				var item_res = load(item_data["item_path"]) as ItemDefinition
				if item_res:
					inv.set_slot(item_data["index"], item_res, item_data["count"])
			if hotbar: _atualizar_visual_hotbar(hotbar.selected_index)
