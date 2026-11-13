class_name StatsPanel
extends PanelContainer
## The statistics screen: a line graph for each of the city's main figures
## over the days on record. Opened and closed with G or the Stats button.

const TITLES: Dictionary[StringName, String] = {
	&"population": "Citizens",
	&"unrest": "Unrest",
	&"crowns": "Crowns",
	&"coal": "Coal",
	&"food": "Food",
	&"water": "Water",
	&"goods": "Goods",
	&"steam": "Steam",
}
const COLORS: Dictionary[StringName, Color] = {
	&"population": Color(0.95, 0.9, 0.75),
	&"unrest": Color(1.0, 0.45, 0.4),
	&"crowns": Color(0.95, 0.8, 0.3),
	&"coal": Color(0.7, 0.7, 0.75),
	&"food": Color(0.55, 0.85, 0.45),
	&"water": Color(0.45, 0.7, 1.0),
	&"goods": Color(0.9, 0.6, 0.85),
	&"steam": Color(0.85, 0.85, 0.95),
}
## The city tier from which each later resource is worth showing.
const FROM_TIER: Dictionary[StringName, int] = {
	&"water": CitySim.WATER_TIER,
	&"goods": CitySim.GOODS_TIER,
	&"steam": CitySim.STEAM_TIER,
}

var _history: CityHistory
var _city: CityState
var _heading: Label
var _graphs: Dictionary[StringName, LineGraph] = {}


func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_heading = Label.new()
	column.add_child(_heading)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	for series in CityHistory.SERIES:
		var graph := LineGraph.new()
		graph.title = TITLES[series]
		graph.line_color = COLORS[series]
		if series == &"unrest":
			graph.fixed_max = 100.0
		grid.add_child(graph)
		_graphs[series] = graph
	hide()


## Called once by the HUD.
func bind(history: CityHistory, city: CityState) -> void:
	_history = history
	_city = city
	_history.updated.connect(_refresh)


## Open the screen, or close it if it is open.
func toggle() -> void:
	visible = not visible
	_refresh()


func _refresh() -> void:
	if not visible or _history == null:
		return
	var days := _history.days()
	_heading.text = "City records: the last %d %s        G: close" % [
			days, "day" if days == 1 else "days"]
	for series in CityHistory.SERIES:
		var graph := _graphs[series]
		graph.visible = _city.tier >= FROM_TIER.get(series, 0)
		graph.set_values(_history.values(series))
