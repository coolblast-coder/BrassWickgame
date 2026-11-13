class_name SettingsPanel
extends VBoxContainer
## The volume sliders, used by both the main menu and the in-game menu.
## Changes apply at once and are remembered by GameSettings.


func _ready() -> void:
	GameSettings.ensure_ready()
	add_theme_constant_override("separation", 6)
	for volume: Array in GameSettings.VOLUMES:
		var key: String = volume[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		add_child(row)
		var label := Label.new()
		label.text = volume[1]
		label.custom_minimum_size.x = 130.0
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = GameSettings.get_volume(key)
		slider.custom_minimum_size = Vector2(180.0, 20.0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Keep keyboard focus off it, so the arrow keys stay camera keys.
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(func(level: float) -> void: GameSettings.set_volume(key, level))
		row.add_child(slider)
