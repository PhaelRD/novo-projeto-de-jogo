extends Node
class_name HotbarInputComponent

## Gerencia input de seleção da hotbar: teclas 1–9 e scroll do mouse.
## Chame handle_input(event) em Player._unhandled_input().

@export var hotbar: ModularHotbar

## Processa o evento. Retorna true se o evento foi consumido.
func handle_input(event: InputEvent) -> bool:
	if not hotbar: return false

	# --- Teclas numéricas 1–9 ---
	for i in range(1, 10):
		var action_name = "hotbar_" + str(i)
		if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
			hotbar.selected_index = i - 1
			return true

	# --- Scroll do mouse ---
	if event is InputEventMouseButton and event.pressed:
		var total_slots = 9
		if hotbar.slots_container:
			total_slots = hotbar.slots_container.get_child_count()

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			hotbar.selected_index = (hotbar.selected_index - 1 + total_slots) % total_slots
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			hotbar.selected_index = (hotbar.selected_index + 1) % total_slots
			return true

	return false
