@tool
extends Control
class_name ItemTooltip

@export var tooltip_label: RichTextLabel
@export var offset: Vector2 = Vector2(16, 16)
@export var max_width: int = 250

var _visible_slot_data: SlotData = null

func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 100
	
	if tooltip_label:
		tooltip_label.bbcode_enabled = true
		tooltip_label.fit_content = true
		
		# REMOVIDO: tooltip_label.custom_minimum_size.x = max_width (Isso travava o tamanho gigante)
		
		tooltip_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		tooltip_label.offset_left = 10
		tooltip_label.offset_top = 10
		tooltip_label.offset_right = -10
		tooltip_label.offset_bottom = -10
		
	_setup_background()

func _setup_background() -> void:
	var bg = get_node_or_null("Background") as Panel
	if not bg:
		bg = Panel.new()
		bg.name = "Background"
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		
	move_child(bg, 0)
	
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 0
	bg.offset_top = 0
	bg.offset_right = 0
	bg.offset_bottom = 0

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.95)
	style.border_color = Color(1, 1, 1, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)

	bg.add_theme_stylebox_override("panel", style)
	
func show_tooltip(slot_data: SlotData, screen_pos: Vector2) -> void:
	if not slot_data or slot_data.is_empty():
		hide_tooltip()
		return
	_visible_slot_data = slot_data
	
	# 1. Reseta os limites para o Godot medir o tamanho original do texto livremente
	tooltip_label.custom_minimum_size.x = 0
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tooltip_label.text = SlotUI.generate_tooltip_text(slot_data)
	
	# 2. Descobre a largura real daquele texto
	var real_width = tooltip_label.get_content_width()
	
	# 3. Se for maior que o máximo permitido, a gente trava a largura e liga a quebra de linha
	if real_width > max_width:
		tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tooltip_label.custom_minimum_size.x = max_width
		tooltip_label.size.x = max_width
	
	visible = true
	_update_position(screen_pos)

func hide_tooltip() -> void:
	visible = false
	_visible_slot_data = null

func _process(_delta: float) -> void:
	if visible and _visible_slot_data:
		_update_position(get_global_mouse_position())

func _update_position(mouse_pos: Vector2) -> void:
	var viewport_size = get_viewport_rect().size
	
	# Descobre o tamanho final do texto após as quebras de linha
	var final_width = tooltip_label.size.x
	if tooltip_label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		final_width = tooltip_label.get_content_width()
		
	# Adiciona 20px (que são as suas margens de 10px de cada lado)
	var target_size = Vector2(final_width + 20, tooltip_label.get_content_height() + 20)
	
	# Força o painel de fundo e o control a assumirem esse tamanho justinho
	size = target_size
	custom_minimum_size = target_size
	
	# Posicionamento inteligente para não fugir da tela
	var pos = mouse_pos + offset
	
	if pos.x + target_size.x > viewport_size.x:
		pos.x = mouse_pos.x - target_size.x - offset.x
	if pos.y + target_size.y > viewport_size.y:
		pos.y = mouse_pos.y - target_size.y - offset.y
		
	global_position = pos
