class_name Walkers
extends Node3D
## Decoration only: citizens and carts going about their business on the
## roads that lead to the Town Hall. They have no effect on the simulation,
## but they follow it: citizens walk from their homes to the workplaces that
## have staff (and back later in the day, or to a Tavern, Market or Tea
## Garden), and carts carry what was produced yesterday to a Warehouse or
## the Town Hall.

## Never more than this many, however large the city.
const MAX_WALKERS := 50
const MAX_CARTS := 20
## One walker appears for every this many citizens.
const CITIZENS_PER_WALKER := 4
## One cart appears for every this many buildings that produced something.
const PRODUCERS_PER_CART := 2
## Speeds in world units per second at 1x game speed.
const WALK_SPEED := 1.6
const CART_SPEED := 2.2
## How often the numbers are brought in line with the city.
const COUNT_CHECK_SECONDS := 0.5
## Seconds a traveller spends out of sight inside a building between trips.
const MIN_PAUSE := 0.4
const MAX_PAUSE := 2.5
## After this point in the day (0 to 1), citizens head home or out for the
## evening instead of to work.
const EVENING_STARTS := 0.55
const BODY_RADIUS := 0.18
const BODY_HEIGHT := 0.75
## How far from the middle of the road a traveller may keep, in world units.
const SIDE_SPREAD := 0.55
const NOWHERE := Vector2i(-1, -1)
const COAT_COLORS: Array[Color] = [
	Color(0.25, 0.27, 0.35), Color(0.45, 0.3, 0.22), Color(0.3, 0.38, 0.3),
	Color(0.55, 0.5, 0.42), Color(0.4, 0.22, 0.25),
]
const CART_COLOR := Color(0.42, 0.3, 0.2)
const COAL_LOAD := Color(0.1, 0.1, 0.11)
const FOOD_LOAD := Color(0.4, 0.6, 0.25)
const GOODS_LOAD := Color(0.7, 0.35, 0.25)
const WATER_LOAD := Color(0.35, 0.55, 0.75)


class Traveller:
	var node: Node3D
	var is_cart: bool = false
	## The road tiles of the current trip, in order.
	var path: Array[Vector2i] = []
	## Index into `path` of the tile being left.
	var leg: int = 0
	## 0 at the start of the leg, 1 at its end.
	var progress: float = 0.0
	## Seconds still to wait out of sight before the next trip.
	var pause: float = 0.0
	## Fixed sideways offset, so they do not all go down the centre line.
	var offset: Vector3 = Vector3.ZERO
	## A cart's load, recoloured for each trip.
	var cargo: MeshInstance3D


var _grid: CityGrid
var _city: CityState
var _clock: GameClock
var _walkers: Array[Traveller] = []
var _carts: Array[Traveller] = []
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
		_sync_counts()

	for walker in _walkers:
		_advance(walker, step)
	for cart in _carts:
		_advance(cart, step)


## Add or remove walkers and carts to match the city.
func _sync_counts() -> void:
	var has_roads := not _grid.connected_road_cells().is_empty()
	var walkers_wanted := 0
	var carts_wanted := 0
	if has_roads:
		walkers_wanted = mini(MAX_WALKERS, ceili(float(_city.population) / CITIZENS_PER_WALKER))
		carts_wanted = mini(MAX_CARTS, ceili(float(_producers().size()) / PRODUCERS_PER_CART))
	_resize(_walkers, walkers_wanted, false)
	_resize(_carts, carts_wanted, true)


func _resize(travellers: Array[Traveller], wanted: int, carts: bool) -> void:
	while travellers.size() > wanted:
		var leaving: Traveller = travellers.pop_back()
		leaving.node.queue_free()
	while travellers.size() < wanted:
		travellers.append(_spawn(carts))


func _spawn(cart: bool) -> Traveller:
	var traveller := Traveller.new()
	traveller.is_cart = cart
	traveller.offset = Vector3(
			randf_range(-SIDE_SPREAD, SIDE_SPREAD), 0.0, randf_range(-SIDE_SPREAD, SIDE_SPREAD))
	if cart:
		traveller.node = _make_cart(traveller)
	else:
		var body := MeshInstance3D.new()
		body.mesh = _body_mesh
		body.position.y = BODY_HEIGHT * 0.5
		body.material_override = BuildingMeshFactory.get_material(COAT_COLORS.pick_random())
		traveller.node = Node3D.new()
		traveller.node.add_child(body)
	traveller.node.visible = false
	add_child(traveller.node)
	# Stagger the first trips, so a new city does not empty all at once.
	traveller.pause = randf_range(0.0, MAX_PAUSE)
	return traveller


## A small handcart: a timber bed on two wheels with its load on top.
func _make_cart(traveller: Traveller) -> Node3D:
	var cart := Node3D.new()
	var bed := MeshInstance3D.new()
	var bed_mesh := BoxMesh.new()
	bed_mesh.size = Vector3(0.5, 0.18, 0.85)
	bed.mesh = bed_mesh
	bed.position.y = 0.3
	bed.material_override = BuildingMeshFactory.get_material(CART_COLOR)
	cart.add_child(bed)
	for side: float in [-1.0, 1.0]:
		var wheel := MeshInstance3D.new()
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.2
		wheel_mesh.bottom_radius = 0.2
		wheel_mesh.height = 0.06
		wheel.mesh = wheel_mesh
		wheel.rotation.z = PI * 0.5
		wheel.position = Vector3(side * 0.3, 0.2, 0.0)
		wheel.material_override = BuildingMeshFactory.get_material(Color(0.2, 0.17, 0.15))
		cart.add_child(wheel)
	traveller.cargo = MeshInstance3D.new()
	var load_mesh := BoxMesh.new()
	load_mesh.size = Vector3(0.4, 0.26, 0.7)
	traveller.cargo.mesh = load_mesh
	traveller.cargo.position.y = 0.52
	cart.add_child(traveller.cargo)
	return cart


func _advance(traveller: Traveller, step: float) -> void:
	if traveller.pause > 0.0:
		traveller.pause -= step
		if traveller.pause > 0.0:
			return
		_start_trip(traveller)
		if traveller.path.size() < 2:
			# Nowhere to go just now; try again shortly.
			traveller.pause = MAX_PAUSE
			return
		traveller.node.visible = true

	# The road ahead may have been demolished or cut off: give up the trip.
	var from := traveller.path[traveller.leg]
	var to := traveller.path[traveller.leg + 1]
	if not _grid.is_connected_road(from) or not _grid.is_connected_road(to):
		_end_trip(traveller)
		return

	var speed := CART_SPEED if traveller.is_cart else WALK_SPEED
	traveller.progress += step * speed / CityGrid.TILE_SIZE
	while traveller.progress >= 1.0:
		traveller.progress -= 1.0
		traveller.leg += 1
		if traveller.leg >= traveller.path.size() - 1:
			_end_trip(traveller)
			return
	from = traveller.path[traveller.leg]
	to = traveller.path[traveller.leg + 1]
	var start := CityGrid.cell_center(from)
	var end := CityGrid.cell_center(to)
	traveller.node.position = start.lerp(end, traveller.progress) + traveller.offset \
			+ Vector3(0.0, BuildingMeshFactory.ROAD_HEIGHT, 0.0)
	var heading := end - start
	traveller.node.rotation.y = atan2(heading.x, heading.z)


## Arrive: step inside and wait a moment before setting out again.
func _end_trip(traveller: Traveller) -> void:
	traveller.node.visible = false
	traveller.path = []
	traveller.pause = randf_range(MIN_PAUSE, MAX_PAUSE)


## Choose where the traveller goes next and find the way there.
func _start_trip(traveller: Traveller) -> void:
	traveller.leg = 0
	traveller.progress = 0.0
	traveller.path = []
	var origin: Building
	var destination: Building
	if traveller.is_cart:
		var producers := _producers()
		if producers.is_empty():
			return
		origin = producers.pick_random()
		destination = _depot()
		traveller.cargo.material_override = BuildingMeshFactory.get_material(_load_color(origin))
	else:
		var homes := _buildings(func(b: Building) -> bool: return b.def.housing > 0 and b.residents > 0)
		if homes.is_empty():
			return
		var home: Building = homes.pick_random()
		var evening := _clock.day_progress() >= EVENING_STARTS
		var places: Array[Building]
		if evening and randf() < 0.5:
			places = _buildings(func(b: Building) -> bool: return b.def.land_value > 0.0)
		if places.is_empty():
			places = _buildings(func(b: Building) -> bool: return b.def.workers > 0 and b.staff > 0)
		if places.is_empty():
			return
		var place: Building = places.pick_random()
		# Out in the morning, back in the evening.
		origin = place if evening else home
		destination = home if evening else place
		if evening and place.def.land_value > 0.0:
			origin = home
			destination = place
	if origin == null or destination == null or origin == destination:
		return
	var start := _door(origin)
	var goal := _door(destination)
	if start == NOWHERE or goal == NOWHERE:
		return
	traveller.path = _route(start, goal)


## Usable buildings that pass `test`.
func _buildings(test: Callable) -> Array[Building]:
	var found: Array[Building] = []
	for building in _grid.all_buildings:
		if building.is_usable() and not building.def.is_road and test.call(building):
			found.append(building)
	return found


## Buildings that made something yesterday worth carting away.
func _producers() -> Array[Building]:
	return _buildings(_made_something)


func _made_something(building: Building) -> bool:
	return building.food_made + building.coal_made + building.goods_made + building.water_made > 0


## Where carts take their loads: a Warehouse if there is one, else the Town
## Hall.
func _depot() -> Building:
	var stores := _buildings(func(b: Building) -> bool: return b.def.storage > 0)
	if stores.is_empty():
		return _grid.town_hall
	return stores.pick_random()


func _load_color(producer: Building) -> Color:
	if producer.coal_made > 0:
		return COAL_LOAD
	if producer.food_made > 0:
		return FOOD_LOAD
	if producer.goods_made > 0:
		return GOODS_LOAD
	return WATER_LOAD


## A connected road tile touching the building, to come out of or go in at;
## NOWHERE if there is none.
func _door(building: Building) -> Vector2i:
	var doors: Array[Vector2i] = []
	for cell in building.cells():
		for direction in CityGrid.NEIGHBOURS:
			var neighbour := cell + direction
			if _grid.is_connected_road(neighbour):
				doors.append(neighbour)
	return NOWHERE if doors.is_empty() else doors.pick_random()


## The shortest way along connected roads from `start` to `goal`, both
## included; empty if there is none.
func _route(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var came_from: Dictionary[Vector2i, Vector2i] = {start: start}
	var frontier: Array[Vector2i] = [start]
	var head := 0
	while head < frontier.size() and not came_from.has(goal):
		var cell := frontier[head]
		head += 1
		for direction in CityGrid.NEIGHBOURS:
			var neighbour := cell + direction
			if _grid.is_connected_road(neighbour) and not came_from.has(neighbour):
				came_from[neighbour] = cell
				frontier.append(neighbour)
	var route: Array[Vector2i] = []
	if not came_from.has(goal):
		return route
	var step := goal
	while step != start:
		route.append(step)
		step = came_from[step]
	route.append(start)
	route.reverse()
	return route
