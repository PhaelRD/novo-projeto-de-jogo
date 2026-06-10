extends Camera3D
class_name FollowCamera

@export var distance: float = 6.0
@export var height: float = 3.0
# --- NOVA VARIÁVEL AQUI ---
@export var look_height: float = 1.0 # Altura onde a câmera vai focar (1.0 = altura do peito)
@export var smooth_speed: float = 3.5
@export var mouse_sensitivity: float = 0.004
@export var collision_margin: float = 0.2 

var _target: Node3D = null

var _smoothed_target_pos: Vector3 = Vector3.ZERO
var _yaw: float = 0.0 
var _is_tracking: bool = false

func _ready() -> void:
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	top_level = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw += event.relative.x * mouse_sensitivity

func _physics_process(delta: float) -> void:
	if not _target:
		return 

	if not _is_tracking:
		_smoothed_target_pos = _target.global_transform.origin
		_is_tracking = true

	var weight: float = clamp(delta * smooth_speed, 0.0, 1.0)
	
	# 1. Suaviza a base (posição dos pés do alvo)
	_smoothed_target_pos = _smoothed_target_pos.lerp(_target.global_transform.origin, weight)
	
	# 2. Define o "Pivô" da câmera (A altura que a câmera FICA suspensa no ar)
	var pivot_pos = _smoothed_target_pos + Vector3(0.0, height, 0.0)
	
	# 3. Calcula a posição ideal da câmera
	var horizontal_offset: Vector2 = Vector2(0.0, distance).rotated(_yaw)
	var ideal_cam_pos = pivot_pos + Vector3(horizontal_offset.x, 0.0, horizontal_offset.y)
	
	# 4. Raycast de Colisão (O Sistema Anti-Clipping)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(pivot_pos, ideal_cam_pos)
	
	if _target is CollisionObject3D:
		query.exclude = [_target.get_rid()]
		
	var result = space_state.intersect_ray(query)
	
	# 5. Posiciona a câmera
	if result:
		var hit_pos = result.position
		var safe_direction = (pivot_pos - hit_pos).normalized()
		global_transform.origin = hit_pos + (safe_direction * collision_margin)
	else:
		global_transform.origin = ideal_cam_pos
		
	# 6. Aponta a câmera PARA O JOGADOR (MODIFICADO)
	# Calculamos um alvo focado no corpo do personagem usando o look_height
	var aim_target = _smoothed_target_pos + Vector3(0.0, look_height, 0.0)
	look_at(aim_target, Vector3.UP)
