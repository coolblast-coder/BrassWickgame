extends Node3D
## Root of the game scene. Wires the independent pieces together.

## The logical map: which building stands on which tile.
var grid := CityGrid.new()

@onready var _tile_cursor: TileCursor = $TileCursor
@onready var _hud: HUD = $HUD
@onready var _buildings: Node3D = $Buildings
@onready var _build_controller: BuildController = $BuildController


func _ready() -> void:
	_tile_cursor.cell_changed.connect(_hud.show_cell)
	_build_controller.setup(grid, _tile_cursor, _buildings)
	_build_controller.mode_changed.connect(_hud.show_build_mode)
	_hud.build_bar.slot_pressed.connect(_build_controller.select_slot)
	_hud.build_bar.demolish_pressed.connect(_build_controller.toggle_demolish)
