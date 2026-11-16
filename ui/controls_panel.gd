class_name ControlsPanel
extends CanvasLayer
## The list of keys, each with a button to change it. It sits on its own
## layer above everything else, and removes itself when closed.
##
## To change a key: press its button, then the new key. If that key was
## already doing something else, the two swap. Esc cancels.

## A key was changed.
signal changed

const FIXED_KEYS := "These cannot be changed:   Esc  menu and cancel   -   1 to 5  build categories   -   " \
		+ "Shift + number  pick a building\nCtrl+Z  undo   -   F9  save   -   F10  load   -   " \
		+ "arrow keys  move the view   -   mouse wheel  zoom   -   right click  cancel"

var _buttons: Dictionary[StringName, Button] = {}
## The action waiting for its new key; empty when none is.
var _waiting: StringName = &""
var _note: Label


func _ready() -> void:
	layer = 20
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = "Controls"
	heading.add_theme_font_size_override("font_size", 24)
	column.add_child(heading)
	_note = Label.new()
	_note.modulate = Color(1.0, 0.85, 0.45)
	column.add_child(_note)

	# Two columns of actions, each a name and the button for its key.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 5)
	column.add_child(grid)
	for entry: Array in GameSettings.KEYS:
		var action: StringName = entry[0]
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size.x = 230.0
		grid.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(110.0, 28.0)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_wait_for.bind(action))
		grid.add_child(button)
		_buttons[action] = button

	var fixed := Label.new()
	fixed.text = FIXED_KEYS
	fixed.modulate = Color(1.0, 1.0, 1.0, 0.65)
	fixed.add_theme_font_size_override("font_size", 13)
	column.add_child(fixed)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var reset := Button.new()
	reset.text = "Put them all back"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_reset)
	row.add_child(reset)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(queue_free)
	row.add_child(close)
	_refresh()


## Every key press comes here first while the panel is open: to be taken as
## a new key, or, for Esc, to cancel or close. Nothing reaches the game.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null:
		return
	get_viewport().set_input_as_handled()
	if not key.pressed or key.echo:
		return
	if _waiting == &"":
		if key.physical_keycode == KEY_ESCAPE:
			queue_free()
		return
	var action := _waiting
	_waiting = &""
	if key.physical_keycode == KEY_ESCAPE:
		_refresh()
	elif GameSettings.set_key(action, key.physical_keycode):
		_refresh()
		changed.emit()
	else:
		_refresh("%s has a fixed job and cannot be used." % OS.get_keycode_string(key.physical_keycode))


func _wait_for(action: StringName) -> void:
	_waiting = action
	_refresh()


func _reset() -> void:
	_waiting = &""
	GameSettings.reset_keys()
	_refresh()
	changed.emit()


func _refresh(problem: String = "") -> void:
	for action: StringName in _buttons:
		_buttons[action].text = "press a key..." if action == _waiting else GameSettings.key_label(action)
	if not problem.is_empty():
		_note.text = problem
	elif _waiting != &"":
		_note.text = "Press the new key. Esc cancels."
	else:
		_note.text = "Click a key to change it."
