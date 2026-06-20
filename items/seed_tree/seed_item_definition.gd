extends ItemDefinition 
class_name SeedItemDefinition

@export_category("Configurações de Plantio")
@export var valid_soil_coords: Array[Vector2i] = [Vector2i(1, 2)]
@export var stamina_cost: int = 2

func use(player: CharacterBody3D, target_info: Dictionary) -> bool:
	if not player.stamina_bar.has_energy(stamina_cost):
		print("Estou muito cansado para plantar...")
		return false
		
	var target_pos = target_info.get("position", Vector3.ZERO)
	var collider = target_info.get("collider")
	
	# Verifica se o espaço físico já não está ocupado por outro obstáculo
	if collider and (collider.is_in_group("interactable") or collider.is_in_group("obstacle")):
		print("Não é possível plantar aqui, o espaço está ocupado!")
		return false

	var mapas = player.get_tree().get_nodes_in_group("terrain")
	var base_y = target_pos.y
	var tile_info = null
	
	if mapas.size() > 0:
		var tile_map = mapas[0]
		if tile_map.runtime_api:
			var player_y = player.global_position.y
			# Scanner vertical baseado na mira do jogador
			for offset_y in [1.0, 0.5, 0.0, -0.5, -1.0, -1.5]:
				var test_pos = target_pos
				test_pos.y = player_y + offset_y
				
				var check = tile_map.runtime_api.find_tile(test_pos, 0) # 0 = FLOOR
				if check != null:
					tile_info = check
					base_y = round(test_pos.y) 
					break
			
			if tile_info == null:
				print("Você não pode plantar no vazio!")
				return false
				
			if not tile_info.atlas_coords in valid_soil_coords:
				print("Esta semente não pode ser plantada aqui! Coordenada atual: ", tile_info.atlas_coords)
				return false
	else:
		print("Nenhum mapa (terrain) encontrado nesta cena.")
		return false

	# Cria a árvore ou planta no mundo fictício
	if placement_scene:
		var new_tree = placement_scene.instantiate()
		if "growth_stage" in new_tree:
			new_tree.growth_stage = 0 
		
		player.get_tree().current_scene.add_child(new_tree)
		new_tree.global_position = Vector3(target_pos.x, base_y, target_pos.z)
		
		if new_tree.has_method("_atualizar_visual_crescimento"):
			new_tree._atualizar_visual_crescimento()
			
		# Sucesso: Consome a stamina e remove a unidade do inventário
		player.stamina_bar.consume(stamina_cost)
		player.inventory_component.get_inventory().remove_item(self, 1)
		print("Semente plantada com sucesso na altura: ", base_y)
		return true

	return false
