extends Node
class_name CraftingController

@export var crafting_panel_scene: PackedScene = preload("res://crafting/ui/crafting_panel.tscn")
var crafting_panel: CraftingPanel

func _ready() -> void:
	# Find the inventory panel to sync visibility
	await get_tree().process_frame
	var inventory_panels = get_tree().get_nodes_in_group("modular_inventory_panel")
	if inventory_panels.size() > 0:
		var inventory_panel = inventory_panels[0] as Control
		
		# Instantiate crafting panel
		crafting_panel = crafting_panel_scene.instantiate()
		inventory_panel.get_parent().add_child(crafting_panel)
		crafting_panel.visible = inventory_panel.visible
		
		# Sync visibility
		inventory_panel.visibility_changed.connect(func():
			if crafting_panel:
				crafting_panel.visible = inventory_panel.visible
		)
		
		# Find player and link inventory
		var player = get_tree().get_first_node_in_group("player")
		if player:
			crafting_panel.inventory_component = player.get_node_or_null("InventoryComponent")
