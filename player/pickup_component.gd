extends Node
class_name PickupComponent

## Detecta DroppedItems na PickupArea e os adiciona ao inventário do player.
## Chame setup(area) em Player._ready() passando o nó Area3D de coleta.

var _inventory_component: Node = null

func setup(pickup_area: Area3D, inventory_component: Node) -> void:
	_inventory_component = inventory_component
	if pickup_area:
		# Desconecta qualquer ligação antiga do Player (se houver) antes de reconectar aqui
		pickup_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("dropped_item"): return
	if not _inventory_component or not _inventory_component.inventory: return

	var remaining = _inventory_component.inventory.add_item(body.item_, body.count)
	if remaining == 0:
		body.queue_free()
	elif remaining < body.count:
		body.count = remaining
