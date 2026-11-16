class_name GameOverPanel
extends ColorRect
## The end screen, for the Great Walkout and for a scenario won or lost.
## Covers the whole window, so nothing behind it can be clicked. A walkout
## ends the game; after a scenario the player may carry on in free play.

signal restart_pressed
## "Keep playing" was pressed after a scenario ended.
signal continue_pressed
signal main_menu_pressed

const WALKOUT_TITLE := "The Great Walkout"

var _title: Label
var _message: Label
var _stats: Label
var _continue_button: Button


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.modulate = Color(1.0, 0.85, 0.45)
	column.add_child(_title)

	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(420.0, 0.0)
	column.add_child(_message)

	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_stats)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_continue_button = _add_button(buttons, "Keep playing", func() -> void: continue_pressed.emit())
	_add_button(buttons, "Restart", func() -> void: restart_pressed.emit())
	_add_button(buttons, "Main menu", func() -> void: main_menu_pressed.emit())

	hide()


## The Great Walkout: the game is over.
func show_result(peak_population: int, days_survived: int) -> void:
	_title.text = WALKOUT_TITLE
	_message.text = "Unrest held at 100 for %d days. The citizens have packed their bags, " % CitySim.WALKOUT_DAYS \
			+ "their grievances and, in several cases, your furniture."
	_continue_button.hide()
	_show_stats(peak_population, days_survived)
	show()


## A scenario has been won or lost. The city is still standing, so the
## player may keep playing it without a goal.
func show_scenario_result(title: String, message: String, peak_population: int, day: int) -> void:
	_title.text = title
	_message.text = message
	_continue_button.show()
	_show_stats(peak_population, day)
	show()


func _show_stats(peak_population: int, days: int) -> void:
	_stats.text = "Peak population: %d\nDays: %d\nDifficulty: %s" % [
			peak_population, days, GameRules.difficulty_name()]
	var twists := GameRules.twist_names()
	if not twists.is_empty():
		_stats.text += "\nTwists: %s" % ", ".join(twists)
	if not ScoreBoard.last_note.is_empty():
		_stats.text += "\n%s" % ScoreBoard.last_note


func _add_button(row: HBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)
	return button
