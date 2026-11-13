class_name WindVane
extends Node3D
## A brass arrow floating high above the Town Hall that points the way the
## wind is blowing, and so the way smog will drift. It lives in the world,
## not the HUD, so it stays true however the camera is turned.

## Height of the arrow above the ground, clear of the clock tower.
const HEIGHT := 15.0
const TURN_SECONDS := 3.0
const COLOR := Color(0.86, 0.68, 0.32)

var _arrow: Node3D
var _turn: Tween


func _ready() -> void:
	_arrow = Node3D.new()
	_arrow.position.y = HEIGHT
	add_child(_arrow)
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.metallic = 0.7
	material.roughness = 0.4
	# Shaft and head lie along the arrow's +Z, which is "downwind" once the
	# arrow is turned.
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.12
	shaft_mesh.bottom_radius = 0.12
	shaft_mesh.height = 3.0
	shaft.mesh = shaft_mesh
	shaft.rotation.x = PI * 0.5
	shaft.position.z = -0.4
	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.55
	head_mesh.height = 1.4
	head.mesh = head_mesh
	head.rotation.x = PI * 0.5
	head.position.z = 1.8
	var tail := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.06, 0.9, 0.9)
	tail.mesh = tail_mesh
	tail.position.z = -1.7
	for part: MeshInstance3D in [shaft, head, tail]:
		part.material_override = material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arrow.add_child(part)


## Point the arrow the way the wind blows: a step on the grid, such as
## (1, 0) for towards +X. `instant` skips the slow turn.
func set_wind(direction: Vector2i, instant: bool = false) -> void:
	if direction == Vector2i.ZERO:
		return
	var yaw := atan2(float(direction.x), float(direction.y))
	if _turn != null:
		_turn.kill()
	if instant:
		_arrow.rotation.y = yaw
		return
	# Turn the short way round.
	var target := _arrow.rotation.y + wrapf(yaw - _arrow.rotation.y, -PI, PI)
	_turn = create_tween()
	_turn.tween_property(_arrow, "rotation:y", target, TURN_SECONDS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
