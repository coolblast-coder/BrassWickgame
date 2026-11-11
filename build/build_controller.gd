class_name BuildController
extends Node
## Owns the player's build state: which building is picked, its rotation, and
## the translucent "ghost" preview that follows the tile cursor.

signal mode_changed(mode: Mode, def: BuildingDef)

enum Mode { IDLE, PLACING, DEMOLISHING }

const GHOST_VALID := Color(0.35, 0.9, 0.4, 0.55)
const GHOST_BLOCKED := Color(0.95, 0.25, 0.2, 0.55)
## Height of the footprint pad above the ground, to avoid flickering.
const PAD_HEIGHT := 0.06

var mode: Mode = Mode.IDLE
## The building being placed; null unless mode is PLACING.
var selected_def: BuildingDef
## Quarter turns clockwise applied to the next placement, 0 to 3.
var rotation_steps: int = 0

var _grid: CityGrid
var _cursor: TileCursor
var _buildings_root: Node3D
var _ghost: Node3D
var _ghost_material: StandardMaterial3D
## The building under the cursor in demolish mode, tinted red; null if none.
var _demolish_target: Building
var _demolish_material: StandardMaterial3D


func _ready() -> void:
	_demolish_material = StandardMaterial3D.new()
	_demolish_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_demolish_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_demolish_material.albedo_color = Color(1.0, 0.15, 0.1, 0.5)
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.albedo_color = GHOST_VALID


## Called once by Main to hand over the things this controller works with.
func setup(grid: CityGrid, cursor: TileCursor, buildings_root: Node3D) -> void:
	_grid = grid
	_cursor = cursor
	_buildings_root = buildings_root


func _process(_delta: float) -> void:
	_update_ghost()
	_update_demolish_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_cancel"):
		if mode != Mode.IDLE:
			cancel()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_rotate"):
		if mode == Mode.PLACING:
			rotation_steps = (rotation_steps + 1) % 4
	elif event.is_action_pressed("demolish_mode"):
		toggle_demolish()
	elif event is InputEventMouseButton:
		# Clicks on HUD buttons never get here; the UI consumes them first.
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if mode == Mode.PLACING:
				try_place()
			elif mode == Mode.DEMOLISHING:
				try_demolish()
	elif event is InputEventKey and event.pressed and not event.echo:
		# Number keys: 1 is reserved for Road, 2 onwards pick from the catalog.
		var slot: int = event.physical_keycode - KEY_2
		if slot >= 0 and slot < BuildingCatalog.all().size():
			select_slot(slot)


## Pick a building by its index in BuildingCatalog. Picking the one that is
## already selected puts it away again.
func select_slot(index: int) -> void:
	var defs := BuildingCatalog.all()
	if index < 0 or index >= defs.size():
		return
	if mode == Mode.PLACING and selected_def == defs[index]:
		cancel()
	else:
		start_placing(defs[index])


func start_placing(def: BuildingDef) -> void:
	_clear_ghost()
	_set_demolish_target(null)
	mode = Mode.PLACING
	selected_def = def
	rotation_steps = 0
	_ghost = _make_ghost(def)
	add_child(_ghost)
	_cursor.show_highlight = false
	_update_ghost()
	mode_changed.emit(mode, selected_def)


## X or the Demolish button: enter demolish mode, or leave it if already in it.
func toggle_demolish() -> void:
	if mode == Mode.DEMOLISHING:
		cancel()
	else:
		start_demolishing()


func start_demolishing() -> void:
	_clear_ghost()
	mode = Mode.DEMOLISHING
	selected_def = null
	_cursor.show_highlight = true
	_update_demolish_target()
	mode_changed.emit(mode, null)


## Remove the building under the cursor and free its tiles. Stays in demolish
## mode so several can be removed in a row.
func try_demolish() -> bool:
	_update_demolish_target()
	if _demolish_target == null:
		return false
	var building := _demolish_target
	_demolish_target = null
	_grid.remove_building(building)
	building.queue_free()
	return true


func cancel() -> void:
	_clear_ghost()
	_set_demolish_target(null)
	mode = Mode.IDLE
	selected_def = null
	_cursor.show_highlight = true
	mode_changed.emit(mode, null)


## The footprint's minimum cell for the current cursor position, chosen so the
## cursor sits at (or just before) the middle of the footprint.
func placement_origin() -> Vector2i:
	var fp := Building.rotated_footprint(selected_def, rotation_steps)
	return _cursor.cell - (fp - Vector2i.ONE) / 2


## True if the picked building fits at the cursor: every tile of its footprint
## is on the map and empty.
func can_place_here() -> bool:
	if mode != Mode.PLACING or not _cursor.in_bounds:
		return false
	return _grid.can_place(Building.cells_for(selected_def, placement_origin(), rotation_steps))


## Place the picked building at the cursor if it fits. Stays in placing mode
## so several can be put down in a row.
func try_place() -> bool:
	if not can_place_here():
		return false
	var building := Building.new()
	building.setup(selected_def, placement_origin(), rotation_steps)
	_buildings_root.add_child(building)
	_grid.add_building(building)
	return true


func _update_ghost() -> void:
	if mode != Mode.PLACING or _ghost == null:
		return
	_ghost.visible = _cursor.in_bounds
	if _cursor.in_bounds:
		_ghost.transform = Building.transform_for(selected_def, placement_origin(), rotation_steps)
		_ghost_material.albedo_color = GHOST_VALID if can_place_here() else GHOST_BLOCKED


func _update_demolish_target() -> void:
	if mode != Mode.DEMOLISHING:
		return
	_set_demolish_target(_grid.building_at(_cursor.cell) if _cursor.in_bounds else null)


func _set_demolish_target(building: Building) -> void:
	if building == _demolish_target:
		return
	if is_instance_valid(_demolish_target):
		_demolish_target.set_overlay(null)
	_demolish_target = building
	if _demolish_target != null:
		_demolish_target.set_overlay(_demolish_material)


func _make_ghost(def: BuildingDef) -> Node3D:
	var ghost := BuildingMeshFactory.build(def)
	ghost.name = "Ghost"
	# A flat pad showing exactly which tiles the building will cover.
	var pad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(def.footprint) * CityGrid.TILE_SIZE
	pad.mesh = plane
	pad.position.y = PAD_HEIGHT
	ghost.add_child(pad)
	for child in ghost.get_children():
		if child is MeshInstance3D:
			child.material_override = _ghost_material
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ghost


func _clear_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
