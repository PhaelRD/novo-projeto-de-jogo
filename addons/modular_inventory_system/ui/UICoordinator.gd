extends Node

func position_inventory(ui: Control, role: String, other_ui: Control = null) -> void:
	ui.set_anchors_preset(Control.PRESET_FULL_RECT, false)
	ui.anchor_left = 0
	ui.anchor_top = 0
	ui.anchor_right = 1
	ui.anchor_bottom = 1
	ui.offset_left = 0
	ui.offset_top = 0
	ui.offset_right = 0
	ui.offset_bottom = 0
	
	match role:
		"player":
			ui.anchor_left = 0.6
			ui.anchor_right = 1.0
			ui.offset_left = 16
			ui.offset_right = -16
			ui.anchor_top = 0.1
			ui.anchor_bottom = 0.9
			
		"container":
			if other_ui and other_ui.visible:
				ui.anchor_left = 0.0
				ui.anchor_right = 0.48
				ui.offset_left = 16
				ui.offset_right = -8
				ui.anchor_top = 0.1
				ui.anchor_bottom = 0.9
			else:
				ui.anchor_left = 0.15
				ui.anchor_right = 0.85
				ui.anchor_top = 0.1
				ui.anchor_bottom = 0.9
		
		"centered":
			ui.anchor_left = 0.15
			ui.anchor_right = 0.85
			ui.anchor_top = 0.1
			ui.anchor_bottom = 0.9
	
	ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.size_flags_vertical = Control.SIZE_EXPAND_FILL

func reset_inventory(ui: Control) -> void:
	ui.size_flags_horizontal = Control.SIZE_FILL
	ui.size_flags_vertical = Control.SIZE_FILL
