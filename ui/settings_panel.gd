class_name SettingsPanel
extends VBoxContainer
## The settings, used by both the main menu and the in-game menu: the volume
## sliders, a few options, and a button that opens the list of keys.
## Changes apply at once and are remembered by GameSettings.

## The keys were changed, so anything showing a key's name should refresh.
signal controls_changed


func _ready() -> void:
	GameSettings.ensure_ready()
	add_theme_constant_override("separation", 6)
	for volume: Array in GameSettings.VOLUMES:
		var key: String = volume[0]
		var slider := _add_slider(volume[1], 0.0, 1.0, 0.05, GameSettings.get_volume(key))
		slider.value_changed.connect(func(level: float) -> void: GameSettings.set_volume(key, level))
	var speed := _add_slider("Camera speed", GameSettings.CAMERA_SPEED_MIN,
			GameSettings.CAMERA_SPEED_MAX, 0.1, GameSettings.camera_speed)
	speed.value_changed.connect(GameSettings.set_camera_speed)
	_add_check("Move the view at the window's edge", GameSettings.edge_pan, GameSettings.set_edge_pan)
	_add_check("Day and night cycle", GameSettings.day_night, GameSettings.set_day_night)
	var controls := Button.new()
	controls.text = "Controls..."
	controls.focus_mode = Control.FOCUS_NONE
	controls.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	controls.custom_minimum_size.x = 150.0
	controls.pressed.connect(_open_controls)
	add_child(controls)


func _open_controls() -> void:
	var panel := ControlsPanel.new()
	panel.changed.connect(func() -> void: controls_changed.emit())
	# Over everything else on screen, whichever scene this is.
	get_tree().root.add_child(panel)


func _add_slider(text: String, low: float, high: float, step: float, value: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 130.0
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(180.0, 20.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Keep keyboard focus off it, so the arrow keys stay camera keys.
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	return slider


func _add_check(text: String, on: bool, action: Callable) -> void:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = on
	box.focus_mode = Control.FOCUS_NONE
	box.toggled.connect(action)
	add_child(box)
