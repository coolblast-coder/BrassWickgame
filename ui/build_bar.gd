class_name BuildBar
extends HBoxContainer
## Row of build buttons along the bottom of the screen, one per catalog entry.

## `index` is the building's position in BuildingCatalog.all().
signal slot_pressed(index: int)
signal demolish_pressed

var _buttons: Array[Button] = []
var _demolish_button: Button


func _ready() -> void:
	var road := _make_button("1  Road")
	road.disabled = true
	road.tooltip_text = "Roads arrive in the next milestone"

	var defs := BuildingCatalog.all()
	for i in defs.size():
		var button := _make_button("%d  %s" % [i + 2, defs[i].display_name])
		button.toggle_mode = true
		button.pressed.connect(func() -> void: slot_pressed.emit(i))
		_buttons.append(button)

	add_child(VSeparator.new())
	_demolish_button = _make_button("X  Demolish")
	_demolish_button.toggle_mode = true
	_demolish_button.pressed.connect(func() -> void: demolish_pressed.emit())


## Show the Demolish button as active or not.
func set_demolishing(active: bool) -> void:
	_demolish_button.set_pressed_no_signal(active)


## Show `def` as the picked building; pass null to clear the selection.
func set_selected(def: BuildingDef) -> void:
	var defs := BuildingCatalog.all()
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(def != null and defs[i] == def)


func _make_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	# Keep keyboard focus off the buttons, so Space/Enter/arrows stay game keys.
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)
	return button
