extends ItemDefinition
class_name SeedItemDefinition

@export_category("Configurações de Plantio")
@export var valid_terrain_ids: Array[int] = [0]  ## IDs do Terrain Set 0 (ex: 0 = Terra Fértil)
@export var stamina_cost: int = 2
@export_category("Estações Permitidas")
@export var plant_in_spring: bool = true
@export var plant_in_summer: bool = true
@export var plant_in_autumn: bool = true
@export var plant_in_winter: bool = true

func use(player: CharacterBody3D, target_info: Dictionary) -> bool:
	if not player.stamina_bar.has_energy(stamina_cost):
		print("Estou muito cansado para plantar...")
		return false

	# Verifica se a estação atual permite o plantio
	var current_season = TimeManager.current_season
	var can_plant: bool = false
	match current_season:
		0: can_plant = plant_in_spring
		1: can_plant = plant_in_summer
		2: can_plant = plant_in_autumn
		3: can_plant = plant_in_winter
		
	if not can_plant:
		var season_names = ["Primavera", "Verão", "Outono", "Inverno"]
		var current_name = season_names[current_season] if current_season >= 0 and current_season < 4 else "Desconhecida"
		print("Semente falhou! Esta semente não pode ser plantada na estação atual (", current_name, ").")
		return false

	var target_pos = target_info.get("position", Vector3.ZERO)
	var collider   = target_info.get("collider")

	if target_info.get("is_blocked", false):
		print("Plantio falhou! Existe um objeto não-interagível na mira.")
		return false

	var validity = check_soil_validity(target_pos, collider)
	if not validity[0]:
		print("Semente falhou! Este tipo de terreno não é adequado ou o espaço está ocupado.")
		return false
		
	var base_y = validity[1]

	# Cria a planta no mundo
	if placement_scene:
		var new_tree = placement_scene.instantiate()
		if "was_planted" in new_tree:
			new_tree.was_planted = true

		player.get_tree().current_scene.add_child(new_tree)
		new_tree.global_position = Vector3(target_pos.x, base_y, target_pos.z)
		new_tree.add_to_group("planted")

		if new_tree.has_method("_atualizar_visual_crescimento"):
			new_tree._atualizar_visual_crescimento()

		player.stamina_bar.consume(stamina_cost)
		player.inventory_component.get_inventory().remove_item(self, 1)
		print("Semente plantada com sucesso na altura: ", base_y)
		return true

	return false

# Retorna o TileMapLayer3D caso o collider seja parte de um.
static func _get_tile_map_from_collider(node: Node) -> Node:
	var n: Node = node
	while n:
		if "runtime_api" in n and n.runtime_api != null:
			return n
		n = n.get_parent()
	return null

# Verifica no mapa atual se a coordenada 3D apontada repousa sobre um Terrain válido para esta semente.
# Retorna um Array: [bool is_valid, float final_y]
func check_soil_validity(target_pos: Vector3, collider: Node) -> Array:
	var tile_map = _get_tile_map_from_collider(collider)
	if not tile_map:
		print("Seed debug: O alvo não é um TileMap.")
		return [false, target_pos.y]
		
	# Tenta encontrar o tile varrendo a altura
	var tile_info = null
	var base_y = target_pos.y
	
	for offset_y in [1.0, 0.5, 0.0, -0.5, -1.0, -1.5]:
		var test_pos = target_pos
		test_pos.y += offset_y
		var check = tile_map.runtime_api.find_tile(test_pos, 0) # 0 = FLOOR
		if check != null:
			tile_info = check
			base_y = round(test_pos.y)
			break
			
	if tile_info == null:
		print("Seed debug: Nenhum tile encontrado na coluna pos: ", target_pos)
		return [false, target_pos.y]
		
	print("Seed debug: Achou tile! atlas_coords=", tile_info.atlas_coords, " | atlas_source_id=", tile_info.atlas_source_id)
		
	# Obter o terrain ID nativo a partir do TileMapLayer3D PlacedTileInfo ou do TileSet Godot
	var terrain = -1
	if "terrain_id" in tile_info and tile_info.terrain_id != -1: 
		terrain = tile_info.terrain_id
	else:
		# Extração direta e absoluta do TileData nativo
		var ts: TileSet = tile_map.settings.tileset
		if ts:
			var source = ts.get_source(tile_info.atlas_source_id) as TileSetAtlasSource
			if source:
				var tdata = source.get_tile_data(tile_info.atlas_coords, 0)
				if tdata:
					terrain = tdata.terrain
					
	var allowed = valid_terrain_ids
	if allowed.is_empty():
		allowed = [0]
		
	print("Seed debug: Terrain ID extraído=", terrain, " (Esperado para aceitar: ", allowed, ")")
					
	if terrain in allowed:
		# Verificação anti-empilhamento para itens sem colisão
		if collider and collider.is_inside_tree():
			var final_pos = Vector3(target_pos.x, base_y, target_pos.z)
			for obj in collider.get_tree().get_nodes_in_group("planted"):
				if obj.is_inside_tree() and obj.global_position.distance_to(final_pos) < 0.1:
					print("Seed debug: Espaço já contém um objeto plantado sem colisão.")
					return [false, base_y]
					
		return [true, base_y]
		
	return [false, base_y]
