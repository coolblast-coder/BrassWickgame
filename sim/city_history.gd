class_name CityHistory
extends RefCounted
## A day-by-day record of the city's main figures, for the statistics screen.
## Main adds one entry after each simulated day.

## Emitted after each new entry.
signal updated

## Oldest entries are dropped beyond this many days.
const MAX_DAYS := 360

## The recorded figures, in the order the statistics screen shows them.
const SERIES: Array[StringName] = [
	&"population", &"unrest", &"crowns", &"coal", &"food", &"water", &"goods", &"steam",
]

var _values: Dictionary[StringName, PackedFloat32Array] = {}


func _init() -> void:
	for series in SERIES:
		_values[series] = PackedFloat32Array()


func record(city: CityState) -> void:
	_add(&"population", city.population)
	_add(&"unrest", city.unrest)
	_add(&"crowns", city.crowns)
	_add(&"coal", city.coal)
	_add(&"food", city.food)
	_add(&"water", city.water)
	_add(&"goods", city.goods)
	_add(&"steam", city.steam)
	updated.emit()


## One figure's values, oldest first.
func values(series: StringName) -> PackedFloat32Array:
	return _values[series]


## How many days are on record.
func days() -> int:
	return _values[&"population"].size()


func _add(series: StringName, value: float) -> void:
	var list := _values[series]
	list.append(value)
	if list.size() > MAX_DAYS:
		list.remove_at(0)
	_values[series] = list


func to_save() -> Dictionary:
	var data := {}
	for series in SERIES:
		data[String(series)] = Array(_values[series])
	return data


func from_save(data: Dictionary) -> void:
	for series in SERIES:
		var list := PackedFloat32Array()
		for value: Variant in data.get(String(series), []):
			list.append(float(value))
		_values[series] = list
	updated.emit()
