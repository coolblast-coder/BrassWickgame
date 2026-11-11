extends Node3D
## Root of the game scene. Wires the independent pieces together.

## The logical map: which building stands on which tile.
var grid := CityGrid.new()

## Set when buildings or roads change; road access is refreshed once per frame
## at most, however many tiles changed (a dragged road adds many at once).
var _road_access_dirty: bool = false

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
	grid.buildings_changed.connect(func() -> void: _road_access_dirty = true)
	_place_town_hall()


func _process(_delta: float) -> void:
	if _road_access_dirty:
		_road_access_dirty = false
		_refresh_road_access()


## The Town Hall is placed for the player in the middle of the map.
func _place_town_hall() -> void:
	var def := load("res://buildings/defs/town_hall.tres") as BuildingDef
	var origin := (CityGrid.SIZE - def.footprint) / 2
	grid.town_hall = _build_controller.place_building(def, origin, 0)


## Work out which roads lead back to the Town Hall and tell every building
## whether that network reaches it.
func _refresh_road_access() -> void:
	grid.recompute_connectivity()
	for child in _buildings.get_children():
		var building := child as Building
		if building != null and not building.is_queued_for_deletion():
			building.set_road_access(grid.has_road_access(building))
