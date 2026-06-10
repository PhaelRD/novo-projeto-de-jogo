class_name ConsumableLogic extends ItemLogic

@export_group("Food Effects")
@export var hunger_restore: float = 15.0
@export var health_restore: float = 5.0
@export var stamina_restore: float = 10.0
@export var use_duration: float = 1.0
@export var consume_sound: AudioStream

func can_use() -> bool:
	#var stats := _player.get_node_or_null("SurvivalStats") as SurvivalStats
	#if stats:
		#return stats.hunger < 100.0 or stats.health < 100.0 or stats.stamina < 100.0
	return true

func on_primary_use(slot_index: int = -1) -> void:
	if not can_use(): return
	_is_active = true
	use_started.emit()
	
	await _player.get_tree().create_timer(use_duration).timeout
	
	_apply_effects(slot_index)
	_is_active = false
	use_ended.emit()
	use_finished.emit(_item, true)


func _apply_effects(slot_index: int) -> void:
	#var stats := _player.get_node_or_null("SurvivalStats") as SurvivalStats
	#if stats:
		#stats.add_hunger(hunger_restore)
		#stats.add_health(health_restore)
		#stats.add_stamina(stamina_restore)
	
	if slot_index >= 0:
		var inv_comp := _player.get_node_or_null("InventoryComponent") as InventoryComponent
		if inv_comp and inv_comp.inventory:
			inv_comp.inventory.remove_item(_item, 1)
			_consume_item_durability(slot_index, _item.durability_loss_per_use)
	_play_feedback()


func _play_feedback() -> void:
	if consume_sound:
		var audio := AudioStreamPlayer3D.new()
		audio.stream = consume_sound
		_player.add_child(audio)
		audio.play()
		await audio.finished
		audio.queue_free()
