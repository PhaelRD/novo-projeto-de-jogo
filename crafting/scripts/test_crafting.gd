extends Node

func test_crafting_logic():
	var inventory = Inventory.new(10)
	var wood = load("res://items/madeira.tres") as ItemDefinition
	var chest = load("res://items/chest/bau_item.tres") as ItemDefinition
	var recipe = load("res://crafting/recipes/recipe_chest.tres") as CraftingRecipe
	
	# Test 1: Not enough wood
	inventory.add_item(wood, 2)
	assert(CraftingManager.can_craft(inventory, recipe) == false, "Should not be able to craft with 2 wood")
	
	# Test 2: Enough wood
	inventory.add_item(wood, 2)
	assert(CraftingManager.can_craft(inventory, recipe) == true, "Should be able to craft with 4 wood")
	
	# Test 3: Perform craft
	var success = CraftingManager.craft(inventory, recipe)
	assert(success == true, "Craft should succeed")
	
	var wood_remaining = _get_count(inventory, wood)
	var chest_count = _get_count(inventory, chest)
	
	assert(wood_remaining == 0, "Wood should be consumed")
	assert(chest_count == 1, "Chest should be added")
	
	print("Crafting logic test passed!")

func _get_count(inventory: Inventory, item: ItemDefinition) -> int:
	var total = 0
	for slot in inventory.slots:
		if slot.item == item:
			total += slot.count
	return total
