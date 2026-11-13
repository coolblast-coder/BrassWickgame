class_name GameMenu
extends PanelContainer
## The in-game menu, opened with Esc: resume, save, load, volume, back to the
## title screen, quit. The game is paused while it is open.

## The menu was opened or closed.
signal toggled(open: bool)
signal save_pressed
signal load_pressed
signal main_menu_pressed


func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = "Brasswick"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	column.add_child(heading)

	_add_button(column, "Resume  (Esc)", close)
	_add_button(column, "Save city  (F9)", func() -> void: save_pressed.emit())
	_add_button(column, "Load saved city  (F10)", func() -> void: load_pressed.emit())
	column.add_child(HSeparator.new())
	column.add_child(SettingsPanel.new())
	column.add_child(HSeparator.new())
	_add_button(column, "Main menu", func() -> void: main_menu_pressed.emit())
	_add_button(column, "Quit game", func() -> void: get_tree().quit())
	var keys := Label.new()
	keys.text = "\n".join([
		"1-5  build categories        Shift+number  pick a building",
		"R  rotate        X  demolish        Right click  cancel",
		"F  repair        P  switch a workplace off or on",
		"O  overlays        G  statistics        M  mute",
		"N  day and night cycle on or off",
		"Space  pause        Tab  speed",
		"WASD / arrows  move        Q E  turn        Wheel  zoom",
	])
	keys.modulate = Color(1.0, 1.0, 1.0, 0.75)
	keys.add_theme_font_size_override("font_size", 13)
	column.add_child(keys)
	var note := Label.new()
	note.text = "Leaving does not save: press F9 first."
	note.modulate = Color(1.0, 1.0, 1.0, 0.6)
	column.add_child(note)
	hide()


func open() -> void:
	if visible:
		return
	show()
	toggled.emit(true)


func close() -> void:
	if not visible:
		return
	hide()
	toggled.emit(false)


func _add_button(column: VBoxContainer, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(300.0, 36.0)
	button.pressed.connect(action)
	column.add_child(button)
