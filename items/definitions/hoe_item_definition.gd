extends ItemDefinition
class_name HoeItemDefinition

@export_category("Configurações da Enchada")
@export var stamina_cost: int = 5

## IDs de terreno que a enchada pode lavrar.
## Consulte a aba "Terrains" do TileSet para ver os IDs.
@export var valid_terrain_ids: Array[int] = [0]

## ID do terreno de DESTINO (para onde o tile vai mudar após lavrar).
## O script busca automaticamente as coords de um tile desse terreno no atlas.
@export var target_terrain_id: int = 1

## Terrain set index a usar na busca (normalmente 0).
@export var terrain_set: int = 0

## Offsets de Y varridos para achar o tile FLOOR abaixo do cursor.
@export var y_scan_offsets: Array[float] = [1.0, 0.5, 0.0, -0.5, -1.0, -1.5]

# ──────────────────────────────────────────────────────────────────────────────
func use(player: CharacterBody3D, target_info: Dictionary) -> bool:
	if not player.stamina_bar.has_energy(stamina_cost):
		print("Estou muito cansado para lavrar...")
		return false

	var target_pos: Vector3 = target_info.get("position", Vector3.ZERO)
	var collider          = target_info.get("collider")

	if target_info.get("is_blocked", false):
		return false

	# ── 1. Encontrar o TileMapLayer3D subindo a hierarquia do collider ─────────
	var tile_map = _get_tile_map_from_collider(collider)
	if not tile_map:
		return false

	# ── 2. Varrer alturas para achar o tile FLOOR (igual à SeedItemDefinition) ─
	var tile_info = null
	for offset_y in y_scan_offsets:
		var test_pos = target_pos
		test_pos.y += offset_y
		var check = tile_map.runtime_api.find_tile(test_pos, 0)  # 0 = FLOOR
		if check != null:
			tile_info = check
			break

	if tile_info == null:
		print("Enchada: nenhum tile encontrado na posição ", target_pos)
		return false

	# ── 3. Extrair terrain_id do tile atual ────────────────────────────────────
	var ts: TileSet = tile_map.settings.tileset
	if not ts:
		return false

	var current_terrain: int = -1
	if "terrain_id" in tile_info and tile_info.terrain_id != -1:
		current_terrain = tile_info.terrain_id
	else:
		var source = ts.get_source(tile_info.atlas_source_id) as TileSetAtlasSource
		if source:
			var tdata = source.get_tile_data(tile_info.atlas_coords, 0)
			if tdata:
				current_terrain = tdata.terrain

	print("Enchada: terrain atual=", current_terrain, " (válidos: ", valid_terrain_ids, ")")

	var terrain_to_apply: int = -1

	if current_terrain in valid_terrain_ids:
		terrain_to_apply = target_terrain_id
	elif current_terrain == target_terrain_id and valid_terrain_ids.size() > 0:
		terrain_to_apply = valid_terrain_ids[0]
	else:
		print("Enchada: terreno inválido para lavrar/deslavrar.")
		return false

	# ── 4. Encontrar as atlas_coords de um tile do terreno de destino ──────────
	var target_coords: Vector2i = _find_coords_for_terrain(
		ts, tile_info.atlas_source_id, terrain_to_apply, terrain_set
	)
	if target_coords == Vector2i(-1, -1):
		push_error("Enchada: nenhum tile encontrado com terrain_id=%d no atlas source %d" \
			% [terrain_to_apply, tile_info.atlas_source_id])
		return false

	print("Enchada: destino terrain_id=", terrain_to_apply, " → atlas_coords=", target_coords)

	# ── 5. Atualizar terrain_id e aplicar Autotile ─────────────────────────────
	# Primeiro atualizamos o ID internamente
	if tile_map._saved_tiles_lookup.has(tile_info.tile_key):
		var tile_index: int = tile_map._saved_tiles_lookup[tile_info.tile_key]
		tile_map.update_tile_terrain_columnar(tile_index, terrain_to_apply)
		
	# Instanciamos a engine de autotile para calcular as bordas corretas
	var autotile = AutotileEngine.new(ts, tile_info.atlas_source_id, terrain_set)
	
	# Calcula o UV correto deste tile central com base nos vizinhos
	var center_uv: Rect2 = autotile.get_autotile_uv(tile_info.grid_position, tile_info.orientation, terrain_to_apply, tile_map)
	if center_uv.has_area():
		var ts_size: Vector2i = TileAtlasResolver.get_tile_size(tile_map.settings)
		var center_coords = Vector2i(
			int(round(center_uv.position.x / float(ts_size.x))),
			int(round(center_uv.position.y / float(ts_size.y)))
		)
		tile_map.update_tile_uv(tile_info.tile_key, center_uv, tile_info.atlas_source_id, center_coords)
	else:
		# Fallback se o autotile falhar (ex: terreno sem regras de autotile)
		var ok = tile_map.runtime_api.swap_tile_texture(tile_info, false, target_coords)
		if not ok:
			print("Enchada: swap_tile_texture falhou para coords ", target_coords)
			return false
			
	# Atualiza os vizinhos para se conectarem a este novo terreno
	var neighbor_updates: Dictionary = autotile.update_neighbors(tile_info.grid_position, tile_info.orientation, tile_map)
	if not neighbor_updates.is_empty():
		var ts_size: Vector2i = TileAtlasResolver.get_tile_size(tile_map.settings)
		for neighbor_key: int in neighbor_updates.keys():
			var n_uv: Rect2 = neighbor_updates[neighbor_key]
			var n_coords = Vector2i(
				int(round(n_uv.position.x / float(ts_size.x))),
				int(round(n_uv.position.y / float(ts_size.y)))
			)
			tile_map.update_tile_uv(neighbor_key, n_uv, tile_info.atlas_source_id, n_coords)

	# ── 6. Consumir stamina e animar ──────────────────────────────────────────
	player.stamina_bar.consume(stamina_cost)
	if player.has_node("AnimatedSprite3D"):
		var spr = player.get_node("AnimatedSprite3D")
		if spr.sprite_frames and spr.sprite_frames.has_animation("attack"):
			spr.play("attack")

	print("Enchada: tile lavrado com sucesso!")
	return true


# ── Helpers ───────────────────────────────────────────────────────────────────

## Retorna as atlas_coords do PRIMEIRO tile que pertence ao [terrain_id] dentro
## do [source_id] do TileSet. Retorna Vector2i(-1,-1) se não encontrar.
## Itera o grid do atlas com get_atlas_grid_size() + has_tile() (API Godot 4 correta).
static func _find_coords_for_terrain(
		ts: TileSet, source_id: int, terrain_id: int, tset: int
) -> Vector2i:
	var source = ts.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return Vector2i(-1, -1)

	var grid_size: Vector2i = source.get_atlas_grid_size()
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var coords := Vector2i(x, y)
			if not source.has_tile(coords):
				continue
			var tdata = source.get_tile_data(coords, 0)
			if tdata and tdata.terrain_set == tset and tdata.terrain == terrain_id:
				return coords

	return Vector2i(-1, -1)



## Sobe a hierarquia do nó até encontrar um TileMapLayer3D (tem runtime_api).
static func _get_tile_map_from_collider(node: Node) -> Node:
	var n: Node = node
	while n:
		if "runtime_api" in n and n.runtime_api != null:
			return n
		n = n.get_parent()
	return null
