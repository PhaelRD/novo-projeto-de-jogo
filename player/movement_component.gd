extends Node
class_name MovementComponent

@export var speed: float = 5.0
@export var gravity: float = 9.8

var _follow_camera: Camera3D = null

func handle_movement(body: CharacterBody3D, input_dir: Vector3, delta: float) -> Vector3:
	var move_dir = _transform_input_by_camera(input_dir)
	
	# Prevenção de queda (Ledge Detection)
	# Se estiver no chão (ou caindo), verifica se tem chão na direção do movimento
	if body.is_on_floor() and move_dir != Vector3.ZERO:
		if move_dir.x != 0:
			var test_offset_x = Vector3(sign(move_dir.x) * 0.4, 0, 0)
			if not _check_floor(body, test_offset_x):
				move_dir.x = 0
		if move_dir.z != 0:
			var test_offset_z = Vector3(0, 0, sign(move_dir.z) * 0.4)
			if not _check_floor(body, test_offset_z):
				move_dir.z = 0
	
	body.velocity.x = move_dir.x * speed
	body.velocity.z = move_dir.z * speed

	if not body.is_on_floor():
		body.velocity.y -= gravity * delta
	else:
		body.velocity.y = 0

	body.move_and_slide()
	return move_dir

func _check_floor(body: CharacterBody3D, offset: Vector3) -> bool:
	var space_state = body.get_world_3d().direct_space_state
	var check_pos = body.global_position + offset
	# Lança um raio de 0.5m acima do pé até 1.5m abaixo
	var ray_from = check_pos + Vector3(0, 0.5, 0)
	var ray_to = check_pos + Vector3(0, -1.5, 0)
	
	var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.exclude = [body.get_rid()]
	var result = space_state.intersect_ray(query)
	return result.size() > 0

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
