extends ItemDefinition
class_name FoodItemDefinition

@export_category("Configurações de Comida")
@export var stamina_restore: int = 50   ## Stamina restaurada ao comer
@export var consume_on_use:  bool = true ## Remove 1 unidade do inventário ao comer

func use(player: CharacterBody3D, _target_info: Dictionary) -> bool:
	if not player.stamina_bar:
		push_warning("FoodItemDefinition: player não tem stamina_bar")
		return false

	# Restaura a stamina
	player.stamina_bar.restore(stamina_restore)
	print("🍎 Comeu ", display_name, " — stamina restaurada: +", stamina_restore)

	# Remove do inventário
	if consume_on_use and player.inventory_component:
		player.inventory_component.get_inventory().remove_item(self, 1)

	return true
