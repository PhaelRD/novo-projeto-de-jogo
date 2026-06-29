extends ItemDefinition
class_name SeedItemDefinition

@export_category("Configurações de Plantio")
@export var valid_soil_coords: Array[Vector2i] = [Vector2i(1, 2)]  ## Tiles de solo válido
@export var stamina_cost: int = 2

func use(player: CharacterBody3D, target_info: Dictionary) -> bool:
	if not player.stamina_bar.has_energy(stamina_cost):
		print("Estou muito cansado para plantar...")
		return false

	var target_pos = target_info.get("position", Vector3.ZERO)
	var collider   = target_info.get("collider")

	# Bloqueia se tiver objeto não-terrain na posição
	# (InteractionComponent já recua a mira via raycast como primeira barreira)
	if collider and not _is_terrain_body(collider):
		print("Não é possível plantar aqui, o espaço está ocupado!")
		return false

	var mapas     = player.get_tree().get_nodes_in_group("terrain")
	var base_y    = target_pos.y
	var tile_info = null

	if mapas.size() > 0:
		var tile_map = mapas[0]
		if tile_map.runtime_api:
			var player_y = player.global_position.y
			for offset_y in [1.0, 0.5, 0.0, -0.5, -1.0, -1.5]:
				var test_pos = target_pos
				test_pos.y   = player_y + offset_y
				var check = tile_map.runtime_api.find_tile(test_pos, 0)  # 0 = FLOOR
				if check != null:
					tile_info = check
					base_y    = round(test_pos.y)
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

	# Cria a planta no mundo
	if placement_scene:
		var new_tree = placement_scene.instantiate()
		if "growth_stage" in new_tree:
			new_tree.growth_stage = 0

		player.get_tree().current_scene.add_child(new_tree)
		new_tree.global_position = Vector3(target_pos.x, base_y, target_pos.z)

		if new_tree.has_method("_atualizar_visual_crescimento"):
			new_tree._atualizar_visual_crescimento()

		player.stamina_bar.consume(stamina_cost)
		player.inventory_component.get_inventory().remove_item(self, 1)
		print("Semente plantada com sucesso na altura: ", base_y)
		return true

	return false

# Sobe a hierarquia de pais até encontrar o grupo "terrain".
static func _is_terrain_body(node: Node) -> bool:
	var n: Node = node
	while n:
		if n.is_in_group("terrain"):
			return true
		n = n.get_parent()
	return false
