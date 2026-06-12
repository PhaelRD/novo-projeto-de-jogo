extends Node

const SAVE_PATH = "user://savegame.json"

func _unhandled_input(event: InputEvent) -> void:
	# Atalhos rápidos para você testar durante o desenvolvimento!
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F5:
			save_game()
		elif event.keycode == KEY_F9:
			load_game()

func save_game():
	var save_dict = {
		# Salva qual é a fase atual que o jogador está
		"current_scene": get_tree().current_scene.scene_file_path,
		"player": {},
		"world_objects": []
	}
	
	# Pega todo mundo que está marcado com o grupo 'persist'
	var save_nodes = get_tree().get_nodes_in_group("persist")
	for node in save_nodes:
		if node is Player:
			save_dict["player"] = node.get_save_data()
		elif node.has_method("get_save_data"):
			save_dict["world_objects"].append(node.get_save_data())
			
	# Cria o arquivo e salva
	var arquivo = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(save_dict, "\t"))
	print("💾 Jogo Salvo com Sucesso! Caminho: ", SAVE_PATH)

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("❌ Nenhum save encontrado.")
		return
		
	var arquivo = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var save_dict = JSON.parse_string(arquivo.get_as_text())
	
	# Aqui, no futuro, nós podemos ler o 'current_scene' e trocar de fase se o 
	# jogador tiver salvo em um mapa diferente do atual.
	
	# Procura os nós para devolver os dados
	var save_nodes = get_tree().get_nodes_in_group("persist")
	for node in save_nodes:
		if node is Player and save_dict.has("player"):
			node.load_save_data(save_dict["player"])
			
	print("📂 Jogo Carregado com Sucesso!")
