extends Node3D
class_name InteractionComponent

@export var valid_soil_coords: Array[Vector2i] = [Vector2i(1, 2)]

@onready var interaction_area: Area3D = $Area3D
var _facing_dir: Vector3 = Vector3.FORWARD

func update_grid(player_pos: Vector3, move_dir: Vector3) -> void:
	if move_dir != Vector3.ZERO:
		_facing_dir = move_dir.normalized()
		
	var target_pos = player_pos + (_facing_dir * 0.9)
	target_pos.x = round(target_pos.x)
	target_pos.z = round(target_pos.z)
	# Guardamos o Y original da mira como base
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
	
	# 1. Verifica objetos físicos na frente
	var bodies = interaction_area.get_overlapping_bodies()
	for body in bodies:
		if body == get_parent(): continue
			
		if body.is_in_group("interactable") or body.is_in_group("obstacle"):
			print("Não é possível plantar aqui, o espaço está ocupado!")
			return false

	var mapas = get_tree().get_nodes_in_group("terrain")
	var base_y = 0.0 # Vai guardar a altura perfeita do chão
	
	if mapas.size() > 0:
		var tile_map = mapas[0]
		
		if tile_map.runtime_api:
			var tile_info = null
			
			# 2. O SCANNER VERTICAL: 
			# Testa as alturas a partir de 1 metro acima do jogador até 1 metro abaixo dele.
			# O primeiro bloco que ele encontrar descendo será o chão verdadeiro!
			var player_y = get_parent().global_position.y
			for offset_y in [1.0, 0.5, 0.0, -0.5, -1.0, -1.5]:
				var test_pos = global_position
				test_pos.y = player_y + offset_y
				
				var check = tile_map.runtime_api.find_tile(test_pos, 0) # 0 = FLOOR
				if check != null:
					tile_info = check
					# Achámos o chão mais alto! Cravamos a altura exata desse bloco.
					base_y = round(test_pos.y) 
					break
			
			if tile_info == null:
				print("Você não pode plantar no vazio!")
				return false
				
			if not tile_info.atlas_coords in valid_soil_coords:
				print("Você só pode plantar em blocos de terra! Coordenada atual: ", tile_info.atlas_coords)
				return false
				
	else:
		print("Nenhum mapa (terrain) encontrado nesta cena.")
		return false

	# --- 3. CRIAÇÃO DA ÁRVORE ---
	var new_tree = tree_scene.instantiate()
	
	if "growth_stage" in new_tree:
		new_tree.growth_stage = 0 
	
	get_tree().current_scene.add_child(new_tree)
	
	# MÁGICA FINAL: Usa o X e Z da mira, mas puxa a altura (Y) exata do bloco que o Scanner encontrou!
	new_tree.global_position = Vector3(self.global_position.x, base_y, self.global_position.z)
	
	if new_tree.has_method("_atualizar_visual_crescimento"):
		new_tree._atualizar_visual_crescimento()
		print("Semente plantada com sucesso na altura: ", base_y)
	
	return true
