class_name Airships
extends Node3D
## Decoration only: a few airships circling high over the Town Hall. Their
## number follows the population; they have no effect on the simulation.

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


var _city: CityState
var _clock: GameClock
var _airships: Array[Airship] = []
var _count_wait: float = 0.0
var _center: Vector3


func _ready() -> void:
	var map_size := Vector2(CityGrid.SIZE) * CityGrid.TILE_SIZE
	_center = Vector3(map_size.x * 0.5, 0.0, map_size.y * 0.5)


## Called once by Main.
func setup(city: CityState, clock: GameClock) -> void:
	_city = city
	_clock = clock


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
	airship.node = _build_model()
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
func _build_model() -> Node3D:
	var root := Node3D.new()
	root.name = "Airship"

	var envelope_mesh := CapsuleMesh.new()
	envelope_mesh.radius = 1.3
	envelope_mesh.height = 6.0
	var envelope := _add_part(root, envelope_mesh, Vector3.ZERO, CANVAS)
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
