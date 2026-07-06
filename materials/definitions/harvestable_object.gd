extends StaticBody3D
class_name HarvestableObject

@export_category("Harvestable Settings")
@export var max_health: int = 10
@export var required_tool: String = "" ## Ex: axe, pickaxe. Vazio = quebra com a mão
@export var drops: Array[DropData] = []

@export_category("Growth Settings")
@export var can_grow: bool = false
@export var days_per_stage: int = 1
@export var initial_growth_stage: int = -1 ## -1 significa que a árvore nasce adulta se colocada no mapa pelo editor
@export var stages: Array[Node3D] = []

var dropped_item_scene = preload("res://addons/modular_inventory_system/world/dropped_item.tscn")

var _current_health: int
var _shake_tween: Tween
var _original_positions: Dictionary = {}

var growth_stage: int = 0
var _days_in_current_stage: int = 0

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	
	_current_health = max_health
	
	# Configura o estágio inicial caso tenha acabado de nascer do mapa (não da semente nem do save)
	if initial_growth_stage == -1:
		growth_stage = max(0, stages.size() - 1)
	else:
		growth_stage = initial_growth_stage
	
	for s in stages:
		if s: _original_positions[s] = s.position
		
	_atualizar_visual_crescimento()
	
	# Verifica se existe um singleton TimeManager e conecta para crescer
	var tm = get_node_or_null("/root/TimeManager")
	if can_grow and tm and not tm.day_changed.is_connected(_on_new_day):
		tm.day_changed.connect(_on_new_day)

func hit(tool_type: String, damage: int) -> void:
	if required_tool != "" and tool_type != required_tool:
		print("Você precisa de um(a) " + required_tool + " para interagir!")
		return
		
	_current_health -= damage
	_shake_visual()
	
	if _current_health <= 0:
		_break_object()

# Para fins de compatibilidade enquanto o jogo é migrado
func hit_with_axe(damage: int) -> void:
	hit("axe", damage)

func _shake_visual() -> void:
	var visual_node: Node3D = _get_current_visual()
	if not visual_node: return
	
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		
	var base_pos = _original_positions.get(visual_node, Vector3.ZERO)
	visual_node.position = base_pos
	
	_shake_tween = create_tween()
	_shake_tween.tween_property(visual_node, "position:x", base_pos.x + 0.08, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", base_pos.x - 0.08, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", base_pos.x + 0.05, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", base_pos.x, 0.04)

func _get_current_visual() -> Node3D:
	if stages.is_empty(): return null
	var idx = clamp(growth_stage, 0, stages.size() - 1)
	return stages[idx]

func _break_object() -> void:
	if not can_grow or growth_stage >= stages.size() - 1:
		for drop_data in drops:
			if drop_data:
				var drop_item = drop_data.get_item()
				if drop_item:
					if randf() <= drop_data.drop_chance:
						for i in range(drop_data.amount):
							_spawn_drop(drop_item)
	queue_free()

func _spawn_drop(item: ItemDefinition) -> void:
	if not dropped_item_scene: return
	var drop = dropped_item_scene.instantiate()
	drop.item_ = item
	drop.count = 1
	get_tree().current_scene.add_child(drop)
	drop.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.6, randf_range(-0.5, 0.5))

func _atualizar_visual_crescimento() -> void:
	if stages.is_empty(): return
	
	for s in stages:
		if s: s.visible = false
		
	var visual = _get_current_visual()
	if visual:
		visual.visible = true
		
	# A semente das plantas costuma permitir que o jogador ande por cima dela
	if can_grow and stages.size() > 1:
		var col = _get_collision_node()
		if col:
			col.disabled = (growth_stage == 0)

func _get_collision_node() -> CollisionShape3D:
	for c in get_children():
		if c is CollisionShape3D:
			return c
	return null

func _on_new_day(_day: int, _season: int, _year: int) -> void:
	if can_grow and stages.size() > 1 and growth_stage < stages.size() - 1:
		_days_in_current_stage += 1
		if _days_in_current_stage >= days_per_stage:
			_crescer()

func _crescer() -> void:
	growth_stage += 1
	_days_in_current_stage = 0
	_current_health = max_health
	_atualizar_visual_crescimento()

# --- SAVE SYSTEM ---
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
	_current_health = dados.get("health", max_health)
	growth_stage = dados.get("growth_stage", growth_stage)
	_days_in_current_stage = dados.get("days_in_stage", 0)
	_atualizar_visual_crescimento()
