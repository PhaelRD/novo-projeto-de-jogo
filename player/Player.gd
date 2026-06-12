extends CharacterBody3D
class_name Player

# --- Exportações ---
@export var starting_axe: ItemDefinition 
@export var toggle_action: StringName = &"toggle_inventory"

# --- Componentes e Nós ---
@onready var inventory_panel: ModularInventoryPanel = $CanvasLayer/ModularInventoryPanel
@onready var hotbar: ModularHotbar = $CanvasLayer/ModularHotbar
@onready var inventory_component = $InventoryComponent 

@onready var movement: MovementComponent = $MovementComponent
@onready var animations: AnimationComponent = $AnimationComponent
@onready var interaction: InteractionComponent = $InteractionComponent
@onready var animated_sprite = $AnimatedSprite3D

func _ready() -> void:
	# 1. Entra no grupo de save!
	add_to_group("persist")
	
	# 2. Liga as animações
	animations.sprite = animated_sprite
	animations.setup()
	
	# 3. Inicializa o inventário
	if inventory_component:
		if inventory_component.inventory != null:
			_on_inventory_ready(inventory_component.inventory)
		else:
			inventory_component.inventory_ready.connect(_on_inventory_ready)
			
	# 4. Conecta o sinal visual da Hotbar
	if hotbar:
		hotbar.selection_changed.connect(_atualizar_visual_hotbar)
		call_deferred("_atualizar_visual_hotbar", hotbar.selected_index)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		toggle_inventory()
		get_viewport().set_input_as_handled()

	if hotbar:
		for i in range(1, 10):
			var action_name = "hotbar_" + str(i)
			if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
				hotbar.selected_index = i - 1
				get_viewport().set_input_as_handled()
				return 

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if _is_holding_axe():
				interaction.use_axe(animated_sprite)

func toggle_inventory() -> void:
	if not inventory_panel: return
	inventory_panel.visible = not inventory_panel.visible
	if inventory_panel.visible:
		InputMode.ui()      
	else:
		InputMode.game()    

func _physics_process(delta: float) -> void:
	var input_dir = Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0,
		Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	).normalized()

	var real_move_dir = movement.handle_movement(self, input_dir, delta)
	animations.update_animation(input_dir)
	interaction.update_grid(global_position, real_move_dir)

func _is_holding_axe() -> bool:
	if not hotbar or not inventory_component: return false
	var inv: Inventory = inventory_component.get_inventory()
	if not inv: return false
	
	var selected_index = hotbar.get_selected_global_index()
	var slot_data = inv.get_slot(selected_index)
	
	return slot_data and slot_data.item == starting_axe

func _on_inventory_ready(inv):
	# Adiciona o Machado inicial se ele estiver configurado no painel
	if starting_axe: inv.add_item(starting_axe, 1)

func _on_pickup_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("dropped_item") and inventory_component and inventory_component.inventory:
		var remaining = inventory_component.inventory.add_item(body.item_, body.count)
		if remaining == 0:
			body.queue_free()
		elif remaining < body.count:
			body.count = remaining

func _atualizar_visual_hotbar(novo_indice: int) -> void:
	if not hotbar or not hotbar.slots_container: return
	var slots = hotbar.slots_container.get_children()
	for i in range(slots.size()):
		var slot_ui = slots[i]
		if i == novo_indice:
			slot_ui.modulate = Color(1.2, 1.2, 0.5) 
		else:
			slot_ui.modulate = Color(1.0, 1.0, 1.0)

# ==========================================
# SISTEMA DE SAVE / LOAD DO PLAYER
# ==========================================

func get_save_data() -> Dictionary:
	var inv_data = []
	var inv: Inventory = inventory_component.get_inventory()
	
	if inv:
		# Varre todos os slots do inventário
		for i in range(inv.slots.size()):
			var slot = inv.slots[i]
			# Se tiver um item naquele slot, nós salvamos o caminho do arquivo dele
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
		"inventory": inv_data
	}

func load_save_data(dados: Dictionary) -> void:
	# 1. Devolve o Player para a coordenada onde ele parou
	global_position = Vector3(dados["pos_x"], dados["pos_y"], dados["pos_z"])
	
	# 2. Devolve os itens no inventário
	if dados.has("inventory"):
		var inv: Inventory = inventory_component.get_inventory()
		if inv:
			inv.clear() # Limpa o inventário atual antes de carregar o save
			
			for item_data in dados["inventory"]:
				# Carrega o recurso `.tres` original de volta pra memória
				var item_res = load(item_data["item_path"]) as ItemDefinition
				if item_res:
					# Bota exatamente na gaveta em que o jogador deixou
					inv.set_slot(item_data["index"], item_res, item_data["count"])
					
			# Força a interface a atualizar pra mostrar os novos itens
			if hotbar: _atualizar_visual_hotbar(hotbar.selected_index)
