class_name AdvisorPanel
extends PanelContainer
## The advisor: a short list of what most needs the player's attention, each
## with what to do about it. Clicking a line that concerns a building moves
## the camera there. Hidden while there is nothing to say.

## Emitted when a line about a building is clicked: where to look.
signal jump_requested(world_position: Vector3)

## Lines shown at once; the list is ordered most urgent first.
const MAX_LINES := 6
## Seconds between checks. The advice reads live state, so it also notices
## what the player builds between days.
const REFRESH_SECONDS := 1.0
## Share of workers without a job above which the advisor mentions it.
const IDLE_SHARE_WORTH_MENTIONING := 0.2
## How many days ahead the advisor warns of winter and summer.
const SEASON_WARNING_DAYS := 4

var _grid: CityGrid
var _city: CityState
var _column: VBoxContainer
## What the list currently shows, to avoid rebuilding it when nothing changed.
var _shown: String = ""


func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 2)
	margin.add_child(_column)
	var timer := Timer.new()
	timer.wait_time = REFRESH_SECONDS
	timer.autostart = true
	timer.timeout.connect(refresh)
	add_child(timer)
	hide()


## Called once by the HUD.
func bind(grid: CityGrid, city: CityState) -> void:
	_grid = grid
	_city = city
	refresh()


func refresh() -> void:
	if _grid == null:
		return
	var advice := _gather()
	if advice.size() > MAX_LINES:
		advice.resize(MAX_LINES)
	var summary := ""
	for item: Array in advice:
		summary += str(item[0]) + "\n"
	if summary == _shown:
		return
	_shown = summary
	for child in _column.get_children():
		child.queue_free()
	visible = not advice.is_empty()
	if advice.is_empty():
		return
	var heading := Label.new()
	heading.text = "Advisor"
	heading.modulate = Color(1.0, 0.85, 0.45)
	_column.add_child(heading)
	for item: Array in advice:
		var text: String = item[0]
		var target: Building = item[1]
		var line := Button.new()
		line.flat = true
		line.alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.focus_mode = Control.FOCUS_NONE
		line.text = text
		if target != null:
			line.tooltip_text = "Click to look at it"
			line.pressed.connect(_jump_to.bind(target))
		else:
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_column.add_child(line)
	# Shrink back to fit a shorter list.
	size = Vector2.ZERO


func _jump_to(target: Building) -> void:
	if is_instance_valid(target):
		jump_requested.emit(target.global_position)


## Everything worth saying, most urgent first. Each item is a line of text
## and the building it is about (null for city-wide advice).
func _gather() -> Array:
	var advice: Array = []
	var city := _city

	# A warning in the last days before a hard season.
	if city.tier >= Seasons.FROM_TIER:
		var days_left := Seasons.days_until_next(city.day)
		var next := Seasons.next_after(city.day)
		if days_left <= SEASON_WARNING_DAYS and next == Seasons.Season.WINTER:
			advice.append(["Winter in %s: stock Food and Coal, add Warehouses." % _count(
					days_left, "day", "days"), null])
		elif days_left <= SEASON_WARNING_DAYS and next == Seasons.Season.SUMMER:
			advice.append(["Summer in %s: citizens will need more Water." % _count(
					days_left, "day", "days"), null])
	if city.days_at_max_unrest > 0:
		advice.append(["Unrest is at 100! Fix the causes in the Unrest tooltip, fast.", null])
	if city.crowns < 0:
		advice.append(["In debt: switch off or demolish what you can spare.", null])
	if city.hungry_citizens > 0:
		advice.append(["Citizens are hungry: build Glasshouses.", null])
	if city.thirsty_citizens > 0:
		advice.append(["Citizens are thirsty: build Pump Stations.", null])
	if city.cold_homes > 0 or city.stopped_machines > 0:
		advice.append(["Coal ran out: build Coal Pits, or switch off a Brassworks.", null])
	if city.citizens_without_goods > 0:
		advice.append(["Townhouses lack Goods: build Workshops.", null])
	if city.unpowered_buildings > 0:
		advice.append(["Buildings stand idle without Steam: build Power Stations.", null])

	# Problems with particular buildings, grouped by kind.
	var cut_off: Dictionary[BuildingDef, Array] = {}
	var broken: Dictionary[BuildingDef, Array] = {}
	var unstaffed: Dictionary[BuildingDef, Array] = {}
	var smoggy_homes: Array = []
	for building in _grid.all_buildings:
		var def := building.def
		if def.is_road or building == _grid.town_hall:
			continue
		if not building.road_access:
			_group(cut_off, building)
		elif building.broken:
			_group(broken, building)
		elif def.workers > 0 and building.staff == 0 and not building.paused and city.population > 0:
			_group(unstaffed, building)
		if def.housing > 0 and building.smoggy:
			smoggy_homes.append(building)
	_advise_groups(advice, cut_off, "has no road to the Town Hall", "have no road to the Town Hall")
	_advise_groups(advice, broken, "is broken: repair it (F)", "are broken: repair them (F)")
	_advise_groups(advice, unstaffed, "has no workers: build homes", "have no workers: build homes")
	if not smoggy_homes.is_empty():
		advice.append(["%s in smog: add a Tea Garden or move the smoke away." % _count(
				smoggy_homes.size(), "home is", "homes are"), smoggy_homes[0]])

	if city.workers_total > 0:
		var idle := city.workers_total - city.workers_employed
		if float(idle) / city.workers_total > IDLE_SHARE_WORTH_MENTIONING:
			advice.append(["%s no job: build a workplace." % _count(idle, "worker has", "workers have"), null])
	for stock: Array in [["Coal", city.coal], ["Food", city.food], ["Water", city.water],
			["Goods", city.goods], ["Steam", city.steam]]:
		var amount: int = stock[1]
		if amount >= city.storage_capacity and city.storage_capacity > 0:
			advice.append(["%s store is full: build a Warehouse, or the surplus is lost." % stock[0], null])
	if city.population > 0 and city.population >= city.housing_capacity \
			and city.unrest < CitySim.UNREST_MOVE_IN_BELOW:
		advice.append(["Every home is full: build housing to grow.", null])
	return advice


func _group(groups: Dictionary[BuildingDef, Array], building: Building) -> void:
	if not groups.has(building.def):
		groups[building.def] = []
	groups[building.def].append(building)


## One line per kind of building in `groups`, pointing at the first of them.
func _advise_groups(advice: Array, groups: Dictionary[BuildingDef, Array],
		one: String, many: String) -> void:
	for def: BuildingDef in groups:
		var buildings: Array = groups[def]
		if buildings.size() == 1:
			advice.append(["%s %s." % [def.display_name, one], buildings[0]])
		else:
			advice.append(["%d x %s %s." % [buildings.size(), def.display_name, many], buildings[0]])


func _count(amount: int, one: String, many: String) -> String:
	return "%d %s" % [amount, one if amount == 1 else many]
