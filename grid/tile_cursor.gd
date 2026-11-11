class_name TileCursor
extends MeshInstance3D
## Tracks which grid cell is under the mouse and highlights it.
## Other systems (HUD, build controller) read `cell` / `in_bounds` or listen
## to `cell_changed`.

signal cell_changed(cell: Vector2i, in_bounds: bool)

## Height above the ground, to avoid flickering against the ground plane.
const HOVER_HEIGHT := 0.05

## The cell under the mouse. Only meaningful while `in_bounds` is true.
var cell: Vector2i = Vector2i(-1, -1)
## True when the mouse is over a tile of the map (and not over UI).
var in_bounds: bool = false
## Turn off to keep tracking the cell but hide the square (e.g. while a
## building ghost is shown instead).
var show_highlight: bool = true:
	set(value):
		show_highlight = value
		visible = in_bounds and show_highlight


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * CityGrid.TILE_SIZE
	mesh = plane

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.4, 0.45)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func _process(_delta: float) -> void:
	var new_cell := cell
	var new_in_bounds := false

	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if camera != null and viewport.gui_get_hovered_control() == null:
		var mouse := viewport.get_mouse_position()
		var ground := Plane(Vector3.UP, 0.0)
		var hit: Variant = ground.intersects_ray(
			camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
		if hit != null:
			new_cell = CityGrid.world_to_cell(hit)
			new_in_bounds = CityGrid.is_in_bounds(new_cell)

	if new_cell == cell and new_in_bounds == in_bounds:
		return
	cell = new_cell
	in_bounds = new_in_bounds
	visible = in_bounds and show_highlight
	if in_bounds:
		position = CityGrid.cell_center(cell) + Vector3(0.0, HOVER_HEIGHT, 0.0)
	cell_changed.emit(cell, in_bounds)
