class_name RangedLogic extends ItemLogic

@export_group("Bow Config")
@export var projectile_scene: PackedScene
@export var charge_speed: float = 2.0
@export var max_charge: float = 2.0
@export var arrow_tag: String = "arrow"
@export var draw_sound: AudioStream
@export var release_sound: AudioStream

var _charge_time: float = 0.0
var _is_charging: bool = false

func update(delta: float) -> void:
	if _is_charging:
		_charge_time = min(_charge_time + delta, max_charge)

func on_primary_use(slot_index: int = -1) -> void:
	if _is_charging: return
	_is_charging = true
	_charge_time = 0.0
	if draw_sound:
		_play_audio(draw_sound)

func on_release() -> void:
	if not _is_charging: return
	_is_charging = false
	
	if not _has_arrows():
		print("No arrows in inventory!")
		return
		
	_fire_arrow()
	use_finished.emit(_item, true)

func _has_arrows() -> bool:
	var inv_comp := _player.get_node_or_null("InventoryComponent") as InventoryComponent
	if inv_comp and inv_comp.inventory:
		for i in inv_comp.inventory.capacity:
			var slot := inv_comp.inventory.get_slot(i)
			if slot and not slot.is_empty() and slot.item.has_tag(arrow_tag):
				return true
	return false

func _consume_arrow() -> bool:
	var inv_comp := _player.get_node_or_null("InventoryComponent") as InventoryComponent
	if inv_comp and inv_comp.inventory:
		for i in inv_comp.inventory.capacity:
			var slot := inv_comp.inventory.get_slot(i)
			if slot and not slot.is_empty() and slot.item.has_tag(arrow_tag):
				inv_comp.inventory.remove_item(slot.item, 1)
				return true
	return false

func _fire_arrow() -> void:
	if not _consume_arrow(): return
	if release_sound: _play_audio(release_sound)
	
	var power := 1.0 + (_charge_time / max_charge) * 2.5
	var cam := _player.get_node_or_null("Camera") as Camera3D
	var dir: Vector3 = cam.global_transform.basis.z.normalized() if cam else -_player.global_transform.basis.z
	
	var proj := projectile_scene.instantiate() as Node3D
	proj.global_position = _player.global_position + Vector3.UP * 1.4
	if proj.has_method("initialize"):
		proj.initialize(dir, power, _player)
	else:
		if proj is RigidBody3D:
			proj.linear_velocity = dir * power * 20.0
	proj.get_tree().root.add_child(proj)
	_charge_time = 0.0

func _play_audio(stream: AudioStream) -> void:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	_player.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
