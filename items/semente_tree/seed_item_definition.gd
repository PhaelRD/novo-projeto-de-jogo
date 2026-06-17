extends ItemDefinition 
class_name SeedItemDefinition

@export_category("Configurações de Plantio")
# Mantive a sua coordenada (1, 2) como padrão!
@export var valid_soil_coords: Array[Vector2i] = [Vector2i(1, 2)]
