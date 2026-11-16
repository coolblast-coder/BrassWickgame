extends Control
## The title screen. On the left: start a new city (choosing its map seed,
## scenario and difficulty), carry on with the saved one, look at records
## and achievements, or quit. On the right: the volume sliders and the
## twists for the next city.

const GAME_SCENE := "res://main/main.tscn"
const BACKGROUND := Color(0.13, 0.11, 0.1)
const BRASS := Color(0.86, 0.68, 0.32)

var _continue_button: Button
var _seed_box: LineEdit
var _difficulty_note: Label
var _scenario_note: Label
var _records: PanelContainer


func _ready() -> void:
	GameSettings.ensure_ready()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	# Two columns: the city on the left, the sound settings on the right, so
	# everything fits the height of the window.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 56)
	centre.add_child(columns)
	columns.add_child(column)
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 8)
	columns.add_child(side)

	var title := Label.new()
	title.text = "BRASSWICK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 50)
	title.add_theme_color_override("font_color", BRASS)
	column.add_child(title)
	var tagline := Label.new()
	tagline.text = "Coal, brass and a restless city"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.modulate = Color(1.0, 1.0, 1.0, 0.7)
	column.add_child(tagline)
	column.add_child(_spacer(8.0))

	_add_button(column, "New city", _on_new_city)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 10)
	column.add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "Map seed"
	seed_row.add_child(seed_label)
	_seed_box = LineEdit.new()
	_seed_box.placeholder_text = "leave empty for a random map"
	_seed_box.custom_minimum_size.x = 236.0
	_seed_box.max_length = 24
	_seed_box.tooltip_text = "The same seed always gives the same map.\nA number or a word both work. The seed of a city is shown in its Esc menu."
	if SaveGame.chosen_map_seed >= 0:
		_seed_box.text = str(SaveGame.chosen_map_seed)
	_seed_box.text_submitted.connect(func(_text: String) -> void: _on_new_city())
	seed_row.add_child(_seed_box)
	var scenario_row := HBoxContainer.new()
	scenario_row.add_theme_constant_override("separation", 10)
	column.add_child(scenario_row)
	var scenario_label := Label.new()
	scenario_label.text = "Scenario"
	scenario_label.custom_minimum_size.x = 74.0
	scenario_row.add_child(scenario_label)
	var scenario_box := OptionButton.new()
	# Offered in menu order, each carrying its index into the scenario list.
	for index in GameRules.MENU_ORDER:
		scenario_box.add_item(GameRules.SCENARIOS[index][0], index)
	scenario_box.custom_minimum_size.x = 236.0
	scenario_box.select(maxi(0, GameRules.MENU_ORDER.find(GameRules.scenario)))
	scenario_box.item_selected.connect(
			func(row: int) -> void: _on_scenario_chosen(scenario_box.get_item_id(row)))
	scenario_row.add_child(scenario_box)
	_scenario_note = Label.new()
	_scenario_note.custom_minimum_size.x = 320.0
	_scenario_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scenario_note.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_scenario_note.add_theme_font_size_override("font_size", 13)
	column.add_child(_scenario_note)
	_on_scenario_chosen(GameRules.scenario)
	var difficulty_row := HBoxContainer.new()
	difficulty_row.add_theme_constant_override("separation", 10)
	column.add_child(difficulty_row)
	var difficulty_label := Label.new()
	difficulty_label.text = "Difficulty"
	difficulty_row.add_child(difficulty_label)
	var difficulty_box := OptionButton.new()
	for level in GameRules.DIFFICULTY_NAMES:
		difficulty_box.add_item(level)
	difficulty_box.custom_minimum_size.x = 236.0
	difficulty_box.select(GameRules.difficulty)
	difficulty_box.item_selected.connect(_on_difficulty_chosen)
	difficulty_row.add_child(difficulty_box)
	_difficulty_note = Label.new()
	_difficulty_note.custom_minimum_size.x = 320.0
	_difficulty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty_note.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_difficulty_note.add_theme_font_size_override("font_size", 13)
	column.add_child(_difficulty_note)
	_on_difficulty_chosen(GameRules.difficulty)
	_continue_button = _add_button(column, "Load a saved city", _on_continue)
	_continue_button.disabled = not SaveGame.any_exists()
	if _continue_button.disabled:
		_continue_button.tooltip_text = "No saved city yet. Press F9 in the game to save."
	_add_button(column, "Records", _show_records)
	_add_button(column, "Achievements", _show_achievements)
	_add_button(column, "Quit", func() -> void: get_tree().quit())

	var settings_heading := Label.new()
	settings_heading.text = "Sound"
	settings_heading.modulate = BRASS
	side.add_child(settings_heading)
	side.add_child(SettingsPanel.new())
	side.add_child(_spacer(10.0))
	var twists_heading := Label.new()
	twists_heading.text = "Twists for the next city"
	twists_heading.modulate = BRASS
	side.add_child(twists_heading)
	for entry: Array in GameRules.TWISTS:
		var twist: StringName = entry[0]
		var box := CheckBox.new()
		box.text = "%s: %s" % [entry[1], entry[2]]
		box.add_theme_font_size_override("font_size", 13)
		box.button_pressed = GameRules.has_twist(twist)
		box.toggled.connect(func(on: bool) -> void: GameRules.set_twist(twist, on))
		side.add_child(box)
	_start_music()


## The same piece that plays in the game, so the title screen is not silent.
func _start_music() -> void:
	var path := "res://audio/music_loop.wav"
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = GameSettings.MUSIC_BUS
	player.volume_db = SoundPlayer.MUSIC_DB
	add_child(player)
	player.play()


## Show the player's best cities, in a panel over the title screen.
func _show_records() -> void:
	var list := _open_panel("Records")
	var records := ScoreBoard.all()
	if records.is_empty():
		_add_line(list, "No city has ended yet. A city is entered here when it ends\nin the Great Walkout, or when its scenario is won or lost.")
	for i in mini(records.size(), 12):
		_add_line(list, "%2d.  %s" % [i + 1, ScoreBoard.describe(records[i])])
	_add_close(list)


## Show every achievement and whether it has been earned.
func _show_achievements() -> void:
	var list := _open_panel("Achievements: %d of %d" % [
			Achievements.earned_count(), Achievements.LIST.size()])
	for entry: Array in Achievements.LIST:
		var earned := Achievements.is_earned(entry[0])
		var line := _add_line(list, "%s  %s: %s" % ["[x]" if earned else "[  ]", entry[1], entry[2]])
		line.modulate = BRASS if earned else Color(1.0, 1.0, 1.0, 0.6)
	_add_close(list)


## A panel over the middle of the title screen, with a heading. Returns the
## column to add lines to. Only one such panel is open at a time.
func _open_panel(heading_text: String) -> VBoxContainer:
	_hide_records()
	_records = PanelContainer.new()
	_records.set_anchors_preset(Control.PRESET_CENTER)
	_records.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_records.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_records)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_records.add_child(margin)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	margin.add_child(list)
	var heading := Label.new()
	heading.text = heading_text
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", BRASS)
	list.add_child(heading)
	return list


func _add_line(list: VBoxContainer, text: String) -> Label:
	var line := Label.new()
	line.text = text
	line.add_theme_font_size_override("font_size", 14)
	list.add_child(line)
	return line


func _add_close(list: VBoxContainer) -> void:
	var close := Button.new()
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_hide_records)
	list.add_child(close)


func _hide_records() -> void:
	if _records != null:
		_records.queue_free()
		_records = null


func _on_scenario_chosen(index: int) -> void:
	GameRules.scenario = index
	_scenario_note.text = GameRules.goal_text()
	if GameRules.is_tutorial():
		_scenario_note.text += " Start here if the game is new to you."
	elif GameRules.scenario_seed() >= 0:
		_scenario_note.text += " Played on its own map unless you type a seed."


func _on_difficulty_chosen(index: int) -> void:
	GameRules.difficulty = index as GameRules.Difficulty
	_difficulty_note.text = GameRules.DIFFICULTY_NOTES[index]


func _on_new_city() -> void:
	SaveGame.pending = {}
	SaveGame.chosen_map_seed = SaveGame.seed_from_text(_seed_box.text)
	get_tree().change_scene_to_file(GAME_SCENE)


## Show the save slots, each with what it holds and a button to load it.
func _on_continue() -> void:
	var list := _open_panel("Load a saved city")
	for slot in SaveGame.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)
		var load_button := Button.new()
		load_button.text = "Load"
		load_button.custom_minimum_size.x = 80.0
		# Empty slots, and saves from an older version, cannot be loaded.
		load_button.disabled = not SaveGame.is_loadable(slot)
		load_button.pressed.connect(_load_slot.bind(slot))
		row.add_child(load_button)
		var line := Label.new()
		line.text = SaveGame.describe(slot)
		line.add_theme_font_size_override("font_size", 14)
		row.add_child(line)
	_add_close(list)


func _load_slot(slot: String) -> void:
	if SaveGame.load_from_disk(slot):
		get_tree().change_scene_to_file(GAME_SCENE)


func _add_button(column: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320.0, 38.0)
	button.pressed.connect(action)
	column.add_child(button)
	return button


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer
