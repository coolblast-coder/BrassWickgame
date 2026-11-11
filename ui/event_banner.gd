class_name EventBanner
extends PanelContainer
## A notice that announces a random event. It closes by itself after a while,
## or at once when clicked.

## Real seconds the notice stays up.
const SHOW_SECONDS := 12.0

var _title: Label
var _message: Label
var _timer: Timer


func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.modulate = Color(1.0, 0.85, 0.45)
	column.add_child(_title)

	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(440.0, 0.0)
	column.add_child(_message)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(hide)
	add_child(_timer)

	tooltip_text = "Click to dismiss"
	hide()


func show_event(title: String, message: String) -> void:
	_title.text = title
	_message.text = message
	show()
	_timer.start(SHOW_SECONDS)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_timer.stop()
		hide()
		accept_event()
