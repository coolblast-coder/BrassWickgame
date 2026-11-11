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
const UPKEEP_PER_BUILDING := 2
## Food eaten per citizen per day.
const FOOD_PER_CITIZEN := 1

var _grid: CityGrid
var _city: CityState


func _init(grid: CityGrid, city: CityState) -> void:
	_grid = grid
	_city = city


func run_day() -> void:
	var crowns_before := _city.crowns
	var coal_before := _city.coal
	var food_before := _city.food
	_update_population()
	_assign_workers()
	_run_economy()
	_city.crowns_change = _city.crowns - crowns_before
	_city.coal_change = _city.coal - coal_before
	_city.food_change = _city.food - food_before
	_city.changed.emit()


## Citizens move into Tenements the road network reaches. If housing is lost
## (demolished or cut off), the citizens it held leave on the next day.
func _update_population() -> void:
	var capacity := 0
	var homes := 0
	for building in _grid.all_buildings:
		if building.def.housing > 0 and building.road_access:
			capacity += building.def.housing
			homes += 1
	_city.housing_capacity = capacity
	if _city.population > capacity:
		_city.population = capacity
	else:
		_city.population = mini(capacity, _city.population + homes * MOVE_IN_PER_HOME)


## Half the population works. Workers fill connected workplaces in the order
## the buildings were placed; later ones go short when workers run out.
func _assign_workers() -> void:
	@warning_ignore("integer_division")
	var total := _city.population / 2
	var available := total
	for building in _grid.all_buildings:
		building.staff = 0
		if building.def.workers > 0 and building.road_access:
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
	var homes: Array[Building] = []
	var machines: Array[Building] = []

	for building in _grid.all_buildings:
		var def := building.def
		if def.is_road or building == _grid.town_hall:
			continue
		upkeep += UPKEEP_PER_BUILDING
		building.fuelled = true
		if not building.road_access:
			continue
		if def.coal_per_day <= 0:
			# Needs no Coal (Coal Pit, Tea Garden): always runs.
			var staffing := _staffing(building)
			coal_pool += roundi(def.coal_output * staffing)
			food_made += roundi(def.food_output * staffing)
			crowns_made += roundi(def.crowns_output * staffing)
		elif def.housing > 0:
			homes.append(building)
		else:
			machines.append(building)

	var cold_homes := 0
	for home in homes:
		if coal_pool >= home.def.coal_per_day:
			coal_pool -= home.def.coal_per_day
		else:
			home.fuelled = false
			cold_homes += 1

	var stopped_machines := 0
	for machine in machines:
		if coal_pool >= machine.def.coal_per_day:
			coal_pool -= machine.def.coal_per_day
			var staffing := _staffing(machine)
			food_made += roundi(machine.def.food_output * staffing)
			crowns_made += roundi(machine.def.crowns_output * staffing)
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
	_city.hungry_citizens = maxi(0, food_needed - food_available)
	_city.cold_homes = cold_homes
	_city.stopped_machines = stopped_machines


## How fully staffed a building is, from 0 to 1. Buildings that need no
## workers always count as fully staffed.
func _staffing(building: Building) -> float:
	if building.def.workers <= 0:
		return 1.0
	return float(building.staff) / building.def.workers
