@tool
extends Resource
class_name DropEntry

## Uma entrada individual de drop: um item com quantidade e chance.
## Usado dentro de StagedDropData para definir múltiplos itens por colheita.
##
## MODO SIMPLES: defina 'item' (ou 'item_path') + 'drop_chance'.
##   → O item sempre será o mesmo, com a chance definida.
##
## MODO QUALIDADE: defina 'quality_pool' e deixe 'item' / 'item_path' vazios.
##   → O pool sorteia automaticamente qual qualidade de item vai cair (ex: 70% normal, 5% ouro).
##   → 'drop_chance' ainda funciona como chance de TENTAR o sorteio do pool.

## Item que será solto (referência direta). Ignorado se quality_pool estiver preenchido.
@export var item: ItemDefinition = null

## Caminho do arquivo .tres. Use para SEMENTES para evitar loop circular.
## Ignorado se quality_pool estiver preenchido.
@export_file("*.tres") var item_path: String = ""

## Pool ponderado de qualidades. Se preenchido, o item sorteado vem daqui.
## Arraste um arquivo .tres do tipo WeightedDropPool aqui.
@export var quality_pool: Resource = null

## Quantidade solta por colheita.
@export var amount: int = 1

## Probabilidade de tentar este drop (0.0 = nunca, 1.0 = sempre).
## No modo qualidade: é a chance de ROLAR o pool. O pool decide qual item sai.
@export_range(0.0, 1.0) var drop_chance: float = 1.0

## Retorna o item a ser dropado (modo simples ou após o sorteio do pool).
func get_item() -> ItemDefinition:
	if quality_pool and quality_pool.has_method("roll"):
		return quality_pool.roll()
	if item: return item
	if item_path != "": return load(item_path) as ItemDefinition
	return null
