extends PanelContainer

@onready var _label: Label = $Label

func _ready() -> void:
	_update_display(0)

## Chamado pelo Player.gd após conectar o WalletComponent
func connect_wallet(wallet: WalletComponent) -> void:
	wallet.wallet_changed.connect(_update_display)
	_update_display(wallet.balance)

func _update_display(new_balance: int) -> void:
	if _label:
		_label.text = "🪙 %d" % new_balance
