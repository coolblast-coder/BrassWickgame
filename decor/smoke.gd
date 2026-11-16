class_name Smoke
extends RefCounted
## Chimney smoke: makes the little particle plumes that rise from buildings
## while they run, and lean with the wind.

## Metadata key on the Marker3D nodes BuildingMeshFactory leaves at chimney
## tops. Its value is the plume's strength: 1 for a factory, less for a home.
const POINT_META := &"smoke"
## How strongly the wind pushes smoke sideways, in units per second squared.
const WIND_PUSH := 0.5
const LIFETIME := 5.0

static var _material: StandardMaterial3D
static var _puff: SphereMesh
static var _growth: Curve


## A plume for a chimney of the given strength, not yet emitting.
static func make(strength: float) -> CPUParticles3D:
	_ensure_shared()
	var plume := CPUParticles3D.new()
	plume.emitting = false
	plume.mesh = _puff
	plume.material_override = _material
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Puffs live in the world, not on the building, so the wind can take them.
	plume.local_coords = false
	plume.amount = 12 if strength >= 0.8 else 7
	plume.lifetime = LIFETIME
	plume.direction = Vector3.UP
	plume.spread = 10.0
	plume.initial_velocity_min = 0.9
	plume.initial_velocity_max = 1.5
	plume.scale_amount_min = 0.5 * strength + 0.25
	plume.scale_amount_max = 0.8 * strength + 0.35
	plume.scale_amount_curve = _growth
	# Factory smoke is dark and thick; a home's is pale and thin.
	var shade := lerpf(0.82, 0.22, strength)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(shade, shade, shade, lerpf(0.35, 0.75, strength)))
	ramp.set_color(1, Color(shade + 0.15, shade + 0.15, shade + 0.15, 0.0))
	plume.color_ramp = ramp
	set_wind(plume, Vector3.ZERO)
	return plume


## Flames over a burning building, with a pall of smoke above them.
## `footprint` is the building's size on the ground and `height` its top.
static func make_fire(footprint: Vector2, height: float) -> Node3D:
	_ensure_shared()
	var fire := Node3D.new()
	fire.name = "Fire"
	var flames := CPUParticles3D.new()
	flames.mesh = _puff
	flames.material_override = _material
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flames.local_coords = false
	flames.amount = 28
	flames.lifetime = 0.9
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flames.emission_box_extents = Vector3(footprint.x * 0.32, height * 0.25, footprint.y * 0.32)
	flames.direction = Vector3.UP
	flames.spread = 20.0
	flames.initial_velocity_min = 1.8
	flames.initial_velocity_max = 3.6
	flames.gravity = Vector3(0.0, 2.0, 0.0)
	flames.scale_amount_min = 0.5
	flames.scale_amount_max = 1.1
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.15))
	flames.scale_amount_curve = shrink
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.3, 0.95))
	ramp.set_color(1, Color(0.9, 0.15, 0.05, 0.0))
	flames.color_ramp = ramp
	flames.position.y = height * 0.55
	fire.add_child(flames)
	var pall := make(1.0)
	pall.position.y = height
	pall.amount = 16
	set_wind(pall, Building.smoke_drift)
	pall.emitting = true
	fire.add_child(pall)
	return fire


## Lean a plume with the wind; `drift` is the way it blows, on the ground.
static func set_wind(plume: CPUParticles3D, drift: Vector3) -> void:
	plume.gravity = Vector3(drift.x * WIND_PUSH, 0.12, drift.z * WIND_PUSH)


static func _ensure_shared() -> void:
	if _material != null:
		return
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_puff = SphereMesh.new()
	_puff.radius = 0.5
	_puff.height = 1.0
	_puff.radial_segments = 8
	_puff.rings = 4
	# Puffs swell as they rise.
	_growth = Curve.new()
	_growth.add_point(Vector2(0.0, 0.35))
	_growth.add_point(Vector2(1.0, 1.0))
