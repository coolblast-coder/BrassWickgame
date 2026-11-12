class_name SmogMap
extends RefCounted
## Smog as a value per tile, from 0 to MAX. Updated once per day by CitySim:
## buildings that ran add smog around themselves, then it clears a little
## everywhere and more near Tea Gardens and working Smog Scrubbers. All
## constants are tuning values.

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

## Set during a Smog Storm: nothing clears, not even near Tea Gardens.
var clearing_paused: bool = false

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

	if not clearing_paused:
		for i in _values.size():
			_values[i] = maxf(0.0, _values[i] - CLEAR_PER_DAY)
		for building in buildings:
			if building.def.smog_clear_per_day > 0 and building.area_effect_active():
				_clear_around(building.footprint_rect(), building.def.effect_range,
						building.def.smog_clear_per_day)

	for i in _values.size():
		_values[i] = minf(_values[i], MAX)

	for building in buildings:
		building.smoggy = not building.def.is_road and max_over(building) >= SMOGGY_THRESHOLD
	updated.emit()


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
