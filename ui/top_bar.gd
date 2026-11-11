class_name TopBar
extends PanelContainer
## Strip along the top of the screen: the day, the pause and speed buttons, and
## the city's stockpiles.

var _clock: GameClock
var _row: HBoxContainer
var _day_label: Label
var _day_progress: ProgressBar
var _pause_button: Button
var _speed_button: Button
var _city: CityState
var _crowns_label: Label
var _coal_label: Label
var _food_label: Label
var _population_label: Label
var _workers_label: Label


func _ready() -> void:
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 12)
	add_child(_row)

	_day_label = Label.new()
	_day_label.custom_minimum_size = Vector2(70.0, 0.0)
	_row.add_child(_day_label)

	_day_progress = ProgressBar.new()
	_day_progress.custom_minimum_size = Vector2(120.0, 12.0)
	_day_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_day_progress.max_value = 1.0
	_day_progress.step = 0.001
	_day_progress.show_percentage = false
	_row.add_child(_day_progress)

	_pause_button = _make_button()
	_speed_button = _make_button()

	_row.add_child(VSeparator.new())
	_crowns_label = _make_stat_label()
	_coal_label = _make_stat_label()
	_food_label = _make_stat_label()
	_population_label = _make_stat_label()
	_population_label.tooltip_text = "Citizens / room in connected Tenements"
	_workers_label = _make_stat_label()
	_workers_label.tooltip_text = "Workers with a job / all workers (half the population)"


## Called once by Main. The labels follow the city's stockpiles.
func bind_city(city: CityState) -> void:
	_city = city
	city.changed.connect(_refresh_city)
	_refresh_city()


func _refresh_city() -> void:
	# The bracketed number is the change over the last day.
	_crowns_label.text = "Crowns: %d (%+d)" % [_city.crowns, _city.crowns_change]
	_coal_label.text = "Coal: %d (%+d)" % [_city.coal, _city.coal_change]
	_food_label.text = "Food: %d (%+d)" % [_city.food, _city.food_change]
	_population_label.text = "Population: %d / %d" % [_city.population, _city.housing_capacity]
	_workers_label.text = "Workers: %d / %d" % [_city.workers_employed, _city.workers_total]
	# Debt is the one stockpile that can go below zero; make it obvious.
	_crowns_label.modulate = Color(1.0, 0.45, 0.4) if _city.crowns < 0 else Color.WHITE


func _make_stat_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(110.0, 0.0)
	# Labels ignore the mouse by default, which would also suppress tooltips.
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	_row.add_child(label)
	return label


## Called once by Main. The buttons drive the clock, and the clock drives the
## labels.
func bind_clock(clock: GameClock) -> void:
	_clock = clock
	_pause_button.pressed.connect(clock.toggle_pause)
	_speed_button.pressed.connect(clock.toggle_speed)
	clock.state_changed.connect(_refresh)
	clock.day_ended.connect(func(_day: int) -> void: _refresh())
	_refresh()


func _process(_delta: float) -> void:
	if _clock != null:
		_day_progress.value = _clock.day_progress()


func _refresh() -> void:
	_day_label.text = "Day %d" % _clock.day
	_pause_button.text = "Resume (Space)" if _clock.paused else "Pause (Space)"
	_speed_button.text = "Speed: %dx (Tab)" % _clock.speed


func _make_button() -> Button:
	var button := Button.new()
	# Keep keyboard focus off the buttons, so Space and Tab stay game keys.
	button.focus_mode = Control.FOCUS_NONE
	_row.add_child(button)
	return button
