class_name Building
extends Node3D
## One placed building on the map.

var def: BuildingDef
## The footprint's minimum (-X, -Z) cell.
var origin: Vector2i
## Quarter turns clockwise seen from above, 0 to 3.
var rotation_steps: int = 0

var _model: Node3D


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


## Draw `material` over the whole model (e.g. a red demolish tint).
## Pass null to remove it.
func set_overlay(material: Material) -> void:
	for child in _model.get_children():
		if child is MeshInstance3D:
			child.material_overlay = material


func cells() -> Array[Vector2i]:
	return cells_for(def, origin, rotation_steps)
