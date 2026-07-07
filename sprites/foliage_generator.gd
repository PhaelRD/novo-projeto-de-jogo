@tool
extends Node3D

@export var generate: bool = false:
	set(value):
		_generate_foliage()

@export_range(0.001, 0.5, 0.001) var grass_density:  float = 0.05
@export_range(0.001, 0.5, 0.001) var flower_density: float = 0.012
@export_range(0.001, 0.5, 0.001) var rock_density:   float = 0.01

@export_group("Rock Settings")
@export_range(0.05, 0.5, 0.01) var rock_scale_min: float = 0.18  ## Tamanho mínimo das pedras
@export_range(0.05, 2.0, 0.01) var rock_scale_max: float = 0.42  ## Tamanho máximo das pedras

## Parâmetros globais do vento exportados no editor
@export_group("Wind Settings")
@export_range(0.1, 5.0, 0.05) var wind_speed: float = 1.8
@export_range(0.0, 0.5, 0.005) var wind_strength: float = 0.12
@export var wind_direction: Vector2 = Vector2(1.0, 0.6)  ## Direção XZ do vento

var _multimesh_grass: MultiMeshInstance3D
var _multimesh_rock: MultiMeshInstance3D
var _multimesh_flower: MultiMeshInstance3D

# ─────────────────────────────────────────────
#  Shader de vento premium — turbulência em camadas, offset por instância
#  INSTANCE_CUSTOM.x = fase aleatória (0..2PI)
#  INSTANCE_CUSTOM.y = multiplicador de força (0.75..1.25)
# ─────────────────────────────────────────────
const WIND_SHADER_CODE := """
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled, vertex_lighting;

uniform bool  apply_wind      = false;
uniform float wind_speed      = 1.8;
uniform float wind_strength   = 0.12;
uniform vec2  wind_dir        = vec2(1.0, 0.6);

void vertex() {
	if (apply_wind && VERTEX.y > 0.02) {
		float t     = TIME * wind_speed;
		float phase = INSTANCE_CUSTOM.x;
		float force = INSTANCE_CUSTOM.y;

		// Camada 1 – onda principal lenta
		float w1 = sin(t + phase + VERTEX.x * 1.8 + VERTEX.z * 1.3);
		// Camada 2 – turbulência rápida
		float w2 = sin(t * 2.3 + phase * 1.7 + VERTEX.x * 3.5 + VERTEX.z * 2.9) * 0.35;
		// Camada 3 – micro-tremor de folha
		float w3 = sin(t * 5.1 + phase * 0.9 + VERTEX.x * 7.0) * 0.12;

		float sway = (w1 + w2 + w3) * wind_strength * force;
		// Atenuação quadrática pela altura: raiz firme, ponta balança muito
		float attn = VERTEX.y * VERTEX.y;

		vec2 wdir = normalize(wind_dir);
		VERTEX.x += wdir.x * sway * attn;
		VERTEX.z += wdir.y * sway * attn;
		// Leve amasso vertical durante rajada
		VERTEX.y -= abs(sway) * 0.04 * attn;
	}
}

void fragment() {
	ALBEDO    = COLOR.rgb;
	ROUGHNESS = 1.0;
	METALLIC  = 0.0;
}
"""

# Shader para pedra — sem vento, especular toon fraco
const ROCK_SHADER_CODE := """
shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;

void vertex() {}

void fragment() {
	ALBEDO    = COLOR.rgb;
	ROUGHNESS = 0.9;
	METALLIC  = 0.05;
	SPECULAR  = 0.15;
}
"""


func _ready() -> void:
	if not Engine.is_editor_hint():
		_generate_foliage()

func _generate_foliage() -> void:
	var parent = get_parent()
	if not parent or not ("_tile_positions" in parent):
		return

	print("--- Gerando Foliage Ultra Premium v2 ---")

	for child in get_children():
		child.queue_free()

	var grass_transforms:  Array[Transform3D] = []
	var rock_transforms:   Array[Transform3D] = []
	var flower_transforms: Array[Transform3D] = []

	# Custom data por instância (fase de vento, multiplicador de força)
	var grass_custom:  PackedColorArray = PackedColorArray()
	var flower_custom: PackedColorArray = PackedColorArray()

	var positions:    PackedVector3Array = parent._tile_positions
	var atlas_coords: PackedInt32Array   = parent._tile_atlas_coords

	var grid_size_val: float = 1.0
	if parent.settings:
		grid_size_val = parent.settings.grid_size

	for i in range(positions.size()):
		var g_pos  = positions[i]
		var center = (g_pos + Vector3(0.5, 0.5, 0.5)) * grid_size_val
		var surf_y = center.y

		if i * 2 + 1 >= atlas_coords.size():
			break
		var atlas_y = atlas_coords[i * 2 + 1]

		# ── Terreno Verde/Pedra (4–7): apenas pedras ──
		if atlas_y >= 4 and atlas_y <= 7:
			if randf() < rock_density:
				_scatter(center.x, surf_y, center.z, grid_size_val, 1,
						 rock_transforms, rock_scale_min, rock_scale_max, true, null, 0.38)

		# ── Terreno de Grama (3): grama densa + flores ──
		# spread 0.22 garante que nada transborda para tiles adjacentes
		elif atlas_y == 3:
			if randf() < grass_density * 3.0:
				var blade_count = randi_range(2, 4)
				_scatter(center.x, surf_y, center.z, grid_size_val, blade_count,
						 grass_transforms, 0.22, 0.42, false, grass_custom, 0.22)
			if randf() < flower_density:
				_scatter(center.x, surf_y, center.z, grid_size_val, 1,
						 flower_transforms, 0.28, 0.50, false, flower_custom, 0.20)

	if grass_transforms.size() > 0:
		_multimesh_grass = _create_multimesh(grass_transforms, grass_custom,
				_create_grass_mesh(), _make_wind_material(true))
		add_child(_multimesh_grass)

	if flower_transforms.size() > 0:
		_multimesh_flower = _create_multimesh(flower_transforms, flower_custom,
				_create_flower_mesh(), _make_wind_material(true))
		add_child(_multimesh_flower)


	if rock_transforms.size() > 0:
		_multimesh_rock = _create_multimesh(rock_transforms, PackedColorArray(),
				_create_rock_mesh(), _make_rock_material())
		add_child(_multimesh_rock)


# ─────────────────────────────────────────────
#  Scatter helper — gera transforms + custom data de vento
# ─────────────────────────────────────────────
func _scatter(
		cx: float, cy: float, cz: float,
		grid: float, count: int,
		t_arr: Array[Transform3D],
		smin: float, smax: float,
		is_rock: bool,
		custom_arr,  # PackedColorArray ou null
		spread: float = 0.38  # raio de espalhamento relativo ao grid
) -> void:
	for _k in range(count):
		var rx = cx + randf_range(-grid * spread, grid * spread)
		var rz = cz + randf_range(-grid * spread, grid * spread)
		var s  = randf_range(smin, smax)
		var b  = Basis()

		if is_rock:
			b = b.scaled(Vector3(
				s * randf_range(1.1, 1.7),
				s * randf_range(0.45, 0.75),
				s * randf_range(1.0, 1.5)
			))
			b = b.rotated(Vector3.RIGHT,   randf_range(-0.15, 0.15))
			b = b.rotated(Vector3.FORWARD, randf_range(-0.15, 0.15))
		else:
			# Leve inclinação aleatória para naturalidade
			b = b.scaled(Vector3(s, s, s))
			b = b.rotated(Vector3.RIGHT,   randf_range(-0.08, 0.08))
			b = b.rotated(Vector3.FORWARD, randf_range(-0.05, 0.05))

		b = b.rotated(Vector3.UP, randf_range(0.0, TAU))
		t_arr.append(Transform3D(b, Vector3(rx, cy, rz)))

		if custom_arr != null:
			custom_arr.append(Color(
				randf() * TAU,          # x = fase (0..2π)
				randf_range(0.75, 1.25), # y = força multiplicadora
				0.0, 0.0
			))


# ─────────────────────────────────────────────
#  MultiMesh com suporte a INSTANCE_CUSTOM
# ─────────────────────────────────────────────
func _create_multimesh(
		t_arr: Array[Transform3D],
		custom_arr: PackedColorArray,
		mesh: Mesh,
		mat: Material
) -> MultiMeshInstance3D:
	var mmi = MultiMeshInstance3D.new()
	var mm  = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# use_custom_data DEVE ser definido ANTES de instance_count em Godot 4
	var has_custom = custom_arr.size() == t_arr.size()
	if has_custom:
		mm.use_custom_data = true
	mm.instance_count = t_arr.size()
	mm.mesh           = mesh
	mesh.surface_set_material(0, mat)

	for i in range(t_arr.size()):
		mm.set_instance_transform(i, t_arr[i])
		if has_custom:
			mm.set_instance_custom_data(i, custom_arr[i])

	mmi.multimesh = mm
	return mmi


# ─────────────────────────────────────────────
#  Materiais
# ─────────────────────────────────────────────
func _make_wind_material(windy: bool) -> ShaderMaterial:
	var sh  = Shader.new()
	sh.code = WIND_SHADER_CODE
	var mat = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("apply_wind",    windy)
	mat.set_shader_parameter("wind_speed",    wind_speed)
	mat.set_shader_parameter("wind_strength", wind_strength)
	mat.set_shader_parameter("wind_dir",      wind_direction.normalized())
	return mat

func _make_rock_material() -> ShaderMaterial:
	var sh  = Shader.new()
	sh.code = ROCK_SHADER_CODE
	var mat = ShaderMaterial.new()
	mat.shader = sh
	return mat


# ─────────────────────────────────────────────
#  MALHA: GRAMA DETALHADA
#  5 lâminas (blades) triangulares em leque com gradiente root→tip
# ─────────────────────────────────────────────
func _create_grass_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_root = Color(0.18, 0.40, 0.10)
	var c_mid  = Color(0.32, 0.65, 0.18)
	var c_tip  = Color(0.55, 0.88, 0.28)

	# Cria uma lâmina de grama: base larga, meio curvado, ponta aguda
	var _add_blade = func(
		ox: float, oz: float,      # offset de posição
		height: float, width: float,
		lean_x: float, lean_z: float  # inclinação da ponta
	) -> void:
		var hw = width * 0.5
		var bl  = Vector3(ox - hw, 0.0, oz)
		var br  = Vector3(ox + hw, 0.0, oz)
		var ml  = Vector3(ox - hw * 0.7 + lean_x * 0.35, height * 0.5, oz + lean_z * 0.35)
		var mr  = Vector3(ox + hw * 0.7 + lean_x * 0.35, height * 0.5, oz + lean_z * 0.35)
		var tip = Vector3(ox + lean_x, height, oz + lean_z)
		var n   = Vector3(0, 0, 1)

		# Frente: segmento inferior
		st.set_color(c_root); st.set_normal(n); st.add_vertex(bl)
		st.set_color(c_mid);  st.set_normal(n); st.add_vertex(ml)
		st.set_color(c_root); st.set_normal(n); st.add_vertex(br)
		st.set_color(c_root); st.set_normal(n); st.add_vertex(br)
		st.set_color(c_mid);  st.set_normal(n); st.add_vertex(ml)
		st.set_color(c_mid);  st.set_normal(n); st.add_vertex(mr)
		# Frente: segmento superior (ponta)
		st.set_color(c_mid);  st.set_normal(n); st.add_vertex(ml)
		st.set_color(c_tip);  st.set_normal(n); st.add_vertex(tip)
		st.set_color(c_mid);  st.set_normal(n); st.add_vertex(mr)
		# Traseira
		st.set_color(c_root); st.set_normal(-n); st.add_vertex(br)
		st.set_color(c_mid);  st.set_normal(-n); st.add_vertex(ml)
		st.set_color(c_root); st.set_normal(-n); st.add_vertex(bl)
		st.set_color(c_mid);  st.set_normal(-n); st.add_vertex(mr)
		st.set_color(c_mid);  st.set_normal(-n); st.add_vertex(ml)
		st.set_color(c_root); st.set_normal(-n); st.add_vertex(br)
		st.set_color(c_mid);  st.set_normal(-n); st.add_vertex(mr)
		st.set_color(c_tip);  st.set_normal(-n); st.add_vertex(tip)
		st.set_color(c_mid);  st.set_normal(-n); st.add_vertex(ml)

	_add_blade.call( 0.00,  0.00, 1.00, 0.14,  0.04,  0.00)  # centro, alta, ereta
	_add_blade.call(-0.18,  0.05, 0.82, 0.13, -0.18,  0.04)  # esquerda, inclina pra fora
	_add_blade.call( 0.18, -0.05, 0.78, 0.13,  0.20, -0.04)  # direita
	_add_blade.call(-0.08, -0.12, 0.68, 0.11, -0.10, -0.12)  # fundo esq
	_add_blade.call( 0.10,  0.10, 0.60, 0.11,  0.12,  0.14)  # fundo dir

	return st.commit()


# ─────────────────────────────────────────────
#  MALHA: FLOR DETALHADA
#  Caule + 2 folhas laterais + 4 pétalas em cruz + centro
# ─────────────────────────────────────────────
func _create_flower_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_stem = Color(0.22, 0.52, 0.14)
	var c_leaf = Color(0.28, 0.60, 0.16)

	var palettes = [
		[Color(0.20, 0.55, 1.00), Color(1.00, 1.00, 0.30)],  # azul + miolo amarelo
		[Color(1.00, 0.22, 0.35), Color(1.00, 1.00, 0.85)],  # vermelha + creme
		[Color(1.00, 0.70, 0.10), Color(0.85, 0.30, 0.10)],  # laranja + centro escuro
		[Color(0.92, 0.30, 0.90), Color(1.00, 1.00, 0.50)],  # lilás + amarelo
		[Color(1.00, 1.00, 1.00), Color(1.00, 0.90, 0.20)],  # branca + amarelo
	]
	var pal     = palettes[randi() % palettes.size()]
	var c_petal = pal[0]
	var c_center = pal[1]
	var tip_col = c_petal.lightened(0.15)

	# Helper quad dupla-face (4 vértices)
	var _add_quad = func(
		a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ca: Color, cb: Color, cc: Color, cd: Color
	) -> void:
		var n = (b - a).cross(c - a).normalized()
		st.set_color(ca); st.set_normal(n);  st.add_vertex(a)
		st.set_color(cb); st.set_normal(n);  st.add_vertex(b)
		st.set_color(cc); st.set_normal(n);  st.add_vertex(c)
		st.set_color(ca); st.set_normal(n);  st.add_vertex(a)
		st.set_color(cc); st.set_normal(n);  st.add_vertex(c)
		st.set_color(cd); st.set_normal(n);  st.add_vertex(d)
		st.set_color(ca); st.set_normal(-n); st.add_vertex(a)
		st.set_color(cc); st.set_normal(-n); st.add_vertex(c)
		st.set_color(cb); st.set_normal(-n); st.add_vertex(b)
		st.set_color(ca); st.set_normal(-n); st.add_vertex(a)
		st.set_color(cd); st.set_normal(-n); st.add_vertex(d)
		st.set_color(cc); st.set_normal(-n); st.add_vertex(c)

	# Caule
	_add_quad.call(
		Vector3(-0.04, 0.0, 0.0), Vector3(0.04, 0.0, 0.0),
		Vector3(0.04, 0.75, 0.0), Vector3(-0.04, 0.75, 0.0),
		c_stem, c_stem, c_leaf, c_leaf
	)
	# Folha esquerda
	_add_quad.call(
		Vector3(-0.04, 0.30, 0.0), Vector3(-0.22, 0.38, 0.0),
		Vector3(-0.16, 0.50, 0.0), Vector3(-0.04, 0.46, 0.0),
		c_stem, c_leaf, c_leaf, c_stem
	)
	# Folha direita
	_add_quad.call(
		Vector3(0.04, 0.20, 0.0), Vector3(0.22, 0.28, 0.0),
		Vector3(0.16, 0.40, 0.0), Vector3(0.04, 0.36, 0.0),
		c_stem, c_leaf, c_leaf, c_stem
	)

	# 4 Pétalas triangulares em cruz
	var fy        = 0.78
	var petal_len = 0.30
	var petal_w   = 0.11
	var _add_petal = func(dir: Vector2) -> void:
		var tip_pos = Vector3(dir.x * petal_len, fy + 0.05, dir.y * petal_len)
		var side    = Vector3(-dir.y, 0, dir.x) * petal_w
		var n       = Vector3(0, 1, 0)
		st.set_color(c_petal); st.set_normal(n);  st.add_vertex(tip_pos)
		st.set_color(tip_col); st.set_normal(n);  st.add_vertex(Vector3(side.x, fy + 0.02, side.z))
		st.set_color(tip_col); st.set_normal(n);  st.add_vertex(Vector3(-side.x, fy + 0.02, -side.z))
		st.set_color(tip_col); st.set_normal(-n); st.add_vertex(Vector3(-side.x, fy + 0.02, -side.z))
		st.set_color(tip_col); st.set_normal(-n); st.add_vertex(Vector3(side.x, fy + 0.02, side.z))
		st.set_color(c_petal); st.set_normal(-n); st.add_vertex(tip_pos)

	_add_petal.call(Vector2( 1,  0))
	_add_petal.call(Vector2(-1,  0))
	_add_petal.call(Vector2( 0,  1))
	_add_petal.call(Vector2( 0, -1))

	# Centro da flor
	var hs = 0.10
	_add_quad.call(
		Vector3(-hs, fy - 0.01, -hs), Vector3(hs, fy - 0.01, -hs),
		Vector3(hs,  fy + 0.08,  hs), Vector3(-hs, fy + 0.08, hs),
		c_center, c_center, c_center, c_center
	)

	return st.commit()




# ─────────────────────────────────────────────
#  MALHA: PEDRA DETALHADA
#  3 blocos sobrepostos com perturbação de vértice e musgo no topo
# ─────────────────────────────────────────────
func _create_rock_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_dark  = Color(0.14, 0.14, 0.18)
	var c_mid   = Color(0.26, 0.26, 0.32)
	var c_light = Color(0.38, 0.38, 0.45)
	var c_moss  = Color(0.22, 0.42, 0.14)

	var _add_rock_box = func(pos: Vector3, size: Vector3, add_moss: bool) -> void:
		var bx  = BoxMesh.new()
		bx.size = size
		var bst = SurfaceTool.new()
		bst.create_from(bx, 0)
		var mdt = MeshDataTool.new()
		mdt.create_from_surface(bst.commit(), 0)
		for i in range(mdt.get_vertex_count()):
			var v  = mdt.get_vertex(i)
			var vy = (v.y + size.y * 0.5) / size.y  # normalizado 0..1
			var col: Color
			if add_moss and vy > 0.60:
				col = c_mid.lerp(c_moss, (vy - 0.60) / 0.40)
			else:
				col = c_dark.lerp(c_light, vy)
			# Perturbação para silhueta orgânica
			if v.y > -size.y * 0.3:
				v.x += randf_range(-0.04, 0.04) * size.x
				v.z += randf_range(-0.04, 0.04) * size.z
			mdt.set_vertex_color(i, col)
			mdt.set_vertex(i, v)
		var colored = ArrayMesh.new()
		mdt.commit_to_surface(colored, 0)
		st.append_from(colored, 0, Transform3D(Basis(), pos))

	# Bloco principal
	_add_rock_box.call(Vector3(0.0,   0.25, 0.0),   Vector3(0.80, 0.50, 0.70), true)
	# Bloco secundário deslocado
	_add_rock_box.call(Vector3(0.15,  0.55, 0.05),  Vector3(0.55, 0.32, 0.48), false)
	# Detalhezinho lateral
	_add_rock_box.call(Vector3(-0.22, 0.18, -0.12), Vector3(0.30, 0.22, 0.28), false)

	return st.commit()
