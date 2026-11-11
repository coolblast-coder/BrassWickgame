class_name Walkers
extends Node3D
## Decoration only: capsule citizens strolling along the roads that lead to
## the Town Hall. Their number follows the population; they have no effect on
## the simulation.

## Never more than this many, however large the city.
const MAX_WALKERS := 50
## One walker appears for every this many citizens.
const CITIZENS_PER_WALKER := 4
## Walking speed in world units per second at 1x game speed.
const SPEED := 1.6
## How often the walker count is brought in line with the population.
const COUNT_CHECK_SECONDS := 0.5
const BODY_RADIUS := 0.18
const BODY_HEIGHT := 0.75
## How far from the middle of the road a walker may keep, in world units.
const SIDE_SPREAD := 0.55
const COAT_COLORS: Array[Color] = [
	Color(0.25, 0.27, 0.35), Color(0.45, 0.3, 0.22), Color(0.3, 0.38, 0.3),
	Color(0.55, 0.5, 0.42), Color(0.4, 0.22, 0.25),
]


class Walker:
	var node: MeshInstance3D
	var from: Vector2i
	var to: Vector2i
	## 0 at `from`, 1 at `to`.
	var progress: float = 0.0
	## Fixed sideways offset, so walkers do not all march down the centre line.
	var offset: Vector3 = Vector3.ZERO


var _grid: CityGrid
var _city: CityState
var _clock: GameClock
var _walkers: Array[Walker] = []
var _body_mesh: CapsuleMesh
var _count_wait: float = 0.0


func _ready() -> void:
	_body_mesh = CapsuleMesh.new()
	_body_mesh.radius = BODY_RADIUS
	_body_mesh.height = BODY_HEIGHT


## Called once by Main.
func setup(grid: CityGrid, city: CityState, clock: GameClock) -> void:
	_grid = grid
	_city = city
	_clock = clock


func _process(delta: float) -> void:
	if _grid == null or _clock.paused:
		return
	var step := delta * _clock.speed

	_count_wait -= delta
	if _count_wait <= 0.0:
		_count_wait = COUNT_CHECK_SECONDS
		_sync_count()

	for walker in _walkers:
		_advance(walker, step)


## Add or remove walkers to match the population.
func _sync_count() -> void:
	var roads := _grid.connected_road_cells()
	var wanted := 0
	if not roads.is_empty():
		wanted = mini(MAX_WALKERS, ceili(float(_city.population) / CITIZENS_PER_WALKER))
	while _walkers.size() > wanted:
		var leaving: Walker = _walkers.pop_back()
		leaving.node.queue_free()
	while _walkers.size() < wanted:
		_walkers.append(_spawn(roads))


func _spawn(roads: Array[Vector2i]) -> Walker:
	var walker := Walker.new()
	walker.node = MeshInstance3D.new()
	walker.node.mesh = _body_mesh
	walker.node.material_override = BuildingMeshFactory.get_material(COAT_COLORS.pick_random())
	walker.offset = Vector3(
			randf_range(-SIDE_SPREAD, SIDE_SPREAD), 0.0, randf_range(-SIDE_SPREAD, SIDE_SPREAD))
	add_child(walker.node)
	_place_on(walker, roads.pick_random())
	return walker


## Put a walker on a road tile and choose where it heads first.
func _place_on(walker: Walker, cell: Vector2i) -> void:
	walker.from = cell
	walker.to = _next_cell(cell, cell)
	walker.progress = randf()
	_update_position(walker)


func _advance(walker: Walker, step: float) -> void:
	# The road under a walker may have been demolished or cut off.
	if not _grid.is_connected_road(walker.from) or not _grid.is_connected_road(walker.to):
		var roads := _grid.connected_road_cells()
		if roads.is_empty():
			walker.node.visible = false
			return
		_place_on(walker, roads.pick_random())
	walker.node.visible = true

	walker.progress += step * SPEED / CityGrid.TILE_SIZE
	if walker.progress >= 1.0:
		walker.progress -= 1.0
		var arrived := walker.to
		walker.to = _next_cell(arrived, walker.from)
		walker.from = arrived
	_update_position(walker)


## A connected road tile next to `cell` to walk to. Avoids turning straight
## back to `came_from` unless it is a dead end; stays put if there is nowhere
## to go.
func _next_cell(cell: Vector2i, came_from: Vector2i) -> Vector2i:
	var options: Array[Vector2i] = []
	for direction in CityGrid.NEIGHBOURS:
		var neighbour := cell + direction
		if _grid.is_connected_road(neighbour):
			options.append(neighbour)
	if options.is_empty():
		return cell
	if options.size() > 1:
		options.erase(came_from)
	return options.pick_random()


func _update_position(walker: Walker) -> void:
	var start := CityGrid.cell_center(walker.from)
	var end := CityGrid.cell_center(walker.to)
	var height := BuildingMeshFactory.ROAD_HEIGHT + BODY_HEIGHT * 0.5
	walker.node.position = start.lerp(end, walker.progress) + walker.offset + Vector3(0.0, height, 0.0)
