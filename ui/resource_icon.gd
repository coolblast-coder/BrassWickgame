class_name ResourceIcon
extends Control
## A small drawn symbol for one of the top bar's figures, so the bar can show
## numbers without spelling out a name beside each. Drawn from shapes: the
## game ships no image files.

const SIZE := 18.0

## Which figure this stands for: &"crowns", &"coal", &"food", &"water",
## &"goods", &"steam", &"store", &"population", &"workers" or &"unrest".
var kind: StringName = &""


func _init(icon_kind: StringName = &"") -> void:
	kind = icon_kind
	custom_minimum_size = Vector2(SIZE, SIZE)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Let the mouse through to the label's tooltip area around it.
	mouse_filter = Control.MOUSE_FILTER_PASS


func _draw() -> void:
	var c := Vector2(SIZE, SIZE) * 0.5
	match kind:
		&"crowns":
			draw_circle(c, 8.0, Color(0.95, 0.78, 0.25))
			draw_circle(c, 5.0, Color(0.8, 0.6, 0.15))
		&"coal":
			draw_colored_polygon(_ring(c, 8.0, 6, 0.3), Color(0.12, 0.12, 0.13))
			draw_colored_polygon(_ring(c + Vector2(-1.5, -1.5), 3.0, 5, 0.9), Color(0.32, 0.32, 0.35))
		&"food":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-8, 6), c + Vector2(-5, -4), c + Vector2(3, -8), c + Vector2(8, -7),
				c + Vector2(7, 1), c + Vector2(1, 7)]), Color(0.45, 0.75, 0.3))
			draw_line(c + Vector2(-7, 6), c + Vector2(6, -6), Color(0.25, 0.5, 0.18), 1.5)
		&"water":
			draw_circle(c + Vector2(0, 3), 5.5, Color(0.4, 0.68, 1.0))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -9), c + Vector2(5, 1), c + Vector2(-5, 1)]), Color(0.4, 0.68, 1.0))
		&"goods":
			draw_rect(Rect2(c - Vector2(7, 6), Vector2(14, 13)), Color(0.72, 0.45, 0.28))
			draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), Color(0.45, 0.27, 0.16), 1.5)
			draw_line(c + Vector2(0, -6), c + Vector2(0, 7), Color(0.45, 0.27, 0.16), 1.5)
		&"steam":
			draw_circle(c + Vector2(-4, 3), 4.5, Color(0.86, 0.88, 0.94))
			draw_circle(c + Vector2(3, 1), 5.5, Color(0.86, 0.88, 0.94))
			draw_circle(c + Vector2(-1, -4), 4.0, Color(0.86, 0.88, 0.94))
		&"store":
			draw_rect(Rect2(c - Vector2(7, 2), Vector2(14, 9)), Color(0.62, 0.5, 0.36))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-9, -2), c + Vector2(0, -9), c + Vector2(9, -2)]), Color(0.42, 0.44, 0.5))
		&"population":
			draw_circle(c + Vector2(0, -4), 3.5, Color(0.93, 0.88, 0.76))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-6, 8), c + Vector2(-4, 0), c + Vector2(4, 0), c + Vector2(6, 8)]),
				Color(0.93, 0.88, 0.76))
		&"workers":
			draw_colored_polygon(_ring(c, 8.0, 8, 0.0), Color(0.7, 0.72, 0.76))
			draw_circle(c, 3.0, Color(0.2, 0.2, 0.22))
		&"unrest":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -9), c + Vector2(8, 7), c + Vector2(-8, 7)]), Color(1.0, 0.55, 0.3))
			draw_line(c + Vector2(0, -3), c + Vector2(0, 2), Color(0.25, 0.1, 0.05), 2.0)
			draw_circle(c + Vector2(0, 5), 1.2, Color(0.25, 0.1, 0.05))


## The corners of a regular polygon, for lumps and cogs.
func _ring(centre: Vector2, radius: float, corners: int, turn: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in corners:
		var angle := TAU * i / corners + turn
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points
