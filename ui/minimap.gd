class_name Minimap
extends Control
## A small map of the whole city in the corner of the screen: the ground,
## every building coloured by what it is, anything on fire, and where the
## camera is looking. Click or drag on it to move the camera there.

## The camera should move to this spot on the ground.
signal pan_requested(world_position: Vector3)

const REFRESH_SECONDS := 0.5
const FRAME_COLOR := Color(0.1, 0.09, 0.08, 0.85)
const VIEW_COLOR := Color(1.0, 1.0, 1.0, 0.9)

const TERRAIN_COLORS: Array[Color] = [
	Color(0.3, 0.38, 0.22),   # grass
	Color(0.22, 0.4, 0.55),   # water
	Color(0.45, 0.44, 0.42),  # rock
	Color(0.17, 0.17, 0.18),  # coal seam
	Color(0.24, 0.31, 0.15),  # fertile soil
]
const ROAD_COLOR := Color(0.62, 0.58, 0.5)
const TOWN_HALL_COLOR := Color(0.95, 0.78, 0.3)
const FIRE_COLOR := Color(1.0, 0.4, 0.0)
const UNFINISHED_COLOR := Color(0.75, 0.72, 0.65)
## Building colours by BuildingDef.Category.
const CATEGORY_COLORS: Array[Color] = [
	Color(0.62, 0.58, 0.5),   # roads
	Color(0.9, 0.62, 0.45),   # housing
	Color(0.55, 0.8, 0.4),    # food and coal
	Color(0.75, 0.3, 0.25),   # industry
	Color(0.5, 0.7, 0.95),    # services
]

var _grid: CityGrid
var _terrain: TerrainMap
var _camera: CameraRig
var _image: Image
var _texture: ImageTexture
var _wait: float = 0.0
var _dragging: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image = Image.create_empty(CityGrid.SIZE.x, CityGrid.SIZE.y, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)


## Called once by Main.
func setup(grid: CityGrid, terrain: TerrainMap, camera: CameraRig) -> void:
	_grid = grid
	_terrain = terrain
	_camera = camera
	_repaint()


func _process(delta: float) -> void:
	if _grid == null:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = REFRESH_SECONDS
		_repaint()
	# The camera marker moves every frame.
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_pan_to(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_pan_to(event.position)
		accept_event()


func _pan_to(point: Vector2) -> void:
	var share := Vector2(clampf(point.x / size.x, 0.0, 1.0), clampf(point.y / size.y, 0.0, 1.0))
	var map_size := Vector2(CityGrid.SIZE) * CityGrid.TILE_SIZE
	pan_requested.emit(Vector3(share.x * map_size.x, 0.0, share.y * map_size.y))


func _repaint() -> void:
	for y in CityGrid.SIZE.y:
		for x in CityGrid.SIZE.x:
			_image.set_pixel(x, y, TERRAIN_COLORS[_terrain.type_at(Vector2i(x, y))])
	for building in _grid.all_buildings:
		var color := CATEGORY_COLORS[building.def.category]
		if building == _grid.town_hall:
			color = TOWN_HALL_COLOR
		elif building.on_fire:
			color = FIRE_COLOR
		elif building.def.is_road:
			color = ROAD_COLOR
		elif building.under_construction():
			color = UNFINISHED_COLOR
		for cell in building.cells():
			_image.set_pixel(cell.x, cell.y, color)
	_texture.update(_image)


func _draw() -> void:
	draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), FRAME_COLOR)
	if _texture != null:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
	if _camera == null:
		return
	# Where the camera looks, and a tail pointing back towards where it stands.
	var map_size := Vector2(CityGrid.SIZE) * CityGrid.TILE_SIZE
	var at := Vector2(_camera.position.x / map_size.x, _camera.position.z / map_size.y) * size
	var reach := clampf(_camera.distance / map_size.x * size.x * 0.45, 5.0, size.x * 0.4)
	draw_arc(at, reach, 0.0, TAU, 24, VIEW_COLOR, 1.5)
	var back := Vector2(sin(_camera.yaw), cos(_camera.yaw))
	draw_line(at, at + back * reach, VIEW_COLOR, 1.5)
