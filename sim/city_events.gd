class_name CityEvents
extends RefCounted
## Random events. Once per day, after the simulation, there is a chance that
## one happens; the chance rises as the population passes each threshold.
## An event does nothing by itself: it is put to the player as an offer with
## two or three options (choice_offered), and takes effect when one is
## picked (choose). All constants are tuning values.

## An event just happened. `title` and `message` are ready to show.
signal event_fired(title: String, message: String)
## A lasting event (strike, storm) started, ticked down, or ended.
signal status_changed
## An event needs the player's decision. `offer` has a title, a message and
## a list of options; answer with choose().
signal choice_offered(offer: Dictionary)
## The pending event has been decided.
signal choice_resolved

enum Type { BURST_BOILER, COAL_STRIKE, SMOG_STORM, AIRSHIP_TRADER, FESTIVAL }

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
const TRADER_COAL_WANTED := 50
const TRADER_COAL_PRICE := 120
## Crowns to stop a boiler bursting.
const EMERGENCY_REPAIR_COST := 40
## Crowns to buy off a strike: this, plus 1 for every 4 citizens.
const STRIKE_DEMANDS_BASE := 60
## A strike broken by force is shorter, but costs Unrest at once.
const STRIKE_BROKEN_DAYS := 2
const STRIKE_BROKEN_UNREST := 15.0
## Crowns for masks in a Smog Storm: this, plus 1 for every 5 citizens.
const MASKS_BASE := 20
## Crowns for a festival: this, plus 1 for every 5 citizens.
const FESTIVAL_BASE := 40
const FESTIVAL_UNREST := -15.0
const FESTIVAL_REFUSED_UNREST := 5.0
## The festival is only proposed once there are this many citizens.
const FESTIVAL_MIN_POPULATION := 50

## Days of Coal Strike still to come; 0 when there is none.
var coal_strike_days_left: int = 0
## Days of Smog Storm still to come; 0 when there is none.
var smog_storm_days_left: int = 0

var _grid: CityGrid
var _city: CityState
var _sim: CitySim
var _smog: SmogMap
var _last_event_day: int = -MIN_DAYS_BETWEEN
## The offer waiting for the player's decision; empty when there is none.
var _pending: Dictionary = {}
## The machine a pending Burst Boiler is about.
var _boiler_victim: Building


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
	if _city.population >= FESTIVAL_MIN_POPULATION:
		options.append(Type.FESTIVAL)
	fire(options.pick_random(), day)


## Put a specific event to the player now. Nothing happens until choose()
## is called with the option picked.
func fire(type: Type, day: int) -> void:
	if has_pending():
		return
	_last_event_day = day
	var offer := _make_offer(type)
	if offer.is_empty():
		return
	_pending = offer
	choice_offered.emit(offer)


## True while an event is waiting for the player's decision.
func has_pending() -> bool:
	return not _pending.is_empty()


## Carry out option `index` of the pending event.
func choose(index: int) -> void:
	if not has_pending():
		return
	var type: Type = _pending["type"]
	var options: Array = _pending["options"]
	var cost: int = options[index].get("cost", 0)
	_pending = {}
	_city.crowns -= cost
	match type:
		Type.BURST_BOILER:
			_resolve_boiler(index)
		Type.COAL_STRIKE:
			_resolve_strike(index)
		Type.SMOG_STORM:
			_resolve_storm(index)
		Type.AIRSHIP_TRADER:
			_resolve_trader(index)
		Type.FESTIVAL:
			_resolve_festival(index)
	status_changed.emit()
	choice_resolved.emit()


## The offer for an event: its title, message and options. Each option has a
## label, a line of detail, a cost in Crowns, and whether it can be picked.
## Empty if the event turns out to have nothing to decide.
func _make_offer(type: Type) -> Dictionary:
	var population := _city.population
	match type:
		Type.BURST_BOILER:
			var machines := _breakable_machines()
			if machines.is_empty():
				event_fired.emit("Burst Boiler",
						"A boiler somewhere considered bursting, found nothing worth the effort, "
						+ "and thought better of it.")
				return {}
			_boiler_victim = machines.pick_random()
			return _offer(type, "Burst Boiler",
					"A boiler at the %s is rattling, hissing and generally clearing its throat. "
							% _boiler_victim.def.display_name
					+ "The foreman would like to know what you propose to do about it.", [
				_option("Send the fitters at once", "Nothing breaks.", EMERGENCY_REPAIR_COST),
				_option("Let it take its course", "It bursts, and stands idle until repaired."),
			])
		Type.COAL_STRIKE:
			@warning_ignore("integer_division")
			var demands := STRIKE_DEMANDS_BASE + population / 4
			return _offer(type, "Coal Strike",
					"The pitmen have downed tools to discuss \"the general state of things\", "
					+ "and have sent a delegation with a list.", [
				_option("Meet their demands", "No strike.", demands),
				_option("Send in the constables",
						"Coal Pits at half output for %d days. +%d Unrest at once." % [
								STRIKE_BROKEN_DAYS, roundi(STRIKE_BROKEN_UNREST)]),
				_option("Wait it out", "Coal Pits at half output for %d days." % STRIKE_DAYS),
			])
		Type.SMOG_STORM:
			@warning_ignore("integer_division")
			var masks := MASKS_BASE + population / 5
			return _offer(type, "Smog Storm",
					"The wind has taken a holiday. Smog will not clear for %d days. " % STORM_DAYS
					+ "Citizens are advised to breathe sparingly.", [
				_option("Hand out masks", "Smoggy homes add no Unrest until it passes.", masks),
				_option("Carry on", "Homes in smog add Unrest as usual."),
			])
		Type.AIRSHIP_TRADER:
			var coal_deal := _option("Sell %d Coal" % TRADER_COAL_WANTED, "+%d Crowns." % TRADER_COAL_PRICE)
			coal_deal["enabled"] = _city.coal >= TRADER_COAL_WANTED
			return _offer(type, "Airship Trader",
					"A passing airship captain, lost and too proud to ask directions, "
					+ "offers to make it worth your while.", [
				_option("Take the purse", "+%d Crowns." % TRADER_CROWNS),
				_option("Take the cargo", "+%d Food." % TRADER_FOOD),
				coal_deal,
			])
		Type.FESTIVAL:
			@warning_ignore("integer_division")
			var purse := FESTIVAL_BASE + population / 5
			return _offer(type, "Founders' Day",
					"The citizens propose a holiday, with bunting, a brass band and a pie of "
					+ "alarming size. They would like the Town Hall to pay for it.", [
				_option("Fund the festival", "%d Unrest at once." % roundi(-FESTIVAL_UNREST), purse),
				_option("Refuse", "+%d Unrest at once." % roundi(FESTIVAL_REFUSED_UNREST)),
			])
	return {}


func _offer(type: Type, title: String, message: String, options: Array) -> Dictionary:
	return {"type": type, "title": title, "message": message, "options": options}


## One option of an offer. One that costs Crowns says so, and cannot be
## picked if the city cannot pay.
func _option(label: String, detail: String, cost: int = 0) -> Dictionary:
	if cost > 0:
		label += "  (%d Crowns)" % cost
	return {"label": label, "detail": detail, "cost": cost, "enabled": _city.can_afford(cost)}


func _resolve_boiler(index: int) -> void:
	var victim := _boiler_victim
	_boiler_victim = null
	if index == 0 or not is_instance_valid(victim):
		event_fired.emit("Burst Boiler", "The fitters arrive in time. The boiler sulks, but holds.")
		return
	victim.set_broken(true)
	event_fired.emit("Burst Boiler",
			"The boiler at the %s has expressed its feelings all over the yard. " % victim.def.display_name
			+ "It is out of action until repaired.")


func _resolve_strike(index: int) -> void:
	match index:
		0:
			event_fired.emit("Coal Strike", "The delegation leaves satisfied. The pits never stop.")
		1:
			coal_strike_days_left = STRIKE_BROKEN_DAYS
			_sim.coal_output_factor = STRIKE_OUTPUT_FACTOR
			_change_unrest(STRIKE_BROKEN_UNREST)
			event_fired.emit("Coal Strike",
					"The constables restore order, and a good deal of resentment. "
					+ "Coal Pits will work at half output for %d days." % STRIKE_BROKEN_DAYS)
		_:
			coal_strike_days_left = STRIKE_DAYS
			_sim.coal_output_factor = STRIKE_OUTPUT_FACTOR
			event_fired.emit("Coal Strike",
					"Coal Pits will work at half output for %d days." % STRIKE_DAYS)


func _resolve_storm(index: int) -> void:
	smog_storm_days_left = STORM_DAYS
	_smog.clearing_paused = true
	_sim.smog_unrest_suppressed = index == 0
	if index == 0:
		event_fired.emit("Smog Storm", "Masks are handed out. The city looks like a convention of plague doctors.")
	else:
		event_fired.emit("Smog Storm", "Smog will not clear for %d days." % STORM_DAYS)


func _resolve_trader(index: int) -> void:
	match index:
		0:
			_city.crowns += TRADER_CROWNS
			event_fired.emit("Airship Trader", "The captain leaves %d Crowns for the trouble." % TRADER_CROWNS)
		1:
			_city.food += TRADER_FOOD
			event_fired.emit("Airship Trader",
					"The airship unloads %d Food its captain \"no longer requires\". " % TRADER_FOOD
					+ "Best not to ask.")
		_:
			_city.coal -= TRADER_COAL_WANTED
			_city.crowns += TRADER_COAL_PRICE
			event_fired.emit("Airship Trader",
					"%d Coal goes aboard, and %d Crowns come ashore." % [TRADER_COAL_WANTED, TRADER_COAL_PRICE])


func _resolve_festival(index: int) -> void:
	if index == 0:
		_change_unrest(FESTIVAL_UNREST)
		event_fired.emit("Founders' Day", "The pie is survived. Spirits are high.")
	else:
		_change_unrest(FESTIVAL_REFUSED_UNREST)
		event_fired.emit("Founders' Day", "There is no festival. There is muttering.")


func _change_unrest(amount: float) -> void:
	_city.unrest = clampf(_city.unrest + amount, 0.0, 100.0)


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
			_sim.smog_unrest_suppressed = false
	if changed:
		status_changed.emit()


func to_save() -> Dictionary:
	return {
		"coal_strike_days_left": coal_strike_days_left,
		"smog_storm_days_left": smog_storm_days_left,
		"last_event_day": _last_event_day,
		"masks": _sim.smog_unrest_suppressed,
	}


func from_save(data: Dictionary) -> void:
	coal_strike_days_left = int(data.get("coal_strike_days_left", 0))
	smog_storm_days_left = int(data.get("smog_storm_days_left", 0))
	_last_event_day = int(data.get("last_event_day", -MIN_DAYS_BETWEEN))
	_sim.coal_output_factor = STRIKE_OUTPUT_FACTOR if coal_strike_days_left > 0 else 1.0
	_smog.clearing_paused = smog_storm_days_left > 0
	_sim.smog_unrest_suppressed = smog_storm_days_left > 0 and bool(data.get("masks", false))
	status_changed.emit()
