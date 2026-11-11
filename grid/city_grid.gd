class_name CityGrid
extends RefCounted
## The logical city grid. Pure data and maths, no nodes, so the simulation,
## road connectivity and overlays can all read it later.
##
## Cells are Vector2i(x, y) where x runs along world +X and y along world +Z.
## Cell (0, 0) has its corner at the world origin.

## Map size in tiles.
const SIZE := Vector2i(64, 64)
## Side length of one tile, in world units.
const TILE_SIZE := 2.0


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
# Which building stands on which cell. A multi-tile building appears once per
# cell it covers.

var _occupancy: Dictionary[Vector2i, Building] = {}


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


## Free all the cells `building` covers.
func remove_building(building: Building) -> void:
	for cell in building.cells():
		if _occupancy.get(cell) == building:
			_occupancy.erase(cell)
