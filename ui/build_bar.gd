class_name BuildBar
extends VBoxContainer
## The build menu along the bottom of the screen. The bottom row holds one
## tab per building category, plus Demolish and Overlay. Opening a category
## shows its buildings in a row above.
##
## Keys: 1 to 5 open or close a category; Shift + a number picks that
## building from the open category.

## `index` is the building's position in BuildingCatalog.all().
signal slot_pressed(index: int)
## The mouse moved onto a building button, or off it (`index` is -1).
signal slot_hovered(index: int)
signal demolish_pressed
signal overlay_pressed
## Any button of the menu was pressed, by mouse or by key.
signal clicked

## Set to false to stop the menu reacting to keys (after the game ends).
var enabled: bool = true

## The category whose buildings are on show, or -1 for none.
var _open_category: int = -1
var _tabs: Array[Button] = []
## One row of building buttons per category.
var _rows: Array[HBoxContainer] = []
## For each category, the catalog indices of its buildings, in row order.
var _row_slots: Array[Array] = []
## Building buttons by catalog index.
var _buttons: Array[Button] = []
var _demolish_button: Button
var _overlay_button: Button
## The city's tier; buildings of a higher tier are locked.
var _tier: int = 0


func _ready() -> void:
	var defs := BuildingCatalog.all()
	var names := BuildingCatalog.CATEGORY_NAMES
	for c in names.size():
		var row := _make_row()
		row.visible = false
		_rows.append(row)
		_row_slots.append([])

	for i in defs.size():
		var c: int = defs[i].category
		_row_slots[c].append(i)
		var button := _make_button(_rows[c],
				"Shift+%d  %s" % [_row_slots[c].size(), defs[i].display_name])
		button.toggle_mode = true
		button.mouse_entered.connect(func() -> void: slot_hovered.emit(i))
		button.mouse_exited.connect(func() -> void: slot_hovered.emit(-1))
		button.pressed.connect(func() -> void: slot_pressed.emit(i))
		_buttons.append(button)

	var tab_row := _make_row()
	for c in names.size():
		var tab := _make_button(tab_row, "%d  %s" % [c + 1, names[c]])
		tab.toggle_mode = true
		tab.visible = not _row_slots[c].is_empty()
		tab.pressed.connect(func() -> void: toggle_category(c))
		_tabs.append(tab)

	tab_row.add_child(VSeparator.new())
	_demolish_button = _make_button(tab_row, "X  Demolish")
	_demolish_button.toggle_mode = true
	_demolish_button.pressed.connect(func() -> void: demolish_pressed.emit())

	_overlay_button = _make_button(tab_row, "")
	_overlay_button.pressed.connect(func() -> void: overlay_pressed.emit())
	set_overlay_name("none")
	set_tier(0)


## Lock the buildings the city has not grown into yet: their buttons are
## greyed out and name the tier that unlocks them.
func set_tier(tier: int) -> void:
	_tier = tier
	var defs := BuildingCatalog.all()
	for c in _row_slots.size():
		for n in _row_slots[c].size():
			var index: int = _row_slots[c][n]
			var def := defs[index]
			var locked := def.tier > tier
			_buttons[index].disabled = locked
			if locked:
				_buttons[index].text = "%s  (%s)" % [def.display_name, CityState.TIER_NAMES[def.tier]]
			else:
				_buttons[index].text = "Shift+%d  %s" % [n + 1, def.display_name]


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var number: int = key.physical_keycode - KEY_1
	if number < 0 or number > 8:
		return
	if key.shift_pressed:
		if _open_category >= 0 and number < _row_slots[_open_category].size():
			var index: int = _row_slots[_open_category][number]
			if not _buttons[index].disabled:
				slot_pressed.emit(index)
				clicked.emit()
			get_viewport().set_input_as_handled()
	elif number < _tabs.size() and _tabs[number].visible:
		toggle_category(number)
		clicked.emit()
		get_viewport().set_input_as_handled()


## Open a category's row of buildings, or close it if it is already open.
func toggle_category(category: int) -> void:
	_show_category(-1 if category == _open_category else category)


## Show which map overlay is active on the Overlay button.
func set_overlay_name(overlay_name: String) -> void:
	_overlay_button.text = "O  Overlay: %s" % overlay_name


## Show the Demolish button as active or not.
func set_demolishing(active: bool) -> void:
	_demolish_button.set_pressed_no_signal(active)


## Show `def` as the picked building, opening its category; pass null to
## clear the selection (the open category stays open).
func set_selected(def: BuildingDef) -> void:
	var defs := BuildingCatalog.all()
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(def != null and defs[i] == def)
	if def != null:
		_show_category(def.category)


func _show_category(category: int) -> void:
	_open_category = category
	for c in _rows.size():
		_rows[c].visible = c == category
		_tabs[c].set_pressed_no_signal(c == category)


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
	button.pressed.connect(func() -> void: clicked.emit())
	row.add_child(button)
	return button
