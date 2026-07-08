extends Node
class_name WalletComponent

## Sinal emitido toda vez que o saldo muda (envia o novo saldo)
signal wallet_changed(new_balance: int)

## Saldo inicial do jogador
@export var starting_balance: int = 0

var _balance: int = 0

# ─── Ciclo de Vida ─────────────────────────────────────────────────────────────
func _ready() -> void:
	_balance = starting_balance

# ─── API Pública ───────────────────────────────────────────────────────────────
var balance: int:
	get: return _balance

func add(amount: int) -> void:
	if amount <= 0: return
	_balance += amount
	wallet_changed.emit(_balance)
	print("💰 +%d moedas  (total: %d)" % [amount, _balance])

## Retorna true se conseguiu gastar; false se não tem saldo suficiente.
func spend(amount: int) -> bool:
	if amount <= 0: return true
	if _balance < amount:
		print("💸 Sem dinheiro suficiente! (tem: %d, precisa: %d)" % [_balance, amount])
		return false
	_balance -= amount
	wallet_changed.emit(_balance)
	print("💸 -%d moedas  (total: %d)" % [amount, _balance])
	return true

func can_afford(amount: int) -> bool:
	return _balance >= amount

# ─── Save / Load ───────────────────────────────────────────────────────────────
func get_save_data() -> int:
	return _balance

func load_save_data(saved_balance: int) -> void:
	_balance = saved_balance
	wallet_changed.emit(_balance)
