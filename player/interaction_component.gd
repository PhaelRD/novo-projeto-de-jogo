extends Node3D
class_name InteractionComponent

@onready var interaction_area: Area3D = $Area3D
var _facing_dir: Vector3 = Vector3.FORWARD

func update_grid(player_pos: Vector3, move_dir: Vector3) -> void:
	if move_dir != Vector3.ZERO:
		_facing_dir = move_dir.normalized()
		
	var target_pos = player_pos + (_facing_dir * 0.9)
	target_pos.x = round(target_pos.x)
	target_pos.z = round(target_pos.z)
	target_pos.y = player_pos.y - 0.4
	global_position = target_pos

# --- NOVA FUNÇÃO CENTRAL DE DETECÇÃO ---
func get_target_info() -> Dictionary:
	var info = {
		"collider": null,
		"position": global_position
	}
	
	if not interaction_area: return info
	
	var bodies = interaction_area.get_overlapping_bodies()
	
	for body in bodies:
		if body == get_parent(): continue # Ignora o player
		
		# Se for uma árvore/pedra/baú, dá PRIORIDADE MÁXIMA e já retorna!
		if body.is_in_group("interactable") or body.is_in_group("obstacle"):
			info.collider = body
			return info
			
		# Se for apenas o chão, guarda na memória, mas continua procurando
		# caso tenha uma árvore junto com o chão na mesma área.
		if info.collider == null:
			info.collider = body
			
	return info

func interact_with_object(player: CharacterBody3D) -> void:
	if not interaction_area: return
	
	var bodies = interaction_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("interactable") and body.has_method("interact"):
			body.interact(player)
			break
