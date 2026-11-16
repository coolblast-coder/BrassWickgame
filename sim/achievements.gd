class_name Achievements
extends RefCounted
## Achievements: things worth having done, remembered between sessions in a
## small file. Main checks them at the end of each day; one that has just
## been earned is announced once and then stays earned for good.

const PATH := "user://brasswick_achievements.json"

## In menu order: id, name, how it is earned.
const LIST: Array[Array] = [
	[&"first_citizens", "First Citizens", "Have 20 citizens."],
	[&"town", "Township", "Grow into a Town."],
	[&"city", "City Charter", "Grow into a City."],
	[&"metropolis", "Metropolis", "Grow into a Metropolis."],
	[&"full_year", "A Full Year", "Keep a city going for a whole year, to day 49."],
	[&"bridge", "Bridge Builder", "Build a bridge across the river."],
	[&"calm", "Perfect Calm", "Have 200 citizens and no Unrest at all."],
	[&"coffers", "Full Coffers", "Have 5,000 Crowns in the treasury."],
	[&"inventor", "Inventor", "Own five inventions."],
	[&"polymath", "Polymath", "Own every invention."],
	[&"fire_chief", "Fire Chief", "Have a Fire Brigade put out a fire."],
	[&"councillor", "Friend of the Council", "Meet five of the council's requests in one city."],
	[&"landmark", "Landmark", "Finish building the Clocktower."],
	[&"scenario", "By the Book", "Win any scenario other than First Steps."],
	[&"harsh_city", "Against the Odds", "Grow into a City on Harsh difficulty."],
]

static var _earned: Dictionary[StringName, bool] = {}
static var _loaded: bool = false


static func is_earned(id: StringName) -> bool:
	_ensure_loaded()
	return _earned.get(id, false)


## How many have been earned, for the title screen.
static func earned_count() -> int:
	_ensure_loaded()
	var count := 0
	for entry: Array in LIST:
		if _earned.get(entry[0], false):
			count += 1
	return count


## Mark an achievement as earned. Returns its name and description if it
## was not earned before, for announcing; an empty array if it already was.
static func earn(id: StringName) -> Array:
	if is_earned(id):
		return []
	_earned[id] = true
	_save()
	for entry: Array in LIST:
		if entry[0] == id:
			return [entry[1], entry[2]]
	return []


## Check everything that can be told from the state of the city. Returns a
## [name, description] pair for each achievement earned just now.
static func check(city: CityState, grid: CityGrid, inventions: Inventions, council: Council) -> Array:
	var fresh: Array = []
	var tests: Dictionary[StringName, bool] = {
		&"first_citizens": city.population >= 20,
		&"town": city.tier >= 1,
		&"city": city.tier >= 2,
		&"metropolis": city.tier >= 3,
		&"full_year": city.day >= Seasons.DAYS_PER_SEASON * 4 + 1,
		&"calm": city.population >= 200 and is_zero_approx(city.unrest),
		&"coffers": city.crowns >= 5000,
		&"inventor": inventions.owned_count() >= 5,
		&"polymath": inventions.owned_count() >= Inventions.LIST.size(),
		&"fire_chief": city.fires_put_out > 0,
		&"councillor": council.requests_met >= 5,
		&"harsh_city": city.tier >= 2 and GameRules.difficulty == GameRules.Difficulty.HARD,
	}
	var has_bridge := false
	var has_landmark := false
	for building in grid.all_buildings:
		if building.is_bridge:
			has_bridge = true
		if building.def.unique and not building.under_construction():
			has_landmark = true
	tests[&"bridge"] = has_bridge
	tests[&"landmark"] = has_landmark
	for id: StringName in tests:
		if tests[id]:
			var earned := earn(id)
			if not earned.is_empty():
				fresh.append(earned)
	return fresh


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		for id: Variant in parsed:
			_earned[StringName(str(id))] = true


static func _save() -> void:
	var earned := []
	for entry: Array in LIST:
		if _earned.get(entry[0], false):
			earned.append(String(entry[0]))
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(earned))
		file.close()
