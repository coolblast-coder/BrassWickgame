class_name CouncilPanel
extends PanelContainer
## Shows the council's current request: what is asked, how far along it is,
## how long is left, and the reward. Hidden while there is no request.

const WIDTH := 300.0

var _council: Council
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = WIDTH
	margin.add_child(_label)
	hide()


## Called once by the HUD.
func bind(council: Council) -> void:
	_council = council
	_council.request_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	visible = _council.has_request()
	if not visible:
		return
	_label.text = "The council asks:\n%s\n%s\nReward: %s" % [
			_council.describe(), _council.progress_text(), _council.reward_text()]
