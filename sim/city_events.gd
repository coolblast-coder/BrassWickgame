class_name CityEvents
extends RefCounted
## Random events. Once per day, after the simulation, there is a chance that
## one fires; the chance rises as the population passes each threshold.
## All constants are tuning values.

## An event just happened. `title` and `message` are ready to show.
signal event_fired(title: String, message: String)
## A lasting event (strike, storm) started, ticked down, or ended.
signal status_changed

enum Type { BURST_BOILER, COAL_STRIKE, SMOG_STORM, AIRSHIP_TRADER }

## No events until this many days have passed.
const QUIET_DAYS_AT_START := 10
## At least this many days between two events.
const MIN_DAYS_BETWEEN := 5
## Daily chance of an event, as [minimum population, chance], highest first.
const CHANCE_BY_POPULATION := [
	[1000, 0.18], [500, 0.13], [250, 0.09], [100, 0.06], [0, 0.04],
]
const STRIKE_DAYS := 5
const STRIKE_OUTPUT_FACTOR := 0.5
const STORM_DAYS := 5
const TRADER_CROWNS := 100
const TRADER_FOOD := 40

## Days of Coal Strike still to come; 0 when there is none.
var coal_strike_days_left: int = 0
## Days of Smog Storm still to come; 0 when there is none.
var smog_storm_days_left: int = 0

var _grid: CityGrid
var _city: CityState
var _sim: CitySim
var _smog: SmogMap
var _last_event_day: int = -MIN_DAYS_BETWEEN


func _init(grid: CityGrid, city: CityState, sim: CitySim, smog: SmogMap) -> void:
	_grid = grid
	_city = city
	_sim = sim
	_smog = smog


## Call once per day, after the simulation. `day` is the day that just ended.
func day_passed(day: int) -> void:
	_tick_lasting_events()
	if day <= QUIET_DAYS_AT_START or day - _last_event_day < MIN_DAYS_BETWEEN:
		return
	if randf() < daily_chance():
		fire_random(day)


func daily_chance() -> float:
	for step: Array in CHANCE_BY_POPULATION:
		if _city.population >= step[0]:
			return step[1]
	return 0.0


## Fire one event chosen at random from those that can happen right now.
func fire_random(day: int) -> void:
	var options: Array[Type] = [Type.AIRSHIP_TRADER]
	if not _breakable_machines().is_empty():
		options.append(Type.BURST_BOILER)
	if coal_strike_days_left == 0:
		options.append(Type.COAL_STRIKE)
	if smog_storm_days_left == 0:
		options.append(Type.SMOG_STORM)
	fire(options.pick_random(), day)


## Make a specific event happen now.
func fire(type: Type, day: int) -> void:
	_last_event_day = day
	match type:
		Type.BURST_BOILER:
			_burst_boiler()
		Type.COAL_STRIKE:
			coal_strike_days_left = STRIKE_DAYS
			_sim.coal_output_factor = STRIKE_OUTPUT_FACTOR
			event_fired.emit("Coal Strike",
					"The pitmen have downed tools to discuss \"the general state of things\". "
					+ "Coal Pits will work at half output for %d days." % STRIKE_DAYS)
		Type.SMOG_STORM:
			smog_storm_days_left = STORM_DAYS
			_smog.clearing_paused = true
			event_fired.emit("Smog Storm",
					"The wind has taken a holiday. Smog will not clear for %d days. " % STORM_DAYS
					+ "Citizens are advised to breathe sparingly.")
		Type.AIRSHIP_TRADER:
			_airship_trader()
	status_changed.emit()


func _burst_boiler() -> void:
	var machines := _breakable_machines()
	if machines.is_empty():
		event_fired.emit("Burst Boiler",
				"A boiler somewhere considered bursting, found nothing worth the effort, "
				+ "and thought better of it.")
		return
	var victim: Building = machines.pick_random()
	victim.set_broken(true)
	event_fired.emit("Burst Boiler",
			"A boiler at the %s has expressed its feelings all over the yard. " % victim.def.display_name
			+ "It is out of action until repaired.")


func _airship_trader() -> void:
	if randf() < 0.5:
		_city.crowns += TRADER_CROWNS
		event_fired.emit("Airship Trader",
				"A passing airship captain, lost and too proud to ask directions, "
				+ "leaves %d Crowns for the trouble." % TRADER_CROWNS)
	else:
		_city.food += TRADER_FOOD
		event_fired.emit("Airship Trader",
				"A passing airship unloads %d Food its captain \"no longer requires\". " % TRADER_FOOD
				+ "Best not to ask.")


## Machines a Burst Boiler could hit: ones that ran today and are not broken.
func _breakable_machines() -> Array[Building]:
	var machines: Array[Building] = []
	for building in _grid.all_buildings:
		if building.def.can_break and building.ran_today and not building.broken:
			machines.append(building)
	return machines


func _tick_lasting_events() -> void:
	var changed := false
	if coal_strike_days_left > 0:
		coal_strike_days_left -= 1
		changed = true
		if coal_strike_days_left == 0:
			_sim.coal_output_factor = 1.0
	if smog_storm_days_left > 0:
		smog_storm_days_left -= 1
		changed = true
		if smog_storm_days_left == 0:
			_smog.clearing_paused = false
	if changed:
		status_changed.emit()
