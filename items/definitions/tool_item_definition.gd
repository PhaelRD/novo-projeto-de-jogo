extends ItemDefinition
class_name ToolItemDefinition

@export_category("Configurações de Ferramenta")
@export var stamina_cost: int = 5  ## Stamina consumida por uso
@export var damage: int = 1        ## Dano aplicado ao alvo

func use(player: CharacterBody3D, target_info: Dictionary) -> bool:
	if not player.stamina_bar.has_energy(stamina_cost):
		print("Estou muito cansado para usar ferramentas...")
		return false

	var body = target_info.get("collider")
	var tem_alvo_valido = body and body.is_in_group("interactable") and body.has_method("hit_with_axe")

	# Só consome stamina e anima se tiver alvo válido
	if tem_alvo_valido:
		player.stamina_bar.consume(stamina_cost)

		if player.animated_sprite and player.animated_sprite.sprite_frames.has_animation("attack"):
			player.animated_sprite.play("attack")

		body.hit_with_axe(damage)
		return true  # Consumiu o clique — não chama interact()

	# Sem alvo válido: libera o clique para interact() (ex: abre porta)
	return false
