extends CharacterBody3D
class_name Player

# --- Exportações de Movimentação ---
@export var speed: float = 5.0
@export var gravity: float = 9.8

# --- Exportações de Inventário e UI ---
@export var starting_apple: ItemDefinition
@onready var inventory_panel: ModularInventoryPanel = $CanvasLayer/ModularInventoryPanel
@export var toggle_action: StringName = &"toggle_inventory"

# --- Referências de Nós ---
@onready var _animated_sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var inventory_component = $InventoryComponent 

# --- Variáveis Internas ---
var _velocity: Vector3 = Vector3.ZERO
var _current_animation: String = ""
var _follow_camera: Camera3D = null # A variável fica aguardando o TestMap preenchê-la

func _ready() -> void:
	# Inicialização da Animação
	if _animated_sprite and _animated_sprite.sprite_frames:
		_animated_sprite.play(_select_animation(Vector3.ZERO, _animated_sprite.sprite_frames))
		_current_animation = _animated_sprite.animation
		
	# Inicialização do Inventário
	if inventory_component:
		# Se o inventário já carregou antes do Player, adicionamos a maçã direto!
		if inventory_component.inventory != null:
			_on_inventory_ready(inventory_component.inventory)
		# Se ainda não carregou, esperamos o sinal
		else:
			inventory_component.inventory_ready.connect(_on_inventory_ready)

# --- Controles de Interface (NOVO) ---
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		toggle_inventory()
		get_viewport().set_input_as_handled()

func toggle_inventory() -> void:
	if not inventory_panel:
		push_warning("Inventory Panel não está linkado no Player!")
		return
		
	var is_open = not inventory_panel.visible
	inventory_panel.visible = is_open

	if is_open:
		InputMode.ui()      # Mostra o cursor do mouse, libera a câmera
	else:
		InputMode.game()    # Esconde o cursor, captura o mouse para a câmera

# --- Física e Movimentação ---
func _physics_process(delta: float) -> void:
	var input_dir: Vector3 = Vector3.ZERO
	if Input.is_action_pressed("move_forward"): input_dir.z -= 1
	if Input.is_action_pressed("move_backward"): input_dir.z += 1
	if Input.is_action_pressed("move_left"): input_dir.x -= 1
	if Input.is_action_pressed("move_right"): input_dir.x += 1
		
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()

	var move_dir: Vector3 = _transform_input_by_camera(input_dir)

	_velocity.x = move_dir.x * speed
	_velocity.z = move_dir.z * speed

	if not is_on_floor():
		_velocity.y -= gravity * delta
	else:
		_velocity.y = 0

	velocity = _velocity
	move_and_slide()

	_update_animation(input_dir)

# --- Funções de Callback (Sinais) ---
func _on_inventory_ready(inv):
	if starting_apple:
		var remaining = inv.add_item(starting_apple, 1)
		if remaining == 0:
			print("Successfully added apple to inventory!")
		else:
			print("Inventory was full or rejected the item.")

# --- Funções Auxiliares de Câmera ---
func _transform_input_by_camera(input_dir: Vector3) -> Vector3:
	if not _follow_camera:
		return input_dir 
	
	var cam_basis = _follow_camera.global_transform.basis
	var cam_forward: Vector3 = -cam_basis.z
	var cam_right: Vector3 = cam_basis.x
	
	cam_forward.y = 0
	cam_right.y = 0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()
	
	var move_dir = (cam_right * input_dir.x) + (cam_forward * -input_dir.z)
	
	if move_dir != Vector3.ZERO:
		return move_dir.normalized()
		
	return Vector3.ZERO

# --- Funções de Animação ---
func _update_animation(direction: Vector3) -> void:
	if not _animated_sprite: return
	var frames: SpriteFrames = _animated_sprite.sprite_frames
	if not frames: return
	
	var desired_anim: String = _select_animation(direction, frames)
	if desired_anim != _current_animation:
		_animated_sprite.play(desired_anim)
		_current_animation = desired_anim

func _select_animation(direction: Vector3, frames: SpriteFrames) -> String:
	if direction == Vector3.ZERO:
		return _fallback(frames, ["idle", "default"])

	var horiz: float = abs(direction.x)
	var vert: float = abs(direction.z)
	var target_anim_name: String = ""
	
	if vert >= horiz:
		target_anim_name = "move_forward" if direction.z < 0 else "move_backward"
	else:
		target_anim_name = "move_left" if direction.x < 0 else "move_right"

	if frames.has_animation(target_anim_name): return target_anim_name
	return _fallback(frames, ["walk", "default", "idle"])

func _fallback(frames: SpriteFrames, candidates: Array) -> String:
	for anim_name in candidates:
		if frames.has_animation(anim_name): return anim_name
	var anims: Array = frames.get_animation_names()
	return anims[0] if anims.size() > 0 else ""

# --- Função de Coleta de Itens ---
func _on_pickup_area_body_entered(body: Node3D) -> void:
	print("Encostei em algo: ", body.name) # <--- ADICIONE ESTA LINHA
	
	if body.is_in_group("dropped_item"):
		var item_def = body.item_
		var amount = body.count
		
		if inventory_component and inventory_component.inventory:
			var remaining = inventory_component.inventory.add_item(item_def, amount)
			
			if remaining == 0:
				body.queue_free()
				print("Coletou: " + item_def.display_name)
			elif remaining < amount:
				body.count = remaining
				print("Inventário quase cheio! Coletou apenas uma parte.")
			else:
				print("Inventário cheio! Não é possível coletar " + item_def.display_name)
