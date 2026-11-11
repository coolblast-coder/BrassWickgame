class_name HUD
extends CanvasLayer
## On-screen interface: top bar, shortage warnings, building info panel,
## build bar with its hint line, and a debug readout of the hovered tile.

@onready var top_bar: TopBar = $TopBar
@onready var build_bar: BuildBar = $BuildBar
@onready var _cell_label: Label = $CellLabel
@onready var _hint_label: Label = $HintLabel
@onready var _warning_label: Label = $WarningLabel
@onready var _info_panel: InfoPanel = $InfoPanel

var _city: CityState
## The building whose details are shown; null when the panel is closed.
var _selected: Building


## Called once by Main. The top bar and the warning line follow the city.
func bind_city(city: CityState) -> void:
	_city = city
	top_bar.bind_city(city)
	city.changed.connect(_refresh_warnings)
	# Staffing and Coal figures change each day; keep the open panel current.
	city.changed.connect(func() -> void: _info_panel.show_building(_selected))
	_refresh_warnings()


## Show the info panel for `building`; pass null to close it.
func show_selection(building: Building) -> void:
	_selected = building
	_info_panel.show_building(building)


## One line listing every shortage from the last day; empty when all is well.
func _refresh_warnings() -> void:
	var warnings: PackedStringArray = []
	if _city.crowns < 0:
		warnings.append("In debt: nothing can be built")
	if _city.hungry_citizens > 0:
		warnings.append("Hungry citizens: %d" % _city.hungry_citizens)
	if _city.cold_homes > 0:
		warnings.append("Cold homes: %d" % _city.cold_homes)
	if _city.stopped_machines > 0:
		warnings.append("Machines stopped, no Coal: %d" % _city.stopped_machines)
	_warning_label.text = "   |   ".join(warnings)


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
				_hint_label.text = "Road (%d Crowns per tile)   |   Click and drag to lay   |   Right click / Esc: cancel" % def.cost
			else:
				_hint_label.text = "%s (%d Crowns)   |   R: rotate   |   Right click / Esc: cancel" % [def.display_name, def.cost]
		BuildController.Mode.DEMOLISHING:
			_hint_label.text = "Demolish   |   Left click: remove   |   Right click / Esc: cancel"
		_:
			_hint_label.text = ""
