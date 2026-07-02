extends Control
class_name CraftingPanel

@export var inventory_component: InventoryComponent
@export var recipes: Array[CraftingRecipe] = []

@onready var recipe_grid: GridContainer = $VBox/ScrollContainer/RecipeGrid

var recipe_item_scene = preload("res://systems/crafting/ui/recipe_item_ui.tscn")
var ingredient_ui_scene = preload("res://systems/crafting/ui/ingredient_ui.tscn")
var tooltip_scene = preload("res://systems/crafting/ui/crafting_tooltip.tscn")

var tooltip_instance: Control

func _ready() -> void:
	tooltip_instance = tooltip_scene.instantiate()
	add_child(tooltip_instance)
	tooltip_instance.visible = false
	
	_populate_recipes()
	
	if inventory_component:
		inventory_component.inventory_ready.connect(func(inv):
			inv.inventory_changed.connect(_update_all_slots)
		)
		if inventory_component.get_inventory():
			inventory_component.get_inventory().inventory_changed.connect(_update_all_slots)
	
	_update_all_slots()

func _process(_delta: float) -> void:
	if tooltip_instance and tooltip_instance.visible:
		tooltip_instance.global_position = get_global_mouse_position() + Vector2(15, 15)

func _populate_recipes() -> void:
	for child in recipe_grid.get_children():
		child.queue_free()
		
	for recipe in recipes:
		var item = recipe_item_scene.instantiate()
		recipe_grid.add_child(item)
		
		var icon_rect = item.get_node("Icon")
		icon_rect.texture = recipe.result_item.icon
		
		item.pressed.connect(_on_craft_clicked.bind(recipe))
		item.mouse_entered.connect(_on_recipe_hovered.bind(recipe))
		item.mouse_exited.connect(_on_recipe_unhovered)
		
		# Set metadata for easy access during updates
		item.set_meta("recipe", recipe)

func _update_all_slots() -> void:
	if not inventory_component: return
	var inventory = inventory_component.get_inventory()
	
	for slot in recipe_grid.get_children():
		var recipe = slot.get_meta("recipe")
		
		var can_craft = CraftingManager.can_craft(inventory, recipe)
		
		var icon = slot.get_node("Icon")
		if can_craft:
			icon.modulate = Color.WHITE
		else:
			icon.modulate = Color(0.2, 0.2, 0.2, 0.6) # Silhouette style

func _on_recipe_hovered(recipe: CraftingRecipe) -> void:
	_update_tooltip(recipe)
	tooltip_instance.visible = true

func _on_recipe_unhovered() -> void:
	tooltip_instance.visible = false

func _update_tooltip(recipe: CraftingRecipe) -> void:
	tooltip_instance.get_node("VBox/ItemName").text = recipe.display_name
	tooltip_instance.get_node("VBox/Description").text = recipe.result_item.description
	
	var container = tooltip_instance.get_node("VBox/IngredientsContainer")
	for child in container.get_children():
		child.queue_free()
		
	var inventory = inventory_component.get_inventory()
	for ing in recipe.ingredients:
		var ing_ui = ingredient_ui_scene.instantiate()
		container.add_child(ing_ui)
		
		var has_count = _get_item_count(inventory, ing.item)
		ing_ui.get_node("Icon").texture = ing.item.icon
		ing_ui.get_node("Name").text = ing.item.display_name
		ing_ui.get_node("Amount").text = "%d/%d" % [has_count, ing.count]
		
		var label_color = Color.DARK_GREEN if has_count >= ing.count else Color.RED
		ing_ui.get_node("Amount").add_theme_color_override("font_color", label_color)
		ing_ui.get_node("Name").add_theme_color_override("font_color", Color.BLACK)

func _on_craft_clicked(recipe: CraftingRecipe) -> void:
	if not inventory_component: return
	var inventory = inventory_component.get_inventory()
	
	if CraftingManager.craft(inventory, recipe):
		_update_all_slots()
		_update_tooltip(recipe) # Refresh tooltip if still hovering

func _get_item_count(inventory: Inventory, item: ItemDefinition) -> int:
	if not inventory: return 0
	var total: int = 0
	for slot in inventory.slots:
		if slot.item == item:
			total += slot.count
	return total
