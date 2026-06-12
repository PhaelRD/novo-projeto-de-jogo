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

func use_axe(sprite: AnimatedSprite3D) -> void:
	if not interaction_area: return
	
	var bodies = interaction_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("interactable") and body.has_method("hit_with_axe"):
			body.hit_with_axe(1)
			if sprite and sprite.sprite_frames.has_animation("attack"):
				sprite.play("attack")
			break
			
func plant_seed(tree_scene: PackedScene) -> bool:
	if not tree_scene: return false
	
	# 1. Verifica o que está dentro da mira vermelha
	var bodies = interaction_area.get_overlapping_bodies()
	for body in bodies:
		# Ignora a colisão do próprio Jogador
		if body == get_parent():
			continue
			
		# Bloqueia se bater de frente com outro objeto real do jogo.
		if body.is_in_group("interactable") or body.is_in_group("obstacle"):
			print("Não é possível plantar aqui, o espaço está ocupado por outro objeto!")
			return false

# 2. Se o espaço está livre de objetos, criamos a árvore
	var new_tree = tree_scene.instantiate()
	
	# MUDANÇA AQUI: Avisamos que ela é uma semente ANTES de colocar no mapa!
	new_tree.growth_stage = 0 
	
	# Agora sim colocamos no mapa (O _ready da árvore vai rodar sabendo que é 0)
	get_tree().current_scene.add_child(new_tree)
	
	# Depois de adicionar, movemos ela para o lugar certo
	new_tree.global_position = self.global_position
	
	return true
