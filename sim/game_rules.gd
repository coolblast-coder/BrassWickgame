class_name GameRules
extends RefCounted
## The terms a city is played on, chosen on the title screen before it is
## founded: the difficulty, the scenario and any twists. They are kept here, apart from
## any one game, so that a restart plays on the same terms, and they are
## saved with the city so that a loaded game gets its own back.
## All numbers are tuning values.

enum Difficulty { EASY, NORMAL, HARD }

const DIFFICULTY_NAMES: Array[String] = ["Gentle", "Standard", "Harsh"]
const DIFFICULTY_NOTES: Array[String] = [
	"More Crowns to start with. Unrest builds more slowly; events, fires and breakdowns are rarer.",
	"The game as designed.",
	"Fewer Crowns to start with. Unrest builds faster; events, fires and breakdowns are more common.",
]
## By difficulty: Crowns at the start, then multipliers on everything that
## raises Unrest, on the chance of an event, of a fire, and of a breakdown.
const START_CROWNS: Array[int] = [900, 600, 450]
const UNREST_GAIN: Array[float] = [0.75, 1.0, 1.25]
const EVENT_CHANCE: Array[float] = [0.7, 1.0, 1.3]
const FIRE_CHANCE: Array[float] = [0.5, 1.0, 1.5]
const BREAKDOWN_CHANCE: Array[float] = [0.75, 1.0, 1.25]

## What a scenario asks for.
enum Goal { NONE, POPULATION, REACH_DAY, POPULATION_AND_CROWNS, CLOCKTOWER }

## The scenarios, in menu order: name, what to tell the player, the kind of
## goal, its target (citizens, or the day to reach), a second target (Crowns,
## where used), the last day on which it can still be met (0 for none), and
## the map seed everyone playing it shares.
const SCENARIOS: Array[Array] = [
	["Free play", "No goal: build what you like, for as long as you can.", Goal.NONE, 0, 0, 0, -1],
	["Township", "Grow Brasswick into a Town of 100 citizens by day 60.",
			Goal.POPULATION, 100, 0, 60, 1101],
	["Three Winters", "Keep the city going to day 145, through three winters.",
			Goal.REACH_DAY, 145, 0, 0, 1102],
	["The Gilded City", "Have 400 citizens and 3,000 Crowns in the treasury by day 200.",
			Goal.POPULATION_AND_CROWNS, 400, 3000, 200, 1103],
	["Metropolis", "Reach 1,000 citizens by day 320.", Goal.POPULATION, 1000, 0, 320, 1104],
	["The Clocktower", "Finish building the Clocktower by day 400.", Goal.CLOCKTOWER, 0, 0, 400, 1105],
]

## Twists: optional changes to the rules, each switched on or off on the
## title screen. Some make the game harder, some easier.
const ENDLESS_WINTER := &"endless_winter"
const STILL_AIR := &"still_air"
const TINDERBOX := &"tinderbox"
const RICH_SEAMS := &"rich_seams"
const QUIET_TIMES := &"quiet_times"
## In menu order: id, name, what it does.
const TWISTS: Array[Array] = [
	[ENDLESS_WINTER, "Endless Winter", "It is always winter. Harder."],
	[STILL_AIR, "Still Air", "There is no wind: smog stays where it is made. Harder."],
	[TINDERBOX, "Tinderbox", "Fires break out twice as often and spread more readily. Harder."],
	[RICH_SEAMS, "Rich Seams", "Coal Pits dig half again as much. Easier."],
	[QUIET_TIMES, "Quiet Times", "No random events. Easier, and duller."],
]
const TINDERBOX_FIRE_FACTOR := 2.0
const TINDERBOX_SPREAD_FACTOR := 1.6
const RICH_SEAMS_FACTOR := 1.5

## The difficulty of the city in play, or of the next one founded.
static var difficulty: Difficulty = Difficulty.NORMAL
## The twists of the city in play, or of the next one founded.
static var _twists: Dictionary[StringName, bool] = {}


static func has_twist(twist: StringName) -> bool:
	return _twists.get(twist, false)


static func set_twist(twist: StringName, on: bool) -> void:
	_twists[twist] = on


## The names of the twists in force, for the HUD; empty if there are none.
static func twist_names() -> PackedStringArray:
	var names := PackedStringArray()
	for entry: Array in TWISTS:
		if has_twist(entry[0]):
			names.append(entry[1])
	return names
## The scenario of the city in play, or of the next one founded: an index
## into SCENARIOS.
static var scenario: int = 0
## True once the scenario in play has been won or lost; the city may go on
## in free play after that.
static var scenario_settled: bool = false


static func scenario_name() -> String:
	return SCENARIOS[scenario][0]


static func goal_text() -> String:
	return SCENARIOS[scenario][1]


static func has_goal() -> bool:
	return SCENARIOS[scenario][2] != Goal.NONE


## The map seed the scenario is played on; -1 if it has none of its own.
static func scenario_seed() -> int:
	return SCENARIOS[scenario][6]


## How the scenario stands at the end of a day: 1 if its goal has just been
## met, -1 if the time has run out, 0 if it is still open (or there is no
## goal, or it was settled earlier).
static func judge(city: CityState, grid: CityGrid) -> int:
	if not has_goal() or scenario_settled:
		return 0
	var entry: Array = SCENARIOS[scenario]
	var target: int = entry[3]
	var second: int = entry[4]
	var deadline: int = entry[5]
	var met := false
	match entry[2]:
		Goal.POPULATION:
			met = city.population >= target
		Goal.REACH_DAY:
			met = city.day >= target
		Goal.POPULATION_AND_CROWNS:
			met = city.population >= target and city.crowns >= second
		Goal.CLOCKTOWER:
			met = _has_clocktower(grid)
	if met:
		return 1
	return -1 if deadline > 0 and city.day > deadline else 0


## How far along the goal is, for the HUD.
static func progress_text(city: CityState, grid: CityGrid) -> String:
	var entry: Array = SCENARIOS[scenario]
	var target: int = entry[3]
	var second: int = entry[4]
	var deadline: int = entry[5]
	var parts: PackedStringArray = []
	match entry[2]:
		Goal.POPULATION:
			parts.append("Citizens %d / %d" % [city.population, target])
		Goal.REACH_DAY:
			parts.append("Day %d / %d" % [city.day, target])
		Goal.POPULATION_AND_CROWNS:
			parts.append("Citizens %d / %d" % [city.population, target])
			parts.append("Crowns %d / %d" % [city.crowns, second])
		Goal.CLOCKTOWER:
			parts.append("Clocktower: %s" % ("built" if _has_clocktower(grid) else "not yet built"))
	if deadline > 0:
		var left := deadline - city.day + 1
		parts.append("%d %s left" % [maxi(left, 0), "day" if left == 1 else "days"])
	return "   ".join(parts)


static func _has_clocktower(grid: CityGrid) -> bool:
	for building in grid.all_buildings:
		if building.def.unique and not building.under_construction():
			return true
	return false


static func difficulty_name() -> String:
	return DIFFICULTY_NAMES[difficulty]


static func start_crowns() -> int:
	return START_CROWNS[difficulty]


static func unrest_gain() -> float:
	return UNREST_GAIN[difficulty]


static func event_chance() -> float:
	return 0.0 if has_twist(QUIET_TIMES) else EVENT_CHANCE[difficulty]


static func fire_chance() -> float:
	return FIRE_CHANCE[difficulty] * (TINDERBOX_FIRE_FACTOR if has_twist(TINDERBOX) else 1.0)


## Multiplier on the chance of a fire spreading to a neighbour.
static func fire_spread() -> float:
	return TINDERBOX_SPREAD_FACTOR if has_twist(TINDERBOX) else 1.0


## Multiplier on what Coal Pits dig.
static func coal_yield() -> float:
	return RICH_SEAMS_FACTOR if has_twist(RICH_SEAMS) else 1.0


static func breakdown_chance() -> float:
	return BREAKDOWN_CHANCE[difficulty]


static func to_save() -> Dictionary:
	var twists := []
	for name in twist_names():
		twists.append(name)
	return {"difficulty": int(difficulty), "scenario": scenario,
			"scenario_settled": scenario_settled, "twists": twists}


## Take on the terms of a saved city. A save from before there were any is
## played on standard terms.
static func from_save(data: Dictionary) -> void:
	difficulty = clampi(int(data.get("difficulty", Difficulty.NORMAL)), 0, DIFFICULTY_NAMES.size() - 1) as Difficulty
	scenario = clampi(int(data.get("scenario", 0)), 0, SCENARIOS.size() - 1)
	scenario_settled = bool(data.get("scenario_settled", false))
	var saved: Array = data.get("twists", [])
	for entry: Array in TWISTS:
		_twists[entry[0]] = entry[1] in saved
