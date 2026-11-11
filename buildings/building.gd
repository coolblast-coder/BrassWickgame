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
## Whether this building is served by the Town Hall's road network.
## Kept up to date by Main through set_road_access().
var road_access: bool = true
## Workers assigned to this building by the last daily simulation.
var staff: int = 0
## False if this building needed Coal on the last simulated day and got none:
## a cold home, or a machine that stopped.
var fuelled: bool = true

var _model: Node3D
## Shown above buildings the road network does not reach; created on first need.
var _no_access_marker: MeshInstance3D


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


func setup(building_def: BuildingDef, at_origin: Vector2i, steps: int = 0) -> void:
	def = building_def
	origin = at_origin
	rotation_steps = posmod(steps, 4)
	name = "%s_%d_%d" % [def.id, origin.x, origin.y]
	transform = transform_for(def, origin, rotation_steps)
	_model = BuildingMeshFactory.build(def)
	add_child(_model)


## Record whether the Town Hall's road network reaches this building, and
## show it: cut-off road tiles turn a dusty brown, and other buildings get a
## red marker above the roof.
func set_road_access(value: bool) -> void:
	if value == road_access:
		return
	road_access = value
	if def.is_road:
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


## A red downward-pointing cone floating above the roof.
func _make_no_access_marker() -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.45
	cone.bottom_radius = 0.0
	cone.height = 0.9
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.95, 0.2, 0.15)
	var marker := MeshInstance3D.new()
	marker.name = "NoRoadAccessMarker"
	marker.mesh = cone
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position.y = _model_top() + 1.0
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


func cells() -> Array[Vector2i]:
	return cells_for(def, origin, rotation_steps)
