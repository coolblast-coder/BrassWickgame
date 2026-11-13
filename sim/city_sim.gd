class_name CitySim
extends RefCounted
## The daily city simulation. Citizens are numbers, not agents: once per
## in-game day run_day() reads the buildings on the grid and updates the
## city's stockpiles. All constants are tuning values.

## Citizens who move in per day for each connected home, while there is room.
const MOVE_IN_PER_HOME := 2
## Citizens per Crown of daily tax.
const CITIZENS_PER_TAX_CROWN := 2
## Crowns per day for every building except roads and the Town Hall.
## The design doc starts this at 2. Lowered after balance modelling: at 2, a
## village without a Brassworks earns about +2 Crowns a day and any extra
## building tips it into permanent debt.
## It then rises with the city's tier, so a big city costs more to run:
## one entry per tier of CityState.TIER_NAMES. Balance modelling showed that
## a rise at every tier (1, 2, 3, 4) bankrupts a city the day it becomes a
## Metropolis.
const UPKEEP_BY_TIER: Array[int] = [1, 1, 2, 2]
## Food eaten per citizen per day.
const FOOD_PER_CITIZEN := 1
## Citizens need Water once the city reaches this tier (Town)...
const WATER_TIER := 1
## ...one Water a day for every this many citizens...
const CITIZENS_PER_WATER := 5
## ...and the city is given this much on the day the need begins, to tide it
## over until the first Pump Station is running.
const WATER_GRANT := 100
## Residents of homes that want Goods (Townhouses) expect them once the city
## reaches this tier (City)...
const GOODS_TIER := 2
## ...one a day for every this many of those residents...
const CITIZENS_PER_GOODS := 10
## ...and the city is given this many on the day the need begins.
const GOODS_GRANT := 40
## Buildings with a Steam need only run on Steam once the city reaches this
## tier (Metropolis)...
const STEAM_TIER := 3
## ...and the city is given this much on the day the need begins. Steam made
## today can only be used from tomorrow, so the stock is what keeps things
## turning.
const STEAM_GRANT := 60
## Food output multiplier for a building standing in smog.
const SMOGGY_FOOD_FACTOR := 0.5

## Airship Docks never sell Coal the city holds below this.
const TRADE_COAL_RESERVE := 100

## Crowns to repair one broken building by hand.
const REPAIR_COST := 20
## Daily chance that a machine which ran today breaks down: the base, plus a
## little for every machine in the city, up to the maximum.
const BREAKDOWN_BASE := 0.01
const BREAKDOWN_PER_MACHINE := 0.001
const BREAKDOWN_MAX := 0.10

## The Great Walkout: the game ends when this many days in a row finish with
## Unrest at 100.
const WALKOUT_DAYS := 3

## Citizens only move in while Unrest is below this.
const UNREST_MOVE_IN_BELOW := 50.0
## Citizens leave while Unrest is above this...
const UNREST_LEAVE_ABOVE := 75.0
## ...this share of the population per day, and never fewer than one.
const LEAVE_SHARE_PER_DAY := 0.05

# Daily Unrest changes. The "share" ones scale with how much of the city is
# affected, from nothing up to the value given.
const UNREST_HUNGER := 20.0        # by share of citizens who went hungry
const UNREST_THIRST := 12.0        # by share of citizens who went without Water
const UNREST_NO_GOODS := 8.0       # by share of citizens who went without Goods
const UNREST_COLD := 10.0          # by share of homes unheated
const UNREST_SMOG := 8.0           # by share of homes in smog
const UNREST_IDLE := 5.0           # by share of workers without a job
const UNREST_PER_BROKEN := 2.0     # per building that was broken today...
const UNREST_BROKEN_MAX := 10.0    # ...up to this much
const UNREST_DEBT := 5.0           # flat, while Crowns are below zero
const UNREST_BASELINE_CALM := 3.0  # flat, every day
const UNREST_TEA_GARDEN := 4.0     # by share of homes near a Tea Garden
const UNREST_TAVERN := 3.0         # by share of homes near an open Tavern

## Steam still unclaimed today; only meaningful while _run_economy() runs.
var _steam_pool: int = 0
## Buildings that went without Steam today.
var _unpowered: int = 0

## Multiplier on all Coal dug. CityEvents lowers it during a Coal Strike.
var coal_output_factor: float = 1.0

var _grid: CityGrid
var _city: CityState
var _smog: SmogMap


func _init(grid: CityGrid, city: CityState, smog: SmogMap) -> void:
	_grid = grid
	_city = city
	_smog = smog
	_city.tier_reached.connect(_on_tier_reached)


## A new tier brings a new need; the city gets a small stock to start with.
func _on_tier_reached(tier: int) -> void:
	if tier == WATER_TIER:
		_city.water += WATER_GRANT
	if tier == GOODS_TIER:
		_city.goods += GOODS_GRANT
	if tier == STEAM_TIER:
		_city.steam += STEAM_GRANT


## Claim today's Steam for a building that needs it. True if it got its
## Steam or needs none; false, and marked unpowered, if the stock ran out.
func _take_steam(building: Building) -> bool:
	var need := building.def.steam_per_day
	if need <= 0 or _city.tier < STEAM_TIER:
		return true
	if _steam_pool >= need:
		_steam_pool -= need
		return true
	building.powered = false
	_unpowered += 1
	return false


func run_day() -> void:
	var crowns_before := _city.crowns
	var coal_before := _city.coal
	var food_before := _city.food
	var water_before := _city.water
	var goods_before := _city.goods
	var steam_before := _city.steam
	_update_population()
	_assign_workers()
	_run_economy()
	_smog.step(_grid.all_buildings)
	_update_unrest()
	# Repairs come after the day's work, so a breakdown always costs at least
	# one day of output unless the player pays to fix it at once.
	_repair_with_yards()
	_roll_breakdowns()
	for building in _grid.all_buildings:
		building.refresh_windows()
	_city.crowns_change = _city.crowns - crowns_before
	_city.coal_change = _city.coal - coal_before
	_city.food_change = _city.food - food_before
	_city.water_change = _city.water - water_before
	_city.goods_change = _city.goods - goods_before
	_city.steam_change = _city.steam - steam_before
	_city.changed.emit()


## Citizens move into homes the road network reaches, while Unrest is low.
## If housing is lost (demolished or cut off), the citizens it held leave on
## the next day. When Unrest is high, a share of everyone leaves each day.
func _update_population() -> void:
	var capacity := 0
	var homes: Array[Building] = []
	for building in _grid.all_buildings:
		building.residents = 0
		if building.def.housing > 0 and building.road_access:
			capacity += building.def.housing
			homes.append(building)
	_city.housing_capacity = capacity
	var population := mini(_city.population, capacity)
	# Unrest here is the value from the end of yesterday.
	if _city.unrest > UNREST_LEAVE_ABOVE and population > 0:
		population -= maxi(1, ceili(population * LEAVE_SHARE_PER_DAY))
	elif _city.unrest < UNREST_MOVE_IN_BELOW:
		population = mini(capacity, population + homes.size() * MOVE_IN_PER_HOME)
	_city.population = population
	_city.peak_population = maxi(_city.peak_population, population)
	_city.update_tier()
	_house_citizens(homes, population, capacity)


## Share the citizens out between the connected homes, in proportion to how
## many each can hold. Odd ones left over go to the homes placed first.
func _house_citizens(homes: Array[Building], population: int, capacity: int) -> void:
	if capacity <= 0:
		return
	var unhoused := population
	for home in homes:
		@warning_ignore("integer_division")
		home.residents = population * home.def.housing / capacity
		unhoused -= home.residents
	for home in homes:
		if unhoused <= 0:
			break
		if home.residents < home.def.housing:
			home.residents += 1
			unhoused -= 1


## Half the population works. Workers fill connected, unbroken workplaces in
## the order the buildings were placed; later ones go short when workers run
## out.
func _assign_workers() -> void:
	@warning_ignore("integer_division")
	var total := _city.population / 2
	var available := total
	for building in _grid.all_buildings:
		building.staff = 0
		if building.def.workers > 0 and building.road_access and not building.broken:
			building.staff = mini(building.def.workers, available)
			available -= building.staff
	_city.workers_total = total
	_city.workers_employed = total - available


## Production, consumption, taxes and upkeep for one day.
## Only buildings the road network reaches produce or burn Coal; every
## building except roads and the Town Hall costs upkeep regardless.
##
## Coal is handed out in a fixed order when it runs short: first everything
## the Coal Pits dug today joins the stockpile, then homes are heated, then
## machines are fuelled in the order they were placed. A machine that cannot
## get its full Coal stops for the day and produces nothing.
func _run_economy() -> void:
	var food_made := 0
	var crowns_made := 0
	var upkeep := 0
	var coal_pool := _city.coal
	var broken := 0
	var homes: Array[Building] = []
	var machines: Array[Building] = []
	var eateries: Array[Building] = []
	var traders: Array[Building] = []
	_steam_pool = _city.steam
	_unpowered = 0

	for building in _grid.all_buildings:
		var def := building.def
		if def.is_road or building == _grid.town_hall:
			continue
		upkeep += UPKEEP_BY_TIER[_city.tier]
		building.fuelled = true
		building.ran_today = false
		building.food_made = 0
		building.coal_made = 0
		building.crowns_made = 0
		building.water_made = 0
		building.goods_made = 0
		building.steam_made = 0
		building.powered = true
		if building.broken:
			# Produces nothing and burns no Coal until repaired.
			broken += 1
			continue
		if not building.road_access:
			continue
		if def.trade_coal > 0:
			# Trades after every home and machine has its Coal, further down.
			traders.append(building)
		elif def.food_per_day > 0:
			# Served after the citizens have eaten, further down.
			eateries.append(building)
		elif def.coal_per_day <= 0:
			# Needs no Coal (Coal Pit, Tea Garden): runs, given any Steam it
			# needs (Clocktower).
			if not _take_steam(building):
				continue
			_produce(building)
			coal_pool += building.coal_made
			food_made += building.food_made
			crowns_made += building.crowns_made
		elif def.housing > 0:
			homes.append(building)
		else:
			machines.append(building)

	var cold_homes := 0
	for home in homes:
		if coal_pool >= home.def.coal_per_day:
			coal_pool -= home.def.coal_per_day
			home.ran_today = true
		else:
			home.fuelled = false
			cold_homes += 1

	var stopped_machines := 0
	for machine in machines:
		if coal_pool < machine.def.coal_per_day:
			machine.fuelled = false
			stopped_machines += 1
		elif _take_steam(machine):
			coal_pool -= machine.def.coal_per_day
			_produce(machine)
			food_made += machine.food_made
			crowns_made += machine.crowns_made

	# Airship Docks sell Coal the city can spare, once everything is fuelled.
	for dock in traders:
		if not _take_steam(dock):
			continue
		var staffing := _staffing(dock)
		dock.ran_today = staffing > 0.0
		var spare := coal_pool - TRADE_COAL_RESERVE
		var sold := mini(roundi(dock.def.trade_coal * staffing), spare)
		if sold > 0:
			coal_pool -= sold
			dock.crowns_made = roundi(float(sold) * dock.def.trade_crowns / dock.def.trade_coal)
			crowns_made += dock.crowns_made

	@warning_ignore("integer_division")
	var tax := _city.population / CITIZENS_PER_TAX_CROWN
	var food_needed := _city.population * FOOD_PER_CITIZEN
	var food_available := _city.food + food_made

	# Taverns open on whatever Food is left once the citizens have eaten.
	var food_left := maxi(0, food_available - food_needed)
	for eatery in eateries:
		if eatery.staff <= 0:
			continue
		if food_left >= eatery.def.food_per_day:
			food_left -= eatery.def.food_per_day
			_produce(eatery)
			crowns_made += eatery.crowns_made
		else:
			eatery.fuelled = false

	# Water: everything pumped today joins the stock, then the citizens drink.
	var water_available := _city.water
	for building in _grid.all_buildings:
		water_available += building.water_made
	var water_needed := 0
	if _city.tier >= WATER_TIER:
		water_needed = ceili(float(_city.population) / CITIZENS_PER_WATER)
	_city.water = maxi(0, water_available - water_needed)
	_city.thirsty_citizens = mini(_city.population,
			maxi(0, water_needed - water_available) * CITIZENS_PER_WATER)

	# Goods: today's output joins the stock, then residents of the homes that
	# want them take their share.
	var goods_available := _city.goods
	var goods_buyers := 0
	for building in _grid.all_buildings:
		goods_available += building.goods_made
		if building.def.wants_goods:
			goods_buyers += building.residents
	var goods_needed := 0
	if _city.tier >= GOODS_TIER:
		goods_needed = ceili(float(goods_buyers) / CITIZENS_PER_GOODS)
	_city.goods = maxi(0, goods_available - goods_needed)
	_city.citizens_without_goods = mini(goods_buyers,
			maxi(0, goods_needed - goods_available) * CITIZENS_PER_GOODS)

	# Steam: what was not used today stays in stock, and today's output joins
	# it for tomorrow.
	var steam_made := 0
	for building in _grid.all_buildings:
		steam_made += building.steam_made
	_city.steam = _steam_pool + steam_made
	_city.unpowered_buildings = _unpowered

	# Crowns may go into debt; Food and Coal stop at zero.
	_city.crowns += crowns_made + tax - upkeep
	_city.food = food_left
	_city.coal = coal_pool
	_city.broken_buildings = broken
	_city.hungry_citizens = maxi(0, food_needed - food_available)
	_city.cold_homes = cold_homes
	_city.stopped_machines = stopped_machines


## Work out what one running building made today and record it on the
## building. Output scales with staffing; smog halves anything grown (smog as
## of the end of yesterday); a Coal Strike cuts anything dug.
func _produce(building: Building) -> void:
	var def := building.def
	var staffing := _staffing(building)
	var growth := SMOGGY_FOOD_FACTOR if building.smoggy else 1.0
	building.ran_today = staffing > 0.0
	building.food_made = roundi(def.food_output * staffing * growth)
	building.coal_made = roundi(def.coal_output * staffing * coal_output_factor)
	building.crowns_made = roundi(def.crowns_output * staffing)
	building.water_made = roundi(def.water_output * staffing)
	building.goods_made = roundi(def.goods_output * staffing)
	building.steam_made = roundi(def.steam_output * staffing)


## How fully staffed a building is, from 0 to 1. Buildings that need no
## workers always count as fully staffed.
func _staffing(building: Building) -> float:
	if building.def.workers <= 0:
		return 1.0
	return float(building.staff) / building.def.workers


## Add up everything that went wrong (and right) today and move the Unrest
## meter. Runs last, so it sees today's shortages and smog.
func _update_unrest() -> void:
	# Each connected Tea Garden, and each Tavern that opened today, calms the
	# homes within its reach. The two add up.
	var calm_areas: Array[Rect2i] = []
	var tavern_areas: Array[Rect2i] = []
	for building in _grid.all_buildings:
		if building.def.calming and building.area_effect_active():
			var area := building.footprint_rect().grow(building.def.effect_range)
			if building.def.workers > 0:
				tavern_areas.append(area)
			else:
				calm_areas.append(area)

	var homes := 0
	var smoggy_homes := 0
	var calmed_homes := 0
	var tavern_homes := 0
	for building in _grid.all_buildings:
		if building.def.housing <= 0 or not building.road_access:
			continue
		homes += 1
		if building.smoggy:
			smoggy_homes += 1
		var footprint := building.footprint_rect()
		for area in calm_areas:
			if area.intersects(footprint):
				calmed_homes += 1
				break
		for area in tavern_areas:
			if area.intersects(footprint):
				tavern_homes += 1
				break

	var idle_workers := _city.workers_total - _city.workers_employed
	var causes := PackedStringArray()
	var change := 0.0
	change += _cause(causes, "Hunger", UNREST_HUNGER * _share(_city.hungry_citizens, _city.population))
	change += _cause(causes, "Thirst", UNREST_THIRST * _share(_city.thirsty_citizens, _city.population))
	change += _cause(causes, "No Goods",
			UNREST_NO_GOODS * _share(_city.citizens_without_goods, _city.population))
	change += _cause(causes, "Cold homes", UNREST_COLD * _share(_city.cold_homes, homes))
	change += _cause(causes, "Smoggy homes", UNREST_SMOG * _share(smoggy_homes, homes))
	change += _cause(causes, "Idle workers", UNREST_IDLE * _share(idle_workers, _city.workers_total))
	change += _cause(causes, "Broken buildings",
			minf(UNREST_BROKEN_MAX, UNREST_PER_BROKEN * _city.broken_buildings))
	if _city.crowns < 0:
		change += _cause(causes, "Debt", UNREST_DEBT)
	change += _cause(causes, "Tea Gardens", -UNREST_TEA_GARDEN * _share(calmed_homes, homes))
	change += _cause(causes, "Taverns", -UNREST_TAVERN * _share(tavern_homes, homes))
	var landmark_calm := 0.0
	for building in _grid.all_buildings:
		if building.def.citywide_calm > 0.0 and building.ran_today:
			landmark_calm += building.def.citywide_calm
	change += _cause(causes, "Clocktower", -landmark_calm)
	change += _cause(causes, "Baseline calm", -UNREST_BASELINE_CALM)

	_city.unrest_causes = causes
	_city.unrest = clampf(_city.unrest + change, 0.0, 100.0)
	if _city.unrest >= 100.0:
		_city.days_at_max_unrest += 1
	else:
		_city.days_at_max_unrest = 0


## Record one Unrest cause for the tooltip (unless it is zero) and return it.
func _cause(causes: PackedStringArray, label: String, amount: float) -> float:
	if not is_zero_approx(amount):
		causes.append("%s: %+.1f" % [label, amount])
	return amount


## `part` as a fraction of `whole`, from 0 to 1; 0 when there is no whole.
func _share(part: int, whole: int) -> float:
	if whole <= 0:
		return 0.0
	return clampf(float(part) / whole, 0.0, 1.0)


## Every staffed, connected, unbroken Mechanic's Yard repairs the broken
## buildings within its reach, for free.
func _repair_with_yards() -> void:
	var repair_areas: Array[Rect2i] = []
	for building in _grid.all_buildings:
		if building.def.repairs and building.road_access and not building.broken \
				and building.staff > 0:
			repair_areas.append(building.footprint_rect().grow(building.def.effect_range))
	if repair_areas.is_empty():
		return
	for building in _grid.all_buildings:
		if not building.broken:
			continue
		var footprint := building.footprint_rect()
		for area in repair_areas:
			if area.intersects(footprint):
				building.set_broken(false)
				break


## Today's chance for each machine in the city to break down.
func breakdown_chance() -> float:
	var machines := 0
	for building in _grid.all_buildings:
		if building.def.can_break:
			machines += 1
	return minf(BREAKDOWN_MAX, BREAKDOWN_BASE + BREAKDOWN_PER_MACHINE * machines)


## Machines that ran today may break down. They stay broken, producing
## nothing, until repaired.
func _roll_breakdowns() -> void:
	var chance := breakdown_chance()
	for building in _grid.all_buildings:
		if building.def.can_break and building.ran_today and not building.broken:
			if randf() < chance:
				building.set_broken(true)
