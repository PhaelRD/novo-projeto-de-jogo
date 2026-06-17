extends ProgressBar
class_name StaminaBar

@export_category("Configuração de Energia")
@export var max_stamina: int = 100
var current_stamina: int = 100

func _ready() -> void:
	# Configura a barra automaticamente ao iniciar
	max_value = max_stamina
	value = current_stamina

# --- FUNÇÕES QUE O PLAYER PODE CHAMAR ---

# Pergunta se tem energia suficiente
func has_energy(amount: int) -> bool:
	return current_stamina >= amount

# Gasta energia e atualiza a barra visual
func consume(amount: int) -> void:
	current_stamina -= amount
	if current_stamina < 0:
		current_stamina = 0
	value = current_stamina

# Recupera energia (para usar com comida ou cama no futuro!)
func restore(amount: int) -> void:
	current_stamina += amount
	if current_stamina > max_stamina:
		current_stamina = max_stamina
	value = current_stamina

# --- SISTEMA DE SAVE ---
func get_save_data() -> int:
	return current_stamina

func load_save_data(saved_stamina: int) -> void:
	current_stamina = saved_stamina
	value = current_stamina
