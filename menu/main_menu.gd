extends Control
## The title screen: start a new city, carry on with the saved one, set the
## volume, or quit.

const GAME_SCENE := "res://main/main.tscn"
const BACKGROUND := Color(0.13, 0.11, 0.1)
const BRASS := Color(0.86, 0.68, 0.32)


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
	column.add_theme_constant_override("separation", 12)
	centre.add_child(column)

	var title := Label.new()
	title.text = "BRASSWICK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", BRASS)
	column.add_child(title)
	var tagline := Label.new()
	tagline.text = "Coal, brass and a restless city"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.modulate = Color(1.0, 1.0, 1.0, 0.7)
	column.add_child(tagline)
	column.add_child(_spacer(18.0))

	_add_button(column, "New city", _on_new_city)
	var continue_button := _add_button(column, "Continue saved city", _on_continue)
	continue_button.disabled = not SaveGame.exists()
	if continue_button.disabled:
		continue_button.tooltip_text = "No saved city yet. Press F9 in the game to save."
	_add_button(column, "Quit", func() -> void: get_tree().quit())

	column.add_child(_spacer(18.0))
	var settings_heading := Label.new()
	settings_heading.text = "Sound"
	settings_heading.modulate = BRASS
	column.add_child(settings_heading)
	column.add_child(SettingsPanel.new())


func _on_new_city() -> void:
	SaveGame.pending = {}
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_continue() -> void:
	if SaveGame.load_from_disk():
		get_tree().change_scene_to_file(GAME_SCENE)


func _add_button(column: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320.0, 44.0)
	button.pressed.connect(action)
	column.add_child(button)
	return button


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer
