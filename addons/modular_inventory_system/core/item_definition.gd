class_name ItemDefinition
extends Resource

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null

@export_group("Stacking")
@export var max_stack_size: int = 1
@export var weight: float = 0.0

@export_group("Durability")
@export var has_durability: bool = false
@export var max_durability: int = 100
@export var durability_loss_per_use: int = 1
@export var break_on_zero: bool = true

@export_group("Visuals")
@export var model_scene: PackedScene = null
@export var placement_scene: PackedScene = null
@export var preview_offset: Vector3 = Vector3.ZERO

@export_group("Runtime Behavior")
@export var logic_script: Script = null

@export_group("State")
@export var default_durability: int = 100

@export_group("Metadata")
@export var tags: Array[String] = []
@export var equipment_type: int = -1

@export var custom_metadata: Dictionary = {}

var _cached_logic: ItemLogic = null 

func is_broken(current_durability: int) -> bool:
	return has_durability and current_durability <= 0

func get_durability_percent(current_durability: int) -> float:
	if not has_durability or max_durability <= 0:
		return 1.0
	return clamp(float(current_durability) / float(max_durability), 0.0, 1.0)
	
func has_tag(tag: String) -> bool:
	return tag in tags

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cached_logic = null

# --- NOVA FUNÇÃO VIRTUAL PARA INTERAÇÃO ---
func use(player: CharacterBody3D, target_info: Dictionary) -> bool:
	# Retorna true se o item foi usado com sucesso (permitindo atualizar UI ou consumir)
	return false
