class_name BuildingMeshFactory
extends RefCounted
## Assembles building models from boxes, cylinders, prisms and capsules.
##
## Every model is built around the local origin: centred on its footprint,
## standing on y = 0, with its front (door side) facing local +Z.
## Colours go in `material_override`; tints (ghost, demolish highlight) are
## applied separately through `material_overlay`, so they never clash.

## Gap left between the model and the edge of its footprint, in world units.
const MARGIN := 0.15
## Thickness of a road slab, in world units.
const ROAD_HEIGHT := 0.1

const BRASS := Color(0.78, 0.6, 0.25)
const SOOT := Color(0.13, 0.12, 0.12)
const DARK_BRICK := Color(0.35, 0.2, 0.17)
const SLATE := Color(0.25, 0.26, 0.3)
const WOOD := Color(0.4, 0.28, 0.18)
const PAVING := Color(0.3, 0.29, 0.27)
const PLASTER := Color(0.9, 0.87, 0.8)
const STONE := Color(0.6, 0.58, 0.54)
const TERRACOTTA := Color(0.62, 0.36, 0.26)
const WINDOW_GLOW := Color(1.0, 0.82, 0.45)
const WINDOW_DARK := Color(0.11, 0.13, 0.17)
## Metadata key set on every window pane, so a Building can find its windows.
const WINDOW_META := &"window"
const IRON := Color(0.15, 0.2, 0.19)
const STEEL := Color(0.5, 0.51, 0.54)
const SOIL := Color(0.24, 0.17, 0.12)
const LEAF := Color(0.27, 0.5, 0.22)
const GRAVEL := Color(0.72, 0.66, 0.52)

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
		BuildingDef.Style.TOWN_HALL:
			_town_hall(root, w, d, def.color)
		BuildingDef.Style.ROAD:
			# Full tile, no margin, so neighbouring road tiles join up.
			_box(root, Vector3(w + MARGIN * 2.0, ROAD_HEIGHT, d + MARGIN * 2.0),
					Vector3(0.0, ROAD_HEIGHT * 0.5, 0.0), def.color)
		_:
			_box(root, Vector3(w, 2.0, d), Vector3(0.0, 1.0, 0.0), def.color)
	return root


# --- Models -----------------------------------------------------------------

static func _tenement(root: Node3D, w: float, d: float, color: Color) -> void:
	# Two-storey brick terrace: stone plinth, string course between the
	# floors, lit windows on every side, gabled slate roof, two chimneys.
	var bw := w - 0.3
	var bd := d - 0.3
	var base := 0.3
	var h := 3.4
	var top := base + h
	_box(root, Vector3(bw + 0.15, base, bd + 0.15), Vector3(0.0, base * 0.5, 0.0), STONE)
	_box(root, Vector3(bw, h, bd), Vector3(0.0, base + h * 0.5, 0.0), color)
	_box(root, Vector3(bw + 0.08, 0.12, bd + 0.08), Vector3(0.0, base + h * 0.5, 0.0), STONE)
	# Roof: eaves slab, then a gable with its ridge running front to back.
	_box(root, Vector3(bw + 0.3, 0.15, bd + 0.3), Vector3(0.0, top + 0.075, 0.0), SLATE.darkened(0.2))
	_prism(root, Vector3(bw + 0.3, 1.3, bd + 0.3), Vector3(0.0, top + 0.8, 0.0), SLATE)
	for side: float in [-1.0, 1.0]:
		var x := side * bw * 0.3
		_box(root, Vector3(0.45, 1.5, 0.45), Vector3(x, top + 0.9, -bd * 0.22), DARK_BRICK)
		_cylinder(root, 0.13, 0.3, Vector3(x, top + 1.8, -bd * 0.22), TERRACOTTA)
	# Windows: three per floor, except where the front door is.
	var pane := Vector2(0.5, 0.75)
	var upper := base + h * 0.75
	var lower := base + h * 0.3
	var front := bd * 0.5 + 0.02
	var flank := bw * 0.5 + 0.02
	_windows_z(root, 3, bw, upper, front, pane)
	_windows_z(root, 3, bw, upper, -front, pane)
	_windows_z(root, 3, bw, lower, -front, pane)
	for side: float in [-1.0, 1.0]:
		_windows_x(root, 3, bd, upper, side * flank, pane)
		_windows_x(root, 3, bd, lower, side * flank, pane)
		_window(root, Vector3(pane.x, pane.y, 0.08), Vector3(side * bw / 3.0, lower, front))
	# Front door with a stone lintel and step.
	_box(root, Vector3(0.7, 1.3, 0.1), Vector3(0.0, base + 0.65, front), WOOD)
	_box(root, Vector3(0.95, 0.14, 0.14), Vector3(0.0, base + 1.37, front), STONE)
	_box(root, Vector3(1.0, 0.15, 0.2), Vector3(0.0, 0.075, bd * 0.5 + 0.1), STONE)


static func _glasshouse(root: Node3D, w: float, d: float, color: Color) -> void:
	# Iron-framed glasshouse on a brick footing, with planting beds showing
	# through the glass and a heating pipe at the back.
	var gw := w - 0.4
	var gd := d - 0.4
	var base := 0.5
	var wall := 1.3
	var rise := 1.0
	var eaves := base + wall
	var ridge := eaves + rise
	_box(root, Vector3(gw + 0.1, base, gd + 0.1), Vector3(0.0, base * 0.5, 0.0), DARK_BRICK)
	# Beds and crops inside.
	for side: float in [-1.0, 1.0]:
		var bed_x := side * gw * 0.24
		_box(root, Vector3(gw * 0.3, 0.2, gd - 0.6), Vector3(bed_x, base + 0.1, 0.0), SOIL)
		_box(root, Vector3(gw * 0.24, 0.4, gd - 0.8), Vector3(bed_x, base + 0.4, 0.0), LEAF)
	# Glass walls and gabled glass roof.
	_glass(_box(root, Vector3(gw, wall, gd), Vector3(0.0, base + wall * 0.5, 0.0), color), color)
	var roof_color := color.lightened(0.2)
	_glass(_prism(root, Vector3(gw, rise, gd), Vector3(0.0, eaves + rise * 0.5, 0.0), roof_color),
			roof_color)
	# Iron frame: posts along the long sides, eaves rails, ridge beam, rafters.
	var bays := maxi(2, roundi(gd / 1.1))
	var slope := atan2(rise, gw * 0.5)
	var rafter := sqrt(rise * rise + gw * gw * 0.25)
	for i in bays + 1:
		var z := -gd * 0.5 + gd * i / bays
		for side: float in [-1.0, 1.0]:
			_box(root, Vector3(0.09, wall, 0.09), Vector3(side * gw * 0.5, base + wall * 0.5, z), IRON)
			var beam := _box(root, Vector3(rafter, 0.07, 0.07),
					Vector3(side * gw * 0.25, eaves + rise * 0.5, z), IRON)
			beam.rotation.z = -side * slope
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.1, 0.1, gd + 0.1), Vector3(side * gw * 0.5, eaves, 0.0), IRON)
		_box(root, Vector3(gw, 0.1, 0.1), Vector3(0.0, eaves, side * gd * 0.5), IRON)
		_cylinder(root, 0.07, 0.4, Vector3(0.0, ridge + 0.2, side * gd * 0.5), BRASS, 0.7)
	_box(root, Vector3(0.1, 0.1, gd + 0.1), Vector3(0.0, ridge, 0.0), IRON)
	# Door at the front, heating pipe with a brass cap at the back.
	_box(root, Vector3(0.7, 1.3, 0.1), Vector3(0.0, 0.65, gd * 0.5 + 0.04), WOOD)
	var pipe_pos := Vector3(-gw * 0.5 - 0.08, 0.0, -gd * 0.5 + 0.5)
	_cylinder(root, 0.11, 2.9, pipe_pos + Vector3(0.0, 1.45, 0.0), SOOT)
	_cylinder(root, 0.16, 0.2, pipe_pos + Vector3(0.0, 3.0, 0.0), BRASS, 0.7)


static func _coal_pit(root: Node3D, w: float, d: float, color: Color) -> void:
	# Timber headframe with a spoked winding wheel over a stone-lined shaft,
	# a brick engine house with a chimney, cart rails and coal heaps.
	var ground := 0.2
	_box(root, Vector3(w, ground, d), Vector3(0.0, ground * 0.5, 0.0), color)
	# Shaft.
	var shaft := Vector3(-w * 0.18, 0.0, -d * 0.12)
	_cylinder(root, 0.72, 0.25, shaft + Vector3(0.0, ground + 0.125, 0.0), STONE)
	_cylinder(root, 0.55, 0.27, shaft + Vector3(0.0, ground + 0.135, 0.0), Color(0.03, 0.03, 0.03))
	# Headframe: four posts, two rings of cross beams, a deck on top.
	var half := 0.75
	var frame_h := 4.2
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box(root, Vector3(0.22, frame_h, 0.22),
				shaft + Vector3(corner.x * half, ground + frame_h * 0.5, corner.y * half), WOOD)
	for level: float in [1.5, 3.0]:
		for side: float in [-1.0, 1.0]:
			_box(root, Vector3(half * 2.0, 0.16, 0.16),
					shaft + Vector3(0.0, ground + level, side * half), WOOD)
			_box(root, Vector3(0.16, 0.16, half * 2.0),
					shaft + Vector3(side * half, ground + level, 0.0), WOOD)
	var deck := ground + frame_h
	_box(root, Vector3(half * 2.0 + 0.4, 0.15, half * 2.0 + 0.4), shaft + Vector3(0.0, deck + 0.075, 0.0), WOOD)
	# Winding wheel: rim, spokes and hub, held between two bearing blocks.
	var wheel := shaft + Vector3(0.0, deck + 1.05, 0.0)
	var rim := _torus(root, 0.68, 0.82, wheel, BRASS, 0.7)
	rim.rotation.x = PI * 0.5
	for i in 3:
		var spoke := _box(root, Vector3(1.4, 0.07, 0.07), wheel, BRASS, 0.7)
		spoke.rotation.z = PI * i / 3.0
	var hub := _cylinder(root, 0.14, 0.5, wheel, SOOT)
	hub.rotation.x = PI * 0.5
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.3, 1.1, 0.14), shaft + Vector3(0.0, deck + 0.7, side * 0.28), WOOD)
	# Engine house.
	var house := Vector3(w * 0.27, 0.0, -d * 0.3)
	_box(root, Vector3(1.8, 1.8, 1.6), house + Vector3(0.0, ground + 0.9, 0.0), DARK_BRICK)
	_prism(root, Vector3(2.0, 0.7, 1.8), house + Vector3(0.0, ground + 2.15, 0.0), SLATE)
	_box(root, Vector3(0.6, 1.1, 0.08), house + Vector3(-0.4, ground + 0.55, 0.82), WOOD)
	_window(root, Vector3(0.45, 0.5, 0.08), house + Vector3(0.45, ground + 1.1, 0.82))
	var stack := house + Vector3(0.6, 0.0, -0.5)
	_cylinder(root, 0.24, 3.6, stack + Vector3(0.0, ground + 1.8, 0.0), DARK_BRICK, 0.0, 0.16)
	_cylinder(root, 0.2, 0.15, stack + Vector3(0.0, ground + 3.65, 0.0), SOOT)
	# Rails from the shaft to the front, with a loaded cart.
	var rail_len := d * 0.5 - shaft.z - 0.9
	var rail_z := shaft.z + 0.9 + rail_len * 0.5
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.06, 0.06, rail_len), Vector3(shaft.x + side * 0.22, ground + 0.03, rail_z), STEEL, 0.6)
	var cart := Vector3(shaft.x, ground, d * 0.3)
	_box(root, Vector3(0.6, 0.35, 0.8), cart + Vector3(0.0, 0.3, 0.0), IRON)
	_box(root, Vector3(0.5, 0.15, 0.7), cart + Vector3(0.0, 0.52, 0.0), SOOT)
	# Coal heaps.
	_cylinder(root, 1.1, 1.2, Vector3(w * 0.25, ground + 0.6, d * 0.25), SOOT, 0.0, 0.0)
	_cylinder(root, 0.6, 0.7, Vector3(w * 0.04, ground + 0.35, d * 0.38), SOOT, 0.0, 0.0)


static func _brassworks(root: Node3D, w: float, d: float, color: Color) -> void:
	# Brick foundry hall with a sawtooth roof and two tall chimneys at the
	# back; a paved yard at the front with a brass boiler piped into the hall.
	var ground := 0.15
	_box(root, Vector3(w, ground, d), Vector3(0.0, ground * 0.5, 0.0), PAVING)
	var bw := w - 0.3
	var hd := d * 0.58
	var hall_z := -d * 0.5 + 0.15 + hd * 0.5
	var front := hall_z + hd * 0.5
	var h := 3.4
	var top := ground + h
	_box(root, Vector3(bw, h, hd), Vector3(0.0, ground + h * 0.5, hall_z), color)
	_box(root, Vector3(bw + 0.12, 0.2, hd + 0.12), Vector3(0.0, top - 0.1, hall_z), STONE)
	# Sawtooth roof: three teeth, each with a glazed upright face.
	var teeth := 3
	var tooth_w := bw / teeth
	for i in teeth:
		var left := -bw * 0.5 + tooth_w * i
		var tooth := _prism(root, Vector3(tooth_w, 0.9, hd), Vector3(left + tooth_w * 0.5, top + 0.45, hall_z), SLATE)
		(tooth.mesh as PrismMesh).left_to_right = 0.0
		_window(root, Vector3(0.06, 0.55, hd - 0.5), Vector3(left - 0.02, top + 0.45, hall_z))
	# Chimneys with a stone band and a brass cap.
	for side: float in [-1.0, 1.0]:
		var stack := Vector3(side * bw * 0.3, 0.0, hall_z - hd * 0.3)
		_cylinder(root, 0.5, 7.5, stack + Vector3(0.0, 3.75, 0.0), DARK_BRICK, 0.0, 0.32)
		_cylinder(root, 0.4, 0.25, stack + Vector3(0.0, 6.4, 0.0), STONE)
		_cylinder(root, 0.37, 0.3, stack + Vector3(0.0, 7.6, 0.0), BRASS, 0.7)
	# Windows and the loading door.
	var pane := Vector2(0.6, 1.2)
	for side: float in [-1.0, 1.0]:
		_windows_x(root, 4, hd, ground + 1.9, side * (bw * 0.5 + 0.02), pane, hall_z)
	_windows_z(root, 4, bw, ground + 1.9, hall_z - hd * 0.5 - 0.02, pane)
	_windows_z(root, 4, bw, ground + 2.85, front + 0.02, Vector2(0.5, 0.55))
	var door_x := w * 0.22
	_box(root, Vector3(1.7, 2.3, 0.1), Vector3(door_x, ground + 1.15, front + 0.03), WOOD)
	_box(root, Vector3(1.95, 0.16, 0.14), Vector3(door_x, ground + 2.38, front + 0.03), STONE)
	# Boiler on stone saddles, with iron bands, a dome and a pipe to the hall.
	var boiler_pos := Vector3(-w * 0.2, ground + 1.0, front + (d * 0.5 - front) * 0.47)
	var boiler := _capsule(root, 0.7, 3.0, boiler_pos, BRASS, 0.7)
	boiler.rotation.z = PI * 0.5
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.3, 0.5, 1.2), Vector3(boiler_pos.x + side * 0.8, ground + 0.25, boiler_pos.z), STONE)
		var band := _cylinder(root, 0.73, 0.1, boiler_pos + Vector3(side * 0.8, 0.0, 0.0), IRON)
		band.rotation.z = PI * 0.5
	_cylinder(root, 0.25, 0.3, boiler_pos + Vector3(0.6, 0.75, 0.0), BRASS, 0.7)
	var pipe_x := boiler_pos.x - 0.5
	var pipe_top := ground + 2.9
	_cylinder(root, 0.1, pipe_top - boiler_pos.y, Vector3(pipe_x, (pipe_top + boiler_pos.y) * 0.5, boiler_pos.z), BRASS, 0.7)
	var run := _cylinder(root, 0.1, boiler_pos.z - front + 0.2,
			Vector3(pipe_x, pipe_top, (boiler_pos.z + front) * 0.5), BRASS, 0.7)
	run.rotation.x = PI * 0.5
	# Brass ingots and crates in the yard.
	var ingots := Vector3(w * 0.3, ground, d * 0.5 - 0.9)
	_box(root, Vector3(0.7, 0.18, 0.3), ingots + Vector3(-0.2, 0.09, 0.0), BRASS, 0.7)
	_box(root, Vector3(0.7, 0.18, 0.3), ingots + Vector3(0.2, 0.09, 0.35), BRASS, 0.7)
	_box(root, Vector3(0.7, 0.18, 0.3), ingots + Vector3(0.0, 0.27, 0.15), BRASS, 0.7)
	_box(root, Vector3(0.6, 0.6, 0.6), Vector3(w * 0.5 - 0.45, ground + 0.3, front + 0.5), WOOD)
	_box(root, Vector3(0.45, 0.45, 0.45), Vector3(w * 0.5 - 0.5, ground + 0.225, front + 1.15), WOOD.lightened(0.15))


static func _mechanic_yard(root: Node3D, w: float, d: float, color: Color) -> void:
	# Paved yard: a workshop with an open doorway in the back-left corner,
	# two meshing gears on stands, a crane and a stack of pipes.
	var ground := 0.15
	_box(root, Vector3(w, ground, d), Vector3(0.0, ground * 0.5, 0.0), PAVING)
	# Workshop.
	var sw := w * 0.58
	var sd := d * 0.55
	var shed := Vector3(-w * 0.5 + sw * 0.5 + 0.05, 0.0, -d * 0.5 + sd * 0.5 + 0.05)
	var shed_top := ground + 2.0
	var shed_front := shed.z + sd * 0.5 + 0.03
	_box(root, Vector3(sw, 2.0, sd), shed + Vector3(0.0, ground + 1.0, 0.0), color)
	_prism(root, Vector3(sw + 0.2, 0.7, sd + 0.2), shed + Vector3(0.0, shed_top + 0.35, 0.0), SLATE)
	_box(root, Vector3(1.0, 1.4, 0.08), Vector3(shed.x - 0.35, ground + 0.7, shed_front), SOOT)
	_window(root, Vector3(0.45, 0.5, 0.08), Vector3(shed.x + 0.6, ground + 1.3, shed_front))
	_cylinder(root, 0.08, 1.3, shed + Vector3(sw * 0.3, shed_top + 0.6, -sd * 0.2), SOOT)
	# Gears.
	var big := Vector3(w * 0.22, ground + 0.95, d * 0.28)
	var small := big + Vector3(-0.86, 0.86, 0.0)
	_box(root, Vector3(0.25, 0.95, 0.3), Vector3(big.x, ground + 0.475, big.z - 0.25), IRON)
	_box(root, Vector3(0.15, small.y - ground, 0.15), Vector3(small.x, (small.y + ground) * 0.5, small.z - 0.25), IRON)
	_gear(root, big, 0.7, 10, BRASS)
	_gear(root, small, 0.4, 6, STEEL)
	# Crane in the back-right corner, reaching forward.
	var crane := Vector3(w * 0.36, 0.0, -d * 0.3)
	_box(root, Vector3(0.2, 2.6, 0.2), crane + Vector3(0.0, ground + 1.3, 0.0), IRON)
	_box(root, Vector3(0.14, 0.14, 1.5), crane + Vector3(0.0, ground + 2.55, 0.6), IRON)
	_cylinder(root, 0.02, 1.0, crane + Vector3(0.0, ground + 2.05, 1.25), SOOT)
	_box(root, Vector3(0.16, 0.2, 0.16), crane + Vector3(0.0, ground + 1.5, 1.25), BRASS, 0.7)
	# Pipes stacked at the front left.
	var pipes := Vector3(-w * 0.3, ground, d * 0.32)
	for offset: Vector3 in [Vector3(0.0, 0.11, -0.12), Vector3(0.0, 0.11, 0.12), Vector3(0.0, 0.3, 0.0)]:
		var pipe := _cylinder(root, 0.11, 1.3, pipes + offset, BRASS, 0.7)
		pipe.rotation.z = PI * 0.5


static func _tea_garden(root: Node3D, w: float, d: float, color: Color) -> void:
	# Hedged lawn with a gravel path leading to an open pavilion, trees at
	# the back and flower beds by the entrance.
	var lawn := 0.15
	_box(root, Vector3(w, lawn, d), Vector3(0.0, lawn * 0.5, 0.0), color)
	# Hedge all round, with a gap at the front for the entrance.
	var hedge := color.darkened(0.35)
	var hedge_y := lawn + 0.25
	var gap := 1.0
	var half_run := (w - gap) * 0.5
	_box(root, Vector3(w, 0.5, 0.3), Vector3(0.0, hedge_y, -d * 0.5 + 0.15), hedge)
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.3, 0.5, d), Vector3(side * (w * 0.5 - 0.15), hedge_y, 0.0), hedge)
		_box(root, Vector3(half_run, 0.5, 0.3),
				Vector3(side * (gap + half_run) * 0.5, hedge_y, d * 0.5 - 0.15), hedge)
	_box(root, Vector3(gap * 0.8, 0.03, d * 0.5), Vector3(0.0, lawn + 0.015, d * 0.25), GRAVEL)
	# Pavilion: stone floor, six slim posts, conical roof, a tea table inside.
	var floor_top := lawn + 0.15
	_cylinder(root, 0.95, 0.15, Vector3(0.0, lawn + 0.075, 0.0), STONE)
	for i in 6:
		var angle := TAU * i / 6.0 + TAU / 12.0
		_cylinder(root, 0.05, 1.1, Vector3(cos(angle) * 0.78, floor_top + 0.55, sin(angle) * 0.78), PLASTER)
	_cylinder(root, 1.15, 0.7, Vector3(0.0, floor_top + 1.45, 0.0), Color(0.6, 0.25, 0.2), 0.0, 0.0)
	_cylinder(root, 0.04, 0.35, Vector3(0.0, floor_top + 1.95, 0.0), BRASS, 0.7)
	_cylinder(root, 0.28, 0.4, Vector3(0.0, floor_top + 0.2, 0.0), WOOD)
	_cylinder(root, 0.1, 0.16, Vector3(0.0, floor_top + 0.48, 0.0), BRASS, 0.7)
	# Trees in the back corners, flower beds in the front ones.
	var petals: Array[Color] = [Color(0.85, 0.45, 0.55), Color(0.9, 0.78, 0.35)]
	for side: float in [-1.0, 1.0]:
		var x := side * w * 0.3
		_cylinder(root, 0.1, 0.9, Vector3(x, lawn + 0.45, -d * 0.3), WOOD)
		_capsule(root, 0.45, 1.2, Vector3(x, lawn + 1.3, -d * 0.3), color.darkened(0.2))
		_box(root, Vector3(0.7, 0.12, 0.5), Vector3(x, lawn + 0.06, d * 0.27), SOIL)
		for n in 3:
			_capsule(root, 0.1, 0.24, Vector3(x - 0.22 + n * 0.22, lawn + 0.22, d * 0.27),
					petals[(n + int(side > 0.0)) % 2])


static func _town_hall(root: Node3D, w: float, d: float, color: Color) -> void:
	# Civic hall on a stone platform: columned portico with a pediment at the
	# front, tall windows, gabled roof and a four-faced clock tower.
	var base := 0.4
	var h := 3.6
	var bw := w - 0.6
	var bd := d - 1.4
	# The hall sits towards the back, leaving room for the portico.
	var bz := -0.4
	var top := base + h
	var front := bz + bd * 0.5
	_box(root, Vector3(w, base, d), Vector3(0.0, base * 0.5, 0.0), STONE)
	_box(root, Vector3(bw, h, bd), Vector3(0.0, base + h * 0.5, bz), color)
	_box(root, Vector3(bw + 0.2, 0.25, bd + 0.2), Vector3(0.0, top + 0.125, bz), STONE)
	_prism(root, Vector3(bw + 0.2, 1.2, bd + 0.2), Vector3(0.0, top + 0.85, bz), SLATE)
	# Corner pilasters.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box(root, Vector3(0.35, h, 0.35),
				Vector3(corner.x * bw * 0.5, base + h * 0.5, bz + corner.y * bd * 0.5), STONE)
	# Portico: four columns carrying a beam and a pediment.
	var porch_z := front + 0.45
	for x: float in [-1.8, -0.6, 0.6, 1.8]:
		_cylinder(root, 0.17, 2.8, Vector3(x, base + 1.4, front + 0.75), PLASTER)
	_box(root, Vector3(4.3, 0.3, 0.9), Vector3(0.0, base + 2.95, porch_z), STONE)
	_prism(root, Vector3(4.3, 0.8, 0.9), Vector3(0.0, base + 3.5, porch_z), STONE)
	_box(root, Vector3(1.3, 2.1, 0.1), Vector3(0.0, base + 1.05, front + 0.03), WOOD)
	# Tall windows.
	var pane := Vector2(0.6, 1.5)
	var sill := base + h * 0.55
	for side: float in [-1.0, 1.0]:
		_window(root, Vector3(pane.x, pane.y, 0.08), Vector3(side * 1.9, sill, front + 0.02))
		_windows_x(root, 3, bd, sill, side * (bw * 0.5 + 0.02), pane, bz)
	_windows_z(root, 4, bw, sill, bz - bd * 0.5 - 0.02, pane)
	# Clock tower rising through the roof, with a brass spire.
	var tower := 1.7
	var tower_h := 5.4
	var tower_top := top + tower_h
	_box(root, Vector3(tower, tower_h, tower), Vector3(0.0, top + tower_h * 0.5, bz), color)
	_box(root, Vector3(tower + 0.25, 0.2, tower + 0.25), Vector3(0.0, tower_top + 0.1, bz), STONE)
	var clock_y := tower_top - 1.0
	var reach := tower * 0.5 + 0.03
	for side: float in [-1.0, 1.0]:
		var rim_z := _cylinder(root, 0.6, 0.08, Vector3(0.0, clock_y, bz + side * reach), BRASS, 0.7)
		rim_z.rotation.x = PI * 0.5
		var dial_z := _cylinder(root, 0.5, 0.12, Vector3(0.0, clock_y, bz + side * reach), PLASTER)
		dial_z.rotation.x = PI * 0.5
		var rim_x := _cylinder(root, 0.6, 0.08, Vector3(side * reach, clock_y, bz), BRASS, 0.7)
		rim_x.rotation.z = PI * 0.5
		var dial_x := _cylinder(root, 0.5, 0.12, Vector3(side * reach, clock_y, bz), PLASTER)
		dial_x.rotation.z = PI * 0.5
	# Hands on the front dial.
	_box(root, Vector3(0.06, 0.4, 0.04), Vector3(0.0, clock_y + 0.17, bz + reach + 0.07), SOOT)
	_box(root, Vector3(0.28, 0.06, 0.04), Vector3(0.12, clock_y, bz + reach + 0.07), SOOT)
	_cylinder(root, 1.1, 2.2, Vector3(0.0, tower_top + 1.3, bz), BRASS, 0.7, 0.0)
	_cylinder(root, 0.05, 0.9, Vector3(0.0, tower_top + 2.7, bz), BRASS, 0.7)


# --- Primitive helpers --------------------------------------------------------
# `center` is the middle of the shape, in the model's local space.

static func _box(root: Node3D, size: Vector3, center: Vector3, color: Color,
		metallic: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(root, mesh, center, color, metallic)


## A triangular prism (gable roof): `size.x` wide, `size.y` tall, with the
## ridge running along Z for `size.z`.
static func _prism(root: Node3D, size: Vector3, center: Vector3, color: Color) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _add(root, mesh, center, color, 0.0)


## A ring lying flat (its hole points up) until rotated.
static func _torus(root: Node3D, inner_radius: float, outer_radius: float, center: Vector3,
		color: Color, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 24
	mesh.ring_segments = 8
	return _add(root, mesh, center, color, metallic)


## An upright toothed gear facing along Z.
static func _gear(root: Node3D, center: Vector3, radius: float, teeth: int, color: Color) -> void:
	# Every part is a direct child of the model: tints and the placement
	# ghost only reach direct children.
	var disc := _cylinder(root, radius, 0.22, center, color, 0.7)
	disc.rotation.x = PI * 0.5
	var hub := _cylinder(root, radius * 0.3, 0.36, center, SOOT)
	hub.rotation.x = PI * 0.5
	var tooth_size := radius * 0.32
	for i in teeth:
		var angle := TAU * i / teeth
		var tooth := _box(root, Vector3(tooth_size, tooth_size, 0.22),
				center + Vector3(cos(angle), sin(angle), 0.0) * (radius + tooth_size * 0.3),
				color, 0.7)
		tooth.rotation.z = angle


## Turn a part see-through, like glass.
static func _glass(part: MeshInstance3D, color: Color) -> void:
	part.material_override = get_glass_material(color)


## One lit window pane.
static func _window(root: Node3D, size: Vector3, center: Vector3) -> MeshInstance3D:
	var pane := _box(root, size, center, WINDOW_GLOW)
	pane.material_override = get_glow_material(WINDOW_GLOW)
	pane.set_meta(WINDOW_META, true)
	return pane


## A row of `count` windows spread evenly along X across `span`, on a wall
## that faces along Z at depth `z`.
static func _windows_z(root: Node3D, count: int, span: float, y: float, z: float,
		pane: Vector2) -> void:
	for i in count:
		var x := (i + 0.5) / count * span - span * 0.5
		_window(root, Vector3(pane.x, pane.y, 0.08), Vector3(x, y, z))


## The same along Z, on a wall that faces along X at `x`. `z_offset` moves
## the whole row.
static func _windows_x(root: Node3D, count: int, span: float, y: float, x: float,
		pane: Vector2, z_offset: float = 0.0) -> void:
	for i in count:
		var z := (i + 0.5) / count * span - span * 0.5 + z_offset
		_window(root, Vector3(0.08, pane.y, pane.x), Vector3(x, y, z))


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
	instance.material_override = get_material(color, metallic)
	root.add_child(instance)
	return instance


## Shared, cached material for a colour. Do not modify the returned material.
static func get_material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), metallic]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.45 if metallic > 0.0 else 0.9
	_materials[key] = mat
	return mat


## Shared, cached material that glows faintly in its own colour, for lit
## windows. Do not modify the returned material.
static func get_glow_material(color: Color) -> StandardMaterial3D:
	var key := "glow|%s" % color.to_html()
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	_materials[key] = mat
	return mat


## Shared, cached see-through material for glazing. Do not modify the
## returned material.
static func get_glass_material(color: Color) -> StandardMaterial3D:
	var key := "glass|%s" % color.to_html()
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	_materials[key] = mat
	return mat
