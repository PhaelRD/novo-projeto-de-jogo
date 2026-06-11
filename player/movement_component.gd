extends Node
class_name MovementComponent

@export var speed: float = 5.0
@export var gravity: float = 9.8

var _follow_camera: Camera3D = null

func handle_movement(body: CharacterBody3D, input_dir: Vector3, delta: float) -> Vector3:
	var move_dir = _transform_input_by_camera(input_dir)
	
	body.velocity.x = move_dir.x * speed
	body.velocity.z = move_dir.z * speed

	if not body.is_on_floor():
		body.velocity.y -= gravity * delta
	else:
		body.velocity.y = 0

	body.move_and_slide()
	return move_dir

func _transform_input_by_camera(input_dir: Vector3) -> Vector3:
	if not _follow_camera or input_dir == Vector3.ZERO:
		return input_dir 
	
	var cam_basis = _follow_camera.global_transform.basis
	var cam_forward = -cam_basis.z
	var cam_right = cam_basis.x
	
	cam_forward.y = 0
	cam_right.y = 0
	
	var move_dir = (cam_right.normalized() * input_dir.x) + (cam_forward.normalized() * -input_dir.z)
	return move_dir.normalized() if move_dir != Vector3.ZERO else Vector3.ZERO
