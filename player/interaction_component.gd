extends Node3D
class_name InteractionComponent

@onready var interaction_area: Area3D = $Area3D
var _facing_dir: Vector3 = Vector3.FORWARD

func update_grid(player_pos: Vector3, move_dir: Vector3) -> void:
	if move_dir != Vector3.ZERO:
		_facing_dir = move_dir.normalized()

	# Posição ideal da mira (grid snapped, 0.9 unidades à frente)
	var target_pos = player_pos + (_facing_dir * 0.9)
	target_pos.x = round(target_pos.x)
	target_pos.z = round(target_pos.z)
	target_pos.y = player_pos.y - 0.4

	# Raycast: se o caminho até o alvo atravessa um objeto sólido não-terrain,
	# recua a mira para não ultrapassar a superfície do obstáculo.
	global_position = _clamp_to_surface(player_pos, target_pos)

# ------------------------------------------------------------------
# Lança um raio de player_pos → target_pos.
# Se bater em objeto não-terrain (parede, casa, etc.), retorna
# a posição do tile em que o player está (antes do obstáculo).
# ------------------------------------------------------------------
func _clamp_to_surface(player_pos: Vector3, target_pos: Vector3) -> Vector3:
	var space = get_world_3d().direct_space_state

	# Origem do raio na altura da mira (mesmo Y do target_pos)
	var ray_from = Vector3(player_pos.x, target_pos.y, player_pos.z)
	var query    = PhysicsRayQueryParameters3D.create(ray_from, target_pos)

	# Exclui o próprio player da detecção
	if get_parent() is CollisionObject3D:
		query.exclude = [get_parent().get_rid()]

	var result = space.intersect_ray(query)

	if result:
		var body = result["collider"]
		# Só bloqueia corpos "sólidos opacos" — paredes, casas, etc.
		# Interactables (baú, árvore) e obstacles são deixados passar;
		# a Area3D os detecta normalmente via get_overlapping_bodies().
		var is_terrain     = _is_terrain(body)
		var is_interactable = body.is_in_group("interactable")
		var is_obstacle    = body.is_in_group("obstacle")

		if not is_terrain and not is_interactable and not is_obstacle:
			# Parede / construção sólida → mira volta para o tile do player
			return Vector3(round(player_pos.x), target_pos.y, round(player_pos.z))

	# Caminho livre (ou bateu em interactable/terrain) → target normal
	return target_pos

# ------------------------------------------------------------------
# FUNÇÃO CENTRAL DE DETECÇÃO — retorna collider e posição da mira
# ------------------------------------------------------------------
func get_target_info() -> Dictionary:
	var info = {
		"collider": null,
		"position": global_position
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

# ------------------------------------------------------------------
# Sobe a hierarquia de pais até encontrar o grupo "terrain".
# Necessário porque TileMapLayer3D gera filhos StaticBody3D sem grupo.
# ------------------------------------------------------------------
func _is_terrain(node: Node) -> bool:
	var n = node
	while n:
		if n.is_in_group("terrain"):
			return true
		n = n.get_parent()
	return false
