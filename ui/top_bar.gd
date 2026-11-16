class_name TopBar
extends PanelContainer
## Strip along the top of the screen: the day, the pause and speed buttons, the
## city's stockpiles and the Unrest meter. Each figure is an icon and a
## number, so the whole row fits the 1152-pixel base width; tooltips name
## the figure and carry the detail.

const DEBT_COLOR := Color(1.0, 0.45, 0.4)
## A stockpile that has no room left: anything more is being lost.
const FULL_COLOR := Color(1.0, 0.85, 0.45)
const UNREST_WARN_COLOR := Color(1.0, 0.75, 0.3)
const UNREST_DANGER_COLOR := Color(1.0, 0.45, 0.4)

var _clock: GameClock
var _city: CityState
var _row: HBoxContainer
var _day_label: Label
var _day_progress: ProgressBar
var _pause_button: Button
var _speed_button: Button
var _crowns_label: Label
var _coal_label: Label
var _food_label: Label
var _water_label: Label
var _goods_label: Label
var _steam_label: Label
var _storage_label: Label
## Each stat label's fixed tooltip, to which yesterday's ledger is added.
var _base_tooltips: Dictionary[Label, String] = {}
var _population_label: Label
var _workers_label: Label
var _unrest_label: Label


func _ready() -> void:
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 12)
	add_child(_row)

	_day_label = Label.new()
	_day_label.custom_minimum_size = Vector2(150.0, 0.0)
	_day_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_row.add_child(_day_label)

	_day_progress = ProgressBar.new()
	_day_progress.custom_minimum_size = Vector2(80.0, 12.0)
	_day_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_day_progress.max_value = 1.0
	_day_progress.step = 0.001
	_day_progress.show_percentage = false
	_row.add_child(_day_progress)

	_pause_button = _make_button("Pause or resume (Space)")
	_speed_button = _make_button("Switch between 1x and 3x speed (Tab)")

	_row.add_child(VSeparator.new())
	_crowns_label = _make_stat_label(&"crowns", "Crowns, and the change over the last day")
	_coal_label = _make_stat_label(&"coal", "Coal, and the change over the last day")
	_food_label = _make_stat_label(&"food", "Food, and the change over the last day")
	_water_label = _make_stat_label(&"water", "Water, and the change over the last day.\nCitizens drink 1 a day for every %d of them." % CitySim.CITIZENS_PER_WATER)
	_goods_label = _make_stat_label(&"goods", "Goods, and the change over the last day.\nTownhouse residents take 1 a day for every %d of them." % CitySim.CITIZENS_PER_GOODS)
	_steam_label = _make_stat_label(&"steam", "Steam, and the change over the last day.\nToday's output can be used from tomorrow.")
	for later: Label in [_water_label, _goods_label, _steam_label]:
		_set_stat_visible(later, false)
	_storage_label = _make_stat_label(&"store", "Storage: the most the city can keep of each resource.\nAnything above it at the end of the day is lost.\nA resource shown in yellow is full. Build Warehouses for more room.")
	_population_label = _make_stat_label(&"population", "Citizens / room in connected homes")
	_workers_label = _make_stat_label(&"workers", "Workers with a job / all workers (half the population)")
	_unrest_label = _make_stat_label(&"unrest", "")


## Called once by Main. The buttons drive the clock, and the clock drives the
## labels.
func bind_clock(clock: GameClock) -> void:
	_clock = clock
	_pause_button.pressed.connect(clock.toggle_pause)
	_speed_button.pressed.connect(clock.toggle_speed)
	clock.state_changed.connect(_refresh_clock)
	clock.day_ended.connect(func(_day: int) -> void: _refresh_clock())
	_refresh_clock()


## Called once by Main. The labels follow the city's stockpiles.
func bind_city(city: CityState) -> void:
	_city = city
	city.changed.connect(_refresh_city)
	_refresh_city()


func _process(_delta: float) -> void:
	if _clock != null:
		_day_progress.value = _clock.day_progress()


func _refresh_clock() -> void:
	var day := _clock.day
	_day_label.text = "Day %d  %s" % [day, Seasons.label(day)]
	var tooltip := "%s: %s" % [Seasons.NAMES[Seasons.of_day(day)], Seasons.EFFECTS[Seasons.of_day(day)]]
	var next := Seasons.next_after(day)
	tooltip += "\n%s in %d days: %s" % [Seasons.NAMES[next], Seasons.days_until_next(day), Seasons.EFFECTS[next]]
	tooltip += "\nThe brass arrow above the Town Hall shows the wind, which carries smog."
	if _city != null and _city.tier < Seasons.FROM_TIER:
		tooltip += "\n\nThe seasons have no effect until the city is a %s." % CityState.TIER_NAMES[Seasons.FROM_TIER]
	_day_label.tooltip_text = tooltip
	_pause_button.text = "Resume" if _clock.paused else "Pause"
	_speed_button.text = "%dx" % _clock.speed


func _refresh_city() -> void:
	# The bracketed number is the change over the last day.
	# Each figure is shown by its icon; hovering names it.
	_crowns_label.text = "%d (%+d)" % [_city.crowns, _city.crowns_change]
	_coal_label.text = "%d (%+d)" % [_city.coal, _city.coal_change]
	_food_label.text = "%d (%+d)" % [_city.food, _city.food_change]
	# Each later resource appears in the bar once the city needs it.
	_set_stat_visible(_water_label, _city.tier >= CitySim.WATER_TIER)
	_water_label.text = "%d (%+d)" % [_city.water, _city.water_change]
	_set_stat_visible(_goods_label, _city.tier >= CitySim.GOODS_TIER)
	_goods_label.text = "%d (%+d)" % [_city.goods, _city.goods_change]
	_set_stat_visible(_steam_label, _city.tier >= CitySim.STEAM_TIER)
	_steam_label.text = "%d (%+d)" % [_city.steam, _city.steam_change]
	_storage_label.text = "%d" % _city.storage_capacity
	_show_ledger(_crowns_label, &"crowns")
	_show_ledger(_coal_label, &"coal")
	_show_ledger(_food_label, &"food")
	_show_ledger(_water_label, &"water")
	_show_ledger(_goods_label, &"goods")
	_show_ledger(_steam_label, &"steam")
	_tint_if_full(_coal_label, _city.coal)
	_tint_if_full(_food_label, _city.food)
	_tint_if_full(_water_label, _city.water)
	_tint_if_full(_goods_label, _city.goods)
	_tint_if_full(_steam_label, _city.steam)
	_population_label.text = "%s  %d/%d" % [_city.tier_name(), _city.population, _city.housing_capacity]
	_workers_label.text = "%d/%d" % [_city.workers_employed, _city.workers_total]
	# Debt is the one stockpile that can go below zero; make it obvious.
	_crowns_label.modulate = DEBT_COLOR if _city.crowns < 0 else Color.WHITE

	_unrest_label.text = "%d" % roundi(_city.unrest)
	if _city.unrest > CitySim.UNREST_LEAVE_ABOVE:
		_unrest_label.modulate = UNREST_DANGER_COLOR
	elif _city.unrest >= CitySim.UNREST_MOVE_IN_BELOW:
		_unrest_label.modulate = UNREST_WARN_COLOR
	else:
		_unrest_label.modulate = Color.WHITE
	var tooltip := "Unrest, 0 to 100. Yesterday's causes:"
	if _city.unrest_causes.is_empty():
		tooltip += "\n(nothing yet)"
	else:
		tooltip += "\n" + "\n".join(_city.unrest_causes)
	_unrest_label.tooltip_text = tooltip


## Add yesterday's ledger for a stockpile to its label's tooltip.
func _show_ledger(label: Label, key: StringName) -> void:
	var lines: PackedStringArray = _city.ledger.get(key, PackedStringArray())
	var tooltip: String = _base_tooltips.get(label, "")
	if not lines.is_empty():
		tooltip += "\n\nYesterday:\n" + "\n".join(lines)
	label.tooltip_text = tooltip


func _tint_if_full(label: Label, amount: int) -> void:
	label.modulate = FULL_COLOR if amount >= _city.storage_capacity else Color.WHITE


## One figure of the bar: its icon, then its number. Returns the number's
## label; the pair sits in a box of its own, so both hide together.
func _make_stat_label(icon: StringName, tooltip: String) -> Label:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_row.add_child(box)
	var symbol := ResourceIcon.new(icon)
	symbol.tooltip_text = tooltip
	box.add_child(symbol)
	var label := Label.new()
	label.tooltip_text = tooltip
	_base_tooltips[label] = tooltip
	# Labels ignore the mouse by default, which would also suppress tooltips.
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(label)
	return label


## Show or hide a figure together with its icon.
func _set_stat_visible(label: Label, shown: bool) -> void:
	(label.get_parent() as Control).visible = shown


func _make_button(tooltip: String) -> Button:
	var button := Button.new()
	button.tooltip_text = tooltip
	# Keep keyboard focus off the buttons, so Space and Tab stay game keys.
	button.focus_mode = Control.FOCUS_NONE
	_row.add_child(button)
	return button
