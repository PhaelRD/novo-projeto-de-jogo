extends ItemDefinition
class_name PlaceableItemDefinition

@export_category("Configurações de Construção")
@export var valid_terrain_ids: Array[int] = [] ## Vazio = aceita qualquer chão. Preenchido (ex: [0]) = exige terreno específico.
@export var stamina_cost: int = 0
@export var require_floor: bool = true  ## Exige chão válido embaixo para colocar

func use(player: CharacterBody3D, target_info: Dictionary) -> bool:
	# 1. Verifica stamina
	if not player.stamina_bar.has_energy(stamina_cost):
		print("Estou muito cansado para colocar objetos...")
		return false

	var target_pos = target_info.get("position", Vector3.ZERO)
	var collider   = target_info.get("collider")

	if not placement_scene:
		push_warning("Atenção: Este item não possui uma placement_scene configurada!")
		return false

	if target_info.get("is_blocked", false):
		print("Construção falhou! Existe um objeto não-interagível na mira.")
		return false

	var validity = check_soil_validity(target_pos, collider)
	if not validity[0]:
		print("Construção falhou! Este terreno não é adequado ou está ocupado.")
		return false
		
	var base_y = validity[1]

	# 4. Instancia e coloca no mundo
	var new_object = placement_scene.instantiate()
	player.get_tree().current_scene.add_child(new_object)
	new_object.global_position = Vector3(target_pos.x, base_y, target_pos.z)
	new_object.add_to_group("planted")

	# 5. Rotação: vira para o player (snap em 90°)
	var look_pos = player.global_position
	look_pos.y   = new_object.global_position.y
	if new_object.global_position.distance_to(look_pos) > 0.1:
		new_object.look_at(look_pos, Vector3.UP)
		new_object.rotation.y = snapped(new_object.rotation.y, PI / 2.0)

	# 6. Consome stamina e remove do inventário
	player.stamina_bar.consume(stamina_cost)
	player.inventory_component.get_inventory().remove_item(self, 1)

	print("Objeto colocado no mundo virado para o jogador!")
	return true

# Retorna o TileMapLayer3D caso o collider seja parte de um.
static func _get_tile_map_from_collider(node: Node) -> Node:
	var n: Node = node
	while n:
		if "runtime_api" in n and n.runtime_api != null:
			return n
		n = n.get_parent()
	return null

# Verifica no mapa se a coordenada repousa sobre um Terrain válido (se require_floor for true).
func check_soil_validity(target_pos: Vector3, collider: Node) -> Array:
	if not require_floor:
		return [true, target_pos.y]
		
	var tile_map = _get_tile_map_from_collider(collider)
	if not tile_map:
		print("Placeable debug: O alvo não é um TileMap.")
		return [false, target_pos.y]
		
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
		print("Placeable debug: Nenhum tile encontrado na coluna pos: ", target_pos)
		return [false, target_pos.y]
		
	# Se a lista estiver vazia, aceita qualquer terreno!
	if valid_terrain_ids.is_empty():
		return [true, base_y]
		
	var terrain = -1
	if "terrain_id" in tile_info and tile_info.terrain_id != -1: 
		terrain = tile_info.terrain_id
	else:
		var ts: TileSet = tile_map.settings.tileset
		if ts:
			var source = ts.get_source(tile_info.atlas_source_id) as TileSetAtlasSource
			if source:
				var tdata = source.get_tile_data(tile_info.atlas_coords, 0)
				if tdata:
					terrain = tdata.terrain
					
	if require_floor and terrain not in valid_terrain_ids:
		return [false, base_y]
		
	# Verificação anti-empilhamento para itens sem colisão no Grid
	if collider and collider.is_inside_tree():
		var final_pos = Vector3(target_pos.x, base_y, target_pos.z)
		for obj in collider.get_tree().get_nodes_in_group("planted"):
			if obj.is_inside_tree() and obj.global_position.distance_to(final_pos) < 0.1:
				print("Build debug: Espaço já contém um objeto.")
				return [false, base_y]
				
	return [true, base_y]
