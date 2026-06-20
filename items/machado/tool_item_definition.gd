extends ItemDefinition
class_name ToolItemDefinition

@export_category("Configurações de Ferramenta")
@export var stamina_cost: int = 5 
@export var damage: int = 1       

func use(player: CharacterBody3D, target_info: Dictionary) -> bool:
	if not player.stamina_bar.has_energy(stamina_cost):
		print("Estou muito cansado para usar ferramentas...")
		return false
		
	# 1. Consome a stamina do jogador IMEDIATAMENTE (Bateu no vento ou na árvore, gasta energia)
	player.stamina_bar.consume(stamina_cost)
	
	# 2. Executa a animação de ataque
	if player.animated_sprite and player.animated_sprite.sprite_frames.has_animation("attack"):
		player.animated_sprite.play("attack")
		
	# 3. Aplica o dano se o alvo for interativo e puder apanhar
	var body = target_info.get("collider")
	if body and body.is_in_group("interactable") and body.has_method("hit_with_axe"):
		body.hit_with_axe(damage)
		
	return true
