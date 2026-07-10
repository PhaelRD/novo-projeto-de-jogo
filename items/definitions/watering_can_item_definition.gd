extends ItemDefinition
class_name WateringCanItemDefinition

@export_category("Configurações do Regador")
@export var stamina_cost: int = 2

# ──────────────────────────────────────────────────────────────────────────────
func use(player: CharacterBody3D, target_info: Dictionary) -> bool:
	var collider = target_info.get("collider")
	
	# Precisamos do slot atual para checar/modificar a durabilidade (água)
	var slot: SlotData = null
	var slot_index: int = -1
	if player.has_method("_get_held_slot"):
		slot = player._get_held_slot()
		if player.hotbar:
			slot_index = player.hotbar.get_selected_global_index()

	if not slot or slot.item != self:
		return false
		
	# ── 1. Se estiver mirando numa fonte de água (reabastecer) ────────────────
	if collider and collider.is_in_group("water_source"):
		# Enche a água ao máximo! (não consome stamina para encher)
		slot.current_durability = max_durability
		
		# Atualiza UI
		if player.inventory_component and player.inventory_component.inventory:
			player.inventory_component.inventory.slot_changed.emit(slot_index)
			
		print("Regador: reabastecido com água!")
		
		# Toca alguma animação se houver
		if player.has_node("AnimatedSprite3D"):
			var spr = player.get_node("AnimatedSprite3D")
			if spr.sprite_frames and spr.sprite_frames.has_animation("attack"):
				spr.play("attack")
				
		return true

	# ── 2. Se estiver mirando em uma planta (regar) ───────────────────────────
	if target_info.get("is_blocked", false):
		return false
		
	if not player.stamina_bar.has_energy(stamina_cost):
		print("Estou muito cansado para regar...")
		return false
		
	if collider and collider is HarvestableObject:
		var planta = collider as HarvestableObject
		if not planta.can_grow or not planta.needs_water or planta._is_wilted:
			print("Esta planta não precisa de água.")
			return false
			
		if planta._was_watered_today:
			print("A planta já está regada!")
			return false
			
		# Verifica se tem água no regador
		var agua_atual = slot.get_effective_durability()
		if agua_atual <= 0:
			print("Regador vazio! Preciso reabastecer na água.")
			return false
			
		# Rega a planta
		planta.water()
		
		# Consome 1 de água (durabilidade)
		if player.inventory_component and player.inventory_component.inventory:
			player.inventory_component.inventory.consume_durability(self, slot_index, durability_loss_per_use)
			
		# Consome stamina e anima
		player.stamina_bar.consume(stamina_cost)
		if player.has_node("AnimatedSprite3D"):
			var spr = player.get_node("AnimatedSprite3D")
			if spr.sprite_frames and spr.sprite_frames.has_animation("attack"):
				spr.play("attack")
				
		return true

	print("Regador: não há nada para regar ou reabastecer aqui.")
	return false
