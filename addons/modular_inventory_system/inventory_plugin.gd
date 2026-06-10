@tool
extends EditorPlugin


func _enter_tree():
	add_autoload_singleton("DragDropSystem", "res://addons/modular_inventory_system/core/drag_drop_system.gd")
	add_autoload_singleton("InputMode", "res://addons/modular_inventory_system/components/InputMode.gd")
	add_autoload_singleton("UICoordinator", "res://addons/modular_inventory_system/ui/UICoordinator.gd")
	

func _exit_tree():
	remove_autoload_singleton("DragDropSystem")
	remove_autoload_singleton("InputMode")
	remove_autoload_singleton("UICoordinator")
