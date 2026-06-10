extends Camera3D
class_name FollowCamera

@export var distance: float = 4.0
@export var height: float = 2.0
@export var smooth_speed: float = 3.5

const ROTATION_DIVISIONS: int = 4
const ROTATION_STEP_RADIANS: float = PI / 2.0
var _rotation_index: int = 0

var _target: Node3D = null

# Variáveis do nosso "alvo fantasma"
var _smoothed_target_pos: Vector3 = Vector3.ZERO
var _current_angle: float = 0.0 # ← Nova variável para guardar o ângulo suave
var _is_tracking: bool = false

func _ready() -> void:
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	top_level = true

func _physics_process(delta: float) -> void:
	if not _target:
		return 

	# Inicializa a posição e o ângulo suaves no exato momento que o jogador surge
	if not _is_tracking:
		_smoothed_target_pos = _target.global_transform.origin
		_current_angle = float(_rotation_index) * ROTATION_STEP_RADIANS
		_is_tracking = true

	# Input para girar a câmera
	if Input.is_action_just_pressed("ui_left"):
		_rotation_index = (_rotation_index - 1 + ROTATION_DIVISIONS) % ROTATION_DIVISIONS
	elif Input.is_action_just_pressed("ui_right"):
		_rotation_index = (_rotation_index + 1) % ROTATION_DIVISIONS

	var weight: float = clamp(delta * smooth_speed, 0.0, 1.0)
	
	# 1. Suaviza a POSIÇÃO (segue o jogador sem balanço lateral)
	_smoothed_target_pos = _smoothed_target_pos.lerp(_target.global_transform.origin, weight)
	
	# 2. Calcula o ângulo alvo e suaviza a ROTAÇÃO
	var target_angle: float = float(_rotation_index) * ROTATION_STEP_RADIANS
	_current_angle = lerp_angle(_current_angle, target_angle, weight) # ← A mágica acontece aqui
	
	# 3. Aplica o ângulo suave no offset
	var horizontal_offset: Vector2 = Vector2(0.0, distance).rotated(_current_angle)
	
	# 4. Posiciona a câmera e aponta para o alvo fantasma
	global_transform.origin = _smoothed_target_pos + Vector3(horizontal_offset.x, height, horizontal_offset.y)
	look_at(_smoothed_target_pos, Vector3.UP)
