class_name CameraRig
extends Node3D
## City-builder camera. This node is the pivot: it sits on the ground at the
## point the camera looks at. The child Camera3D is held back and up from it.

## Pan speed in world units per second, per unit of camera distance,
## so panning feels the same at every zoom level.
@export var pan_speed: float = 0.7
## Pan when the mouse is pushed against a screen edge.
@export var edge_pan_enabled: bool = true
## Width of the band along each screen edge that triggers panning, in pixels.
@export var edge_pan_margin: float = 12.0
## Keyboard rotation speed (Q / E), in degrees per second.
@export var rotate_speed_degrees: float = 100.0
## Middle-mouse drag rotation, in degrees per pixel dragged.
@export var drag_rotate_degrees: float = 0.3
## Distance from the pivot to the camera, in world units.
@export var distance: float = 60.0
@export var min_distance: float = 12.0
@export var max_distance: float = 140.0
## Each wheel notch multiplies the distance by this (or divides, zooming in).
@export var zoom_step: float = 1.15
## How quickly the camera eases to the target zoom; higher is snappier.
@export var zoom_smoothing: float = 10.0
## Downward tilt of the camera, in degrees (90 = straight down).
@export_range(20.0, 85.0) var tilt_degrees: float = 50.0
## World-space area (x/z) the pivot may move in. Matches the 64 x 64 map.
@export var bounds: Rect2 = Rect2(0.0, 0.0, 128.0, 128.0)

## Rotation around the vertical axis, in radians.
var yaw: float = 0.0

var _target_distance: float
var _mouse_in_window: bool = false

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	distance = clampf(distance, min_distance, max_distance)
	_target_distance = distance
	_apply_view()


func _process(delta: float) -> void:
	_pan(delta)
	_rotate_with_keys(delta)
	_ease_zoom(delta)
	_apply_view()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = maxf(_target_distance / zoom_step, min_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = minf(_target_distance * zoom_step, max_distance)
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			yaw -= deg_to_rad(event.relative.x * drag_rotate_degrees)


func _rotate_with_keys(delta: float) -> void:
	var turn := Input.get_axis("cam_rotate_left", "cam_rotate_right")
	yaw += deg_to_rad(turn * rotate_speed_degrees * delta)
	yaw = wrapf(yaw, -PI, PI)


func _ease_zoom(delta: float) -> void:
	# Frame-rate independent easing towards the target distance.
	distance = lerpf(distance, _target_distance, 1.0 - exp(-zoom_smoothing * delta))


func _pan(delta: float) -> void:
	var input := Input.get_vector("cam_left", "cam_right", "cam_forward", "cam_back")
	input = (input + _edge_pan_input()).limit_length(1.0)
	if input == Vector2.ZERO:
		return
	# Move relative to where the camera faces, staying on the ground plane.
	var move := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)
	position += move * pan_speed * distance * delta
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.y, bounds.end.y)
	position.y = 0.0


func _notification(what: int) -> void:
	# Godot keeps reporting the last in-window mouse position after the cursor
	# leaves, which would otherwise keep the camera panning forever.
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_in_window = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_in_window = false


func _edge_pan_input() -> Vector2:
	if not edge_pan_enabled or not _mouse_in_window or not get_window().has_focus():
		return Vector2.ZERO
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		return Vector2.ZERO
	var mouse := get_viewport().get_mouse_position()
	var size := get_viewport().get_visible_rect().size
	var input := Vector2.ZERO
	if mouse.x <= edge_pan_margin:
		input.x = -1.0
	elif mouse.x >= size.x - edge_pan_margin:
		input.x = 1.0
	if mouse.y <= edge_pan_margin:
		input.y = -1.0
	elif mouse.y >= size.y - edge_pan_margin:
		input.y = 1.0
	return input


func _apply_view() -> void:
	rotation = Vector3(0.0, yaw, 0.0)
	var tilt := deg_to_rad(tilt_degrees)
	_camera.position = Vector3(0.0, sin(tilt), cos(tilt)) * distance
	_camera.rotation = Vector3(-tilt, 0.0, 0.0)
