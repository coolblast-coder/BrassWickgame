class_name Airships
extends Node3D
## Decoration only: a few airships circling high over the Town Hall, their
## number following the population, and a trading airship that calls at the
## Airship Docks that have staff: it flies in from beyond the hills, settles
## over the dock's landing ring, waits while it is loaded, and leaves again.
## None of them affect the simulation.

## Never more than this many.
const MAX_AIRSHIPS := 5
## The first airship arrives with the first citizens; one more for every
## this many citizens after that.
const CITIZENS_PER_EXTRA_AIRSHIP := 150
## How often the count is brought in line with the population.
const COUNT_CHECK_SECONDS := 1.0
## Circle radius, flying height and turning speed (radians per second at 1x)
## are picked at random per airship from these ranges.
const RADIUS_RANGE := Vector2(18.0, 46.0)
const HEIGHT_RANGE := Vector2(14.0, 22.0)
const TURN_SPEED_RANGE := Vector2(0.04, 0.09)
## Gentle rise and fall, in world units.
const BOB_HEIGHT := 0.6
const BOB_SPEED := 0.5

## The trading airship: seconds (at 1x) between visits, its speeds in world
## units per second, how high it cruises and hovers, and how long it stays.
const VISIT_GAP_RANGE := Vector2(12.0, 30.0)
const TRADER_SPEED := 7.0
const TRADER_CLIMB_SPEED := 3.0
const TRADER_CRUISE_HEIGHT := 17.0
const TRADER_HOVER_HEIGHT := 3.6
const TRADER_LOADING_SECONDS := 5.0
## How far from the middle of the map it appears and disappears.
const TRADER_EDGE_DISTANCE := 115.0
## Where on a dock the landing ring is, before the dock's own rotation.
const LANDING_RING := Vector3(1.43, 0.0, 1.71)
const TRADER_CANVAS := Color(0.58, 0.3, 0.24)

const CANVAS := Color(0.72, 0.62, 0.45)
const GONDOLA := Color(0.4, 0.28, 0.18)
const BRASS := Color(0.78, 0.6, 0.25)


class Airship:
	var node: Node3D
	var angle: float
	var radius: float
	var height: float
	## Radians per second; negative circles the other way.
	var turn_speed: float
	var bob_phase: float


enum TraderPhase { AWAY, ARRIVING, DESCENDING, LOADING, CLIMBING, LEAVING }

var _city: CityState
var _clock: GameClock
var _grid: CityGrid
var _trader: Node3D
var _trader_phase: TraderPhase = TraderPhase.AWAY
## Seconds until the next visit while away, or left to load while loading.
var _trader_wait: float = 8.0
## The spot above the landing ring, and the point at the map's edge it is
## coming from or making for.
var _trader_over_dock: Vector3
var _trader_edge: Vector3
var _airships: Array[Airship] = []
var _count_wait: float = 0.0
var _center: Vector3


func _ready() -> void:
	var map_size := Vector2(CityGrid.SIZE) * CityGrid.TILE_SIZE
	_center = Vector3(map_size.x * 0.5, 0.0, map_size.y * 0.5)


## Called once by Main.
func setup(city: CityState, clock: GameClock, grid: CityGrid) -> void:
	_city = city
	_clock = clock
	_grid = grid
	_trader = _build_model(TRADER_CANVAS)
	_trader.scale = Vector3.ONE * 0.8
	_trader.visible = false
	add_child(_trader)


func _process(delta: float) -> void:
	if _city == null or _clock.paused:
		return
	var step := delta * _clock.speed

	_count_wait -= delta
	if _count_wait <= 0.0:
		_count_wait = COUNT_CHECK_SECONDS
		_sync_count()

	for airship in _airships:
		airship.angle += airship.turn_speed * step
		airship.bob_phase += BOB_SPEED * step
		_update_transform(airship)
	_fly_trader(step)


## Move the trading airship through its visit.
func _fly_trader(step: float) -> void:
	match _trader_phase:
		TraderPhase.AWAY:
			_trader_wait -= step
			if _trader_wait <= 0.0:
				_begin_visit()
		TraderPhase.ARRIVING:
			if _move_trader(_trader_over_dock, TRADER_SPEED * step):
				_trader_phase = TraderPhase.DESCENDING
		TraderPhase.DESCENDING:
			var hover := Vector3(_trader_over_dock.x, TRADER_HOVER_HEIGHT, _trader_over_dock.z)
			if _move_trader(hover, TRADER_CLIMB_SPEED * step):
				_trader_phase = TraderPhase.LOADING
				_trader_wait = TRADER_LOADING_SECONDS
		TraderPhase.LOADING:
			_trader_wait -= step
			if _trader_wait <= 0.0:
				_trader_phase = TraderPhase.CLIMBING
		TraderPhase.CLIMBING:
			if _move_trader(_trader_over_dock, TRADER_CLIMB_SPEED * step):
				_trader_phase = TraderPhase.LEAVING
		TraderPhase.LEAVING:
			if _move_trader(_trader_edge, TRADER_SPEED * step):
				_trader.visible = false
				_trader_phase = TraderPhase.AWAY
				_trader_wait = randf_range(VISIT_GAP_RANGE.x, VISIT_GAP_RANGE.y)


## Pick a dock that is open for business and set off for it. If there is
## none, look again a little later.
func _begin_visit() -> void:
	var docks: Array[Building] = []
	for building in _grid.all_buildings:
		if building.def.trade_coal > 0 and building.is_usable() and building.staff > 0:
			docks.append(building)
	if docks.is_empty():
		_trader_wait = VISIT_GAP_RANGE.x
		return
	var dock: Building = docks.pick_random()
	var ring := dock.global_transform * LANDING_RING
	_trader_over_dock = Vector3(ring.x, TRADER_CRUISE_HEIGHT, ring.z)
	var bearing := randf() * TAU
	_trader_edge = _center + Vector3(cos(bearing), TRADER_CRUISE_HEIGHT / TRADER_EDGE_DISTANCE,
			sin(bearing)) * TRADER_EDGE_DISTANCE
	_trader.position = _trader_edge
	_trader.visible = true
	_trader_phase = TraderPhase.ARRIVING


## Move the trader up to `distance` towards `target`, nose first when it is
## travelling across the map. True once it has arrived.
func _move_trader(target: Vector3, distance: float) -> bool:
	var to_go := target - _trader.position
	var across := Vector3(to_go.x, 0.0, to_go.z)
	if across.length() > 0.5:
		_trader.rotation.y = atan2(across.x, across.z)
	if to_go.length() <= distance:
		_trader.position = target
		return true
	_trader.position += to_go.normalized() * distance
	return false


## Add or remove airships to match the population.
func _sync_count() -> void:
	var wanted := 0
	if _city.population > 0:
		@warning_ignore("integer_division")
		wanted = mini(MAX_AIRSHIPS, 1 + _city.population / CITIZENS_PER_EXTRA_AIRSHIP)
	while _airships.size() > wanted:
		var leaving: Airship = _airships.pop_back()
		leaving.node.queue_free()
	while _airships.size() < wanted:
		_airships.append(_spawn())


func _spawn() -> Airship:
	var airship := Airship.new()
	airship.node = _build_model(CANVAS)
	airship.angle = randf() * TAU
	airship.radius = randf_range(RADIUS_RANGE.x, RADIUS_RANGE.y)
	airship.height = randf_range(HEIGHT_RANGE.x, HEIGHT_RANGE.y)
	airship.turn_speed = randf_range(TURN_SPEED_RANGE.x, TURN_SPEED_RANGE.y)
	if randf() < 0.5:
		airship.turn_speed = -airship.turn_speed
	airship.bob_phase = randf() * TAU
	add_child(airship.node)
	_update_transform(airship)
	return airship


func _update_transform(airship: Airship) -> void:
	var around := Vector3(cos(airship.angle), 0.0, sin(airship.angle))
	var bob := sin(airship.bob_phase) * BOB_HEIGHT
	airship.node.position = _center + around * airship.radius \
			+ Vector3(0.0, airship.height + bob, 0.0)
	# Point the nose (local +Z) along the direction of travel.
	var heading := Vector3(-around.z, 0.0, around.x) * signf(airship.turn_speed)
	airship.node.rotation.y = atan2(heading.x, heading.z)


## An airship from primitives: a capsule envelope lying along local Z, a box
## gondola slung underneath, and a cross of tail fins at the back.
func _build_model(canvas: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Airship"

	var envelope_mesh := CapsuleMesh.new()
	envelope_mesh.radius = 1.3
	envelope_mesh.height = 6.0
	var envelope := _add_part(root, envelope_mesh, Vector3.ZERO, canvas)
	envelope.rotation.x = PI * 0.5

	var gondola_mesh := BoxMesh.new()
	gondola_mesh.size = Vector3(0.9, 0.6, 2.2)
	_add_part(root, gondola_mesh, Vector3(0.0, -1.7, 0.0), GONDOLA)

	var upright_fin := BoxMesh.new()
	upright_fin.size = Vector3(0.1, 1.8, 1.0)
	_add_part(root, upright_fin, Vector3(0.0, 0.0, -2.8), BRASS, 0.7)
	var level_fin := BoxMesh.new()
	level_fin.size = Vector3(1.8, 0.1, 1.0)
	_add_part(root, level_fin, Vector3(0.0, 0.0, -2.8), BRASS, 0.7)
	return root


func _add_part(root: Node3D, shape: Mesh, at: Vector3, color: Color,
		metallic: float = 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = shape
	part.position = at
	part.material_override = BuildingMeshFactory.get_material(color, metallic)
	root.add_child(part)
	return part
