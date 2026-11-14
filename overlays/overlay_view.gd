class_name OverlayView
extends MeshInstance3D
## A see-through sheet over the whole map, painted one pixel per tile.
## O (or the HUD button) cycles the modes: none, smog, unrest, land value.
##
## - Land value shows where homes would pay more tax (green) or less (red).
## - Smog shows how much smog lies on each tile.
## - Unrest shows where the trouble is: every building that is adding to
##   Unrest is ringed in a colour for its problem, and the areas Tea Gardens
##   calm are washed green.

signal mode_changed(mode: Mode)

enum Mode { NONE, SMOG, UNREST, LAND }

## Height above the ground: over roads and yard slabs, under most roofs.
const HEIGHT := 0.25
const CLEAR := Color(0.0, 0.0, 0.0, 0.0)

const SMOG_COLOR := Color(0.42, 0.34, 0.2)
## Smog at or above this draws at full opacity.
const SMOG_FULL_AT := 60.0
const MAX_OPACITY := 0.85

const NO_ROAD_COLOR := Color(0.95, 0.2, 0.15)
const BROKEN_COLOR := Color(1.0, 0.85, 0.1)
const NO_COAL_COLOR := Color(1.0, 0.55, 0.1)
const COLD_COLOR := Color(0.3, 0.6, 1.0)
const SMOGGY_HOME_COLOR := Color(0.7, 0.35, 0.9)
const CALM_COLOR := Color(0.3, 0.85, 0.4, 0.22)
## Opacity of a troubled building's own tiles, and of the ring around them
## (the ring is what stays visible beside the model).
const TROUBLE_OPACITY := 0.9
const TROUBLE_RING_OPACITY := 0.5
## The unrest view reads live building state, so it repaints on a timer.
const UNREST_REPAINT_SECONDS := 0.25
## The land value view is worked out afresh each time, so less often.
const LAND_REPAINT_SECONDS := 1.0
const LAND_GOOD_COLOR := Color(0.3, 0.85, 0.4)
const LAND_POOR_COLOR := Color(0.95, 0.3, 0.2)
## How far above or below ordinary a tile must be to draw at full opacity.
const LAND_FULL_AT := 0.4

var mode: Mode = Mode.NONE

var _smog: SmogMap
var _grid: CityGrid
var _land: LandValueMap
var _image: Image
var _texture: ImageTexture
var _repaint_wait: float = 0.0


func _ready() -> void:
	var map_size := Vector2(CityGrid.SIZE) * CityGrid.TILE_SIZE
	var plane := PlaneMesh.new()
	plane.size = map_size
	mesh = plane
	position = Vector3(map_size.x * 0.5, HEIGHT, map_size.y * 0.5)

	# One pixel per tile; pixel (x, y) is cell (x, y).
	_image = Image.create_empty(CityGrid.SIZE.x, CityGrid.SIZE.y, false, Image.FORMAT_RGBA8)
	_image.fill(CLEAR)
	_texture = ImageTexture.create_from_image(_image)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_texture = _texture
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## Called once by Main.
func setup(smog: SmogMap, grid: CityGrid, land: LandValueMap) -> void:
	_smog = smog
	_grid = grid
	_land = land
	smog.updated.connect(_redraw)


func _process(delta: float) -> void:
	if mode != Mode.UNREST and mode != Mode.LAND:
		return
	_repaint_wait -= delta
	if _repaint_wait <= 0.0:
		_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("overlay_cycle"):
		cycle()
		get_viewport().set_input_as_handled()


## Switch to the next overlay mode, wrapping back to none.
func cycle() -> void:
	mode = ((mode + 1) % Mode.size()) as Mode
	visible = mode != Mode.NONE
	_redraw()
	mode_changed.emit(mode)


func mode_name() -> String:
	match mode:
		Mode.SMOG:
			return "smog"
		Mode.UNREST:
			return "unrest"
		Mode.LAND:
			return "land value"
		_:
			return "none"


## What the colours of the current mode mean, one line each; empty for none.
func legend() -> String:
	match mode:
		Mode.SMOG:
			return "Smog overlay\nDarker brown: more smog\nSmog drifts the way the brass arrow\nabove the Town Hall points"
		Mode.UNREST:
			return "Unrest overlay\nRed: no road access\nYellow: broken down\n" \
					+ "Orange: no Coal, Steam or (Tavern) Food\nBlue: cold home\n" \
					+ "Purple: smoggy home\nGreen: calmed by a Tea Garden or Tavern"
		Mode.LAND:
			return "Land value overlay\nGreen: homes here pay more tax\n" \
					+ "Red: homes here pay less\nGardens, Markets, Taverns and the\n" \
					+ "river raise it; industry and smog lower it"
		_:
			return ""


func _redraw() -> void:
	if _smog == null or _grid == null:
		return
	match mode:
		Mode.SMOG:
			_draw_smog()
		Mode.UNREST:
			_draw_unrest()
			_repaint_wait = UNREST_REPAINT_SECONDS
		Mode.LAND:
			_draw_land()
			_repaint_wait = LAND_REPAINT_SECONDS
		_:
			return
	_texture.update(_image)


func _draw_smog() -> void:
	for y in CityGrid.SIZE.y:
		for x in CityGrid.SIZE.x:
			var amount := _smog.get_at(Vector2i(x, y))
			var opacity := clampf(amount / SMOG_FULL_AT, 0.0, 1.0) * MAX_OPACITY
			_image.set_pixel(x, y, Color(SMOG_COLOR, opacity))


func _draw_land() -> void:
	_land.recompute(_grid, _smog)
	for y in CityGrid.SIZE.y:
		for x in CityGrid.SIZE.x:
			var cell := Vector2i(x, y)
			var above := _land.value_at(cell) - 1.0
			# Nothing to say about ground nobody can live on.
			var barren := _grid.terrain != null and not _grid.terrain.is_buildable(cell)
			if is_zero_approx(above) or barren:
				_image.set_pixel(x, y, CLEAR)
				continue
			var color := LAND_GOOD_COLOR if above > 0.0 else LAND_POOR_COLOR
			var opacity := clampf(absf(above) / LAND_FULL_AT, 0.0, 1.0) * 0.6
			_image.set_pixel(x, y, Color(color, opacity))


func _draw_unrest() -> void:
	_image.fill(CLEAR)
	# Calm areas first, so trouble paints over them.
	for building in _grid.all_buildings:
		if building.def.calming and building.area_effect_active():
			_fill(building.footprint_rect().grow(building.def.effect_range), CALM_COLOR)
	for building in _grid.all_buildings:
		var color := _trouble_color(building)
		if color.a <= 0.0:
			continue
		var footprint := building.footprint_rect()
		_fill(footprint.grow(1), Color(color, TROUBLE_RING_OPACITY))
		_fill(footprint, Color(color, TROUBLE_OPACITY))


## The colour for what is wrong with a building, most serious first;
## fully transparent if nothing is.
func _trouble_color(building: Building) -> Color:
	var def := building.def
	if def.is_road or building == _grid.town_hall:
		return CLEAR
	if not building.road_access:
		return NO_ROAD_COLOR
	if building.broken:
		return BROKEN_COLOR
	if not building.powered:
		return NO_COAL_COLOR
	if not building.fuelled:
		return COLD_COLOR if def.housing > 0 else NO_COAL_COLOR
	if building.smoggy and def.housing > 0:
		return SMOGGY_HOME_COLOR
	return CLEAR


func _fill(area: Rect2i, color: Color) -> void:
	var clipped := area.intersection(Rect2i(Vector2i.ZERO, CityGrid.SIZE))
	if clipped.has_area():
		_image.fill_rect(clipped, color)
