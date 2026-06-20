extends StaticBody3D
class_name Chest

@export_category("Configuração de Quebra")
@export var health: int = 3
# CORREÇÃO AQUI: Usando String para evitar o loop infinito no Godot!
@export_file("*.tres") var chest_item_path: String 

# Carregamento seguro: não precisa mais arrastar no Inspector!
var dropped_item_scene = preload("res://addons/modular_inventory_system/world/dropped_item.tscn")

@onready var inventory_component: InventoryComponent = $InventoryComponent
@onready var chest_panel: ModularInventoryPanel = $CanvasLayer/ChestPanel

var is_open: bool = false

func _ready() -> void:
	if not is_in_group("persist"):
		add_to_group("persist")
	if not is_in_group("interactable"):
		add_to_group("interactable")

func interact(player: Player) -> void:
	if is_open:
		close_chest(player)
	else:
		open_chest(player)

func open_chest(player: Player) -> void:
	is_open = true
	
	var chest_inv = inventory_component.inventory
	if not chest_inv and inventory_component.has_method("get_inventory"):
		chest_inv = inventory_component.get_inventory()
	
	if "inventory" in chest_panel:
		chest_panel.inventory = chest_inv
	elif "source_component" in chest_panel:
		chest_panel.source_component = inventory_component
		
	if chest_panel.has_method("_on_inventory_attached"):
		chest_panel._on_inventory_attached(chest_inv)
	
	player.inventory_panel.visible = true
	chest_panel.visible = true

	InputMode.ui()

func close_chest(player: Player) -> void:
	is_open = false
	
	player.inventory_panel.visible = false
	chest_panel.visible = false
	chest_panel.source_component = null
	
	InputMode.game()

# ==========================================
# SISTEMA DE QUEBRA E DROPS
# ==========================================

func hit_with_axe(damage: int) -> void:
	health -= damage
	print("Baú tomou dano! Vida restante: ", health)
	
	if health <= 0:
		break_chest()

func break_chest() -> void:
	# 1. Se quebrar enquanto estiver aberto, limpa a UI
	if is_open:
		chest_panel.visible = false
		chest_panel.source_component = null
		InputMode.game()

	# 2. Resgata o inventário interno para ejetar os itens
	var inv = inventory_component.inventory
	if not inv and inventory_component.has_method("get_inventory"):
		inv = inventory_component.get_inventory()
		
	if inv:
		for slot in inv.slots:
			if slot and slot.item and slot.count > 0:
				_spawn_dropped_item(slot.item, slot.count)
				
	# 3. CORREÇÃO: Dropa o item do próprio baú carregando o caminho
	if chest_item_path != "":
		var chest_item_definition = load(chest_item_path) as ItemDefinition
		if chest_item_definition:
			_spawn_dropped_item(chest_item_definition, 1)
	else:
		push_warning("Atenção: Caminho do 'chest_item' não configurado no Baú!")
		
	# 4. Destrói o baú no mundo
	queue_free()

func _spawn_dropped_item(item_def: ItemDefinition, amount: int) -> void:
	if not dropped_item_scene:
		return
		
	var drop = dropped_item_scene.instantiate()
	
	drop.item_ = item_def
	drop.count = amount
	
	# MUDANÇA AQUI: Adiciona ao nó pai do baú, garantindo que ele exista 
	# na mesma sub-cena/mapa em que o baú foi colocado!
	get_parent().add_child(drop)
	
	# Posição do Baú + um desvio aleatório para os itens "pularem"
	var random_offset = Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))
	drop.global_position = self.global_position + random_offset

# ==========================================
# SISTEMA DE SAVE / LOAD DO BAÚ
# ==========================================

func get_save_data() -> Dictionary:
	var inv_data = []
	var inv = inventory_component.inventory
	if not inv and inventory_component.has_method("get_inventory"):
		inv = inventory_component.get_inventory()
		
	if inv:
		for i in range(inv.slots.size()):
			var slot = inv.slots[i]
			if slot and slot.item:
				inv_data.append({
					"index": i,
					"item_path": slot.item.resource_path, 
					"count": slot.count
				})
				
	return {
		"scene_file": scene_file_path, 
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"pos_z": global_position.z,
		"inventory": inv_data,
		"health": health
	}

func load_save_data(dados: Dictionary) -> void:
	global_position = Vector3(dados["pos_x"], dados["pos_y"], dados["pos_z"])
	
	if dados.has("health"):
		health = dados["health"]
	
	var inv = inventory_component.inventory
	if not inv and inventory_component.has_method("get_inventory"):
		inv = inventory_component.get_inventory()
		
	if inv and dados.has("inventory"):
		inv.clear() 
		for item_data in dados["inventory"]:
			var item_res = load(item_data["item_path"]) as ItemDefinition
			if item_res:
				inv.set_slot(item_data["index"], item_res, item_data["count"])
				
		if chest_panel and chest_panel.visible and chest_panel.has_method("_on_inventory_attached"):
			chest_panel._on_inventory_attached(inv)
