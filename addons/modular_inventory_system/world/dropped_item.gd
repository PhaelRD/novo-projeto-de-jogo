@tool
extends Node3D
class_name DroppedItem

@export var item_: ItemDefinition
@export var count: int = 1

var _pickup_component: Node3D # Quando pronto, o tipo real será PickupComponent

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	add_to_group("dropped_item")
	
	_setup_model()
	_setup_pickup()

func _setup_model() -> void:
	# 1. Tenta usar um modelo 3D, se existir
	if item_ and item_.model_scene:
		var model_instance = item_.model_scene.instantiate()
		add_child(model_instance)
		
	# 2. Se não tem modelo 3D, mas tem ícone 2D
	elif item_ and item_.icon:
		var sprite = Sprite3D.new()
		sprite.texture = item_.icon
		
		# Faz a imagem ser renderizada de forma nítida (ideal para pixel art)
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		
		# Faz a arte estar sempre "de frente" para a câmera do jogador
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		
		# --- MATEMÁTICA DE PADRONIZAÇÃO DE TAMANHO ---
		# Defina aqui o tamanho físico máximo que o item deve ter no mundo 3D (ex: 0.8 metros)
		var tamanho_desejado: float = 0.8 
		
		# Pega a largura e altura originais da imagem (do arquivo PNG)
		var largura_img: float = item_.icon.get_width()
		var altura_img: float = item_.icon.get_height()
		
		# Pega o maior lado da imagem para garantir que ela caiba inteira no tamanho desejado
		var maior_lado: float = max(largura_img, altura_img)
		
		# Calcula o pixel_size ideal automaticamente para essa imagem específica!
		if maior_lado > 0:
			sprite.pixel_size = tamanho_desejado / maior_lado
		
		add_child(sprite)
		
	# 3. Fallback do fallback: se não tiver NADA, vira um cubo
	else:
		var mesh = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(0.7, 0.7, 0.7)
		mesh.mesh = box_mesh
		add_child(mesh)

func _setup_pickup() -> void:
	# Desativamos o código original que causa crash
	pass
