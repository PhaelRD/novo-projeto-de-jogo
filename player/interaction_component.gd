extends Node3D
class_name InteractionComponent

@onready var interaction_area: Area3D = $Area3D
var _facing_dir: Vector3 = Vector3.FORWARD

func update_grid(player_pos: Vector3, move_dir: Vector3) -> void:
	if move_dir != Vector3.ZERO:
		_facing_dir = move_dir.normalized()

	# Posição ideal da mira (grid snapped, 0.9 unidades à frente)
	var target_pos = player_pos + (_facing_dir * 0.9)
	target_pos.x = floor(target_pos.x) + 0.5
	target_pos.z = floor(target_pos.z) + 0.5
	target_pos.y = player_pos.y - 0.4

	# A colisão física volta a funcionar e não permite invadir paredes!
	# Ela bate, recua a mira para sua proteção e acende o alarme de bloqueio.
	global_position = _check_obstacle(player_pos, target_pos)

var _aim_is_blocked_by_wall: bool = false

# ------------------------------------------------------------------
func _check_obstacle(player_pos: Vector3, target_pos: Vector3) -> Vector3:
	var space = get_world_3d().direct_space_state
	
	# Dispara o raio na altura do peito (player_pos.y + 0.5) para evitar 
	# colidir falsamente com pequenos desníveis ou vazar no chão diagonal
	var ray_from = Vector3(player_pos.x, player_pos.y + 0.5, player_pos.z)
	var ray_to   = Vector3(target_pos.x, player_pos.y + 0.5, target_pos.z)
	
	var query    = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	
	if get_parent() is CollisionObject3D:
		query.exclude = [get_parent().get_rid()]

	var result = space.intersect_ray(query)

	if result:
		var body = result["collider"]
		
		# Árvores ("interactable") deixam a mira penetrá-las para que a Área de Interação as toque.
		if not body.is_in_group("interactable") and not body.is_in_group("obstacle"):
			# A mira bateu em algo do cenário (Muro, Parede da Casa, ou Chão Inclinado/Rampa).
			# Paredes reais têm ângulos retos ou próximos a ele (Normal.y < 0.3).
			# Já as Rampas e Ladeiras (Diagonais do terreno) apontam mais para o céu (Normal.y >= 0.3).
			if result["normal"].y < 0.3:
				# É Muro vertical opaco! A mira bate, liga o alerta e recua para não invadir a casa.
				_aim_is_blocked_by_wall = true
				return Vector3(floor(player_pos.x) + 0.5, target_pos.y, floor(player_pos.z) + 0.5)

	_aim_is_blocked_by_wall = false
	return target_pos

# ------------------------------------------------------------------
# Retorna true se a própria CAIXA DA MIRA encostar em algo não-interagível
# (ex: Casas inteiras, Pedras blindadas)
# ------------------------------------------------------------------
func _is_blocked_by_non_interactable() -> bool:
	if not interaction_area: return false
	
	var bodies = interaction_area.get_overlapping_bodies()
	for body in bodies:
		if body == get_parent(): continue
		if body.is_in_group("interactable") or body.is_in_group("obstacle"):
			continue
		if _is_terrain(body):
			continue
			
		# Encostou num Corpo Estranho Sólido (não é terreno, nem interactable)
		return true
		
	return false

# ------------------------------------------------------------------
# Subimos a árvore para saber se a física faz parte do chão natural (Addon)
# ------------------------------------------------------------------
func _is_terrain(node: Node) -> bool:
	var n = node
	while n:
		if "runtime_api" in n and n.runtime_api != null:
			return true
		n = n.get_parent()
	return false


# ------------------------------------------------------------------
# FUNÇÃO CENTRAL DE DETECÇÃO — retorna collider e posição da mira
# ------------------------------------------------------------------
func get_target_info() -> Dictionary:
	var is_blocked = _aim_is_blocked_by_wall or _is_blocked_by_non_interactable()

	var info = {
		"collider": null,
		"position": global_position,
		"is_blocked": is_blocked
	}

	if not interaction_area: return info

	var bodies = interaction_area.get_overlapping_bodies()

	for body in bodies:
		if body == get_parent(): continue # Ignora o player

		# Interactable/obstacle têm prioridade máxima
		if body.is_in_group("interactable") or body.is_in_group("obstacle"):
			info.collider = body
			return info

		# Chão: guarda mas continua procurando
		if info.collider == null:
			info.collider = body

	return info
