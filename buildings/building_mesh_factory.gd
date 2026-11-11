class_name BuildingMeshFactory
extends RefCounted
## Assembles placeholder building models from boxes, cylinders and capsules.
##
## Every model is built around the local origin: centred on its footprint,
## standing on y = 0, with its front (door side) facing local +Z.
## Colours go in `material_override`; tints (ghost, demolish highlight) are
## applied separately through `material_overlay`, so they never clash.

## Gap left between the model and the edge of its footprint, in world units.
const MARGIN := 0.15

const BRASS := Color(0.78, 0.6, 0.25)
const SOOT := Color(0.13, 0.12, 0.12)
const DARK_BRICK := Color(0.35, 0.2, 0.17)
const SLATE := Color(0.25, 0.26, 0.3)
const WOOD := Color(0.4, 0.28, 0.18)
const PAVING := Color(0.3, 0.29, 0.27)
const PLASTER := Color(0.9, 0.87, 0.8)

static var _materials: Dictionary = {}


static func build(def: BuildingDef) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var w := def.footprint.x * CityGrid.TILE_SIZE - MARGIN * 2.0
	var d := def.footprint.y * CityGrid.TILE_SIZE - MARGIN * 2.0
	match def.style:
		BuildingDef.Style.TENEMENT:
			_tenement(root, w, d, def.color)
		BuildingDef.Style.GLASSHOUSE:
			_glasshouse(root, w, d, def.color)
		BuildingDef.Style.COAL_PIT:
			_coal_pit(root, w, d, def.color)
		BuildingDef.Style.BRASSWORKS:
			_brassworks(root, w, d, def.color)
		BuildingDef.Style.MECHANIC_YARD:
			_mechanic_yard(root, w, d, def.color)
		BuildingDef.Style.TEA_GARDEN:
			_tea_garden(root, w, d, def.color)
		_:
			_box(root, Vector3(w, 2.0, d), Vector3(0.0, 1.0, 0.0), def.color)
	return root


# --- Models -----------------------------------------------------------------

static func _tenement(root: Node3D, w: float, d: float, color: Color) -> void:
	var h := 3.2
	_box(root, Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0), color)
	_box(root, Vector3(w + 0.1, 0.25, d + 0.1), Vector3(0.0, h + 0.125, 0.0), SLATE)
	_box(root, Vector3(0.4, 0.9, 0.4), Vector3(-w * 0.3, h + 0.7, -d * 0.2), DARK_BRICK)
	_box(root, Vector3(0.4, 0.9, 0.4), Vector3(w * 0.3, h + 0.7, d * 0.2), DARK_BRICK)
	_box(root, Vector3(0.7, 1.2, 0.1), Vector3(0.0, 0.6, d * 0.5 + 0.03), WOOD)


static func _glasshouse(root: Node3D, w: float, d: float, color: Color) -> void:
	_box(root, Vector3(w, 0.4, d), Vector3(0.0, 0.2, 0.0), DARK_BRICK)
	var gw := w - 0.4
	var gd := d - 0.4
	_box(root, Vector3(gw, 1.2, gd), Vector3(0.0, 1.0, 0.0), color)
	# Barrel roof: a cylinder on its side, squashed to half height.
	var roof := _cylinder(root, gw * 0.5, gd - 0.05, Vector3(0.0, 1.6, 0.0), color.lightened(0.2))
	roof.rotation.x = PI * 0.5
	roof.scale = Vector3(1.0, 1.0, 0.5)
	_box(root, Vector3(0.6, 1.0, 0.1), Vector3(0.0, 0.9, gd * 0.5 + 0.03), WOOD)


static func _coal_pit(root: Node3D, w: float, d: float, color: Color) -> void:
	_box(root, Vector3(w, 0.2, d), Vector3(0.0, 0.1, 0.0), color)
	# Shaft mouth.
	_cylinder(root, minf(w, d) * 0.22, 0.1, Vector3(w * 0.1, 0.25, d * 0.12), Color(0.03, 0.03, 0.03))
	# Headframe with winding wheel.
	_box(root, Vector3(0.7, 4.0, 0.7), Vector3(-w * 0.3, 2.2, -d * 0.3), WOOD)
	var wheel := _cylinder(root, 0.8, 0.2, Vector3(-w * 0.3, 4.4, -d * 0.3), BRASS, 0.7)
	wheel.rotation.x = PI * 0.5
	# Coal heaps (cones).
	_cylinder(root, 1.1, 1.3, Vector3(w * 0.28, 0.85, -d * 0.25), SOOT, 0.0, 0.0)
	_cylinder(root, 0.7, 0.8, Vector3(-w * 0.25, 0.6, d * 0.3), SOOT, 0.0, 0.0)


static func _brassworks(root: Node3D, w: float, d: float, color: Color) -> void:
	var h := 3.0
	_box(root, Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0), color)
	_box(root, Vector3(w + 0.1, 0.2, d + 0.1), Vector3(0.0, h + 0.1, 0.0), SLATE)
	# Two tapered chimneys with brass caps at the back.
	for side: float in [-1.0, 1.0]:
		var x := side * w * 0.3
		_cylinder(root, 0.45, 6.0, Vector3(x, 3.0, -d * 0.3), DARK_BRICK, 0.0, 0.35)
		_cylinder(root, 0.42, 0.3, Vector3(x, 6.15, -d * 0.3), BRASS, 0.7)
	# Boiler lying across the roof.
	var boiler := _capsule(root, 0.7, w * 0.7, Vector3(0.0, h + 0.9, d * 0.2), BRASS, 0.7)
	boiler.rotation.z = PI * 0.5
	_box(root, Vector3(1.4, 1.6, 0.1), Vector3(0.0, 0.8, d * 0.5 + 0.03), WOOD)


static func _mechanic_yard(root: Node3D, w: float, d: float, color: Color) -> void:
	_box(root, Vector3(w, 0.15, d), Vector3(0.0, 0.075, 0.0), PAVING)
	# Shed in the back-left corner.
	var sw := w * 0.55
	var sd := d * 0.6
	var shed_x := -w * 0.5 + sw * 0.5
	var shed_z := -d * 0.5 + sd * 0.5
	_box(root, Vector3(sw, 2.0, sd), Vector3(shed_x, 1.15, shed_z), color)
	_box(root, Vector3(sw + 0.1, 0.2, sd + 0.1), Vector3(shed_x, 2.25, shed_z), SLATE)
	_box(root, Vector3(0.7, 1.0, 0.1), Vector3(shed_x, 0.65, shed_z + sd * 0.5 + 0.03), WOOD)
	# A big upright gear in the yard.
	var gear_pos := Vector3(w * 0.25, 1.05, d * 0.25)
	var gear := _cylinder(root, 0.9, 0.3, gear_pos, BRASS, 0.7)
	gear.rotation.x = PI * 0.5
	var hub := _cylinder(root, 0.25, 0.5, gear_pos, SOOT)
	hub.rotation.x = PI * 0.5


static func _tea_garden(root: Node3D, w: float, d: float, color: Color) -> void:
	_box(root, Vector3(w, 0.15, d), Vector3(0.0, 0.075, 0.0), color)
	# Pavilion with a conical roof.
	_cylinder(root, 0.6, 1.0, Vector3(0.0, 0.65, 0.0), PLASTER)
	_cylinder(root, 0.9, 0.6, Vector3(0.0, 1.45, 0.0), Color(0.6, 0.25, 0.2), 0.0, 0.0)
	# A tree in each corner.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var x := corner.x * w * 0.33
		var z := corner.y * d * 0.33
		_cylinder(root, 0.12, 0.8, Vector3(x, 0.55, z), WOOD)
		_capsule(root, 0.45, 1.3, Vector3(x, 1.5, z), color.darkened(0.25))


# --- Primitive helpers --------------------------------------------------------
# `center` is the middle of the shape, in the model's local space.

static func _box(root: Node3D, size: Vector3, center: Vector3, color: Color,
		metallic: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(root, mesh, center, color, metallic)


## Pass `top_radius` to taper the cylinder; 0 makes a cone.
static func _cylinder(root: Node3D, radius: float, height: float, center: Vector3,
		color: Color, metallic: float = 0.0, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	return _add(root, mesh, center, color, metallic)


## `height` is the full length including both rounded ends.
static func _capsule(root: Node3D, radius: float, height: float, center: Vector3,
		color: Color, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	return _add(root, mesh, center, color, metallic)


static func _add(root: Node3D, mesh: Mesh, center: Vector3, color: Color,
		metallic: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	instance.material_override = _material(color, metallic)
	root.add_child(instance)
	return instance


static func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), metallic]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.45 if metallic > 0.0 else 0.9
	_materials[key] = mat
	return mat
