extends ProgressBar
class_name StaminaBar

@export_category("Configuração de Energia")
@export var max_stamina: int = 100
var current_stamina: int = 100

func _ready() -> void:
	max_value = max_stamina
	value = current_stamina
	
	# 1. Torna a barra VERTICAL (Enche de baixo para cima, esvazia descendo)
	fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	
	# Opcional: Esconde o texto da percentagem para ficar mais parecido com Stardew Valley
	show_percentage = false
	
	# 2. Cria a cor AMARELA (Estilo da energia)
	var estilo_amarelo = StyleBoxFlat.new()
	estilo_amarelo.bg_color = Color(0.95, 0.85, 0.1) # Amarelo
	# Adiciona uma bordinha leve para a energia não grudar no fundo
	estilo_amarelo.border_width_left = 2
	estilo_amarelo.border_width_right = 2
	estilo_amarelo.border_width_top = 2
	estilo_amarelo.border_width_bottom = 2
	estilo_amarelo.border_color = Color(0.1, 0.1, 0.1, 0.0) # Borda invisível por dentro
	add_theme_stylebox_override("fill", estilo_amarelo)
	
	# 3. Cria um fundo escuro com borda para a barra
	var estilo_fundo = StyleBoxFlat.new()
	estilo_fundo.bg_color = Color(0.15, 0.15, 0.15, 0.4) # Cinza quase preto e meio transparente
	estilo_fundo.border_width_left = 3
	estilo_fundo.border_width_right = 3
	estilo_fundo.border_width_top = 3
	estilo_fundo.border_width_bottom = 3
	estilo_fundo.border_color = Color(0.05, 0.05, 0.05) # Borda preta por fora
	add_theme_stylebox_override("background", estilo_fundo)


func _process(_delta: float) -> void:
	# Pega o tamanho atual da janela do jogo (para saber onde é o canto)
	var tamanho_tela = get_viewport_rect().size
	
	# Define as medidas da barra (Fina e Alta)
	var largura_barra = 25
	var altura_barra = 100
	var margem = 5 # Distância da barra até a borda da tela
	
	# Crava a posição exatamente no Canto Inferior Direito
	position = Vector2(tamanho_tela.x - largura_barra - margem, tamanho_tela.y - altura_barra - margem)
	size = Vector2(largura_barra, altura_barra)
	visible = true

# --- FUNÇÕES QUE O PLAYER PODE CHAMAR ---

func has_energy(amount: int) -> bool:
	return current_stamina >= amount

func consume(amount: int) -> void:
	current_stamina -= amount
	if current_stamina < 0:
		current_stamina = 0
	value = current_stamina

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
