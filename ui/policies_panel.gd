class_name PoliciesPanel
extends PanelContainer
## The Town Hall's policies: one switch per policy, with what it gives and
## what it costs. Opened and closed with T or the Policies button.

## A policy switch was pressed.
signal policy_pressed(policy: StringName)

const ON_COLOR := Color(1.0, 0.85, 0.45)

var _policies: Policies
var _city: CityState
var _heading: Label
var _switches: Dictionary[StringName, Button] = {}
var _notes: Dictionary[StringName, Label] = {}


func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_heading = Label.new()
	column.add_child(_heading)
	for entry: Array in Policies.LIST:
		var policy: StringName = entry[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		column.add_child(row)
		var switch := Button.new()
		switch.toggle_mode = true
		switch.focus_mode = Control.FOCUS_NONE
		switch.custom_minimum_size = Vector2(190.0, 40.0)
		switch.pressed.connect(func() -> void: policy_pressed.emit(policy))
		row.add_child(switch)
		_switches[policy] = switch
		var note := Label.new()
		note.custom_minimum_size.x = 430.0
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(note)
		_notes[policy] = note
	hide()


## Called once by the HUD.
func bind(policies: Policies, city: CityState) -> void:
	_policies = policies
	_city = city
	_policies.changed.connect(_refresh)
	_city.changed.connect(_refresh)


## Open the panel, or close it if it is open.
func toggle() -> void:
	visible = not visible
	_refresh()


func _refresh() -> void:
	if not visible or _policies == null:
		return
	var open_for_business := _city.tier >= Policies.FROM_TIER
	if open_for_business:
		_heading.text = "Town Hall policies        T: close"
	else:
		_heading.text = "Town Hall policies: the council first sits when Brasswick is a %s        T: close" % (
				CityState.TIER_NAMES[Policies.FROM_TIER])
	for entry: Array in Policies.LIST:
		var policy: StringName = entry[0]
		var on := _policies.is_on(policy)
		var locked := _policies.days_locked(policy, _city.day)
		var switch := _switches[policy]
		switch.set_pressed_no_signal(on)
		switch.text = "%s: %s" % [entry[1], "ON" if on else "off"]
		switch.modulate = ON_COLOR if on else Color.WHITE
		switch.disabled = not open_for_business or locked > 0
		var text := "%s  Cost: %s" % [entry[2], entry[3]]
		if locked > 0:
			text += "\nCan be changed again in %d %s." % [locked, "day" if locked == 1 else "days"]
		_notes[policy].text = text
