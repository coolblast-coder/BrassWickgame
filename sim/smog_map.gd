class_name SmogMap
extends RefCounted
## Smog as a value per tile, from 0 to MAX. Updated once per day by CitySim:
## buildings that ran add smog around themselves, the wind carries some of
## it downwind, then it clears a little everywhere and more near Tea Gardens
## and working Smog Scrubbers. All constants are tuning values.

## Emitted after each daily update.
signal updated

const MAX := 100.0
## At or above this, a tile is "smoggy": Tenements there add Unrest and
## Glasshouses there grow less.
const SMOGGY_THRESHOLD := 30.0
## Smog is full strength on the source's own tiles and fades to nothing this
## many tiles out.
const SPREAD_RADIUS := 3
## Natural clearing per tile per day.
const CLEAR_PER_DAY := 2.0
## Share of each tile's smog that the wind carries one tile downwind each
## day. With no drift a single Brassworks slowly smothers its surroundings;
## with it, smog thins near the source and trails off downwind instead.
const DRIFT_SHARE := 0.2

## Set during a Smog Storm: nothing clears, not even near Tea Gardens.
var clearing_paused: bool = false
## The way the wind blows, as a step on the grid; zero for still air.
## Set by CitySim from the season.
var wind: Vector2i = Vector2i.ZERO

var _values: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	_values.resize(CityGrid.SIZE.x * CityGrid.SIZE.y)
	_values.fill(0.0)


func get_at(cell: Vector2i) -> float:
	if not CityGrid.is_in_bounds(cell):
		return 0.0
	return _values[_index(cell.x, cell.y)]


## The worst smog on any tile the building covers.
func max_over(building: Building) -> float:
	var worst := 0.0
	for cell in building.cells():
		worst = maxf(worst, get_at(cell))
	return worst


## One day of smog: emit, clear, then mark which buildings sit in smog.
func step(buildings: Array[Building]) -> void:
	for building in buildings:
		if building.def.smog_per_day > 0 and building.ran_today:
			_emit_around(building.footprint_rect(), building.def.smog_per_day)

	_drift()

	if not clearing_paused:
		for i in _values.size():
			_values[i] = maxf(0.0, _values[i] - CLEAR_PER_DAY)
		for building in buildings:
			if building.def.smog_clear_per_day > 0 and building.area_effect_active():
				_clear_around(building.footprint_rect(), building.def.effect_range,
						building.def.smog_clear_per_day)

	for i in _values.size():
		_values[i] = minf(_values[i], MAX)

	mark_buildings(buildings)
	updated.emit()


## Set each building's `smoggy` flag from the smog on its tiles.
func mark_buildings(buildings: Array[Building]) -> void:
	for building in buildings:
		building.smoggy = not building.def.is_road and max_over(building) >= SMOGGY_THRESHOLD


func to_save() -> Array:
	return Array(_values)


func from_save(data: Array) -> void:
	if data.size() != _values.size():
		return
	for i in data.size():
		_values[i] = float(data[i])
	updated.emit()


## The wind carries a share of every tile's smog one tile downwind. Smog
## blown off the edge of the map is gone.
func _drift() -> void:
	if wind == Vector2i.ZERO:
		return
	var before := _values.duplicate()
	for y in CityGrid.SIZE.y:
		for x in CityGrid.SIZE.x:
			var carried := before[_index(x, y)] * DRIFT_SHARE
			if carried <= 0.0:
				continue
			_values[_index(x, y)] -= carried
			var to := Vector2i(x, y) + wind
			if CityGrid.is_in_bounds(to):
				_values[_index(to.x, to.y)] += carried


func _emit_around(source: Rect2i, amount: float) -> void:
	var area := _clip(source.grow(SPREAD_RADIUS))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var distance := CityGrid.distance_to_rect(Vector2i(x, y), source)
			var strength := 1.0 - float(distance) / SPREAD_RADIUS
			if strength > 0.0:
				_values[_index(x, y)] += amount * strength


func _clear_around(source: Rect2i, reach: int, amount: float) -> void:
	var area := _clip(source.grow(reach))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var i := _index(x, y)
			_values[i] = maxf(0.0, _values[i] - amount)


func _clip(area: Rect2i) -> Rect2i:
	return area.intersection(Rect2i(Vector2i.ZERO, CityGrid.SIZE))


func _index(x: int, y: int) -> int:
	return y * CityGrid.SIZE.x + x
