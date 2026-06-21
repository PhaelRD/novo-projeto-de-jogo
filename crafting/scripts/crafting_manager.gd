class_name CraftingManager
extends Node

static func can_craft(inventory: Inventory, recipe: CraftingRecipe) -> bool:
	if not inventory or not recipe: return false
	
	for ingredient in recipe.ingredients:
		if not _has_item_amount(inventory, ingredient.item, ingredient.count):
			return false
	return true

static func craft(inventory: Inventory, recipe: CraftingRecipe) -> bool:
	if not can_craft(inventory, recipe):
		return false
	
	# Consume ingredients
	for ingredient in recipe.ingredients:
		inventory.remove_item(ingredient.item, ingredient.count)
	
	# Add result
	inventory.add_item(recipe.result_item, recipe.result_count)
	return true

static func _has_item_amount(inventory: Inventory, item: ItemDefinition, amount: int) -> bool:
	var total: int = 0
	for slot in inventory.slots:
		if slot.item == item:
			total += slot.count
	return total >= amount
