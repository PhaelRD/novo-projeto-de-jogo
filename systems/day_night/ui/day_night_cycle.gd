extends Node3D
class_name DayNightCycle

# ─── Referências aos nós filhos ────────────────────────────────────────────────
@onready var _world_env     : WorldEnvironment   = $WorldEnvironment
@onready var _sun           : DirectionalLight3D = $Sun
@onready var _moon          : DirectionalLight3D = $Moon
@onready var _night_overlay : ColorRect          = $CanvasLayer/NightOverlay
@onready var _rain_overlay  : ColorRect          = $CanvasLayer/RainOverlay

var splash_particles: GPUParticles3D

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
	TimeManager.weather_changed.connect(_on_weather_changed)
	_create_splash_particles()
	_apply_season(TimeManager.current_season)
	_update_lighting(TimeManager.current_hour)

# ─── Efeito de Splash no Chão ──────────────────────────────────────────────────
func _create_splash_particles() -> void:
	splash_particles = GPUParticles3D.new()
	splash_particles.name = "RainSplashes"
	splash_particles.amount = 400
	splash_particles.lifetime = 0.25
	splash_particles.emitting = false
	
	var pmat = ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(25.0, 0.0, 25.0)
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.3
	pmat.scale_max = 0.8
	
	var curve_scale = CurveTexture.new()
	var cs = Curve.new()
	cs.add_point(Vector2(0, 0))
	cs.add_point(Vector2(1, 1))
	curve_scale.curve = cs
	pmat.scale_curve = curve_scale
	
	var curve_alpha = CurveTexture.new()
	var ca = Curve.new()
	ca.add_point(Vector2(0, 1))
	ca.add_point(Vector2(1, 0))
	curve_alpha.curve = ca
	pmat.alpha_curve = curve_alpha

	splash_particles.process_material = pmat
	
	var quad = QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	quad.orientation = PlaneMesh.FACE_Y
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.7, 0.85, 1.0, 0.6)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	splash_particles.draw_pass_1 = quad
	
	add_child(splash_particles)

func _process(_delta: float) -> void:
	if splash_particles and splash_particles.emitting:
		var cam = get_viewport().get_camera_3d()
		if cam:
			var pos = cam.global_position
			pos.y = 0.1 # Nível do chão com margem
			splash_particles.global_position = pos

# ─── Callbacks dos sinais ──────────────────────────────────────────────────────
func _on_hour_changed(hour: float) -> void:
	_update_lighting(hour)

func _on_day_changed(_day: int, season: int, _year: int) -> void:
	if season != _current_season:
		_apply_season(season)

func _on_season_changed(season: int, _year: int) -> void:
	_apply_season(season)

func _on_weather_changed(_is_raining: bool) -> void:
	_update_lighting(TimeManager.current_hour)

# ─── Lógica de Iluminação ──────────────────────────────────────────────────────
func _update_lighting(hour: float) -> void:
	# Normaliza a madrugada: horas < 4 viram 24+ para continuar a curva
	var h : float = hour if hour >= 4.0 else hour + 24.0

	var rot_x    : float = _sample_curve(h, 1)
	var intens_f : float = _sample_curve(h, 2)
	var overlay  : float = _sample_curve(h, 3)

	var s : Dictionary = SEASON_DATA[_current_season]
	
	var is_raining : bool = TimeManager.is_raining
	var cloud_cov : float = 0.5
	
	if is_raining:
		cloud_cov = 0.95
		# Duplica o dict pra gente modificar sem alterar a constante global das seasons
		s = s.duplicate()
		s["sun_intensity"] *= 0.3
		s["sun_color"]     = (s["sun_color"] as Color).lerp(Color(0.8, 0.85, 0.9), 0.8)
		s["sky_top"]       = (s["sky_top"] as Color).lerp(Color(0.4, 0.45, 0.5), 0.8)
		s["sky_horizon"]   = (s["sky_horizon"] as Color).lerp(Color(0.5, 0.55, 0.6), 0.8)
		s["ambient"]       = (s["ambient"] as Color).lerp(Color(0.4, 0.45, 0.5), 0.8)

	var base_intensity : float = s["sun_intensity"]
	var is_night : bool = intens_f <= 0.0

	# Ativar / Desativar tela de chuva
	if _rain_overlay and _rain_overlay.material:
		_rain_overlay.material.set_shader_parameter("rain_amount", 1.0 if is_raining else 0.0)
	if splash_particles:
		splash_particles.emitting = is_raining

	# ── Sol / Lua ──────────────────────────────────────────────
	_sun.visible  = not is_night
	_moon.visible = is_night

	var tilt_basis = Basis.from_euler(Vector3(0.0, deg_to_rad(-35.0), 0.0))
	_sun.transform.basis = tilt_basis * Basis.from_euler(Vector3(deg_to_rad(rot_x), 0.0, 0.0))
	_moon.transform.basis = tilt_basis * Basis.from_euler(Vector3(deg_to_rad(rot_x + 180.0), 0.0, 0.0))

	if not is_night:
		_sun.light_color        = s["sun_color"]
		_sun.light_energy       = base_intensity * intens_f

	# ── Overlay noturno ────────────────────────────────────────
	var oc := _night_overlay.color
	# // Se estiver chovendo, o céu chumbo já escurece naturalmente a luz ambiente, 
	# // então não pesamos tanto no filtro preto na tela.
	var final_overlay = overlay * (0.6 if is_raining else 1.0)
	oc.a = final_overlay
	_night_overlay.color = oc

	# ── Ambiente (WorldEnvironment) ────────────────────────────
	var env := _world_env.environment
	if not env:
		return

	var night_ambient := Color(0.15, 0.18, 0.25)
	env.ambient_light_color  = (s["ambient"] as Color).lerp(night_ambient, final_overlay)
	
#	// Para noites chuvosas, manter a energia ambiente levemente mais alta para compensar o bloqueio das nuvens
	var target_ambient_energy = 0.5 if is_raining else 0.3
	env.ambient_light_energy = lerp(0.5, target_ambient_energy, overlay)
	
#	// Reforçar o poder da lua na chuva para iluminar o chão molhado
	if is_night:
		_moon.light_energy = 0.35 if is_raining else 0.15

	# ── Céu (ShaderMaterial) ───────────────────────────────────
	if env.sky and env.sky.sky_material is ShaderMaterial:
		var sky_mat := env.sky.sky_material as ShaderMaterial
		var night_top     := Color(0.10, 0.15, 0.25)
		var night_horizon := Color(0.20, 0.25, 0.35)
		var final_top := (s["sky_top"] as Color).lerp(night_top, overlay)
		var final_hor := (s["sky_horizon"] as Color).lerp(night_horizon, overlay)
		
		sky_mat.set_shader_parameter("sky_top_color", final_top)
		sky_mat.set_shader_parameter("sky_horizon_color", final_hor)
		sky_mat.set_shader_parameter("sun_color", s["sun_color"])
		sky_mat.set_shader_parameter("cloud_coverage", cloud_cov)
		sky_mat.set_shader_parameter("lightning_amount", 1.0 if is_raining else 0.0)
		
		# Calcular fase da lua usando o TimeManager
		var phase : float = float(TimeManager.current_day) / float(TimeManager.DAYS_PER_SEASON)
		sky_mat.set_shader_parameter("moon_phase", phase)
		
		# Solução do Swap de Luzes (Mandar manualmente o vetor 3D)
		sky_mat.set_shader_parameter("sun_direction", _sun.global_transform.basis.z)
		sky_mat.set_shader_parameter("moon_direction", _moon.global_transform.basis.z)

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
