extends PanelContainer
class_name ClockDisplay

# ─── Nós ──────────────────────────────────────────────────────────────────────
@onready var _season_label : Label = $VBoxContainer/SeasonLabel
@onready var _day_label    : Label = $VBoxContainer/DayLabel
@onready var _clock_label  : Label = $VBoxContainer/ClockLabel

# Emoji de cada estação (índice espelha TimeManager.SEASON_NAMES)
const SEASON_ICONS := ["🌸", "☀️", "🍂", "❄️"]

# ─── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_apply_style()
	TimeManager.hour_changed.connect(_on_hour_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	_refresh_all()

# ─── Callbacks ────────────────────────────────────────────────────────────────
func _on_hour_changed(_hour: float) -> void:
	_clock_label.text = TimeManager.get_time_string()

func _on_day_changed(_day: int, _season: int, _year: int) -> void:
	_refresh_all()

# ─── Atualização Completa ──────────────────────────────────────────────────────
func _refresh_all() -> void:
	var icon : String = SEASON_ICONS[TimeManager.current_season]
	_season_label.text = "%s  %s" % [icon, TimeManager.get_season_name()]
	_day_label.text    = "Dia %d  ·  Ano %d" % [TimeManager.current_day, TimeManager.current_year]
	_clock_label.text  = TimeManager.get_time_string()

# ─── Estilo Programático (estilo Stardew Valley) ──────────────────────────────
func _apply_style() -> void:
	# Fundo do painel: semi-transparente, bordas arredondadas
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color              = Color(0.08, 0.06, 0.04, 0.80)
	panel_style.border_width_left     = 2
	panel_style.border_width_right    = 2
	panel_style.border_width_top      = 2
	panel_style.border_width_bottom   = 2
	panel_style.border_color          = Color(0.55, 0.42, 0.22, 0.90)
	panel_style.corner_radius_top_left     = 6
	panel_style.corner_radius_top_right    = 6
	panel_style.corner_radius_bottom_left  = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left   = 10.0
	panel_style.content_margin_right  = 10.0
	panel_style.content_margin_top    = 6.0
	panel_style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", panel_style)

	# Estação
	_season_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	_season_label.add_theme_font_size_override("font_size", 13)

	# Dia / Ano
	_day_label.add_theme_color_override("font_color", Color(0.80, 0.72, 0.55))
	_day_label.add_theme_font_size_override("font_size", 11)

	# Relógio — destaque maior
	_clock_label.add_theme_color_override("font_color", Color(1.00, 0.97, 0.80))
	_clock_label.add_theme_font_size_override("font_size", 16)

	# Alinha os textos ao centro
	_season_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
