extends Node
class_name AnimationComponent

@export var sprite: AnimatedSprite3D
var _current_animation: String = ""

func setup() -> void:
	if sprite and sprite.sprite_frames:
		sprite.play("default") # Inicia com uma animação padrão segura
		_current_animation = sprite.animation

func update_animation(direction: Vector3) -> void:
	if not sprite or not sprite.sprite_frames: return
	var frames = sprite.sprite_frames
	
	if direction == Vector3.ZERO:
		sprite.stop() 
		sprite.frame = 0 
		return 

	var desired_anim = _select_animation(direction, frames)
	
	if desired_anim != _current_animation:
		sprite.play(desired_anim)
		_current_animation = desired_anim
	elif not sprite.is_playing():
		sprite.play()

func _select_animation(direction: Vector3, frames: SpriteFrames) -> String:
	var horiz: float = abs(direction.x)
	var vert: float = abs(direction.z)
	var target_anim = "move_forward" if direction.z < 0 else "move_backward"
	if horiz > vert:
		target_anim = "move_left" if direction.x < 0 else "move_right"

	if frames.has_animation(target_anim): return target_anim
	return "default"
