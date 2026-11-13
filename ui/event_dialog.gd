class_name EventDialog
extends PanelContainer
## Puts an event to the player: what has happened, and a button for each way
## of dealing with it. The game is paused until one is chosen.

## An option was picked; `index` is its place in the offer's list.
signal chosen(index: int)

const WIDTH := 460.0

var _title: Label
var _message: Label
var _options: VBoxContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.modulate = Color(1.0, 0.85, 0.45)
	column.add_child(_title)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = WIDTH
	column.add_child(_message)
	column.add_child(HSeparator.new())
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 6)
	column.add_child(_options)
	hide()


## Show an offer from CityEvents: a title, a message, and options that each
## have a label, a line on what it does, and whether it can be afforded.
func show_offer(offer: Dictionary) -> void:
	_title.text = offer.get("title", "")
	_message.text = offer.get("message", "")
	for child in _options.get_children():
		# Out of the layout at once, so the panel can be sized to the new list.
		_options.remove_child(child)
		child.queue_free()
	var options: Array = offer.get("options", [])
	for i in options.size():
		var option: Dictionary = options[i]
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(WIDTH, 44.0)
		button.text = "%s\n    %s" % [option.get("label", ""), option.get("detail", "")]
		button.disabled = not option.get("enabled", true)
		button.pressed.connect(_choose.bind(i))
		_options.add_child(button)
	show()
	# Fit the new contents and stay in the middle of the screen.
	set_anchors_and_offsets_preset.call_deferred(Control.PRESET_CENTER)


func _choose(index: int) -> void:
	hide()
	chosen.emit(index)
