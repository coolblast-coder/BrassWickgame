class_name Tutorial
extends RefCounted
## The guided first game: a list of tasks shown one at a time, each done
## when the city shows that it has been. It runs only in the "First Steps"
## scenario. Main checks the current task about once a second.

## The tasks, in order: a short name, then what to do and why.
const TASKS: Array[Array] = [
	["Lay a road",
		"Open Roads (key 1), pick Road, and drag a road a few tiles out from the Town Hall. "
		+ "A building only works while a road touches it and leads back to the Town Hall."],
	["Build homes",
		"Open Housing (key 2) and place two Tenements beside your road. "
		+ "Citizens move in a few a day. Half of them will work."],
	["Grow food",
		"Open Food & Coal (key 3) and place a Glasshouse on the road. "
		+ "Every citizen eats each day; the darker soil by the river grows more."],
	["Dig coal",
		"Place a Coal Pit from the same menu, a little away from the homes: it smokes. "
		+ "Homes need Coal for heat, and so does the Glasshouse."],
	["Let the city grow",
		"Wait until 20 citizens have moved in. The pause and speed buttons are in the top bar. "
		+ "New buildings take a day or two to finish."],
	["Read the city",
		"Press the overlay key (O) to see where the smog lies; press it again for the other views. "
		+ "Hover the icons in the top bar to see what each number is."],
	["Earn Crowns",
		"Open Industry (key 4) and place a Market. Its workers bring in Crowns every day, "
		+ "on top of the taxes the citizens pay."],
	["Store for hard times",
		"Place a Warehouse from Food & Coal. The city can only keep so much of each thing; "
		+ "a Warehouse makes room for more, which winter will need."],
	["Become a Town",
		"Keep adding homes and food until 100 citizens live here. "
		+ "The Advisor on the right says what is going wrong; click a line to go there."],
	["Find water",
		"A Town's citizens need Water. Place a Pump Station from Food & Coal, by the river if you can, "
		+ "and see that it gets workers."],
	["Get through the winter",
		"From now the seasons matter. Winter doubles the Coal homes burn and cuts what Glasshouses grow. "
		+ "Stock up, and keep the city going until spring of the second year, on day 49."],
]

## The task in hand, as an index into TASKS; TASKS.size() when all are done.
static var step: int = 0
## Set by Main once the player has looked at an overlay.
static var overlay_seen: bool = false


static func reset() -> void:
	step = 0
	overlay_seen = false


static func finished() -> bool:
	return step >= TASKS.size()


## The task in hand, for the HUD: its number and name, then what to do.
static func describe() -> String:
	if finished():
		return "Every task is done."
	return "Task %d of %d: %s\n%s" % [step + 1, TASKS.size(), TASKS[step][0], TASKS[step][1]]


## If the task in hand has been done, move on to the next. Returns the name
## of the task just finished, or an empty string if nothing changed.
static func advance(city: CityState, grid: CityGrid) -> String:
	if finished() or not _done(step, city, grid):
		return ""
	var finished_name: String = TASKS[step][0]
	step += 1
	return finished_name


static func _done(task: int, city: CityState, grid: CityGrid) -> bool:
	match task:
		0:
			return grid.connected_road_cells().size() >= 4
		1:
			return _count(grid, func(b: Building) -> bool: return b.def.housing > 0) >= 2
		2:
			return _count(grid, func(b: Building) -> bool: return b.def.food_output > 0) >= 1
		3:
			return _count(grid, func(b: Building) -> bool: return b.def.coal_output > 0) >= 1
		4:
			return city.population >= 20
		5:
			return overlay_seen
		6:
			return _count(grid, func(b: Building) -> bool: return b.def.crowns_output > 0) >= 1
		7:
			return _count(grid, func(b: Building) -> bool: return b.def.storage > 0) >= 1
		8:
			return city.tier >= 1
		9:
			return _count(grid, _is_working_pump) >= 1
		10:
			return city.day >= Seasons.DAYS_PER_SEASON * 4 + 1
	return true


static func _is_working_pump(building: Building) -> bool:
	return building.def.water_output > 0 and building.is_usable() and building.staff > 0


static func _count(grid: CityGrid, test: Callable) -> int:
	var count := 0
	for building in grid.all_buildings:
		if test.call(building):
			count += 1
	return count
