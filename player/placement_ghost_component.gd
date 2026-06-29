extends Node
class_name PlacementGhostComponent

## Gerencia o ghost visual de placement (verde/vermelho).
## Absorve PlacementGhost — arquivo único, sem dependência externa.
## Adicione como nó filho do Player na cena e configure os exports.

@export var interaction: InteractionComponent
@export var hotbar: ModularHotbar
@export var inventory_component: Node   # InventoryComponent
@export var inventory_panel: Control    # Esconde o ghost quando o inventário está aberto

# --- Estado interno do ghost ---
var _ghost_root: Node3D       = null
var _last_item: ItemDefinition = null
var _mat_valid:   StandardMaterial3D
var _mat_invalid: StandardMaterial3D

func _ready() -> void:
	_mat_valid   = _make_mat(Color(0.1, 1.0, 0.2, 0.42))
	_mat_invalid = _make_mat(Color(1.0, 0.1, 0.1, 0.42))

# ------------------------------------------------------------------
# Chamado em Player._physics_process() a cada frame
# ------------------------------------------------------------------
func update(player_pos: Vector3) -> void:
	# Esconde ghost enquanto inventário estiver aberto
	if inventory_panel and inventory_panel.visible:
		clear()
		return

	var slot = _get_held_slot()
	var item = slot.item if (slot and slot.item) else null

	# Apenas itens colocáveis com placement_scene exibem ghost
	if not item or not item.placement_scene:
		clear()
		return

	if not (item is PlaceableItemDefinition or item is SeedItemDefinition):
		clear()
		return

	var target_info = interaction.get_target_info()
	var target_pos  = target_info.get("position", player_pos)
	var collider    = target_info.get("collider")
	var is_valid    = _is_valid(collider)

	# Recria o ghost se o item mudou
	if item != _last_item:
		clear()
		_spawn_ghost(item)

	if not is_instance_valid(_ghost_root):
		return

	_ghost_root.visible         = true
	_ghost_root.global_position = target_pos

	# Rotação: vira para o player em ângulos retos (apenas itens colocáveis)
	if item is PlaceableItemDefinition and player_pos != Vector3.ZERO:
		var look_pos = player_pos
		look_pos.y   = target_pos.y
		if target_pos.distance_to(look_pos) > 0.1:
			_ghost_root.look_at(look_pos, Vector3.UP)
			_ghost_root.rotation.y = snapped(_ghost_root.rotation.y, PI / 2.0)

	_apply_material(_ghost_root, _mat_valid if is_valid else _mat_invalid)

# ------------------------------------------------------------------
# Remove o ghost do mundo
# ------------------------------------------------------------------
func clear() -> void:
	if is_instance_valid(_ghost_root):
		_ghost_root.queue_free()
	_ghost_root = null
	_last_item  = null

# ------------------------------------------------------------------
# Helpers privados
# ------------------------------------------------------------------
func _get_held_slot() -> SlotData:
	if not hotbar or not inventory_component: return null
	var inv: Inventory = inventory_component.get_inventory()
	if not inv: return null
	return inv.get_slot(hotbar.get_selected_global_index())

func _is_valid(collider: Node) -> bool:
	if collider:
		var n: Node = collider
		while n:
			if n.is_in_group("terrain"):
				return true
			n = n.get_parent()
		return false
	return true

func _spawn_ghost(item: ItemDefinition) -> void:
	_ghost_root            = item.placement_scene.instantiate()
	_ghost_root.top_level  = true  # não herda a transform do player
	_disable_collision(_ghost_root)
	_stop_animations(_ghost_root)
	get_tree().current_scene.add_child(_ghost_root)
	_last_item = item

func _make_mat(color: Color) -> StandardMaterial3D:
	var mat              := StandardMaterial3D.new()
	mat.albedo_color      = color
	mat.transparency      = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode      = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode         = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test     = false
	return mat

func _disable_collision(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask  = 0
	if node is CollisionShape3D or node is CollisionPolygon3D:
		node.disabled = true
	for child in node.get_children():
		_disable_collision(child)

func _stop_animations(node: Node) -> void:
	if node is AnimationPlayer:
		node.stop()
	for child in node.get_children():
		_stop_animations(child)

func _apply_material(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		if mesh:
			for i in mesh.get_surface_count():
				node.set_surface_override_material(i, mat)
	elif node is Sprite3D or node is AnimatedSprite3D:
		node.modulate = mat.albedo_color
	for child in node.get_children():
		_apply_material(child, mat)
