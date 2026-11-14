class_name InventionsPanel
extends PanelContainer
## The inventions on offer: what each does, what it costs, and a button to
## buy it. Opened and closed with I or the Inventions button.

## A Buy button was pressed.
signal buy_pressed(invention: StringName)

const OWNED_COLOR := Color(1.0, 0.85, 0.45)

var _inventions: Inventions
var _city: CityState
var _buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "Inventions: each is bought once and lasts for good        I: close"
	column.add_child(heading)
	column.add_child(HSeparator.new())
	for entry: Array in Inventions.LIST:
		var invention: StringName = entry[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		column.add_child(row)
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(210.0, 34.0)
		button.pressed.connect(func() -> void: buy_pressed.emit(invention))
		row.add_child(button)
		_buttons[invention] = button
		var note := Label.new()
		note.text = "%s  %s" % [entry[1], entry[5]]
		note.custom_minimum_size.x = 440.0
		row.add_child(note)
	hide()


## Called once by the HUD.
func bind(inventions: Inventions, city: CityState) -> void:
	_inventions = inventions
	_city = city
	_inventions.changed.connect(_refresh)
	_city.changed.connect(_refresh)


## Open the panel, or close it if it is open.
func toggle() -> void:
	visible = not visible
	_refresh()


func _refresh() -> void:
	if not visible or _inventions == null:
		return
	for entry: Array in Inventions.LIST:
		var invention: StringName = entry[0]
		var button := _buttons[invention]
		var reason := _inventions.blocked_reason(invention, _city)
		button.disabled = not reason.is_empty()
		button.modulate = OWNED_COLOR if _inventions.has(invention) else Color.WHITE
		button.text = "Buy for %d Crowns" % entry[2] if reason.is_empty() else reason
