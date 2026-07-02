extends StaticBody3D

# --- Exportações ---
@export var wood_item: ItemDefinition 
@export var apple_item: ItemDefinition  ## Maçã dropada ao cortar a árvore adulta (100%)
@export_file("*.tres") var seed_item_path: String 
@export_category("Configuração de Quebra")
@export var max_health: int = 10 
@export var drop_amount: int = 4 
@export var apple_drop_amount: int = 1 ## Quantidade de maçãs dropadas ao cortar a árvore adulta

@export_category("Configuração de Crescimento")
@export var days_per_stage: int = 3 ## Dias necessários para avançar de semente -> broto, e broto -> adulta

# --- Referências dos 3 Sprites ---
@onready var sprite_seed: Sprite3D = $SpriteSeed
@onready var sprite_sprout: Sprite3D = $SpriteSprout
@onready var sprite_adult: Sprite3D = $SpriteAdult
@onready var collision_shape: CollisionShape3D = $CollisionShape3D 

var dropped_item_scene = preload("res://addons/modular_inventory_system/world/dropped_item.tscn") 

var _current_health: int
var _shake_tween: Tween 

# MUDANÇA IMPORTANTE: Guarda a posição individual de CADA sprite!
var _original_positions: Dictionary = {}

var growth_stage: int = 2 # 0 = Semente, 1 = Broto, 2 = Adulta
var _days_in_current_stage: int = 0

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	
	_current_health = max_health
	
	# Regista a posição exata em que você deixou cada imagem no Editor
	if sprite_seed: _original_positions[sprite_seed] = sprite_seed.position
	if sprite_sprout: _original_positions[sprite_sprout] = sprite_sprout.position
	if sprite_adult: _original_positions[sprite_adult] = sprite_adult.position
		
	_atualizar_visual_crescimento()
	
	if TimeManager and not TimeManager.day_changed.is_connected(_on_new_day):
		TimeManager.day_changed.connect(_on_new_day)

func hit_with_axe(damage: int) -> void:
	_current_health -= damage
	_shake_tree()
	
	if _current_health <= 0:
		_chop_down()

func _shake_tree() -> void:
	# Descobre qual dos 3 sprites está visível agora para tremer só ele
	var visual_node: Sprite3D = null
	if growth_stage == 0: visual_node = sprite_seed
	elif growth_stage == 1: visual_node = sprite_sprout
	elif growth_stage == 2: visual_node = sprite_adult
	
	if not visual_node: return
	
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		
	# Puxa a posição base daquele sprite específico
	var base_pos = _original_positions.get(visual_node, Vector3.ZERO)
	visual_node.position = base_pos
	
	_shake_tween = create_tween()
	_shake_tween.tween_property(visual_node, "position:x", base_pos.x + 0.08, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", base_pos.x - 0.08, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", base_pos.x + 0.05, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", base_pos.x, 0.04)

func _chop_down() -> void:
	if growth_stage == 2:
		# Drop da madeira
		if wood_item and dropped_item_scene:
			for i in range(drop_amount):
				var drop = dropped_item_scene.instantiate()
				drop.item_ = wood_item
				drop.count = 1
				get_tree().current_scene.add_child(drop)
				drop.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))
		
		# Drop da semente
		if seed_item_path != "" and dropped_item_scene:
			var seed_item = load(seed_item_path) as ItemDefinition
			if seed_item:
				var drop_seed = dropped_item_scene.instantiate()
				drop_seed.item_ = seed_item
				drop_seed.count = 1
				get_tree().current_scene.add_child(drop_seed)
				drop_seed.global_position = global_position + Vector3(0, 0.6, 0)

		# Drop da maçã
		if apple_item and dropped_item_scene and apple_drop_amount > 0:
			for i in range(apple_drop_amount):
				var drop_apple = dropped_item_scene.instantiate()
				drop_apple.item_ = apple_item
				drop_apple.count = 1
				get_tree().current_scene.add_child(drop_apple)
				drop_apple.global_position = global_position + Vector3(randf_range(-0.4, 0.4), 0.8, randf_range(-0.4, 0.4))
			print("🍎 Árvore derrubada — %d maçã(s) dropada(s)!" % apple_drop_amount)

	queue_free()

# --- SISTEMA DE CRESCIMENTO (Troca de Sprites) ---
func _atualizar_visual_crescimento() -> void:
	# 1. Esconde todos primeiro
	if sprite_seed: sprite_seed.visible = false
	if sprite_sprout: sprite_sprout.visible = false
	if sprite_adult: sprite_adult.visible = false
	
	# 2. Liga apenas o correto e ajusta a colisão
	if growth_stage == 0:
		if sprite_seed: sprite_seed.visible = true
		if collision_shape: collision_shape.disabled = true
	elif growth_stage == 1:
		if sprite_sprout: sprite_sprout.visible = true
		if collision_shape: collision_shape.disabled = false
	else:
		if sprite_adult: sprite_adult.visible = true
		if collision_shape: collision_shape.disabled = false

func _on_new_day(_day: int, _season: int, _year: int) -> void:
	if growth_stage < 2:
		_days_in_current_stage += 1
		if _days_in_current_stage >= days_per_stage:
			_crescer()

func _crescer() -> void:
	growth_stage += 1
	_days_in_current_stage = 0
	_current_health = max_health 
	_atualizar_visual_crescimento()

# --- SISTEMA DE SAVE DA ÁRVORE ---
func get_save_data() -> Dictionary:
	return {
		"scene_file": scene_file_path, 
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"pos_z": global_position.z,
		"health": _current_health,
		"growth_stage": growth_stage,
		"days_in_stage": _days_in_current_stage
	}

func load_save_data(dados: Dictionary) -> void:
	global_position = Vector3(dados["pos_x"], dados["pos_y"], dados["pos_z"])
	_current_health = dados["health"]
	growth_stage = dados["growth_stage"]
	if dados.has("days_in_stage"):
		_days_in_current_stage = dados["days_in_stage"]
	_atualizar_visual_crescimento()
