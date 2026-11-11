class_name CitySim
extends RefCounted
## The daily city simulation. Citizens are numbers, not agents: once per
## in-game day run_day() reads the buildings on the grid and updates the
## city's stockpiles. All constants are tuning values.

## Citizens who move in per day for each connected Tenement, while there is room.
const MOVE_IN_PER_HOME := 2
## Citizens per Crown of daily tax.
const CITIZENS_PER_TAX_CROWN := 2
## Crowns per day for every building except roads and the Town Hall.
## The design doc starts this at 2. Lowered after balance modelling: at 2, a
## village without a Brassworks earns about +2 Crowns a day and any extra
## building tips it into permanent debt.
const UPKEEP_PER_BUILDING := 1
## Food eaten per citizen per day.
const FOOD_PER_CITIZEN := 1
## Food output multiplier for a building standing in smog.
const SMOGGY_FOOD_FACTOR := 0.5

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
const UNREST_COLD := 10.0          # by share of Tenements unheated
const UNREST_SMOG := 8.0           # by share of Tenements in smog
const UNREST_IDLE := 5.0           # by share of workers without a job
const UNREST_PER_BROKEN := 2.0     # per building that was broken today...
const UNREST_BROKEN_MAX := 10.0    # ...up to this much
const UNREST_DEBT := 5.0           # flat, while Crowns are below zero
const UNREST_BASELINE_CALM := 3.0  # flat, every day
const UNREST_TEA_GARDEN := 4.0     # by share of Tenements near a Tea Garden

## Multiplier on all Coal dug. CityEvents lowers it during a Coal Strike.
var coal_output_factor: float = 1.0

var _grid: CityGrid
var _city: CityState
var _smog: SmogMap


func _init(grid: CityGrid, city: CityState, smog: SmogMap) -> void:
	_grid = grid
	_city = city
	_smog = smog


func run_day() -> void:
	var crowns_before := _city.crowns
	var coal_before := _city.coal
	var food_before := _city.food
	_update_population()
	_assign_workers()
	_run_economy()
	_smog.step(_grid.all_buildings)
	_update_unrest()
	# Repairs come after the day's work, so a breakdown always costs at least
	# one day of output unless the player pays to fix it at once.
	_repair_with_yards()
	_roll_breakdowns()
	_city.crowns_change = _city.crowns - crowns_before
	_city.coal_change = _city.coal - coal_before
	_city.food_change = _city.food - food_before
	_city.changed.emit()


## Citizens move into Tenements the road network reaches, while Unrest is low.
## If housing is lost (demolished or cut off), the citizens it held leave on
## the next day. When Unrest is high, a share of everyone leaves each day.
func _update_population() -> void:
	var capacity := 0
	var homes := 0
	for building in _grid.all_buildings:
		if building.def.housing > 0 and building.road_access:
			capacity += building.def.housing
			homes += 1
	_city.housing_capacity = capacity
	var population := mini(_city.population, capacity)
	# Unrest here is the value from the end of yesterday.
	if _city.unrest > UNREST_LEAVE_ABOVE and population > 0:
		population -= maxi(1, ceili(population * LEAVE_SHARE_PER_DAY))
	elif _city.unrest < UNREST_MOVE_IN_BELOW:
		population = mini(capacity, population + homes * MOVE_IN_PER_HOME)
	_city.population = population
	_city.peak_population = maxi(_city.peak_population, population)


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

	for building in _grid.all_buildings:
		var def := building.def
		if def.is_road or building == _grid.town_hall:
			continue
		upkeep += UPKEEP_PER_BUILDING
		building.fuelled = true
		building.ran_today = false
		building.food_made = 0
		building.coal_made = 0
		building.crowns_made = 0
		if building.broken:
			# Produces nothing and burns no Coal until repaired.
			broken += 1
			continue
		if not building.road_access:
			continue
		if def.coal_per_day <= 0:
			# Needs no Coal (Coal Pit, Tea Garden): always runs.
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
		if coal_pool >= machine.def.coal_per_day:
			coal_pool -= machine.def.coal_per_day
			_produce(machine)
			food_made += machine.food_made
			crowns_made += machine.crowns_made
		else:
			machine.fuelled = false
			stopped_machines += 1

	@warning_ignore("integer_division")
	var tax := _city.population / CITIZENS_PER_TAX_CROWN
	var food_needed := _city.population * FOOD_PER_CITIZEN
	var food_available := _city.food + food_made

	# Crowns may go into debt; Food and Coal stop at zero.
	_city.crowns += crowns_made + tax - upkeep
	_city.food = maxi(0, food_available - food_needed)
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


## How fully staffed a building is, from 0 to 1. Buildings that need no
## workers always count as fully staffed.
func _staffing(building: Building) -> float:
	if building.def.workers <= 0:
		return 1.0
	return float(building.staff) / building.def.workers


## Add up everything that went wrong (and right) today and move the Unrest
## meter. Runs last, so it sees today's shortages and smog.
func _update_unrest() -> void:
	# Each connected Tea Garden calms Tenements within its reach.
	var calm_areas: Array[Rect2i] = []
	for building in _grid.all_buildings:
		if building.def.calming and building.road_access:
			calm_areas.append(building.footprint_rect().grow(building.def.effect_range))

	var homes := 0
	var smoggy_homes := 0
	var calmed_homes := 0
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

	var idle_workers := _city.workers_total - _city.workers_employed
	var causes := PackedStringArray()
	var change := 0.0
	change += _cause(causes, "Hunger", UNREST_HUNGER * _share(_city.hungry_citizens, _city.population))
	change += _cause(causes, "Cold homes", UNREST_COLD * _share(_city.cold_homes, homes))
	change += _cause(causes, "Smoggy homes", UNREST_SMOG * _share(smoggy_homes, homes))
	change += _cause(causes, "Idle workers", UNREST_IDLE * _share(idle_workers, _city.workers_total))
	change += _cause(causes, "Broken buildings",
			minf(UNREST_BROKEN_MAX, UNREST_PER_BROKEN * _city.broken_buildings))
	if _city.crowns < 0:
		change += _cause(causes, "Debt", UNREST_DEBT)
	change += _cause(causes, "Tea Gardens", -UNREST_TEA_GARDEN * _share(calmed_homes, homes))
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
