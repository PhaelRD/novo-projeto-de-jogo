extends Node

const SAVE_PATH = "user://savegame.json"

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
		"world_objects": [] # Aqui vão ficar as árvores!
	}
	
	var save_nodes = get_tree().get_nodes_in_group("persist")
	for node in save_nodes:
		# Se for o Player, salva no espaço do Player
		if node is Player:
			save_dict["player"] = node.get_save_data()
		# Se for árvore (ou baú, fornalha, etc no futuro), salva na lista de objetos
		elif node.has_method("get_save_data"):
			save_dict["world_objects"].append(node.get_save_data())
			
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
	
	# --- LÓGICA DO PLAYER ---
	for node in save_nodes:
		if node is Player and save_dict.has("player"):
			node.load_save_data(save_dict["player"])
			
	# --- NOVA LÓGICA: CARREGANDO AS ÁRVORES ---
	
	# 1. Primeiro, apagamos todas as árvores que estão no mapa atualmente.
	# (Isso evita que o mapa fique com árvores duplicadas quando você der load)
	for node in save_nodes:
		if not node is Player:
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
						
	print("📂 Jogo Carregado com Sucesso!")
