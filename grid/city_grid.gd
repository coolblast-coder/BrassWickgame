class_name CityGrid
extends RefCounted
## The logical city grid: which building stands on which tile, and which roads
## lead back to the Town Hall. It draws nothing itself, so the simulation and
## overlays can read it later without touching the scene.
##
## Cells are Vector2i(x, y) where x runs along world +X and y along world +Z.
## Cell (0, 0) has its corner at the world origin.

## Emitted whenever a building or road is added or removed. Listeners should
## call recompute_connectivity() before asking about road access again.
signal buildings_changed

## Map size in tiles.
const SIZE := Vector2i(64, 64)
## Side length of one tile, in world units.
const TILE_SIZE := 2.0
## The four edge-adjacent directions. Diagonals do not count as touching.
const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

## The Town Hall, placed by Main at the start. Roads count as connected when
## they lead back to it.
var town_hall: Building:
	set(value):
		town_hall = value
		buildings_changed.emit()

## Which building stands on which cell. A multi-tile building appears once per
## cell it covers.
var _occupancy: Dictionary[Vector2i, Building] = {}
## Road cells that lead back to the Town Hall, as of the last
## recompute_connectivity().
var _connected_roads: Dictionary[Vector2i, bool] = {}


## The cell containing a world position (may be out of bounds).
static func world_to_cell(world_pos: Vector3) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE_SIZE), floori(world_pos.z / TILE_SIZE))


## World position of a cell's minimum (-X, -Z) corner, on the ground.
static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * TILE_SIZE, 0.0, cell.y * TILE_SIZE)


## World position of the middle of a cell, on the ground.
static func cell_center(cell: Vector2i) -> Vector3:
	return cell_to_world(cell) + Vector3(TILE_SIZE, 0.0, TILE_SIZE) * 0.5


static func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y


# --- Occupancy ----------------------------------------------------------------

## The building covering this cell, or null if the cell is empty.
func building_at(cell: Vector2i) -> Building:
	return _occupancy.get(cell)


## True if every cell is on the map and empty.
func can_place(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if not is_in_bounds(cell) or _occupancy.has(cell):
			return false
	return true


## Record `building` on all the cells it covers.
func add_building(building: Building) -> void:
	for cell in building.cells():
		_occupancy[cell] = building
	buildings_changed.emit()


## Free all the cells `building` covers.
func remove_building(building: Building) -> void:
	for cell in building.cells():
		if _occupancy.get(cell) == building:
			_occupancy.erase(cell)
	buildings_changed.emit()


# --- Road network -------------------------------------------------------------
# A road tile is "connected" when a chain of edge-adjacent road tiles leads
# from it to a tile beside the Town Hall. Diagonals do not count.


func is_road(cell: Vector2i) -> bool:
	var building := building_at(cell)
	return building != null and building.def.is_road


## Flood-fill the road network outwards from the Town Hall.
func recompute_connectivity() -> void:
	_connected_roads.clear()
	if town_hall == null:
		return
	var frontier: Array[Vector2i] = []
	for hall_cell in town_hall.cells():
		for offset in NEIGHBOURS:
			_visit_road(hall_cell + offset, frontier)
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_back()
		for offset in NEIGHBOURS:
			_visit_road(current + offset, frontier)


## True if the building is served by the Town Hall's road network:
## a road that is part of it, or a building with at least one footprint tile
## edge-adjacent to such a road. Uses the last recompute_connectivity() result.
func has_road_access(building: Building) -> bool:
	if building == town_hall:
		return true
	if building.def.is_road:
		return _connected_roads.has(building.origin)
	for cell in building.cells():
		for offset in NEIGHBOURS:
			if _connected_roads.has(cell + offset):
				return true
	return false


func _visit_road(cell: Vector2i, frontier: Array[Vector2i]) -> void:
	if _connected_roads.has(cell) or not is_road(cell):
		return
	_connected_roads[cell] = true
	frontier.append(cell)
