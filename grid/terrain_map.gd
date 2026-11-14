class_name TerrainMap
extends RefCounted
## What the ground is made of on each tile: grass, a river, outcrops of
## rock, coal seams and fertile soil. Generated from a seed, so the same
## seed always gives the same map and a save only has to store the seed.
##
## Water and rock cannot be built on. The middle of the map, around the
## Town Hall, is always open grass.

enum Type { GRASS, WATER, ROCK, COAL_SEAM, FERTILE }

const NAMES: Array[String] = ["Grass", "Water", "Rock", "Coal seam", "Fertile soil"]

## Tiles around the middle of the map kept as plain grass.
const CLEAR_RADIUS := 9
## How far from the middle the river's course lies, before it meanders.
const RIVER_MIN_OFFSET := 16
const RIVER_MAX_OFFSET := 21
## How far the river wanders either side of its course.
const RIVER_MEANDER := 5.0
## Soil within this many tiles of the river is fertile.
const BANK_WIDTH := 2
const COAL_SEAMS := 5
const FERTILE_PATCHES := 3

## The seed this map was generated from.
var map_seed: int = 0

var _types: PackedByteArray = PackedByteArray()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_types.resize(CityGrid.SIZE.x * CityGrid.SIZE.y)
	_types.fill(Type.GRASS)


func type_at(cell: Vector2i) -> Type:
	if not CityGrid.is_in_bounds(cell):
		return Type.GRASS
	return _types[_index(cell)] as Type


func name_at(cell: Vector2i) -> String:
	return NAMES[type_at(cell)]


## Whether anything can be built on this tile.
func is_buildable(cell: Vector2i) -> bool:
	var type := type_at(cell)
	return type != Type.WATER and type != Type.ROCK


## The map as a picture for the ground shader, one pixel per tile:
## red = water, green = rock, blue = coal seam, alpha = fertile soil.
func to_image() -> Image:
	var image := Image.create(CityGrid.SIZE.x, CityGrid.SIZE.y, false, Image.FORMAT_RGBA8)
	for y in CityGrid.SIZE.y:
		for x in CityGrid.SIZE.x:
			var type := type_at(Vector2i(x, y))
			image.set_pixel(x, y, Color(
					1.0 if type == Type.WATER else 0.0,
					1.0 if type == Type.ROCK else 0.0,
					1.0 if type == Type.COAL_SEAM else 0.0,
					1.0 if type == Type.FERTILE else 0.0))
	return image


## Build the map for a seed.
func generate(seed_value: int) -> void:
	map_seed = seed_value
	_rng.seed = seed_value
	_types.fill(Type.GRASS)
	var centre := CityGrid.SIZE / 2

	# The river crosses the whole map to one side of the middle, running
	# along X or along Y, three tiles wide, wandering as it goes.
	var along_y := _rng.randf() < 0.5
	var side := -1 if _rng.randf() < 0.5 else 1
	var course := (centre.x if along_y else centre.y) + side * _rng.randi_range(RIVER_MIN_OFFSET, RIVER_MAX_OFFSET)
	var meander := FastNoiseLite.new()
	meander.seed = seed_value
	meander.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	meander.frequency = 0.045
	var length := CityGrid.SIZE.y if along_y else CityGrid.SIZE.x
	for i in length:
		var middle := course + roundi(meander.get_noise_1d(float(i)) * RIVER_MEANDER)
		for across in range(-1, 2):
			var cell := Vector2i(middle + across, i) if along_y else Vector2i(i, middle + across)
			_set_if(cell, Type.WATER, Type.GRASS)

	# Fertile banks along the river.
	var banks: Array[Vector2i] = []
	for y in CityGrid.SIZE.y:
		for x in CityGrid.SIZE.x:
			var cell := Vector2i(x, y)
			if type_at(cell) == Type.GRASS and _near(cell, Type.WATER, BANK_WIDTH):
				banks.append(cell)
	for cell in banks:
		_types[_index(cell)] = Type.FERTILE

	# Outcrops of rock, away from the middle.
	var outcrops := FastNoiseLite.new()
	outcrops.seed = seed_value + 1
	outcrops.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	outcrops.frequency = 0.085
	for y in CityGrid.SIZE.y:
		for x in CityGrid.SIZE.x:
			var cell := Vector2i(x, y)
			if _from_centre(cell) > CLEAR_RADIUS and outcrops.get_noise_2d(x, y) > 0.46:
				_set_if(cell, Type.ROCK, Type.GRASS)

	# Coal seams: the first close to the middle, so there is always one
	# within reach of the first roads; the rest anywhere.
	for i in COAL_SEAMS:
		var reach := Vector2i(CLEAR_RADIUS + 1, 14) if i == 0 else Vector2i(CLEAR_RADIUS + 1, 27)
		_blob(_spot(reach.x, reach.y), _rng.randf_range(2.2, 3.4), Type.COAL_SEAM)
	for i in FERTILE_PATCHES:
		_blob(_spot(CLEAR_RADIUS + 1, 27), _rng.randf_range(3.0, 4.5), Type.FERTILE)


## A random tile whose distance from the middle is between the two limits.
func _spot(min_distance: int, max_distance: int) -> Vector2i:
	var centre := CityGrid.SIZE / 2
	for attempt in 200:
		var cell := Vector2i(_rng.randi_range(2, CityGrid.SIZE.x - 3), _rng.randi_range(2, CityGrid.SIZE.y - 3))
		var distance := _from_centre(cell)
		if distance >= min_distance and distance <= max_distance and type_at(cell) == Type.GRASS:
			return cell
	return centre + Vector2i(min_distance + 1, 0)


## Turn the grass within `radius` of `around` into `type`.
func _blob(around: Vector2i, radius: float, type: Type) -> void:
	var reach := ceili(radius)
	for y in range(around.y - reach, around.y + reach + 1):
		for x in range(around.x - reach, around.x + reach + 1):
			var cell := Vector2i(x, y)
			if Vector2(cell - around).length() <= radius and _from_centre(cell) > CLEAR_RADIUS:
				_set_if(cell, type, Type.GRASS)


## Set a tile's type, but only if it is on the map and currently `only_if`.
func _set_if(cell: Vector2i, type: Type, only_if: Type) -> void:
	if CityGrid.is_in_bounds(cell) and _types[_index(cell)] == only_if:
		_types[_index(cell)] = type


## True if any tile within `reach` of `cell` is of `type`.
func _near(cell: Vector2i, type: Type, reach: int) -> bool:
	for y in range(cell.y - reach, cell.y + reach + 1):
		for x in range(cell.x - reach, cell.x + reach + 1):
			var other := Vector2i(x, y)
			if CityGrid.is_in_bounds(other) and _types[_index(other)] == type:
				return true
	return false


## Distance from the middle of the map, in tiles, diagonals counting as one.
func _from_centre(cell: Vector2i) -> int:
	var centre := CityGrid.SIZE / 2
	return maxi(absi(cell.x - centre.x), absi(cell.y - centre.y))


func _index(cell: Vector2i) -> int:
	return cell.y * CityGrid.SIZE.x + cell.x
