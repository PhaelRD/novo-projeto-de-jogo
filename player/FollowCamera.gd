extends Camera3D
class_name FollowCamera

@export var distance: float = 6.0
@export var height: float = 3.0
@export var look_height: float = 1.0 # Altura onde a câmera vai focar (1.0 = altura do peito)
@export var smooth_speed: float = 3.5
@export var collision_margin: float = 0.2 

# Variáveis do sistema de rotação por setas (4 direções)
const ROTATION_DIVISIONS: int = 4
const ROTATION_STEP_RADIANS: float = PI / 2.0
var _rotation_index: int = 0
var _current_angle: float = 0.0 

var _target: Node3D = null
var _smoothed_target_pos: Vector3 = Vector3.ZERO
var _is_tracking: bool = false

func _ready() -> void:
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	top_level = true

func _physics_process(delta: float) -> void:
	if not _target:
		return 

	if not _is_tracking:
		_smoothed_target_pos = _target.global_transform.origin
		_current_angle = float(_rotation_index) * ROTATION_STEP_RADIANS
		_is_tracking = true

	# --- Captura das Setas para Girar 90 Graus ---
	if Input.is_action_just_pressed("ui_left"):
		_rotation_index = (_rotation_index - 1 + ROTATION_DIVISIONS) % ROTATION_DIVISIONS
	elif Input.is_action_just_pressed("ui_right"):
		_rotation_index = (_rotation_index + 1) % ROTATION_DIVISIONS

	var weight: float = clamp(delta * smooth_speed, 0.0, 1.0)
	
	# 1. Suaviza a base (posição dos pés do alvo) e o Ângulo de Rotação
	_smoothed_target_pos = _smoothed_target_pos.lerp(_target.global_transform.origin, weight)
	var target_angle: float = float(_rotation_index) * ROTATION_STEP_RADIANS
	_current_angle = lerp_angle(_current_angle, target_angle, weight)
	
	# 2. Define o "Pivô" da câmera (A altura que a câmera FICA suspensa no ar)
	var pivot_pos = _smoothed_target_pos + Vector3(0.0, height, 0.0)
	
	# 3. Calcula a posição ideal da câmera usando o ângulo atual
	var horizontal_offset: Vector2 = Vector2(0.0, distance).rotated(_current_angle)
	var ideal_cam_pos = pivot_pos + Vector3(horizontal_offset.x, 0.0, horizontal_offset.y)
	
	# 4. Raycast de Colisão (O Sistema Anti-Clipping)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(pivot_pos, ideal_cam_pos)
	
	if _target is CollisionObject3D:
		query.exclude = [_target.get_rid()]
		
	var result = space_state.intersect_ray(query)
	
	# 5. Posiciona a câmera (respeitando as paredes)
	if result:
		var hit_pos = result.position
		var safe_direction = (pivot_pos - hit_pos).normalized()
		global_transform.origin = hit_pos + (safe_direction * collision_margin)
	else:
		global_transform.origin = ideal_cam_pos
		
	# 6. Aponta a câmera PARA O JOGADOR
	var aim_target = _smoothed_target_pos + Vector3(0.0, look_height, 0.0)
	look_at(aim_target, Vector3.UP)
