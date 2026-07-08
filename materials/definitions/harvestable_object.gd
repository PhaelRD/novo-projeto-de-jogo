extends StaticBody3D
class_name HarvestableObject

# ─── Configurações Básicas ────────────────────────────────────────────────────
@export_category("Harvestable Settings")
@export var max_health: int = 10
@export var required_tool: String = "" ## Ex: axe, pickaxe. Vazio = quebra com a mão
@export var shake_intensity: float = 0.08

# ─── Configurações de Crescimento ─────────────────────────────────────────────
@export_category("Growth Settings")
@export var can_grow: bool = false
@export var days_per_stage: int = 1
## -1 = nasce adulto quando colocado pelo editor
@export var initial_growth_stage: int = -1
@export var stages: Array[Node3D] = []

# ─── Configurações Avançadas de Cultivo ───────────────────────────────────────
@export_category("Crop Settings")

## Se verdadeiro, a planta só avança de estágio se foi regada naquele dia.
@export var needs_water: bool = false

## Se verdadeiro, ao ser colhida no estágio final volta para regrow_stage
## em vez de ser destruída.
@export var regrows_after_harvest: bool = false

## Estágio para o qual a planta volta após ser colhida (rebroto).
@export var regrow_stage: int = 0

## Estações em que a planta pode crescer [Primavera, Verão, Outono, Inverno].
## Se a estação atual não estiver marcada, a planta murcha permanentemente.
@export var allowed_seasons: Array[bool] = [true, true, true, true]

## Índice do estágio visual de "planta murcha". -1 = sem visual de murcha
## (simplesmente para de crescer/muda flags mas não troca o visual).
@export var wilt_stage: int = -1

## Se verdadeiro, o jogador atravessa a planta em todos os estágios.
## A colisão vai para a Layer 2 (invisível ao player, mas detectável pelo InteractionComponent).
@export var passthrough: bool = false

## Drops vinculados a estágios específicos. Cada entrada define em qual
## estágio de crescimento aquele drop ocorre ao colher.
@export var staged_drops: Array[StagedDropData] = []

# ─── Estado Interno ───────────────────────────────────────────────────────────
var dropped_item_scene = preload("res://addons/modular_inventory_system/world/dropped_item.tscn")

var _current_health: int
var _shake_tween: Tween
var _original_positions: Dictionary = {}

var was_planted: bool = false
var growth_stage: int = 0
var _days_in_current_stage: int = 0

## Indica se foi regada hoje — resetado a cada virada de dia.
var _was_watered_today: bool = false

## Indica se a planta murchou. Morte permanente — não revive.
var _is_wilted: bool = false

# ─── Ciclo de Vida ─────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	
	_current_health = max_health
	
	if was_planted:
		growth_stage = 0
	else:
		if initial_growth_stage == -1:
			growth_stage = max(0, stages.size() - 1)
		else:
			growth_stage = initial_growth_stage
	
	for s in stages:
		if s: _original_positions[s] = s.position
		
	var fallback = _get_fallback_visual()
	if fallback and not _original_positions.has(fallback):
		_original_positions[fallback] = fallback.position
		
	_atualizar_visual_crescimento()
	
	# Configura a layer de colisão conforme o modo passthrough
	if passthrough:
		# Layer 2 = detetável pelo InteractionComponent mas não bloqueia o player
		collision_layer = 2
		collision_mask = 0
		
		# Cria área para detectar quando o player passa pela planta (efeito de balanço)
		var rustle_area = Area3D.new()
		rustle_area.collision_layer = 0
		rustle_area.collision_mask = 1 # Detecta o Player na layer 1
		add_child(rustle_area)
		
		var col = _get_collision_node()
		if col and col.shape:
			var col_dup = CollisionShape3D.new()
			col_dup.shape = col.shape
			col_dup.position = col.position
			rustle_area.add_child(col_dup)
			
		rustle_area.body_entered.connect(_on_rustle_body_entered)
		rustle_area.body_exited.connect(_on_rustle_body_entered)

	
	var tm = get_node_or_null("/root/TimeManager")
	if can_grow and tm and not tm.day_changed.is_connected(_on_new_day):
		tm.day_changed.connect(_on_new_day)

# ─── Interação ─────────────────────────────────────────────────────────────────
func interact(player: Node3D) -> void:
	# Só aceita interação de mão vazia quando required_tool está vazio.
	# Se o jogador está segurando qualquer item, recusa.
	if player.has_method("_get_held_slot"):
		var slot = player._get_held_slot()
		if slot and slot.item:
			print("Solte o item da mão para interagir com isso!")
			return
	hit("", 1)

func hit(tool_type: String, damage: int) -> void:
	if tool_type != required_tool:
		if required_tool == "":
			print("Use as mãos livres para interagir com isso!")
		else:
			print("Você precisa de um(a) " + required_tool + " para interagir!")
		return
		
	_current_health -= damage
	_shake_visual()
	
	if _current_health <= 0:
		_break_object()

## Compatibilidade legada
func hit_with_axe(damage: int) -> void:
	hit("axe", damage)

## Chamado pelo Regador quando o jogador rega a planta.
func water() -> void:
	if _is_wilted or not can_grow or not needs_water:
		return
	_was_watered_today = true
	print(name, ": foi regada hoje ✓")

# ─── Virada de Dia ─────────────────────────────────────────────────────────────
func _on_new_day(_day: int, season: int, _year: int) -> void:
	if not can_grow or _is_wilted:
		return
	
	# ── Checar estação ────────────────────────────────────────────────────────
	var season_ok = _is_season_allowed(season)
	if not season_ok:
		_wilt()
		return
	
	# ── Chuva conta como rega automática ─────────────────────────────────────
	var tm = get_node_or_null("/root/TimeManager")
	if tm and tm.is_raining:
		_was_watered_today = true
	
	# ── Crescimento ───────────────────────────────────────────────────────────
	if growth_stage >= _final_growth_stage():
		return  # Já no estágio final
	
	# Se precisa de rega e não foi regada, não conta o dia
	if needs_water and not _was_watered_today:
		print(name, ": não foi regada hoje, crescimento pausado.")
		_was_watered_today = false
		return
	
	_days_in_current_stage += 1
	if _days_in_current_stage >= days_per_stage:
		_crescer()
	
	# Reseta o estado de rega para o dia seguinte
	_was_watered_today = false

func _is_season_allowed(season: int) -> bool:
	if allowed_seasons.size() != 4:
		return true  # configuração inválida: não penaliza
	return allowed_seasons[clamp(season, 0, 3)]

## Retorna o índice do último estágio de crescimento real.
## Se wilt_stage estiver configurado, ele fica de fora do crescimento normal.
func _final_growth_stage() -> int:
	if wilt_stage >= 0:
		# O estágio de murça fica reservado: o crescimento para no anterior
		return max(0, wilt_stage - 1)
	return max(0, stages.size() - 1)

func _wilt() -> void:
	_is_wilted = true
	print(name, ": murchou! A planta morreu permanentemente.")
	
	if wilt_stage >= 0 and wilt_stage < stages.size():
		# Força o visual de murcha sem mexer em growth_stage
		for s in stages:
			if s: s.visible = false
		var wilt_visual = stages[wilt_stage]
		if wilt_visual:
			wilt_visual.visible = true
	
	# Planta morta não tem colisão (o jogador pode colher/destruir)
	var col = _get_collision_node()
	if col:
		col.disabled = false  # mantém colidível para o jogador poder acertar

# ─── Colheita / Destruição ─────────────────────────────────────────────────────
func _break_object() -> void:
	# Planta murcha: sem drops, só destrói
	if _is_wilted:
		queue_free()
		return
	
	# ── Determinar quais drops liberar ───────────────────────────────────────
	_release_drops()
	
	# ── Rebroto ou Destruição ─────────────────────────────────────────────────
	if regrows_after_harvest and growth_stage >= _final_growth_stage():
		# Volta ao estágio de rebroto
		growth_stage = clamp(regrow_stage, 0, stages.size() - 1)
		_days_in_current_stage = 0
		_current_health = max_health
		_was_watered_today = false
		_atualizar_visual_crescimento()
		print(name, ": colhido! Voltou ao estágio ", growth_stage, ".")
	else:
		queue_free()

func _release_drops() -> void:
	for sd in staged_drops:
		if not sd: continue
		# harvest_stage == -1 significa "apenas no estágio final"
		var matches_stage = (sd.harvest_stage == -1 and growth_stage >= _final_growth_stage()) \
							or sd.harvest_stage == growth_stage
		if not matches_stage:
			continue
		# Itera cada entrada de item dentro do estágio
		for entry in sd.items:
			if not entry: continue
			if randf() <= entry.drop_chance:
				var drop_item = entry.get_item()
				if drop_item:
					for i in range(entry.amount):
						_spawn_drop(drop_item)

func _spawn_drop(item: ItemDefinition) -> void:
	if not dropped_item_scene: return
	var drop = dropped_item_scene.instantiate()
	drop.item_ = item
	drop.count = 1
	get_tree().current_scene.add_child(drop)
	drop.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.6, randf_range(-0.5, 0.5))

# ─── Visual ─────────────────────────────────────────────────────────────────────
func _shake_visual() -> void:
	var visual_node: Node3D = _get_current_visual()
	if not visual_node: return
	
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		
	var base_pos = _original_positions.get(visual_node, Vector3.ZERO)
	visual_node.position = base_pos
	
	var strength: float = shake_intensity / max(0.1, scale.x)
	var half_strength: float = strength * 0.6
	
	_shake_tween = create_tween()
	_shake_tween.tween_property(visual_node, "position:x", base_pos.x + strength, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", base_pos.x - strength, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", base_pos.x + half_strength, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", base_pos.x - half_strength, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", base_pos.x, 0.04)

func _on_rustle_body_entered(body: Node3D) -> void:
	# Só balança se não for mais uma semente (estágio 0)
	if body is Player and growth_stage > 0:
		# Uma sacudida um pouco mais leve para o "passar" do jogador
		var original_intensity = shake_intensity
		shake_intensity = original_intensity * 0.7
		_shake_visual()
		shake_intensity = original_intensity

func _atualizar_visual_crescimento() -> void:
	if stages.is_empty(): return
	
	# Planta murcha já foi tratada em _wilt(), não sobrescreve
	if _is_wilted: return
	
	for s in stages:
		if s: s.visible = false
		
	var visual = _get_current_visual()
	if visual:
		visual.visible = true
		
	# Se passthrough=true, nunca desabilita a colisão (mantém sempre detectável)
	if passthrough:
		return
	
	# No estágio 0 (broto) a colisão fica desabilitada para o jogador não travar
	if can_grow and stages.size() > 1:
		var col = _get_collision_node()
		if col:
			col.disabled = (growth_stage == 0)

func _get_current_visual() -> Node3D:
	if stages.is_empty(): return _get_fallback_visual()
	var idx = clamp(growth_stage, 0, stages.size() - 1)
	var node = stages[idx]
	if node: return node
	return _get_fallback_visual()

func _get_fallback_visual() -> Node3D:
	for c in get_children():
		if c is Sprite3D or c is MeshInstance3D:
			return c
	return null

func _get_collision_node() -> CollisionShape3D:
	for c in get_children():
		if c is CollisionShape3D:
			return c
	return null

func _crescer() -> void:
	growth_stage += 1
	_days_in_current_stage = 0
	_current_health = max_health
	_atualizar_visual_crescimento()

# ─── Save System ───────────────────────────────────────────────────────────────
func get_save_data() -> Dictionary:
	return {
		"scene_file": scene_file_path, 
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"pos_z": global_position.z,
		"health": _current_health,
		"growth_stage": growth_stage,
		"days_in_stage": _days_in_current_stage,
		"was_watered": _was_watered_today,
		"is_wilted": _is_wilted
	}

func load_save_data(dados: Dictionary) -> void:
	global_position = Vector3(dados["pos_x"], dados["pos_y"], dados["pos_z"])
	_current_health = dados.get("health", max_health)
	growth_stage = dados.get("growth_stage", growth_stage)
	_days_in_current_stage = dados.get("days_in_stage", 0)
	_was_watered_today = dados.get("was_watered", false)
	_is_wilted = dados.get("is_wilted", false)
	
	if _is_wilted:
		_wilt()
	else:
		_atualizar_visual_crescimento()
