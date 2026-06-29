extends StaticBody3D

@onready var anim_player: AnimationPlayer = $blockbench_export/AnimationPlayer
@onready var area_porta1: Area3D          = $ZonaPorta1
@onready var area_porta2: Area3D          = $ZonaPorta2

var _animando: bool = false

func _ready() -> void:
	print("🏠 [CASA] _ready() chamado")

	# --- Verifica se os nós existem ---
	if not anim_player:
		push_error("🏠 [CASA] AnimationPlayer NÃO encontrado em $blockbench_export/AnimationPlayer")
	else:
		print("🏠 [CASA] AnimationPlayer OK. Animações disponíveis: ", anim_player.get_animation_list())
		anim_player.animation_finished.connect(_on_animation_finished)
		anim_player.play("defaut")
		print("🏠 [CASA] Tocando animação 'defaut'")

	if not area_porta1:
		push_error("🏠 [CASA] ZonaPorta1 NÃO encontrada")
	else:
		print("🏠 [CASA] ZonaPorta1 OK na posição: ", area_porta1.global_position)

	if not area_porta2:
		push_error("🏠 [CASA] ZonaPorta2 NÃO encontrada")
	else:
		print("🏠 [CASA] ZonaPorta2 OK na posição: ", area_porta2.global_position)

	print("🏠 [CASA] Grupos deste nó: ", get_groups())

# ------------------------------------------------------------------
# Chamado por Player.gd: body.interact(self)
# ------------------------------------------------------------------
func interact(player: CharacterBody3D) -> void:
	print("🏠 [CASA] interact() CHAMADO! _animando=", _animando)

	if _animando:
		print("🏠 [CASA] Ignorado: animação de porta já em progresso")
		return

	# --- Verifica o InteractionComponent ---
	var interaction_node = player.get_node_or_null("InteractionComponent")
	if not interaction_node:
		push_error("🏠 [CASA] InteractionComponent NÃO encontrado no player")
		return
	print("🏠 [CASA] InteractionComponent encontrado: ", interaction_node)

	# --- Verifica a Area3D do InteractionComponent ---
	var player_area: Area3D = interaction_node.get_node_or_null("Area3D")
	if not player_area:
		push_error("🏠 [CASA] Area3D NÃO encontrada dentro de InteractionComponent")
		return
	print("🏠 [CASA] Area3D do player encontrada. Posição: ", player_area.global_position)

	# --- Lista todas as áreas sobrepostas ---
	var areas_sobreadas: Array = player_area.get_overlapping_areas()
	print("🏠 [CASA] Áreas sobrepostas pela Area3D do player: ", areas_sobreadas.size())
	for a in areas_sobreadas:
		print("   → ", a.name, " (", a, ")")

	# --- Verifica se bate com alguma porta ---
	var achou_porta = false
	for area in areas_sobreadas:
		if area == area_porta1:
			print("🏠 [CASA] ✅ ZonaPorta1 detectada! Tocando 'porta1'")
			_play_porta("porta1")
			achou_porta = true
			return
		if area == area_porta2:
			print("🏠 [CASA] ✅ ZonaPorta2 detectada! Tocando 'porta2'")
			_play_porta("porta2")
			achou_porta = true
			return

	if not achou_porta:
		print("🏠 [CASA] ⚠️ Nenhuma zona de porta sobreposta. Player longe demais das portas.")
		print("         Posição player_area: ", player_area.global_position)
		print("         Posição ZonaPorta1:  ", area_porta1.global_position if area_porta1 else "NULL")
		print("         Posição ZonaPorta2:  ", area_porta2.global_position if area_porta2 else "NULL")

func _play_porta(nome: String) -> void:
	if not anim_player:
		push_error("🏠 [CASA] _play_porta: AnimationPlayer é null!")
		return
	_animando = true
	print("🏠 [CASA] Iniciando animação: '", nome, "'")
	anim_player.play(nome)

func _on_animation_finished(anim_name: StringName) -> void:
	print("🏠 [CASA] Animação '", anim_name, "' terminou. Voltando para 'defaut'")
	_animando = false
	if anim_player:
		anim_player.play("defaut")
