class_name BuildController
extends Node
## Everything the player does to the map with the mouse: placing buildings
## (with a translucent "ghost" preview), dragging out roads and rows of
## buildings, demolishing, and selecting a building for inspection. A
## selected building can be repaired, switched off, upgraded or moved, and
## the last placements can be undone. It also shows how far a building
## reaches. Everything is paid for from CityState.

signal mode_changed(mode: Mode, def: BuildingDef)
## Emitted when a building is selected for inspection; null when deselected.
signal selection_changed(building: Building)
## Something happened that should be heard: &"build", &"road", &"demolish",
## &"repair", or &"error" for a click that could not be carried out.
signal feedback(sound: StringName)
## While placing, the bonus the ground under the ghost would give changed.
## `factor` is the output multiplier: 1 for none.
signal ground_bonus_changed(factor: float)
## While placing, what the building under the ghost would reach changed:
## a short note such as "Calms 4 homes", or empty.
signal reach_note_changed(note: String)
## The last placement was undone and `refund` Crowns given back; or, with a
## refund of -1, there was nothing that could be undone.
signal undone(refund: int)
## The selected building has been picked up to be moved, at this price.
signal move_started(def: BuildingDef, cost: int)

enum Mode { IDLE, PLACING, DEMOLISHING }

const GHOST_VALID := Color(0.35, 0.9, 0.4, 0.55)
const GHOST_BLOCKED := Color(0.95, 0.25, 0.2, 0.55)
## The spot is free, but the city cannot pay for the building.
const GHOST_UNAFFORDABLE := Color(1.0, 0.65, 0.1, 0.55)
const DEMOLISH_TINT := Color(1.0, 0.15, 0.1, 0.5)
const SELECTION_TINT := Color(1.0, 0.95, 0.6, 0.35)
## How many placements Ctrl+Z can step back through.
const UNDO_DEPTH := 10
## Moving a building costs this share of its price.
const MOVE_COST_SHARE := 0.25
## Tints for the area a building reaches: what it does (calm, repair, fight
## fires, clear smog), and what it does to land value, for better or worse.
const REACH_EFFECT_TINT := Color(0.35, 0.65, 1.0, 0.2)
const REACH_VALUE_TINT := Color(0.4, 0.9, 0.45, 0.18)
const REACH_BLIGHT_TINT := Color(0.95, 0.35, 0.25, 0.18)
## Heights of the two reach sheets above the ground, apart from each other
## and from the overlay, to avoid flickering.
const REACH_HEIGHTS: Array[float] = [0.19, 0.22]
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
## The ground bonus last reported for the ghost's position.
var _ghost_bonus: float = 1.0
## Two flat sheets showing how far a building reaches: [0] its effect, [1]
## its pull on land value.
var _reach_sheets: Array[MeshInstance3D] = []
## What the sheets were last drawn for, so they are redone only on a change.
var _reach_key: Array = []
var _reach_note: String = ""
## The last few placements, newest last, for Ctrl+Z. Each is the buildings
## put down in one go (one building, or a dragged line of road), what they
## cost, and the day they were placed.
var _undo_stack: Array[Dictionary] = []
## The building picked up to be moved; null unless a move is under way.
var _moving: Building
## True while a row of buildings is being dragged out (as opposed to a line
## of road), and where the row starts and what it holds so far.
var _row_active: bool = false
var _row_start: Vector2i
var _row_origins: Array[Vector2i] = []
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

	var unit := PlaneMesh.new()
	unit.size = Vector2.ONE
	for i in 2:
		var sheet := MeshInstance3D.new()
		sheet.mesh = unit
		sheet.material_override = _translucent(REACH_EFFECT_TINT, true)
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.visible = false
		add_child(sheet)
		_reach_sheets.append(sheet)


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
	_update_reach()
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
	elif event.is_action_pressed(&"toggle_power"):
		toggle_selected_power()
	elif event.is_action_pressed(&"move_building"):
		start_moving()
	elif event.is_action_pressed(&"upgrade"):
		if upgrade_target() != null:
			upgrade_selected()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_Z and event.ctrl_pressed:
		undo()
		get_viewport().set_input_as_handled()
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
					_begin_row()
			elif mode == Mode.DEMOLISHING:
				try_demolish()
			else:
				_select_at_cursor()


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


## Switch the selected workplace off, or back on. Homes and buildings
## without workers have no switch.
func toggle_selected_power() -> void:
	if selected_building == null or selected_building.def.workers <= 0:
		return
	selected_building.set_paused(not selected_building.paused)
	# Refresh the info panel.
	selection_changed.emit(selected_building)


## What the selected building can be upgraded to, or null if nothing.
func upgrade_target() -> BuildingDef:
	if not is_instance_valid(selected_building) or selected_building.def.upgrade_to == &"":
		return null
	return BuildingCatalog.by_id(selected_building.def.upgrade_to)


## Why the selected building cannot be upgraded right now; empty if it can.
func upgrade_blocked_reason() -> String:
	var target := upgrade_target()
	if target == null:
		return "Cannot be upgraded"
	var building := selected_building
	if building.under_construction():
		return "Still being built"
	if building.on_fire:
		return "On fire"
	if _city.tier < target.tier:
		return "Needs a %s" % CityState.TIER_NAMES[target.tier]
	if not _city.can_afford(upgrade_cost()):
		return "Needs %d Crowns" % upgrade_cost()
	return ""


## The price of upgrading the selected building: the difference between
## what it cost and what its upgrade costs.
func upgrade_cost() -> int:
	var target := upgrade_target()
	if target == null:
		return 0
	return maxi(0, target.cost - selected_building.def.cost)


## Rebuild the selected building as its upgrade, on the same spot. The new
## building takes the old one's place in the building order, and is ready by
## the end of the day, so nobody living there has to leave.
func upgrade_selected() -> bool:
	if not upgrade_blocked_reason().is_empty():
		feedback.emit(&"error")
		return false
	var old := selected_building
	var target := upgrade_target()
	var cost := upgrade_cost()
	var place := _grid.all_buildings.find(old)
	var residents := old.residents
	select(null)
	_grid.remove_building(old)
	old.queue_free()
	_city.crowns -= cost
	var built := place_building(target, old.origin, old.rotation_steps)
	built.residents = residents
	built.set_construction(1)
	# place_building() put it at the end of the order; move it back.
	_grid.all_buildings.erase(built)
	_grid.all_buildings.insert(clampi(place, 0, _grid.all_buildings.size()), built)
	select(built)
	feedback.emit(&"build")
	return true


## Pay to repair the selected building at once, if it is broken and the city
## can afford it.
func repair_selected() -> bool:
	if selected_building == null or not is_instance_valid(selected_building):
		return false
	if selected_building.on_fire:
		# Putting a fire out by hand comes before any repair.
		if not _city.can_afford(CitySim.FIRE_FIGHT_COST):
			feedback.emit(&"error")
			return false
		selected_building.set_on_fire(false)
		_city.crowns -= CitySim.FIRE_FIGHT_COST
		feedback.emit(&"repair")
		selection_changed.emit(selected_building)
		return true
	if not selected_building.broken:
		return false
	if not _city.can_afford(CitySim.REPAIR_COST):
		feedback.emit(&"error")
		return false
	selected_building.set_broken(false)
	_city.crowns -= CitySim.REPAIR_COST  # Also refreshes the HUD.
	feedback.emit(&"repair")
	return true


## Idle-mode click: select the building under the cursor. Roads and empty
## ground deselect.
func _select_at_cursor() -> void:
	var target: Building = _grid.building_at(_cursor.cell) if _cursor.in_bounds else null
	if target != null and target.def.is_road:
		target = null
	select(target)


func start_placing(def: BuildingDef) -> void:
	# Picking something from the menu abandons any move under way.
	_moving = null
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
	feedback.emit(&"demolish")
	return true


func cancel() -> void:
	_moving = null
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
	return _fits(placement_origin())


## True if the building in hand fits with its footprint's corner at
## `origin`. A building being moved may overlap where it stands now.
func _fits(origin: Vector2i) -> bool:
	if _moving == null and _already_built(selected_def):
		return false
	return _grid.can_place(Building.cells_for(selected_def, origin, rotation_steps),
			selected_def, _moving)


## What putting down the building in hand costs: its price, or the smaller
## price of moving it.
func placement_cost() -> int:
	if _moving != null:
		return ceili(selected_def.cost * MOVE_COST_SHARE)
	return selected_def.cost


## Why the selected building cannot be moved; empty if it can.
func move_blocked_reason() -> String:
	if not is_instance_valid(selected_building):
		return "Nothing selected"
	var building := selected_building
	if building.def.is_road or not building.def.demolishable:
		return "Cannot be moved"
	if building.under_construction():
		return "Still being built"
	if building.on_fire:
		return "On fire"
	return ""


## V: pick up the selected building, to put it down somewhere else.
func start_moving() -> void:
	if not move_blocked_reason().is_empty():
		if is_instance_valid(selected_building):
			feedback.emit(&"error")
		return
	var building := selected_building
	start_placing(building.def)
	_moving = building
	rotation_steps = building.rotation_steps
	move_started.emit(building.def, placement_cost())


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
	return fits_here() and _city.can_afford(placement_cost())


## Pay for and place the picked building at the cursor. Stays in placing mode
## so several can be put down in a row.
func try_place() -> bool:
	if not can_place_here():
		feedback.emit(&"error")
		return false
	_city.crowns -= selected_def.cost
	var building := place_building(selected_def, placement_origin(), rotation_steps)
	building.set_construction(selected_def.construction_days())
	var placed: Array[Building] = [building]
	_remember(placed, selected_def.cost)
	feedback.emit(&"build")
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
	building.setup(def, origin, steps, def.is_road and _grid.is_water(origin))
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
	if _row_active:
		_update_row()
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
	var laid: Array[Building] = []
	var spent := 0
	for cell in _drag_cells:
		var one: Array[Vector2i] = [cell]
		var cost := _road_cost(cell)
		if _grid.can_place(one, selected_def) and _city.can_afford(cost):
			_city.crowns -= cost
			laid.append(place_building(selected_def, cell, 0))
			spent += cost
	if not laid.is_empty():
		_remember(laid, spent)
	feedback.emit(&"road" if not laid.is_empty() else &"error")
	_end_drag()


## Note a placement so that it can be undone.
func _remember(buildings: Array[Building], cost: int) -> void:
	_undo_stack.append({"buildings": buildings, "cost": cost, "day": _city.day})
	if _undo_stack.size() > UNDO_DEPTH:
		_undo_stack.pop_front()


## Ctrl+Z: take back the last placement for a full refund. Only what has not
## yet been of any use can be taken back: a building still under
## construction, or road laid today.
func undo() -> void:
	while not _undo_stack.is_empty():
		var entry: Dictionary = _undo_stack.pop_back()
		var buildings: Array = entry["buildings"]
		var fresh := true
		for item: Variant in buildings:
			if not is_instance_valid(item) or item.is_queued_for_deletion():
				fresh = false
				break
			var building: Building = item
			if building.def.is_road:
				fresh = fresh and int(entry["day"]) == _city.day
			else:
				fresh = fresh and building.under_construction()
		if not fresh:
			# Too late for this one; try the placement before it.
			continue
		for item: Variant in buildings:
			var building: Building = item
			if building == selected_building:
				select(null)
			_grid.remove_building(building)
			building.queue_free()
		var cost: int = entry["cost"]
		_city.crowns += cost
		feedback.emit(&"road")
		undone.emit(cost)
		return
	feedback.emit(&"error")
	undone.emit(-1)


## What one tile of the picked road costs here: more on water, where it is
## a bridge.
func _road_cost(cell: Vector2i) -> int:
	return selected_def.water_cost if _grid.is_water(cell) else selected_def.cost


## Press with a building in hand: start a row of them from here. A click
## without dragging is a row of one.
func _begin_row() -> void:
	if not _cursor.in_bounds:
		return
	_dragging = true
	_row_active = true
	_row_start = placement_origin()
	_row_origins = [_row_start]
	_rebuild_row_preview()


func _update_row() -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_row()
		return
	var origins := _row_between(_row_start, placement_origin())
	if origins == _row_origins:
		return
	_row_origins = origins
	_rebuild_row_preview()


## Where the buildings of a row dragged from `start` towards `end` go: side
## by side along whichever way the drag mostly runs. One-per-city buildings
## and a building being moved never make a row.
func _row_between(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var origins: Array[Vector2i] = [start]
	if selected_def.unique or _moving != null:
		return origins
	var footprint := Building.rotated_footprint(selected_def, rotation_steps)
	var delta := end - start
	var along_x := absi(delta.x) >= absi(delta.y)
	var pitch := footprint.x if along_x else footprint.y
	var distance := absi(delta.x) if along_x else absi(delta.y)
	var direction := Vector2i(signi(delta.x), 0) if along_x else Vector2i(0, signi(delta.y))
	@warning_ignore("integer_division")
	for i in range(1, distance / pitch + 1):
		origins.append(start + direction * pitch * i)
	return origins


## One pad per building of the row: green if it will be built, amber if the
## Crowns run out before it, red if it does not fit.
func _rebuild_row_preview() -> void:
	for child in _drag_preview.get_children():
		child.queue_free()
	var footprint := Building.rotated_footprint(selected_def, rotation_steps)
	var budget := _city.crowns
	var cost := placement_cost()
	for origin in _row_origins:
		var pad := MeshInstance3D.new()
		pad.mesh = _drag_tile_mesh
		pad.scale = Vector3(footprint.x, 1.0, footprint.y)
		if not _fits(origin):
			pad.material_override = _drag_blocked_material
		elif budget >= cost:
			budget -= cost
			pad.material_override = _drag_valid_material
		else:
			pad.material_override = _drag_unaffordable_material
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pad.position = CityGrid.cell_to_world(origin) \
				+ Vector3(footprint.x, 0.0, footprint.y) * CityGrid.TILE_SIZE * 0.5 \
				+ Vector3(0.0, PAD_HEIGHT, 0.0)
		_drag_preview.add_child(pad)


## Release: build every building of the row that fits and can be paid for,
## or put down the building being moved.
func _finish_row() -> void:
	var origins := _row_origins.duplicate()
	var cost := placement_cost()
	if _moving != null:
		_finish_move(origins[0], cost)
		return
	var built: Array[Building] = []
	var spent := 0
	for origin in origins:
		if _fits(origin) and _city.can_afford(cost):
			_city.crowns -= cost
			var building := place_building(selected_def, origin, rotation_steps)
			building.set_construction(selected_def.construction_days())
			built.append(building)
			spent += cost
	if not built.is_empty():
		_remember(built, spent)
	feedback.emit(&"build" if not built.is_empty() else &"error")
	_end_drag()


## Put the building being moved down at `origin`, if it fits and the move
## can be paid for. It keeps its place in the building order, and is out of
## use for a day while it is put back together.
func _finish_move(origin: Vector2i, cost: int) -> void:
	var building := _moving
	if not is_instance_valid(building) or not _fits(origin) or not _city.can_afford(cost):
		feedback.emit(&"error")
		_end_drag()
		return
	var steps := rotation_steps
	var place := _grid.all_buildings.find(building)
	_grid.remove_building(building)
	building.relocate(origin, steps)
	_grid.add_building(building)
	_grid.all_buildings.erase(building)
	_grid.all_buildings.insert(clampi(place, 0, _grid.all_buildings.size()), building)
	building.set_construction(1)
	_city.crowns -= cost
	feedback.emit(&"build")
	cancel()
	select(building)


func _end_drag() -> void:
	_row_active = false
	_row_origins = []
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
		var one: Array[Vector2i] = [cell]
		var cost := _road_cost(cell)
		if occupant != null or not _grid.can_place(one, selected_def):
			pad.material_override = _drag_blocked_material
		elif budget >= cost:
			budget -= cost
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
		elif not _city.can_afford(placement_cost()):
			_ghost_material.albedo_color = GHOST_UNAFFORDABLE
		else:
			_ghost_material.albedo_color = GHOST_VALID
	var factor := 1.0
	if _ghost.visible:
		factor = _grid.terrain_factor(selected_def,
				Building.cells_for(selected_def, placement_origin(), rotation_steps))
	if not is_equal_approx(factor, _ghost_bonus):
		_ghost_bonus = factor
		ground_bonus_changed.emit(factor)


## Show how far a building reaches: the one being placed, or failing that
## the one selected. Nothing is shown for buildings with no reach.
func _update_reach() -> void:
	var def: BuildingDef = null
	var origin := Vector2i.ZERO
	var steps := 0
	var placing := mode == Mode.PLACING and _ghost != null and _ghost.visible
	if placing:
		def = selected_def
		origin = placement_origin()
		steps = rotation_steps
	elif mode == Mode.IDLE and is_instance_valid(selected_building):
		def = selected_building.def
		origin = selected_building.origin
		steps = selected_building.rotation_steps
	# Counting what is in reach walks every building, so only redo it when
	# something moved or the map changed.
	var key: Array = [def, origin, steps, _grid.all_buildings.size()]
	if key == _reach_key:
		return
	_reach_key = key

	var note := ""
	var footprint := Rect2i(origin, Building.rotated_footprint(def, steps)) if def != null else Rect2i()
	var effect_reach := 0
	if def != null and (def.calming or def.repairs or def.fights_fire or def.smog_clear_per_day > 0):
		effect_reach = def.effect_range
	_fit_sheet(0, footprint, effect_reach, REACH_EFFECT_TINT)
	if effect_reach > 0 and placing:
		note = _effect_note(def, footprint.grow(effect_reach))
	var value_reach := 0
	if def != null and not is_zero_approx(def.land_value):
		value_reach = def.land_value_range
	_fit_sheet(1, footprint, value_reach, REACH_VALUE_TINT if def != null and def.land_value > 0.0 else REACH_BLIGHT_TINT)
	if value_reach > 0 and placing:
		var homes := _count_in(footprint.grow(value_reach), func(b: Building) -> bool: return b.def.housing > 0)
		var tax_note := "%s of %d homes" % ["Raises tax" if def.land_value > 0.0 else "Lowers tax", homes]
		note = tax_note if note.is_empty() else "%s, %s" % [note, tax_note.to_lower()]
	if note != _reach_note:
		_reach_note = note
		reach_note_changed.emit(note)


## Lay sheet `index` over `footprint` grown by `reach` tiles, or hide it if
## there is no reach.
func _fit_sheet(index: int, footprint: Rect2i, reach: int, tint: Color) -> void:
	var sheet := _reach_sheets[index]
	sheet.visible = reach > 0
	if not sheet.visible:
		return
	var area := footprint.grow(reach).intersection(Rect2i(Vector2i.ZERO, CityGrid.SIZE))
	var size := Vector2(area.size) * CityGrid.TILE_SIZE
	var corner := CityGrid.cell_to_world(area.position)
	sheet.scale = Vector3(size.x, 1.0, size.y)
	sheet.position = corner + Vector3(size.x * 0.5, REACH_HEIGHTS[index], size.y * 0.5)
	(sheet.material_override as StandardMaterial3D).albedo_color = tint


## What a building of kind `def` would do for the buildings inside `area`.
func _effect_note(def: BuildingDef, area: Rect2i) -> String:
	if def.calming:
		return "Calms %d homes" % _count_in(area, func(b: Building) -> bool: return b.def.housing > 0)
	if def.repairs:
		return "Reaches %d machines" % _count_in(area, func(b: Building) -> bool: return b.def.can_break)
	if def.fights_fire:
		return "Protects %d buildings" % _count_in(area,
				func(b: Building) -> bool: return not b.def.is_road and b.def.demolishable)
	return ""


## How many buildings touching `area` pass `test`.
func _count_in(area: Rect2i, test: Callable) -> int:
	var count := 0
	for building in _grid.all_buildings:
		if area.intersects(building.footprint_rect()) and test.call(building):
			count += 1
	return count


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
