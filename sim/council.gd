class_name Council
extends RefCounted
## The town council's requests: one goal at a time, each with a deadline and
## a reward, to give the player something to aim for beyond survival.
## Checked once per day, after the simulation. All numbers are tuning values.

## The current request changed, or its progress did.
signal request_changed
## A request ended. `title` and `message` are ready to show.
signal request_finished(success: bool, title: String, message: String)

## No requests until this many days have passed.
const QUIET_DAYS_AT_START := 6
## Days between one request ending and the next being made.
const DAYS_BETWEEN := 3
## Unrest added when a request is not met in time.
const FAILURE_UNREST := 4.0

## Kinds of request. "Reach" kinds are met the day the figure is reached;
## "streak" kinds need the condition to hold for a run of days.
const GROW := &"grow"
const STOCK_FOOD := &"stock_food"
const STOCK_COAL := &"stock_coal"
const SAVE_CROWNS := &"save_crowns"
const CALM := &"calm"
const NO_BREAKDOWNS := &"no_breakdowns"
const CLEAN_HOMES := &"clean_homes"

var _grid: CityGrid
var _city: CityState
## The request in force; empty when there is none. Keys: kind, target (the
## figure to reach, or the days of streak needed), limit (for CALM, the
## Unrest to stay below), progress, days_left, reward.
var _request: Dictionary = {}
## Days until the next request is made, while there is none.
var _days_until_next: int = 0
var _last_kind: StringName = &""


func _init(grid: CityGrid, city: CityState) -> void:
	_grid = grid
	_city = city


func has_request() -> bool:
	return not _request.is_empty()


## Call once per day, after the simulation. `day` is the day that just ended.
func day_passed(day: int) -> void:
	if not has_request():
		if day < QUIET_DAYS_AT_START:
			return
		_days_until_next -= 1
		if _days_until_next <= 0:
			_request = _new_request()
			_last_kind = _request["kind"]
			request_changed.emit()
		return

	_request["progress"] = _measure()
	_request["days_left"] = int(_request["days_left"]) - 1
	if int(_request["progress"]) >= int(_request["target"]):
		_finish(true)
	elif int(_request["days_left"]) <= 0:
		_finish(false)
	else:
		request_changed.emit()


## What the council is asking for, in words.
func describe() -> String:
	if not has_request():
		return ""
	var target := int(_request["target"])
	match _request["kind"]:
		GROW:
			return "Grow the city to %d citizens." % target
		STOCK_FOOD:
			return "Lay in a stock of %d Food." % target
		STOCK_COAL:
			return "Lay in a stock of %d Coal." % target
		SAVE_CROWNS:
			return "Put %d Crowns in the treasury." % target
		CALM:
			return "Keep Unrest below %d for %d days running." % [int(_request["limit"]), target]
		NO_BREAKDOWNS:
			return "Go %d days running with nothing broken down." % target
		CLEAN_HOMES:
			return "Keep every home out of the smog for %d days running." % target
	return ""


## How far along the request is, in words.
func progress_text() -> String:
	if not has_request():
		return ""
	var progress := int(_request["progress"])
	var target := int(_request["target"])
	var days := int(_request["days_left"])
	var unit := "days" if _is_streak() else ""
	return "%d / %d %s   -   %d %s left" % [progress, target, unit, days, "day" if days == 1 else "days"]


func reward_text() -> String:
	return "%d Crowns" % int(_request["reward"]) if has_request() else ""


func _is_streak() -> bool:
	return _request["kind"] in [CALM, NO_BREAKDOWNS, CLEAN_HOMES]


## The figure the current request is judged on, as of today.
func _measure() -> int:
	var streak := int(_request["progress"])
	match _request["kind"]:
		GROW:
			return _city.population
		STOCK_FOOD:
			return _city.food
		STOCK_COAL:
			return _city.coal
		SAVE_CROWNS:
			return _city.crowns
		CALM:
			return streak + 1 if _city.unrest < float(_request["limit"]) else 0
		NO_BREAKDOWNS:
			return streak + 1 if _count_broken() == 0 else 0
		CLEAN_HOMES:
			return streak + 1 if _count_smoggy_homes() == 0 else 0
	return 0


func _finish(success: bool) -> void:
	var asked := describe()
	var reward := int(_request["reward"])
	_request = {}
	_days_until_next = DAYS_BETWEEN
	if success:
		_city.crowns += reward
		request_finished.emit(true, "The council is pleased",
				"%s\nDone. The treasury receives %d Crowns." % [asked, reward])
	else:
		_city.unrest = clampf(_city.unrest + FAILURE_UNREST, 0.0, 100.0)
		request_finished.emit(false, "The council is disappointed",
				"%s\nNot done in time. +%d Unrest." % [asked, roundi(FAILURE_UNREST)])
	request_changed.emit()


## Pick a request that suits the city as it stands, and is not the same
## kind as the last one.
func _new_request() -> Dictionary:
	var population := _city.population
	var room := _city.storage_capacity
	var options: Array[Dictionary] = []
	# Always something to grow towards: about a quarter more citizens.
	@warning_ignore("integer_division")
	var grow_to := (maxi(population, 20) * 5 / 4 / 10 + 1) * 10
	options.append(_make(GROW, grow_to, 20, 100))
	options.append(_make(STOCK_FOOD, mini(room, maxi(100, population * 2)), 16, 80))
	options.append(_make(STOCK_COAL, mini(room, maxi(100, population)), 16, 80))
	options.append(_make(SAVE_CROWNS, maxi(400, _city.crowns + 300), 20, 60))
	var calm := _make(CALM, 8, 20, 100)
	calm["limit"] = 20
	options.append(calm)
	if _city.tier >= 1:
		options.append(_make(NO_BREAKDOWNS, 8, 20, 120))
		options.append(_make(CLEAN_HOMES, 8, 20, 120))
	var fresh := options.filter(func(option: Dictionary) -> bool: return option["kind"] != _last_kind)
	return fresh.pick_random()


## A request of `kind`: reach or hold `target` within `days`, for a reward
## that grows with the city's tier.
func _make(kind: StringName, target: int, days: int, reward: int) -> Dictionary:
	return {
		"kind": kind, "target": target, "limit": 0, "progress": 0, "days_left": days,
		"reward": reward * (_city.tier + 1),
	}


func _count_broken() -> int:
	var broken := 0
	for building in _grid.all_buildings:
		if building.broken:
			broken += 1
	return broken


func _count_smoggy_homes() -> int:
	var smoggy := 0
	for building in _grid.all_buildings:
		if building.def.housing > 0 and building.smoggy:
			smoggy += 1
	return smoggy


func to_save() -> Dictionary:
	var request := _request.duplicate()
	if has_request():
		request["kind"] = String(_request["kind"])
	return {"request": request, "days_until_next": _days_until_next, "last_kind": String(_last_kind)}


func from_save(data: Dictionary) -> void:
	_request = {}
	var saved: Variant = data.get("request", {})
	if saved is Dictionary and saved.has("kind"):
		_request = {
			"kind": StringName(str(saved["kind"])),
			"target": int(saved.get("target", 0)),
			"limit": int(saved.get("limit", 0)),
			"progress": int(saved.get("progress", 0)),
			"days_left": int(saved.get("days_left", 1)),
			"reward": int(saved.get("reward", 0)),
		}
	_days_until_next = int(data.get("days_until_next", 0))
	_last_kind = StringName(str(data.get("last_kind", "")))
	request_changed.emit()
