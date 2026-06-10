class_name PlacementLogic extends ItemLogic
signal placement_started
signal placement_confirmed
signal placement_cancelled

@export_group("Placement Config")
@export var grid_size: float = 1.0
@export var use_grid_snap: bool = false
@export var max_slope_angle: float = 90.0
@export var placement_layer_mask: int = 1
@export var ghost_opacity: float = 0.5
@export_group("Rotation")
@export var rotation_step: float = 15.0
@export var rotation_input_axis: StringName = &"use_secondary"

var _ghost: Node3D
var _is_placing: bool = false
var _is_valid: bool = false
var _ghost_rotation_y: float = 0.0
var _placement_scene: PackedScene

func on_primary_use(slot_index: int = -1) -> void:
	if not _is_placing:
		_enter_placement_mode()
	elif _is_valid:
		_confirm_placement(slot_index)
	else:
		print("[Placement] Invalid position. Adjust angle or move closer.")

func on_secondary_use(_slot_index: int = -1) -> void:
	if _is_placing:
		_cancel_placement()

func on_release() -> void:
	pass

func update(_delta: float) -> void:
	if not _is_placing or not _ghost: return
	_update_ghost_position()
	_handle_rotation_input()
	_update_ghost_visuals()

func _enter_placement_mode() -> void:
	print("[Placement] Entering placement mode...")
	_placement_scene = null
	if _item:
		_placement_scene = _item.placement_scene
	if not _placement_scene:
		push_error("[Placement] No placement_scene assigned in ItemDefinition!")
		return

	_is_placing = true
	_ghost_rotation_y = 0.0
	
	_ghost = _placement_scene.instantiate()
	_disable_ghost_collision(_ghost)
	_apply_ghost_material(_ghost)
	
	var tree := _player.get_tree() if _player else Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(_ghost)

	placement_started.emit()

func _update_ghost_position() -> void:
	var camera := _player.get_node_or_null("Camera") as Camera3D
	if not camera: return
	
	var viewport_size := _player.get_viewport().get_visible_rect().size
	var screen_center := viewport_size * 0.5
	
	var ray_from := camera.project_ray_origin(screen_center)
	var ray_to := ray_from + camera.project_ray_normal(screen_center) * 50.0
	
	var space := _player.get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, placement_layer_mask)
	query.exclude = []
	if _player is PhysicsBody3D: query.exclude.append(_player.get_rid())
	if _ghost: query.exclude.append(_ghost.get_rid())
	
	var result := space.intersect_ray(query) as Dictionary
	
	if result and not result.is_empty():
		var pos: Vector3 = result["position"]
		var normal: Vector3 = result.get("normal", Vector3.UP)
		
		if use_grid_snap:
			pos = _snap_to_grid(pos)
		
		var y_axis := normal
		var z_axis := Vector3.FORWARD
		var x_axis := y_axis.cross(z_axis).normalized()
		
		if x_axis.length_squared() < 0.001:
			x_axis = Vector3.RIGHT
			z_axis = x_axis.cross(y_axis).normalized()
			
		_ghost.global_basis = Basis(x_axis, y_axis, z_axis).rotated(normal, _ghost_rotation_y)
		_ghost.global_position = pos
		_ghost.visible = true
		_is_valid = _validate_placement(pos, normal)
	else:
		_is_valid = false
		_ghost.visible = false

func _snap_to_grid(pos: Vector3) -> Vector3:
	return Vector3(
		round(pos.x / grid_size) * grid_size,
		pos.y,
		round(pos.z / grid_size) * grid_size
	)

func _validate_placement(pos: Vector3, ground_normal: Vector3) -> bool:
	var slope_angle := rad_to_deg(ground_normal.angle_to(Vector3.UP))
	if slope_angle > max_slope_angle:
		return false
		
	var player_pos := (_player as Node3D).global_position
	if pos.distance_to(player_pos) < 1.5:
		return false
		
	var space := _player.get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = 0.5
	query.transform = Transform3D(Basis(), pos + Vector3.UP * 0.5)
	query.collision_mask = placement_layer_mask | 2
	
	return space.intersect_shape(query).is_empty()

func _handle_rotation_input() -> void:
	if Input.is_action_just_pressed(rotation_input_axis):
		_ghost_rotation_y += deg_to_rad(rotation_step)
	elif Input.is_action_just_pressed(&"ui_left"):
		_ghost_rotation_y -= deg_to_rad(rotation_step)

func _confirm_placement(slot_index: int) -> void:
	if not _is_valid or not _ghost or not _placement_scene: return
	
	var placed_obj := _placement_scene.instantiate()
	placed_obj.global_transform = _ghost.global_transform
	
	var tree := _player.get_tree() if _player else Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(placed_obj)
		
	_consume_item(slot_index)
	_cancel_placement()
	placement_confirmed.emit()

func _cancel_placement() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
		
	if _is_placing:
		_is_placing = false
		placement_cancelled.emit()
		print("[Placement] Canceled")

func _consume_item(slot_index: int) -> void:
	if slot_index < 0: return
	var inv_comp := _player.get_node_or_null("InventoryComponent") as InventoryComponent
	if inv_comp and inv_comp.inventory:
		inv_comp.inventory.remove_item(_item, 1)

func _disable_ghost_collision(node: Node) -> void:
	if node is CollisionShape3D: node.disabled = true
	if node is PhysicsBody3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_ghost_collision(child)

func _apply_ghost_material(node: Node) -> void:
	for child in node.find_children("", "MeshInstance3D", true, true):
		var mesh_child := child as MeshInstance3D
		for i in mesh_child.get_surface_override_material_count():
			var mat := mesh_child.get_surface_override_material(i) as StandardMaterial3D
			if mat:
				mat = mat.duplicate()
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = ghost_opacity
				mesh_child.set_meta("orig_albedo", mat.albedo_color)
				mesh_child.set_surface_override_material(i, mat)

func _update_ghost_visuals() -> void:
	if not _ghost: return
	_ghost.visible = true
	var tint_color := Color.GREEN if _is_valid else Color.RED
	for child in _ghost.find_children("", "MeshInstance3D", true, true):
		var mesh_child := child as MeshInstance3D
		for i in mesh_child.get_surface_override_material_count():
			var mat := mesh_child.get_surface_override_material(i) as StandardMaterial3D
			if mat:
				var orig := mat.get_meta("orig_albedo", Color.WHITE)
				mat.albedo_color = orig.blend(tint_color * 0.6)
