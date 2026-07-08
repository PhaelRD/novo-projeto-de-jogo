@tool
extends Resource
class_name WeightedDropPool

## Pool de itens com pesos para sorteio de qualidade.
## 
## O sistema sorteia UM item da lista com base nos pesos.
## Exemplo: Pimenta Normal (peso 70) + Pimenta de Ferro (peso 25) + Pimenta de Ouro (peso 5).
## A soma dos pesos não precisa ser 100 — o peso é relativo ao total.
##
## Se a soma dos pesos for menor que 'total_weight_cap', existe chance de não dropar nada.
## 'total_weight_cap = 0' → automático: usa a soma dos pesos (sempre dropa algo).

@export var entries: Array[WeightedEntry] = []

## Teto do sorteio. 0 = automático (soma dos pesos = sempre dropa).
## Defina > soma para criar chance de "sem drop".
## Ex: pesos somam 70 e cap=100 → 30% de chance de não dropar nada.
@export var total_weight_cap: float = 0.0

func roll() -> ItemDefinition:
	if entries.is_empty(): return null
	
	var cap = total_weight_cap
	if cap <= 0.0:
		for e in entries:
			cap += e.weight
	
	var roll_value = randf() * cap
	var accumulated = 0.0
	
	for e in entries:
		accumulated += e.weight
		if roll_value <= accumulated:
			return e.get_item()
	
	# roll_value > soma dos pesos → sem drop (quando total_weight_cap > soma)
	return null
