class_name Building
extends Node3D
## One placed building on the map.

## Colour of a road tile that does not lead back to the Town Hall.
const CUT_OFF_ROAD_COLOR := Color(0.5, 0.4, 0.3)

var def: BuildingDef
## The footprint's minimum (-X, -Z) cell.
var origin: Vector2i
## Quarter turns clockwise seen from above, 0 to 3.
var rotation_steps: int = 0
## True for a road tile laid on water.
var is_bridge: bool = false
## Whether this building is served by the Town Hall's road network.
## Kept up to date by Main through set_road_access().
var road_access: bool = true
## Citizens living here, for homes; set by the daily simulation.
var residents: int = 0
## True while the player has switched this workplace off: it takes no
## workers, burns nothing and makes nothing, but still costs upkeep.
## Change it through set_paused().
var paused: bool = false
## Multiplier on this building's output from the ground it stands on: 1 for
## no effect. Set by CityGrid when the building is placed.
var terrain_factor: float = 1.0
## For homes: how desirable the spot is, as a multiplier on the taxes its
## residents pay, and what they paid on the last simulated day.
var land_value: float = 1.0
var tax_paid: int = 0
## Workers assigned to this building by the last daily simulation.
var staff: int = 0
## False if this building needed Coal (or, for a Tavern, Food) on the last
## simulated day and got none: a cold home, a machine that stopped, a shut
## Tavern.
var fuelled: bool = true
## True if this building operated on the last simulated day: connected,
## fuelled, and staffed if it needs workers. Only such buildings emit smog.
var ran_today: bool = false
## What this building actually produced on the last simulated day, after
## staffing, smog, strikes and stoppages.
var food_made: int = 0
var coal_made: int = 0
var crowns_made: int = 0
var water_made: int = 0
var goods_made: int = 0
var steam_made: int = 0
## False if this building needed Steam on the last simulated day and got
## none, so it did not run.
var powered: bool = true
## True if any tile under this building is at or above the smoggy threshold.
var smoggy: bool = false
## True while broken down: produces nothing and burns no Coal until repaired.
## Change it through set_broken().
var broken: bool = false

var _model: Node3D
## This home's window panes, in a fixed random order: the first ones light up
## first. Empty for buildings that house nobody.
var _windows: Array[MeshInstance3D] = []
## Shown above buildings the road network does not reach; created on first need.
var _no_access_marker: MeshInstance3D
## Shown above broken buildings; created on first need.
var _broken_marker: MeshInstance3D
## Shown above buildings that are switched off; created on first need.
var _paused_marker: MeshInstance3D


## Footprint in tiles after rotation: odd quarter turns swap width and depth.
static func rotated_footprint(building_def: BuildingDef, steps: int) -> Vector2i:
	var fp := building_def.footprint
	return Vector2i(fp.y, fp.x) if posmod(steps, 2) == 1 else fp


## All cells a building of this kind would cover at this origin and rotation.
static func cells_for(building_def: BuildingDef, at_origin: Vector2i, steps: int) -> Array[Vector2i]:
	var fp := rotated_footprint(building_def, steps)
	var result: Array[Vector2i] = []
	for y in fp.y:
		for x in fp.x:
			result.append(at_origin + Vector2i(x, y))
	return result


## World transform for a model of this kind at this origin and rotation:
## centred on the rotated footprint, standing on the ground.
static func transform_for(building_def: BuildingDef, at_origin: Vector2i, steps: int) -> Transform3D:
	var fp := rotated_footprint(building_def, steps)
	var center := CityGrid.cell_to_world(at_origin) \
			+ Vector3(fp.x, 0.0, fp.y) * CityGrid.TILE_SIZE * 0.5
	var turn := Basis(Vector3.UP, -posmod(steps, 4) * PI * 0.5)
	return Transform3D(turn, center)


func setup(building_def: BuildingDef, at_origin: Vector2i, steps: int = 0,
		bridge: bool = false) -> void:
	is_bridge = bridge
	def = building_def
	origin = at_origin
	rotation_steps = posmod(steps, 4)
	name = "%s_%d_%d" % [def.id, origin.x, origin.y]
	transform = transform_for(def, origin, rotation_steps)
	_model = BuildingMeshFactory.build(def, is_bridge)
	add_child(_model)
	if def.housing > 0:
		for child in _model.get_children():
			var pane := child as MeshInstance3D
			if pane != null and pane.has_meta(BuildingMeshFactory.WINDOW_META):
				_windows.append(pane)
		# The same home always lights its windows in the same order.
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(origin)
		for i in range(_windows.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap := _windows[i]
			_windows[i] = _windows[j]
			_windows[j] = swap
		refresh_windows()


## Light a home's windows in proportion to how full it is. All of them go
## dark when nobody lives here or the home went without Coal.
func refresh_windows() -> void:
	if _windows.is_empty():
		return
	var lit := 0
	if residents > 0 and fuelled:
		lit = maxi(1, roundi(float(_windows.size()) * residents / def.housing))
	var glow := BuildingMeshFactory.get_glow_material(BuildingMeshFactory.WINDOW_GLOW)
	var dark := BuildingMeshFactory.get_material(BuildingMeshFactory.WINDOW_DARK, 0.3)
	for i in _windows.size():
		_windows[i].material_override = glow if i < lit else dark


## Record whether the Town Hall's road network reaches this building, and
## show it: cut-off road tiles turn a dusty brown, and other buildings get a
## red marker above the roof.
func set_road_access(value: bool) -> void:
	if value == road_access:
		return
	road_access = value
	if is_bridge:
		# A bridge keeps its timber look whether or not it is connected.
		pass
	elif def.is_road:
		var color := def.color if road_access else CUT_OFF_ROAD_COLOR
		var material := BuildingMeshFactory.get_material(color)
		for child in _model.get_children():
			if child is MeshInstance3D:
				child.material_override = material
	else:
		if _no_access_marker == null and not road_access:
			_no_access_marker = _make_no_access_marker()
			add_child(_no_access_marker)
		if _no_access_marker != null:
			_no_access_marker.visible = not road_access


## Mark this building as broken down or repaired, and show it: a broken
## building gets a yellow tilted cube above the roof.
func set_broken(value: bool) -> void:
	if value == broken:
		return
	broken = value
	if _broken_marker == null and broken:
		_broken_marker = _make_broken_marker()
		add_child(_broken_marker)
	if _broken_marker != null:
		_broken_marker.visible = broken


## Switch a workplace off or back on, and show it: a switched-off building
## gets a grey slab above the roof.
func set_paused(value: bool) -> void:
	if value == paused:
		return
	paused = value
	if _paused_marker == null and paused:
		var slab := BoxMesh.new()
		slab.size = Vector3(0.9, 0.25, 0.9)
		_paused_marker = _make_marker("PausedMarker", slab, Color(0.6, 0.62, 0.66), 3.3)
		add_child(_paused_marker)
	if _paused_marker != null:
		_paused_marker.visible = paused


## A red downward-pointing cone floating above the roof.
func _make_no_access_marker() -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.45
	cone.bottom_radius = 0.0
	cone.height = 0.9
	return _make_marker("NoRoadAccessMarker", cone, Color(0.95, 0.2, 0.15), 1.0)


## A yellow cube standing on one corner, floating above the no-access cone's
## spot so both can show at once.
func _make_broken_marker() -> MeshInstance3D:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.7
	var marker := _make_marker("BrokenMarker", cube, Color(1.0, 0.85, 0.1), 2.3)
	marker.rotation_degrees = Vector3(45.0, 0.0, 45.0)
	return marker


## A flat-coloured shape floating `height_above_roof` over the model.
func _make_marker(marker_name: String, shape: Mesh, color: Color,
		height_above_roof: float) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	marker.mesh = shape
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position.y = _model_top() + height_above_roof
	return marker


## Height of the tallest point of the model, in local units.
func _model_top() -> float:
	var top := 0.0
	for child in _model.get_children():
		var part := child as MeshInstance3D
		if part != null and part.mesh != null:
			var box: AABB = part.transform * part.mesh.get_aabb()
			top = maxf(top, box.end.y)
	return top


## Draw `material` over the whole model (e.g. a red demolish tint).
## Pass null to remove it.
func set_overlay(material: Material) -> void:
	for child in _model.get_children():
		if child is MeshInstance3D:
			child.material_overlay = material


## Whether this building's area effect (calming, smog clearing) applies
## today: it must be on the road network, and if it needs workers it must
## have run.
func area_effect_active() -> bool:
	if not road_access:
		return false
	return def.workers <= 0 or ran_today


## The tiles this building covers, as a rectangle.
func footprint_rect() -> Rect2i:
	return Rect2i(origin, rotated_footprint(def, rotation_steps))


func cells() -> Array[Vector2i]:
	return cells_for(def, origin, rotation_steps)


## This building's saved state. Its place in the list is its place in the
## building order, which decides who gets workers and Coal first.
func to_save() -> Dictionary:
	return {
		"id": String(def.id), "x": origin.x, "y": origin.y, "rotation": rotation_steps,
		"broken": broken, "paused": paused, "residents": residents, "staff": staff,
		"fuelled": fuelled, "powered": powered, "ran_today": ran_today,
	}


## Restore the state that setup() does not cover.
func from_save(data: Dictionary) -> void:
	set_broken(bool(data.get("broken", false)))
	set_paused(bool(data.get("paused", false)))
	residents = int(data.get("residents", 0))
	staff = int(data.get("staff", 0))
	fuelled = bool(data.get("fuelled", true))
	powered = bool(data.get("powered", true))
	ran_today = bool(data.get("ran_today", false))
	refresh_windows()
