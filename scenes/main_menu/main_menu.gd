extends CanvasLayer

const GAME_SCENE = "res://scenes/teste/test_map.tscn"

@onready var btn_new_game  : Button = $Background/VBox/BtnNewGame
@onready var btn_load_game : Button = $Background/VBox/BtnLoadGame
@onready var lbl_no_save   : Label  = $Background/VBox/LblNoSave

func _ready() -> void:
	# Habilita o botão de carregar apenas se houver save
	var save_exists = SaveManager.has_save()
	btn_load_game.disabled = not save_exists
	lbl_no_save.visible    = not save_exists

	btn_new_game.pressed.connect(_on_new_game)
	btn_load_game.pressed.connect(_on_load_game)

	# Usa call_deferred para garantir que o mouse apareça após as transições de cena limparem,
	# e adiciona focus automático para jogar por teclado/controle (caso a "seta" seja foco)
	call_deferred("_setup_focus_and_mouse", save_exists)

func _setup_focus_and_mouse(save_exists: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if save_exists:
		btn_load_game.grab_focus()
	else:
		btn_new_game.grab_focus()

func _on_new_game() -> void:
	TimeManager.reset()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_load_game() -> void:
	# load_game() já cuida de trocar de cena e carregar tudo
	SaveManager.load_game()
