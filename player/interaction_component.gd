extends Node3D
class_name InteractionComponent

@onready var interaction_area: Area3D = $Area3D
var _facing_dir: Vector3 = Vector3.FORWARD

func update_grid(player_pos: Vector3, move_dir: Vector3) -> void:
	if move_dir != Vector3.ZERO:
		_facing_dir = move_dir.normalized()
		
	var target_pos = player_pos + (_facing_dir * 0.9)
	target_pos.x = round(target_pos.x)
	target_pos.z = round(target_pos.z)
	target_pos.y = player_pos.y - 0.4
	global_position = target_pos

func use_axe(sprite: AnimatedSprite3D) -> void:
	if not interaction_area: return
	
	var bodies = interaction_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("interactable") and body.has_method("hit_with_axe"):
			body.hit_with_axe(1)
			if sprite and sprite.sprite_frames.has_animation("attack"):
				sprite.play("attack")
			break
