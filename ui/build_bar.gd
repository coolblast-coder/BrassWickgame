class_name BuildBar
extends VBoxContainer
## Build buttons along the bottom of the screen, one per catalog entry, in
## two rows: keys 1 to 7 on the lower row, Shift + 1 to 7 on the upper row.

## `index` is the building's position in BuildingCatalog.all().
signal slot_pressed(index: int)
signal demolish_pressed
signal overlay_pressed

var _buttons: Array[Button] = []
var _demolish_button: Button
var _overlay_button: Button


func _ready() -> void:
	var upper := _make_row()
	var lower := _make_row()
	var defs := BuildingCatalog.all()
	var per_row := BuildingCatalog.KEYS_PER_ROW
	for i in defs.size():
		var button: Button
		if i < per_row:
			button = _make_button(lower, "%d  %s" % [i + 1, defs[i].display_name])
		else:
			button = _make_button(upper, "Shift+%d  %s" % [i - per_row + 1, defs[i].display_name])
		button.toggle_mode = true
		button.tooltip_text = "%s: %d Crowns" % [defs[i].display_name, defs[i].cost]
		button.pressed.connect(func() -> void: slot_pressed.emit(i))
		_buttons.append(button)
	upper.visible = defs.size() > per_row

	lower.add_child(VSeparator.new())
	_demolish_button = _make_button(lower, "X  Demolish")
	_demolish_button.toggle_mode = true
	_demolish_button.pressed.connect(func() -> void: demolish_pressed.emit())

	_overlay_button = _make_button(lower, "")
	_overlay_button.pressed.connect(func() -> void: overlay_pressed.emit())
	set_overlay_name("none")


## Show which map overlay is active on the Overlay button.
func set_overlay_name(overlay_name: String) -> void:
	_overlay_button.text = "O  Overlay: %s" % overlay_name


## Show the Demolish button as active or not.
func set_demolishing(active: bool) -> void:
	_demolish_button.set_pressed_no_signal(active)


## Show `def` as the picked building; pass null to clear the selection.
func set_selected(def: BuildingDef) -> void:
	var defs := BuildingCatalog.all()
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(def != null and defs[i] == def)


func _make_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Let clicks between the buttons through to the map.
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	return row


func _make_button(row: HBoxContainer, label: String) -> Button:
	var button := Button.new()
	button.text = label
	# Keep keyboard focus off the buttons, so Space/Enter/arrows stay game keys.
	button.focus_mode = Control.FOCUS_NONE
	row.add_child(button)
	return button
