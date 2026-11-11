class_name TopBar
extends PanelContainer
## Strip along the top of the screen: the day, the pause and speed buttons, the
## city's stockpiles and the Unrest meter. Texts are kept short so the whole
## row fits the 1152-pixel base width; tooltips carry the detail.

const DEBT_COLOR := Color(1.0, 0.45, 0.4)
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
var _population_label: Label
var _workers_label: Label
var _unrest_label: Label


func _ready() -> void:
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 12)
	add_child(_row)

	_day_label = Label.new()
	_day_label.custom_minimum_size = Vector2(64.0, 0.0)
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
	_crowns_label = _make_stat_label("Crowns, and the change over the last day")
	_coal_label = _make_stat_label("Coal, and the change over the last day")
	_food_label = _make_stat_label("Food, and the change over the last day")
	_population_label = _make_stat_label("Citizens / room in connected Tenements")
	_workers_label = _make_stat_label("Workers with a job / all workers (half the population)")
	_unrest_label = _make_stat_label("")


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
	_day_label.text = "Day %d" % _clock.day
	_pause_button.text = "Resume" if _clock.paused else "Pause"
	_speed_button.text = "%dx" % _clock.speed


func _refresh_city() -> void:
	# The bracketed number is the change over the last day.
	_crowns_label.text = "Crowns %d (%+d)" % [_city.crowns, _city.crowns_change]
	_coal_label.text = "Coal %d (%+d)" % [_city.coal, _city.coal_change]
	_food_label.text = "Food %d (%+d)" % [_city.food, _city.food_change]
	_population_label.text = "Pop %d/%d" % [_city.population, _city.housing_capacity]
	_workers_label.text = "Workers %d/%d" % [_city.workers_employed, _city.workers_total]
	# Debt is the one stockpile that can go below zero; make it obvious.
	_crowns_label.modulate = DEBT_COLOR if _city.crowns < 0 else Color.WHITE

	_unrest_label.text = "Unrest %d" % roundi(_city.unrest)
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


func _make_stat_label(tooltip: String) -> Label:
	var label := Label.new()
	label.tooltip_text = tooltip
	# Labels ignore the mouse by default, which would also suppress tooltips.
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	_row.add_child(label)
	return label


func _make_button(tooltip: String) -> Button:
	var button := Button.new()
	button.tooltip_text = tooltip
	# Keep keyboard focus off the buttons, so Space and Tab stay game keys.
	button.focus_mode = Control.FOCUS_NONE
	_row.add_child(button)
	return button
