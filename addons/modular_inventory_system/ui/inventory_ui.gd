@tool
extends Control
class_name InventoryUI

@export_group("Binding")
@export var source_component: InventoryComponent
@export var auto_bind_to_owner: bool = true

var _inventory: Inventory

func _ready():
	if Engine.is_editor_hint(): return
	_bind_inventory()

func _bind_inventory():
	if source_component:
		_attach(source_component.get_inventory())
		return
	
	if auto_bind_to_owner:
		var target = owner
		var comp: InventoryComponent = null
		
		if target.has_node("InventoryComponent"):
			comp = target.get_node("InventoryComponent")
		else:
			for child in target.get_children(true):
				if child is InventoryComponent:
					comp = child
					break
		
		if comp:
			source_component = comp
			_attach(comp.get_inventory())
			return
	
	push_warning("InventoryUI '%s': No InventoryComponent found. UI will remain empty." % name)

func _attach(inv: Inventory):
	if _inventory == inv: return
	_detach()
	_inventory = inv
	if _inventory:
		_inventory.inventory_changed.connect(_refresh_all)
		_inventory.slot_changed.connect(_refresh_slot)
		_on_inventory_attached(_inventory)
		_refresh_all()

func _detach():
	if _inventory:
		_inventory.inventory_changed.disconnect(_refresh_all)
		_inventory.slot_changed.disconnect(_refresh_slot)

func _exit_tree():
	_detach()

func _on_inventory_attached(inv: Inventory):
	pass

func _refresh_all():
	pass

func _refresh_slot(idx: int):
	pass
