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
	# Liga as animações
	animations.sprite = animated_sprite
	animations.setup()
	
	# Inicializa o inventário
	if inventory_component:
		if inventory_component.inventory != null:
			_on_inventory_ready(inventory_component.inventory)
		else:
			inventory_component.inventory_ready.connect(_on_inventory_ready)
			
	# Conecta o sinal visual da Hotbar para destacar o item selecionado
	if hotbar:
		hotbar.selection_changed.connect(_atualizar_visual_hotbar)
		# Dá um pequeno atraso apenas na inicialização para garantir que a UI carregou
		call_deferred("_atualizar_visual_hotbar", hotbar.selected_index)

func _unhandled_input(event: InputEvent) -> void:
	# 1. Botão de abrir/fechar inventário
	if event.is_action_pressed(toggle_action):
		toggle_inventory()
		get_viewport().set_input_as_handled()

	# 2. Seleção de itens na Hotbar pelos números
	if hotbar:
		for i in range(1, 10):
			var action_name = "hotbar_" + str(i)
			if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
				hotbar.selected_index = i - 1
				get_viewport().set_input_as_handled()
				return 

	# 3. Botão esquerdo do mouse para usar ferramentas
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

	# 1. O MovementComponent processa a física e devolve para onde o player realmente foi
	var real_move_dir = movement.handle_movement(self, input_dir, delta)
	
	# 2. O AnimationComponent atualiza a arte baseada no input bruto
	animations.update_animation(input_dir)
	
	# 3. O InteractionComponent atualiza o grid baseado na direção real
	interaction.update_grid(global_position, real_move_dir)

func _is_holding_axe() -> bool:
	if not hotbar or not inventory_component: return false
	var inv: Inventory = inventory_component.get_inventory()
	if not inv: return false
	
	var selected_index = hotbar.get_selected_global_index()
	var slot_data = inv.get_slot(selected_index)
	
	return slot_data and slot_data.item == starting_axe

func _on_inventory_ready(inv):
	if starting_axe: inv.add_item(starting_axe, 1)

func _on_pickup_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("dropped_item") and inventory_component and inventory_component.inventory:
		var remaining = inventory_component.inventory.add_item(body.item_, body.count)
		if remaining == 0:
			body.queue_free()
		elif remaining < body.count:
			body.count = remaining

# --- Função Visual da Hotbar ---
func _atualizar_visual_hotbar(novo_indice: int) -> void:
	if not hotbar or not hotbar.slots_container: return
	
	var slots = hotbar.slots_container.get_children()
	
	for i in range(slots.size()):
		var slot_ui = slots[i]
		
		if i == novo_indice:
			# Destaca o slot selecionado (amarelo claro)
			slot_ui.modulate = Color(1.2, 1.2, 0.5) 
		else:
			# Retorna os outros slots para a cor normal
			slot_ui.modulate = Color(1.0, 1.0, 1.0)
