class_name LineGraph
extends Control
## A small line graph of one figure over time, with its name, latest value
## and the range of the vertical axis.

const BACKGROUND := Color(0.0, 0.0, 0.0, 0.35)
const AXIS_COLOR := Color(1.0, 1.0, 1.0, 0.25)
const TEXT_COLOR := Color(0.92, 0.9, 0.85)
const DIM_TEXT_COLOR := Color(0.92, 0.9, 0.85, 0.6)
## Space around the plot, in pixels: room for the title above it.
const PAD := 6.0
const TITLE_HEIGHT := 20.0

var title: String = ""
var line_color: Color = Color.WHITE
## If above zero, the top of the axis is fixed here (Unrest: 100).
var fixed_max: float = 0.0

var _values: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	custom_minimum_size = Vector2(250.0, 120.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Show these values, oldest first.
func set_values(values: PackedFloat32Array) -> void:
	_values = values
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var font_size := 13
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)

	var latest := "-" if _values.is_empty() else str(roundi(_values[_values.size() - 1]))
	draw_string(font, Vector2(PAD, PAD + font_size), "%s  %s" % [title, latest],
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, TEXT_COLOR)

	var plot := Rect2(PAD, PAD + TITLE_HEIGHT, size.x - PAD * 2.0, size.y - PAD * 2.0 - TITLE_HEIGHT)
	# The axis always includes zero, and dips below it for debt.
	var low := 0.0
	var high := 1.0
	for value in _values:
		low = minf(low, value)
		high = maxf(high, value)
	if fixed_max > 0.0:
		high = fixed_max
	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), AXIS_COLOR)
	var zero_y := plot.end.y - (0.0 - low) / (high - low) * plot.size.y
	draw_line(Vector2(plot.position.x, zero_y), Vector2(plot.end.x, zero_y), AXIS_COLOR)
	draw_string(font, Vector2(plot.end.x - 70.0, PAD + font_size), "max %d" % roundi(high),
			HORIZONTAL_ALIGNMENT_RIGHT, 70.0, font_size, DIM_TEXT_COLOR)

	if _values.size() < 2:
		return
	var points := PackedVector2Array()
	var last := _values.size() - 1
	for i in _values.size():
		var x := plot.position.x + plot.size.x * i / last
		var y := plot.end.y - (_values[i] - low) / (high - low) * plot.size.y
		points.append(Vector2(x, y))
	draw_polyline(points, line_color, 2.0, true)
