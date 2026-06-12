extends StaticBody3D

# --- Exportações ---
@export var wood_item: ItemDefinition 

# MUDANÇA AQUI: Agora guardamos apenas o caminho (texto) da semente
@export_file("*.tres") var seed_item_path: String 

@export var max_health: int = 10 
@export var drop_amount: int = 2 

# --- Referências de Nós ---
@onready var pivot: Node3D = $Pivot # O eixo de crescimento (colado no chão)
@onready var visual_node: Sprite3D = $Pivot/Sprite3D # A imagem da árvore (para tremer)
@onready var collision_shape: CollisionShape3D = $CollisionShape3D 

var dropped_item_scene = preload("res://addons/modular_inventory_system/world/dropped_item.tscn") 

var _current_health: int
var _original_visual_pos: Vector3
var _shake_tween: Tween 

# --- LÓGICA DE CRESCIMENTO ---
var growth_stage: int = 2 # 0 = Semente, 1 = Broto, 2 = Adulta
var grow_timer: Timer

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	
	_current_health = max_health
	
	# Salva a posição original da imagem (agora em relação ao Pivot)
	if visual_node:
		_original_visual_pos = visual_node.position
		
	_atualizar_visual_crescimento()
	
	if growth_stage < 2:
		_iniciar_crescimento()

func hit_with_axe(damage: int) -> void:
	# AGORA O JOGADOR PODE BATER EM QUALQUER ESTÁGIO!
	_current_health -= damage
	_shake_tree()
	
	if _current_health <= 0:
		_chop_down()

func _shake_tree() -> void:
	if not visual_node: return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		
	visual_node.position = _original_visual_pos
	_shake_tween = create_tween()
	_shake_tween.tween_property(visual_node, "position:x", _original_visual_pos.x + 0.08, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", _original_visual_pos.x - 0.08, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", _original_visual_pos.x + 0.05, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", _original_visual_pos.x, 0.04)

func _chop_down() -> void:
	# SÓ DROPA ITENS SE A ÁRVORE FOR ADULTA
	if growth_stage == 2:
		if wood_item and dropped_item_scene:
			for i in range(drop_amount):
				var drop = dropped_item_scene.instantiate()
				drop.item_ = wood_item
				drop.count = 1
				get_tree().current_scene.add_child(drop)
				drop.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))
				
		# MUDANÇA AQUI: Carrega a semente na memória apenas no momento do drop
		if seed_item_path != "" and dropped_item_scene:
			var seed_item = load(seed_item_path) as ItemDefinition
			if seed_item:
				var drop_seed = dropped_item_scene.instantiate()
				drop_seed.item_ = seed_item
				drop_seed.count = 1
				get_tree().current_scene.add_child(drop_seed)
				drop_seed.global_position = global_position + Vector3(0, 0.6, 0)
			
	# Em qualquer estágio, ela some se a vida chegar a zero
	queue_free()

# --- SISTEMA DE CRESCIMENTO ---
func _atualizar_visual_crescimento() -> void:
	if not pivot: return # Agora nós checamos e escalamos o Pivot!
	
	if growth_stage == 0:
		pivot.scale = Vector3(0.3, 0.3, 0.3) 
		if collision_shape: collision_shape.disabled = true
	elif growth_stage == 1:
		pivot.scale = Vector3(0.6, 0.6, 0.6) 
		if collision_shape: collision_shape.disabled = false
	else:
		pivot.scale = Vector3(1.0, 1.0, 1.0) 
		if collision_shape: collision_shape.disabled = false

func _iniciar_crescimento() -> void:
	if grow_timer: return
	grow_timer = Timer.new()
	grow_timer.wait_time = 10.0 
	grow_timer.autostart = true
	grow_timer.timeout.connect(_crescer)
	add_child(grow_timer)

func _crescer() -> void:
	growth_stage += 1
	
	# Quando ela cresce, ela renova a vida para ficar inteira na próxima fase!
	_current_health = max_health 
	
	_atualizar_visual_crescimento()
	
	if growth_stage >= 2:
		grow_timer.stop()
		grow_timer.queue_free()

# --- SISTEMA DE SAVE DA ÁRVORE ---
func get_save_data() -> Dictionary:
	return {
		"scene_file": scene_file_path, 
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"pos_z": global_position.z,
		"health": _current_health,
		"growth_stage": growth_stage
	}

func load_save_data(dados: Dictionary) -> void:
	global_position = Vector3(dados["pos_x"], dados["pos_y"], dados["pos_z"])
	_current_health = dados["health"]
	growth_stage = dados["growth_stage"]
	_atualizar_visual_crescimento()
	if growth_stage < 2:
		_iniciar_crescimento()
