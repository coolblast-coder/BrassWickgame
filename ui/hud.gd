class_name HUD
extends CanvasLayer
## On-screen interface: build bar, a hint line, and a debug readout of the
## hovered tile.

@onready var build_bar: BuildBar = $BuildBar
@onready var _cell_label: Label = $CellLabel
@onready var _hint_label: Label = $HintLabel


func show_cell(cell: Vector2i, in_bounds: bool) -> void:
	if in_bounds:
		_cell_label.text = "Tile: (%d, %d)" % [cell.x, cell.y]
	else:
		_cell_label.text = "Tile: -"


func show_build_mode(mode: BuildController.Mode, def: BuildingDef) -> void:
	build_bar.set_selected(def if mode == BuildController.Mode.PLACING else null)
	build_bar.set_demolishing(mode == BuildController.Mode.DEMOLISHING)
	match mode:
		BuildController.Mode.PLACING:
			if def.is_road:
				_hint_label.text = "Road   |   Click and drag to lay   |   Right click / Esc: cancel"
			else:
				_hint_label.text = "%s   |   R: rotate   |   Right click / Esc: cancel" % def.display_name
		BuildController.Mode.DEMOLISHING:
			_hint_label.text = "Demolish   |   Left click: remove   |   Right click / Esc: cancel"
		_:
			_hint_label.text = ""
