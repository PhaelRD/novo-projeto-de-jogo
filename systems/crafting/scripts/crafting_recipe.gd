class_name CraftingRecipe
extends Resource

@export var display_name: String = ""
@export var ingredients: Array[RecipeIngredient] = []
@export var result_item: ItemDefinition
@export var result_count: int = 1
