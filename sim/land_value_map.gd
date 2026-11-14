class_name LandValueMap
extends RefCounted
## How desirable each tile is to live on, as a multiplier on the taxes a
## home there pays: 1 is ordinary ground. Pleasant neighbours and the river
## raise it; industry and smog lower it. Recomputed from the map whenever it
## is needed. All numbers are tuning values.

const MIN_VALUE := 0.5
const MAX_VALUE := 1.6
## Bonus for living within RIVER_RANGE tiles of the river.
const RIVER_BONUS := 0.15
const RIVER_RANGE := 2
## Penalty for living in heavy smog.
const SMOG_PENALTY := -0.25

## One layer per kind of building that affects land value: a flag per tile
## saying whether one of that kind is in reach. A second Tea Garden beside
## the first adds nothing.
var _layers: Dictionary[BuildingDef, PackedByteArray] = {}
var _riverside: PackedByteArray = PackedByteArray()
var _smoggy: PackedByteArray = PackedByteArray()
var _size: int = CityGrid.SIZE.x * CityGrid.SIZE.y


func _init() -> void:
	_riverside.resize(_size)
	_smoggy.resize(_size)


## Work the map out afresh from the buildings, the ground and the smog.
func recompute(grid: CityGrid, smog: SmogMap) -> void:
	_layers.clear()
	for building in grid.all_buildings:
		var def := building.def
		if is_zero_approx(def.land_value):
			continue
		# Pleasant things only count while they are open; an idle factory is
		# as ugly as a working one.
		if def.land_value > 0.0 and not building.area_effect_active():
			continue
		if not _layers.has(def):
			var blank := PackedByteArray()
			blank.resize(_size)
			_layers[def] = blank
		var layer := _layers[def]
		var area := building.footprint_rect().grow(def.land_value_range) \
				.intersection(Rect2i(Vector2i.ZERO, CityGrid.SIZE))
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				layer[y * CityGrid.SIZE.x + x] = 1
		_layers[def] = layer

	_riverside.fill(0)
	_smoggy.fill(0)
	for y in CityGrid.SIZE.y:
		for x in CityGrid.SIZE.x:
			var cell := Vector2i(x, y)
			var i := y * CityGrid.SIZE.x + x
			if smog.get_at(cell) >= SmogMap.SMOGGY_THRESHOLD:
				_smoggy[i] = 1
			if grid.is_water(cell):
				# Mark the bank around each water tile.
				for by in range(maxi(0, y - RIVER_RANGE), mini(CityGrid.SIZE.y, y + RIVER_RANGE + 1)):
					for bx in range(maxi(0, x - RIVER_RANGE), mini(CityGrid.SIZE.x, x + RIVER_RANGE + 1)):
						_riverside[by * CityGrid.SIZE.x + bx] = 1


## The land value of one tile.
func value_at(cell: Vector2i) -> float:
	if not CityGrid.is_in_bounds(cell):
		return 1.0
	var i := cell.y * CityGrid.SIZE.x + cell.x
	var value := 1.0
	for def: BuildingDef in _layers:
		if _layers[def][i] == 1:
			value += def.land_value
	if _riverside[i] == 1:
		value += RIVER_BONUS
	if _smoggy[i] == 1:
		value += SMOG_PENALTY
	return clampf(value, MIN_VALUE, MAX_VALUE)


## The land value of a building: the average over the tiles it covers.
func value_of(cells: Array[Vector2i]) -> float:
	if cells.is_empty():
		return 1.0
	var total := 0.0
	for cell in cells:
		total += value_at(cell)
	return total / cells.size()


## What raises or lowers the value of a tile, one line each.
func reasons_at(cell: Vector2i) -> PackedStringArray:
	var reasons := PackedStringArray()
	if not CityGrid.is_in_bounds(cell):
		return reasons
	var i := cell.y * CityGrid.SIZE.x + cell.x
	for def: BuildingDef in _layers:
		if _layers[def][i] == 1:
			reasons.append("%s %+d%%" % [def.display_name, roundi(def.land_value * 100.0)])
	if _riverside[i] == 1:
		reasons.append("River %+d%%" % roundi(RIVER_BONUS * 100.0))
	if _smoggy[i] == 1:
		reasons.append("Smog %+d%%" % roundi(SMOG_PENALTY * 100.0))
	return reasons
