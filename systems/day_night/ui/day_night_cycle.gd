extends Node3D
class_name DayNightCycle

# ─── Referências aos nós filhos ────────────────────────────────────────────────
@onready var _world_env     : WorldEnvironment   = $WorldEnvironment
@onready var _sun           : DirectionalLight3D = $Sun
@onready var _moon          : DirectionalLight3D = $Moon
@onready var _night_overlay : ColorRect          = $CanvasLayer/NightOverlay

# ─── Dados das Estações ────────────────────────────────────────────────────────
# Cada entrada define a paleta visual de uma estação.
# Campos: sun_color, sun_intensity, ambient_color, sky_top, sky_horizon
const SEASON_DATA : Array[Dictionary] = [
	# 0 — Primavera
	{
		"sun_color"     : Color(1.00, 0.97, 0.85),
		"sun_intensity" : 1.0,
		"ambient"       : Color(0.50, 0.60, 0.45),
		"sky_top"       : Color(0.30, 0.55, 0.90),
		"sky_horizon"   : Color(0.70, 0.85, 1.00),
	},
	# 1 — Verão
	{
		"sun_color"     : Color(1.00, 0.98, 0.80),
		"sun_intensity" : 1.3,
		"ambient"       : Color(0.55, 0.55, 0.35),
		"sky_top"       : Color(0.20, 0.45, 0.95),
		"sky_horizon"   : Color(0.75, 0.88, 1.00),
	},
	# 2 — Outono
	{
		"sun_color"     : Color(1.00, 0.85, 0.60),
		"sun_intensity" : 0.85,
		"ambient"       : Color(0.50, 0.42, 0.30),
		"sky_top"       : Color(0.45, 0.55, 0.80),
		"sky_horizon"   : Color(0.85, 0.72, 0.55),
	},
	# 3 — Inverno
	{
		"sun_color"     : Color(0.85, 0.90, 1.00),
		"sun_intensity" : 0.65,
		"ambient"       : Color(0.40, 0.45, 0.55),
		"sky_top"       : Color(0.50, 0.60, 0.85),
		"sky_horizon"   : Color(0.80, 0.85, 0.95),
	},
]

# ─── Curva horária ─────────────────────────────────────────────────────────────
# Pontos de controle: [hora, rot_x_sol, fator_intensidade, alpha_overlay]
# A hora 26 = 2h da manhã (continuação após as 24h)
# Interpolado linearmente entre pontos com _sample_curve()
const HOUR_CURVE : Array = [
	[  4.0,   15.0, 0.00, 0.70 ],  # madrugada (sol abaixo do horizonte)
	[  6.0,    0.0, 0.30, 0.00 ],  # nascer do sol (horizontal)
	[  9.0,  -45.0, 0.80, 0.00 ],  # manhã
	[ 12.0,  -90.0, 1.00, 0.00 ],  # zênite (meio-dia, sem sombra lateral)
	[ 15.0, -135.0, 1.00, 0.00 ],  # tarde
	[ 18.0, -180.0, 0.75, 0.00 ],  # pôr do sol (horizontal oposto)
	[ 20.0, -195.0, 0.20, 0.20 ],  # entardecer
	[ 22.0, -270.0, 0.00, 0.55 ],  # noite (sol do outro lado do mundo)
	[ 26.0, -270.0, 0.00, 0.70 ],  # 2h da manhã (= hora 26)
]

var _current_season : int = 0

# ─── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	TimeManager.hour_changed.connect(_on_hour_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.season_changed.connect(_on_season_changed)
	_apply_season(TimeManager.current_season)
	_update_lighting(TimeManager.current_hour)

# ─── Callbacks dos sinais ──────────────────────────────────────────────────────
func _on_hour_changed(hour: float) -> void:
	_update_lighting(hour)

func _on_day_changed(_day: int, season: int, _year: int) -> void:
	if season != _current_season:
		_apply_season(season)

func _on_season_changed(season: int, _year: int) -> void:
	_apply_season(season)

# ─── Lógica de Iluminação ──────────────────────────────────────────────────────
func _update_lighting(hour: float) -> void:
	# Normaliza a madrugada: horas < 4 viram 24+ para continuar a curva
	var h : float = hour if hour >= 4.0 else hour + 24.0

	var rot_x    : float = _sample_curve(h, 1)
	var intens_f : float = _sample_curve(h, 2)
	var overlay  : float = _sample_curve(h, 3)

	var s : Dictionary = SEASON_DATA[_current_season]
	var base_intensity : float = s["sun_intensity"]
	var is_night : bool = intens_f <= 0.0

	# ── Sol / Lua ──────────────────────────────────────────────
	_sun.visible  = not is_night
	_moon.visible = is_night

	if not is_night:
		_sun.rotation_degrees.x = rot_x
		_sun.light_color        = s["sun_color"]
		_sun.light_energy       = base_intensity * intens_f

	# ── Overlay noturno ────────────────────────────────────────
	var oc := _night_overlay.color
	oc.a = overlay
	_night_overlay.color = oc

	# ── Ambiente (WorldEnvironment) ────────────────────────────
	var env := _world_env.environment
	if not env:
		return

	var night_ambient := Color(0.04, 0.05, 0.12)
	env.ambient_light_color  = (s["ambient"] as Color).lerp(night_ambient, overlay)
	env.ambient_light_energy = lerp(0.5, 0.12, overlay)

	# ── Céu procedural ─────────────────────────────────────────
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
		var night_top     := Color(0.01, 0.01, 0.06)
		var night_horizon := Color(0.03, 0.04, 0.12)
		sky_mat.sky_top_color     = (s["sky_top"]     as Color).lerp(night_top,     overlay)
		sky_mat.sky_horizon_color = (s["sky_horizon"] as Color).lerp(night_horizon, overlay)
		sky_mat.ground_bottom_color = Color(0.08, 0.08, 0.08)

func _apply_season(season_idx: int) -> void:
	_current_season = clamp(season_idx, 0, SEASON_DATA.size() - 1)
	_update_lighting(TimeManager.current_hour)

# ─── Utilitário: amostra a curva de controle ──────────────────────────────────
# field: 1=rot_x  2=intensidade  3=overlay_alpha
func _sample_curve(hour: float, field: int) -> float:
	for i in range(HOUR_CURVE.size() - 1):
		var a : Array = HOUR_CURVE[i]
		var b : Array = HOUR_CURVE[i + 1]
		if hour >= a[0] and hour <= b[0]:
			var t : float = remap(hour, a[0], b[0], 0.0, 1.0)
			return lerp(float(a[field]), float(b[field]), t)
	return float(HOUR_CURVE[-1][field])
