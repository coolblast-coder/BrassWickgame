class_name GameMenu
extends PanelContainer
## The in-game menu, opened with Esc. On the left: resume, the save slots,
## back to the title screen, quit. On the right: the settings (with the
## button that opens the list of keys) and the terms the city is played on
## (its scenario, difficulty, twists and map seed). The game is paused while
## it is open.

## The menu was opened or closed.
signal toggled(open: bool)
signal save_pressed(slot: String)
signal load_pressed(slot: String)
signal main_menu_pressed
## The keys were changed in the settings.
signal controls_changed

var _seed_label: Label
var _terms_label: Label
var _map_seed: int = 0
## Per slot: its line of description and its Load button.
var _slot_labels: Dictionary[String, Label] = {}
var _load_buttons: Dictionary[String, Button] = {}


func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	margin.add_child(columns)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	columns.add_child(column)
	var side_column := VBoxContainer.new()
	side_column.add_theme_constant_override("separation", 8)
	columns.add_child(side_column)

	var heading := Label.new()
	heading.text = "Brasswick"
	heading.add_theme_font_size_override("font_size", 24)
	column.add_child(heading)
	_add_button(column, "Resume  (Esc)", close)
	column.add_child(HSeparator.new())

	# One row per save slot. The game writes the autosave itself, so that
	# row can only be loaded.
	for slot in SaveGame.SLOTS:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 13)
		label.custom_minimum_size.x = 420.0
		column.add_child(label)
		_slot_labels[slot] = label
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)
		if slot != SaveGame.AUTOSAVE:
			_add_small_button(row, "Save here", func() -> void: save_pressed.emit(slot))
		_load_buttons[slot] = _add_small_button(row, "Load", func() -> void: load_pressed.emit(slot))
	var slots_note := Label.new()
	slots_note.text = "F9 saves to the slot last used; F10 loads the newest save."
	slots_note.modulate = Color(1.0, 1.0, 1.0, 0.6)
	slots_note.add_theme_font_size_override("font_size", 13)
	column.add_child(slots_note)
	column.add_child(HSeparator.new())
	_add_button(column, "Main menu", func() -> void: main_menu_pressed.emit())
	_add_button(column, "Quit game", func() -> void: get_tree().quit())
	var note := Label.new()
	note.text = "Leaving does not save."
	note.modulate = Color(1.0, 1.0, 1.0, 0.6)
	column.add_child(note)

	var settings := SettingsPanel.new()
	settings.controls_changed.connect(func() -> void: controls_changed.emit())
	side_column.add_child(settings)
	side_column.add_child(HSeparator.new())
	_terms_label = Label.new()
	side_column.add_child(_terms_label)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 10)
	side_column.add_child(seed_row)
	_seed_label = Label.new()
	_seed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed_label)
	var copy := Button.new()
	copy.text = "Copy"
	copy.focus_mode = Control.FOCUS_NONE
	copy.tooltip_text = "Copy the seed, to start this same map again from the title screen."
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(str(_map_seed)))
	seed_row.add_child(copy)
	side_column.add_child(HSeparator.new())
	var keys := Label.new()
	keys.text = "Controls... above lists every key, and lets you change them."
	keys.modulate = Color(1.0, 1.0, 1.0, 0.6)
	keys.add_theme_font_size_override("font_size", 13)
	side_column.add_child(keys)
	hide()


## Show the terms this city is played on.
func set_terms(difficulty: String) -> void:
	_terms_label.text = "%s   -   Difficulty: %s" % [GameRules.scenario_name(), difficulty]
	var twists := GameRules.twist_names()
	if not twists.is_empty():
		_terms_label.text += "\nTwists: %s" % ", ".join(twists)


## Show which map this city is built on.
func set_map_seed(map_seed: int) -> void:
	_map_seed = map_seed
	_seed_label.text = "Map seed: %d" % map_seed


## Bring the slot rows up to date with the files on disk.
func refresh_slots() -> void:
	for slot in SaveGame.SLOTS:
		_slot_labels[slot].text = SaveGame.describe(slot)
		_load_buttons[slot].disabled = not SaveGame.is_loadable(slot)


func open() -> void:
	if visible:
		return
	refresh_slots()
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
	button.custom_minimum_size = Vector2(300.0, 34.0)
	button.pressed.connect(action)
	column.add_child(button)


func _add_small_button(row: HBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(110.0, 28.0)
	button.pressed.connect(action)
	row.add_child(button)
	return button
