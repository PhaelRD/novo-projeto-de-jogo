extends Node

const SAVE_PATH = "user://savegame.json"

## Retorna true se existe um arquivo de save salvo
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F5:
			save_game()
		elif event.keycode == KEY_F9:
			load_game()

func save_game():
	var save_dict = {
		"current_scene": get_tree().current_scene.scene_file_path,
		"player": {},
		"world_objects": [], # Aqui vão ficar as árvores!
		"time": TimeManager.get_save_data(),
		"tilemaps": {}
	}
	
	var save_nodes = get_tree().get_nodes_in_group("persist")
	for node in save_nodes:
		# Se for o Player, salva no espaço do Player
		if node is Player:
			save_dict["player"] = node.get_save_data()
		# Se for árvore (ou baú, fornalha, etc no futuro), salva na lista de objetos
		elif node.has_method("get_save_data"):
			save_dict["world_objects"].append(node.get_save_data())
			
	# --- SALVAR TILEMAPS ---
	var tilemaps = get_tree().current_scene.find_children("*", "TileMapLayer3D", true, false)
	for tilemap in tilemaps:
		var tm_path = str(get_tree().current_scene.get_path_to(tilemap))
		save_dict["tilemaps"][tm_path] = {
			"positions": var_to_str(tilemap._tile_positions),
			"uv_rects": var_to_str(tilemap._tile_uv_rects),
			"atlas_source_ids": var_to_str(tilemap._tile_atlas_source_ids),
			"atlas_coords": var_to_str(tilemap._tile_atlas_coords),
			"flags": var_to_str(tilemap._tile_flags),
			"transform_indices": var_to_str(tilemap._tile_transform_indices),
			"transform_data": var_to_str(tilemap._tile_transform_data),
			"custom_transforms": var_to_str(tilemap._tile_custom_transforms),
			"anim_indices": var_to_str(tilemap._tile_anim_indices),
			"anim_data": var_to_str(tilemap._tile_anim_data)
		}
	var arquivo = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(save_dict, "\t"))
	print("💾 Jogo Salvo com Sucesso! Caminho: ", SAVE_PATH)

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("❌ Nenhum save encontrado.")
		return
		
	var arquivo = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var save_dict = JSON.parse_string(arquivo.get_as_text())
	
	# --- LÓGICA DE TROCA DE CENA ---
	if save_dict.has("current_scene") and save_dict["current_scene"] != get_tree().current_scene.scene_file_path:
		print("Mudando para o mapa: ", save_dict["current_scene"])
		get_tree().change_scene_to_file(save_dict["current_scene"])
		await get_tree().process_frame
		await get_tree().process_frame
	
	# Pega todo mundo que está vivo no mapa atual
	var save_nodes = get_tree().get_nodes_in_group("persist")
	
	# --- LÓGICA DO TEMPO ---
	if save_dict.has("time"):
		TimeManager.load_save_data(save_dict["time"])

	# --- LÓGICA DO PLAYER ---
	for node in save_nodes:
		if node is Player and save_dict.has("player"):
			node.load_save_data(save_dict["player"])
			
	# --- NOVA LÓGICA: CARREGANDO AS ÁRVORES ---
	
	# 1. Primeiro, apagamos todas as árvores que estão no mapa atualmente.
	# (Isso evita que o mapa fique com árvores duplicadas quando você der load)
	for node in save_nodes:
		if not node is Player and not node.has_method("_rebuild_chunks_from_saved_data"):
			node.queue_free()
			
	# 2. Agora, lemos o JSON e "plantamos" tudo o que estava salvo
	if save_dict.has("world_objects"):
		for obj_data in save_dict["world_objects"]:
			# Se o objeto salvo tiver o caminho da cena dele (res://Tree.tscn)
			if obj_data.has("scene_file"):
				var cena = load(obj_data["scene_file"]) as PackedScene
				if cena:
					# Cria a árvore do zero
					var novo_objeto = cena.instantiate()
					get_tree().current_scene.add_child(novo_objeto)
					
					# Entrega os dados pra ela se posicionar e definir o tamanho
					if novo_objeto.has_method("load_save_data"):
						novo_objeto.load_save_data(obj_data)
						
	# --- CARREGAR TILEMAPS ---
	# Backward compatibility: formato antigo
	if save_dict.has("tilemap") and not save_dict["tilemap"].is_empty():
		var tilemap = get_tree().current_scene.get_node_or_null("TileMapLayer3D")
		if tilemap:
			_restore_tilemap_data(tilemap, save_dict["tilemap"])
			
	# Novo formato: múltiplos tilemaps baseados no node_path
	if save_dict.has("tilemaps") and not save_dict["tilemaps"].is_empty():
		for tm_path in save_dict["tilemaps"].keys():
			var tilemap = get_tree().current_scene.get_node_or_null(tm_path)
			if tilemap and tilemap.has_method("_rebuild_chunks_from_saved_data"):
				_restore_tilemap_data(tilemap, save_dict["tilemaps"][tm_path])
			
	print("📂 Jogo Carregado com Sucesso!")

func _restore_tilemap_data(tilemap: Node, tdata: Dictionary):
	if tdata.has("positions"): tilemap._tile_positions = str_to_var(tdata["positions"])
	if tdata.has("uv_rects"): tilemap._tile_uv_rects = str_to_var(tdata["uv_rects"])
	if tdata.has("atlas_source_ids"): tilemap._tile_atlas_source_ids = str_to_var(tdata["atlas_source_ids"])
	if tdata.has("atlas_coords"): tilemap._tile_atlas_coords = str_to_var(tdata["atlas_coords"])
	if tdata.has("flags"): tilemap._tile_flags = str_to_var(tdata["flags"])
	if tdata.has("transform_indices"): tilemap._tile_transform_indices = str_to_var(tdata["transform_indices"])
	if tdata.has("transform_data"): tilemap._tile_transform_data = str_to_var(tdata["transform_data"])
	if tdata.has("custom_transforms"): tilemap._tile_custom_transforms = str_to_var(tdata["custom_transforms"])
	if tdata.has("anim_indices"): tilemap._tile_anim_indices = str_to_var(tdata["anim_indices"])
	if tdata.has("anim_data"): tilemap._tile_anim_data = str_to_var(tdata["anim_data"])
	
	tilemap.clear_highlights()
	tilemap._rebuild_chunks_from_saved_data(true)
