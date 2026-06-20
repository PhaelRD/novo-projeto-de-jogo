extends StaticBody3D
class_name Chest

@onready var inventory_component: InventoryComponent = $InventoryComponent
@onready var chest_panel: ModularInventoryPanel = $CanvasLayer/ChestPanel

var is_open: bool = false

func _ready() -> void:
	# Garante que o baú está etiquetado corretamente caso não tenha sido feito no Editor
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
# SISTEMA DE SAVE / LOAD DO BAÚ
# ==========================================

func get_save_data() -> Dictionary:
	var inv_data = []
	var inv = inventory_component.inventory
	if not inv and inventory_component.has_method("get_inventory"):
		inv = inventory_component.get_inventory()
		
	# Varre todos os slots do baú salvando apenas o necessário (índice, o item e a quantidade)
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
		"scene_file": scene_file_path, # Permite ao SaveManager recriar o baú do zero se necessário
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"pos_z": global_position.z,
		"inventory": inv_data
	}

func load_save_data(dados: Dictionary) -> void:
	# Restaura a posição exata no mundo
	# Restaura a posição exata no mundo
	global_position = Vector3(dados["pos_x"], dados["pos_y"], dados["pos_z"])
	
	var inv = inventory_component.inventory
	if not inv and inventory_component.has_method("get_inventory"):
		inv = inventory_component.get_inventory()
		
	# Limpa o inventário atual e reconstrói com os itens carregados do arquivo
	if inv and dados.has("inventory"):
		inv.clear() 
		for item_data in dados["inventory"]:
			var item_res = load(item_data["item_path"]) as ItemDefinition
			if item_res:
				inv.set_slot(item_data["index"], item_res, item_data["count"])
				
		# Atualiza o painel visual caso o jogo seja carregado com a tela aberta
		if chest_panel and chest_panel.visible and chest_panel.has_method("_on_inventory_attached"):
			chest_panel._on_inventory_attached(inv)
