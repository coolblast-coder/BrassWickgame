class_name GameOverPanel
extends ColorRect
## The end screen. Covers the whole window, so nothing behind it can be
## clicked, and offers a restart.

signal restart_pressed

var _stats: Label


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

	var title := Label.new()
	title.text = "The Great Walkout"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(1.0, 0.85, 0.45)
	column.add_child(title)

	var message := Label.new()
	message.text = "Unrest held at 100 for %d days. The citizens have packed their bags, " % CitySim.WALKOUT_DAYS \
			+ "their grievances and, in several cases, your furniture."
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(420.0, 0.0)
	column.add_child(message)

	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_stats)

	var restart := Button.new()
	restart.text = "Restart"
	restart.focus_mode = Control.FOCUS_NONE
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	column.add_child(restart)

	hide()


func show_result(peak_population: int, days_survived: int) -> void:
	_stats.text = "Peak population: %d\nDays survived: %d" % [peak_population, days_survived]
	show()
