class_name BuildController
extends Node
## Everything the player does to the map with the mouse: placing buildings
## (with a translucent "ghost" preview), dragging roads, demolishing, and
## selecting a building for inspection. Placement is paid for from CityState.

signal mode_changed(mode: Mode, def: BuildingDef)
## Emitted when a building is selected for inspection; null when deselected.
signal selection_changed(building: Building)

enum Mode { IDLE, PLACING, DEMOLISHING }

const GHOST_VALID := Color(0.35, 0.9, 0.4, 0.55)
const GHOST_BLOCKED := Color(0.95, 0.25, 0.2, 0.55)
## The spot is free, but the city cannot pay for the building.
const GHOST_UNAFFORDABLE := Color(1.0, 0.65, 0.1, 0.55)
const DEMOLISH_TINT := Color(1.0, 0.15, 0.1, 0.5)
const SELECTION_TINT := Color(1.0, 0.95, 0.6, 0.35)
## Height of the footprint pad above the ground, to avoid flickering.
const PAD_HEIGHT := 0.15

var mode: Mode = Mode.IDLE
## The building being placed; null unless mode is PLACING.
var selected_def: BuildingDef
## Quarter turns clockwise applied to the next placement, 0 to 3.
var rotation_steps: int = 0
## The building picked for inspection by clicking it while idle; null if none.
var selected_building: Building

var _grid: CityGrid
var _city: CityState
var _cursor: TileCursor
var _buildings_root: Node3D
var _ghost: Node3D
var _ghost_material: StandardMaterial3D
## The building under the cursor in demolish mode, tinted red; null if none.
var _demolish_target: Building
var _demolish_material: StandardMaterial3D
var _selection_material: StandardMaterial3D

# Road dragging: press on a tile, drag, release to lay the whole line.
var _dragging: bool = false
var _drag_start: Vector2i
var _drag_end: Vector2i
var _drag_cells: Array[Vector2i] = []
## Parent of the per-tile preview pads shown while dragging.
var _drag_preview: Node3D
var _drag_tile_mesh: PlaneMesh
var _drag_valid_material: StandardMaterial3D
var _drag_blocked_material: StandardMaterial3D
var _drag_unaffordable_material: StandardMaterial3D


func _ready() -> void:
	# The ghost's colour is changed every frame, so it gets its own material.
	_ghost_material = _translucent(GHOST_VALID)
	_drag_valid_material = _translucent(GHOST_VALID)
	_drag_blocked_material = _translucent(GHOST_BLOCKED)
	_drag_unaffordable_material = _translucent(GHOST_UNAFFORDABLE)
	_demolish_material = _translucent(DEMOLISH_TINT, true)
	_selection_material = _translucent(SELECTION_TINT, true)

	_drag_preview = Node3D.new()
	_drag_preview.name = "DragPreview"
	add_child(_drag_preview)
	_drag_tile_mesh = PlaneMesh.new()
	_drag_tile_mesh.size = Vector2.ONE * CityGrid.TILE_SIZE


## A see-through material. `flat` ignores lighting, for tints drawn over a
## building that should look the same on every face.
static func _translucent(color: Color, flat: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	if flat:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


## Called once by Main to hand over the things this controller works with.
func setup(grid: CityGrid, city: CityState, cursor: TileCursor, buildings_root: Node3D) -> void:
	_grid = grid
	_city = city
	_cursor = cursor
	_buildings_root = buildings_root


func _process(_delta: float) -> void:
	_update_drag()
	_update_ghost()
	_update_demolish_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_cancel"):
		if _dragging:
			# Abandon the line being dragged, but keep Road picked.
			_end_drag()
			get_viewport().set_input_as_handled()
		elif mode != Mode.IDLE:
			cancel()
			get_viewport().set_input_as_handled()
		elif selected_building != null:
			select(null)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_rotate"):
		if mode == Mode.PLACING:
			rotation_steps = (rotation_steps + 1) % 4
	elif event.is_action_pressed("demolish_mode"):
		toggle_demolish()
	elif event.is_action_pressed("repair"):
		repair_selected()
	elif OS.is_debug_build() and event is InputEventKey and event.pressed \
			and not event.echo and event.physical_keycode == KEY_B:
		# Development aid: B breaks the selected machine, to test repairs
		# without waiting for a random breakdown. Not in exported builds.
		if selected_building != null and selected_building.def.can_break:
			selected_building.set_broken(true)
			selection_changed.emit(selected_building)
	elif event is InputEventMouseButton:
		# Clicks on HUD buttons never get here; the UI consumes them first.
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if mode == Mode.PLACING:
				if selected_def.is_road:
					_begin_drag()
				else:
					try_place()
			elif mode == Mode.DEMOLISHING:
				try_demolish()
			else:
				_select_at_cursor()
	elif event is InputEventKey and event.pressed and not event.echo:
		# Number keys 1 to 7 pick from the catalog, in build-bar order; with
		# Shift held they pick from the second row.
		var slot: int = event.physical_keycode - KEY_1
		if slot >= 0 and slot < BuildingCatalog.KEYS_PER_ROW:
			if event.shift_pressed:
				slot += BuildingCatalog.KEYS_PER_ROW
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


## Select a building for inspection (tinted, details in the HUD), or pass null
## to deselect.
func select(building: Building) -> void:
	if building == selected_building:
		return
	if is_instance_valid(selected_building):
		selected_building.set_overlay(null)
	selected_building = building
	if selected_building != null:
		selected_building.set_overlay(_selection_material)
	selection_changed.emit(selected_building)


## Game over: drop whatever tool or selection is active and stop listening to
## the mouse and keyboard.
func shut_down() -> void:
	cancel()
	select(null)
	set_process_unhandled_input(false)


## Pay to repair the selected building at once, if it is broken and the city
## can afford it.
func repair_selected() -> bool:
	if selected_building == null or not selected_building.broken:
		return false
	if not _city.can_afford(CitySim.REPAIR_COST):
		return false
	selected_building.set_broken(false)
	_city.crowns -= CitySim.REPAIR_COST  # Also refreshes the HUD.
	return true


## Idle-mode click: select the building under the cursor. Roads and empty
## ground deselect.
func _select_at_cursor() -> void:
	var target: Building = _grid.building_at(_cursor.cell) if _cursor.in_bounds else null
	if target != null and target.def.is_road:
		target = null
	select(target)


func start_placing(def: BuildingDef) -> void:
	select(null)
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
	select(null)
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
func fits_here() -> bool:
	if mode != Mode.PLACING or not _cursor.in_bounds:
		return false
	if _already_built(selected_def):
		return false
	return _grid.can_place(Building.cells_for(selected_def, placement_origin(), rotation_steps))


## True for a one-per-city building that already stands somewhere.
func _already_built(def: BuildingDef) -> bool:
	if not def.unique:
		return false
	for building in _grid.all_buildings:
		if building.def == def:
			return true
	return false


## True if the picked building fits at the cursor and the city can pay for it.
func can_place_here() -> bool:
	return fits_here() and _city.can_afford(selected_def.cost)


## Pay for and place the picked building at the cursor. Stays in placing mode
## so several can be put down in a row.
func try_place() -> bool:
	if not can_place_here():
		return false
	_city.crowns -= selected_def.cost
	place_building(selected_def, placement_origin(), rotation_steps)
	return true


## The tiles a road dragged from `from` to `to` covers: a straight line, or an
## L that runs along the longer side first.
static func road_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [from]
	var delta := to - from
	var step := delta.sign()
	var x_first := absi(delta.x) >= absi(delta.y)
	var cell := from
	for leg in 2:
		var along_x := (leg == 0) == x_first
		var count := absi(delta.x) if along_x else absi(delta.y)
		for i in count:
			cell += Vector2i(step.x, 0) if along_x else Vector2i(0, step.y)
			cells.append(cell)
	return cells


## Put a building on the map and return it. Charges nothing; the caller has
## already checked that it fits and taken any payment.
func place_building(def: BuildingDef, origin: Vector2i, steps: int) -> Building:
	var building := Building.new()
	building.setup(def, origin, steps)
	_buildings_root.add_child(building)
	_grid.add_building(building)
	return building


func _begin_drag() -> void:
	if not _cursor.in_bounds:
		return
	_dragging = true
	_drag_start = _cursor.cell
	_drag_cells = [_drag_start]
	_drag_end = _drag_start
	_rebuild_drag_preview()


func _update_drag() -> void:
	if not _dragging:
		return
	# Polling the button (instead of waiting for a release event) also catches
	# releases that happen over the HUD or outside the window.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_drag()
		return
	var end := _cursor.cell.clamp(Vector2i.ZERO, CityGrid.SIZE - Vector2i.ONE)
	if end == _drag_end:
		return
	_drag_end = end
	_drag_cells = road_path(_drag_start, _drag_end)
	_rebuild_drag_preview()


## Lay a road on every free tile of the dragged line, paying per tile, until
## the Crowns run out. Blocked tiles are skipped.
func _finish_drag() -> void:
	for cell in _drag_cells:
		var one: Array[Vector2i] = [cell]
		if _grid.can_place(one) and _city.can_afford(selected_def.cost):
			_city.crowns -= selected_def.cost
			place_building(selected_def, cell, 0)
	_end_drag()


func _end_drag() -> void:
	_dragging = false
	_drag_cells = []
	for child in _drag_preview.get_children():
		child.queue_free()


func _rebuild_drag_preview() -> void:
	for child in _drag_preview.get_children():
		child.queue_free()
	var budget := _city.crowns
	for cell in _drag_cells:
		var occupant := _grid.building_at(cell)
		if occupant != null and occupant.def.is_road:
			continue  # Crossing an existing road is fine; nothing to show.
		var pad := MeshInstance3D.new()
		pad.mesh = _drag_tile_mesh
		if occupant != null:
			pad.material_override = _drag_blocked_material
		elif budget >= selected_def.cost:
			budget -= selected_def.cost
			pad.material_override = _drag_valid_material
		else:
			pad.material_override = _drag_unaffordable_material
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pad.position = CityGrid.cell_center(cell) + Vector3(0.0, PAD_HEIGHT, 0.0)
		_drag_preview.add_child(pad)


func _update_ghost() -> void:
	if mode != Mode.PLACING or _ghost == null:
		return
	_ghost.visible = _cursor.in_bounds and not _dragging
	if _ghost.visible:
		_ghost.transform = Building.transform_for(selected_def, placement_origin(), rotation_steps)
		if not fits_here():
			_ghost_material.albedo_color = GHOST_BLOCKED
		elif not _city.can_afford(selected_def.cost):
			_ghost_material.albedo_color = GHOST_UNAFFORDABLE
		else:
			_ghost_material.albedo_color = GHOST_VALID


func _update_demolish_target() -> void:
	if mode != Mode.DEMOLISHING:
		return
	var target: Building = _grid.building_at(_cursor.cell) if _cursor.in_bounds else null
	if target != null and not target.def.demolishable:
		target = null  # e.g. the Town Hall
	_set_demolish_target(target)


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


## Drops the ghost and any road line being dragged (every mode change does both).
func _clear_ghost() -> void:
	_end_drag()
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
