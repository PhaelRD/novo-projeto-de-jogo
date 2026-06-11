extends StaticBody3D

# --- Exportações ---
@export var wood_item: ItemDefinition 
@export var max_health: int = 10 
@export var drop_amount: int = 2 

# --- Referências de Nós ---
# ATENÇÃO: Verifique se o nome do nó que tem a arte da árvore é exatamente "Sprite3D"
@onready var visual_node: Node3D = $Sprite3D

var dropped_item_scene = preload("res://addons/modular_inventory_system/world/dropped_item.tscn") 

var _current_health: int
var _original_visual_pos: Vector3
var _shake_tween: Tween # Guarda a animação atual

func _ready() -> void:
	_current_health = max_health
	
	# Salva a posição exata da imagem quando a árvore nasce
	# Isso impede que a árvore saia "andando" pelo mapa de tanto apanhar
	if visual_node:
		_original_visual_pos = visual_node.position

# Função que o Player vai chamar quando acertar a árvore com o machado
func hit_with_axe(damage: int) -> void:
	_current_health -= damage
	print("TOC! Árvore recebeu dano. Vida restante: ", _current_health)
	
	# Chama a tremidinha sempre que tomar um golpe!
	_shake_tree()
	
	# Se a vida chegar a zero ou menos, a árvore cai
	if _current_health <= 0:
		_chop_down()

# --- NOVA LÓGICA: O Game Feel da Tremidinha ---
func _shake_tree() -> void:
	if not visual_node: return
	
	# Se a árvore já estiver tremendo de um golpe anterior, nós paramos ela
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		
	# Garante que a imagem está no centro exato antes de começar
	visual_node.position = _original_visual_pos
	
	# Cria a nova animação de tremor
	_shake_tween = create_tween()
	
	# Sequência rápida de movimento no eixo X (Direita -> Esquerda -> Direita -> Centro)
	_shake_tween.tween_property(visual_node, "position:x", _original_visual_pos.x + 0.08, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", _original_visual_pos.x - 0.08, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", _original_visual_pos.x + 0.05, 0.04)
	_shake_tween.tween_property(visual_node, "position:x", _original_visual_pos.x, 0.04)

func _chop_down() -> void:
	print("Madeiraaa! A árvore caiu.")
	
	# Gera os itens de madeira no chão
	if wood_item and dropped_item_scene:
		for i in range(drop_amount):
			var drop = dropped_item_scene.instantiate()
			drop.item_ = wood_item
			drop.count = 1
			
			# Descobre qual é a cena principal atual do jogo e joga o item lá
			get_tree().current_scene.add_child(drop)
			
			# Posiciona a madeira onde a árvore estava, com um pequeno desvio
			var random_offset = Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))
			drop.global_position = global_position + random_offset
			
	# Remove a árvore do mapa
	queue_free()
