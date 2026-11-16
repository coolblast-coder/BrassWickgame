class_name ScenarioPanel
extends PanelContainer
## Shows the goal of the scenario in play and how far along it is. Hidden in
## free play, and once the scenario has been won or lost.

const WIDTH := 300.0

var _grid: CityGrid
var _city: CityState
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = WIDTH
	_label.modulate = Color(1.0, 0.9, 0.65)
	margin.add_child(_label)
	hide()


## Called once by the HUD.
func bind(grid: CityGrid, city: CityState) -> void:
	_grid = grid
	_city = city
	_city.changed.connect(refresh)
	refresh()


func refresh() -> void:
	visible = GameRules.has_goal() and not GameRules.scenario_settled
	if visible:
		_label.text = "%s\n%s\n%s" % [
				GameRules.scenario_name(), GameRules.goal_text(),
				GameRules.progress_text(_city, _grid)]
