extends ItemDefinition
class_name PlaceableItemDefinition

@export_category("Configurações de Construção")
@export var stamina_cost: int = 0
@export var require_floor: bool = true # Exige que tenha um chão embaixo para ser colocado

func use(player: CharacterBody3D, target_info: Dictionary) -> bool:
	# 1. Verifica stamina
	if not player.stamina_bar.has_energy(stamina_cost):
		print("Estou muito cansado para colocar objetos...")
		return false
		
	var target_pos = target_info.get("position", Vector3.ZERO)
	var collider = target_info.get("collider")
	
	# 2. Verifica se o espaço já está ocupado por algo interativo ou parede
	if collider and (collider.is_in_group("interactable") or collider.is_in_group("obstacle")):
		print("Não posso colocar o objeto aqui, o espaço está ocupado!")
		return false

	if not placement_scene:
		push_warning("Atenção: Este item não possui uma placement_scene configurada!")
		return false

	var base_y = target_pos.y

	# 3. Procura o chão para não deixar o objeto flutuando
	if require_floor:
		var mapas = player.get_tree().get_nodes_in_group("terrain")
		var found_floor = false
		
		if mapas.size() > 0:
			var tile_map = mapas[0]
			if tile_map.runtime_api:
				var player_y = player.global_position.y
				for offset_y in [1.0, 0.5, 0.0, -0.5, -1.0, -1.5]:
					var test_pos = target_pos
					test_pos.y = player_y + offset_y
					
					var check = tile_map.runtime_api.find_tile(test_pos, 0) # 0 = FLOOR
					if check != null:
						base_y = round(test_pos.y)
						found_floor = true
						break
						
		if not found_floor:
			print("Você precisa colocar este objeto sobre um chão válido!")
			return false

	# 4. Instancia e coloca no mundo
	var new_object = placement_scene.instantiate()
	player.get_tree().current_scene.add_child(new_object)
	new_object.global_position = Vector3(target_pos.x, base_y, target_pos.z)
	
	# --- 5. LÓGICA DE ROTAÇÃO (Frente para o Player) ---
	var look_pos = player.global_position
	look_pos.y = new_object.global_position.y # Nivela o eixo Y para o baú não tombar para trás/frente
	
	# Só gira se o player não estiver exatamente dentro do mesmo pixel do baú
	if new_object.global_position.distance_to(look_pos) > 0.1:
		# Faz o objeto olhar para a posição nivelada do jogador
		new_object.look_at(look_pos, Vector3.UP)
		
		# Como o seu jogo tem estilo Grid (posições arredondadas), 
		# arredondamos a rotação para ângulos retos (0, 90, 180, 270 graus)
		var snapped_rot = snapped(new_object.rotation.y, PI / 2.0)
		new_object.rotation.y = snapped_rot
	# ----------------------------------------------------
	
	# 6. Consome energia e o item
	player.stamina_bar.consume(stamina_cost)
	player.inventory_component.get_inventory().remove_item(self, 1)
	
	print("Objeto colocado no mundo virado para o jogador!")
	return true
