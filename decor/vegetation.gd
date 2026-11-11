class_name Vegetation
extends Node3D
## Decorative trees, bushes and rocks. Those on the hills never change. Trees
## on the map stand on single tiles and are cleared for good, at no cost, the
## first time something is built on their tile.
##
## Everything is drawn with MultiMeshes: one draw call per kind of plant.

## Same number, same landscape.
@export var plant_seed: int = 1869
## How far beyond the map edge plants are scattered, in world units.
@export var hill_reach: float = 170.0
## Scatter attempts on the hills. About a third become plants.
@export var hill_attempts: int = 6000
## Share of map tiles that get a tree inside the densest woodland.
@export var map_tree_density: float = 0.3
## Tiles around the middle of the map kept clear for the first buildings.
@export var clearing_radius: int = 7

const PINE_COLOR := Color(0.15, 0.29, 0.18)
const LEAF_COLOR := Color(0.31, 0.43, 0.17)
const BUSH_COLOR := Color(0.36, 0.42, 0.2)
const TRUNK_COLOR := Color(0.3, 0.21, 0.14)
const ROCK_COLOR := Color(0.44, 0.42, 0.39)

var _grid: CityGrid
var _rng := RandomNumberGenerator.new()
var _woodland := FastNoiseLite.new()
## Map trees still standing: tile -> [MultiMesh, instance index].
var _map_trees: Dictionary[Vector2i, Array] = {}
var _dirty: bool = false


func setup(grid: CityGrid, hills: Hills) -> void:
	_grid = grid
	_rng.seed = plant_seed
	_woodland.seed = plant_seed
	_woodland.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_woodland.frequency = 0.018

	var pine := _tree_mesh(_cone(1.0, 3.2), 2.4, PINE_COLOR, 1.0)
	var leafy := _tree_mesh(_ball(1.15, 2.3, 8, 5), 2.3, LEAF_COLOR, 1.4)
	var bush := _single_mesh(_ball(0.65, 0.9, 7, 4), 0.3, BUSH_COLOR)
	var rock := _single_mesh(_ball(0.8, 1.0, 5, 3), 0.25, ROCK_COLOR)

	_scatter_on_hills(hills, pine, leafy, bush, rock)
	_scatter_on_map(pine, leafy)
	_grid.buildings_changed.connect(func() -> void: _dirty = true)
	_clear_built_tiles()


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_clear_built_tiles()


## Remove every map tree whose tile now has a building or road on it.
func _clear_built_tiles() -> void:
	for cell: Vector2i in _map_trees.keys():
		if _grid.building_at(cell) == null:
			continue
		var entry: Array = _map_trees[cell]
		var multimesh: MultiMesh = entry[0]
		var index: int = entry[1]
		# A MultiMesh cannot drop one instance; shrink it to nothing instead.
		var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -100.0, 0.0))
		multimesh.set_instance_transform(index, hidden)
		_map_trees.erase(cell)


## How wooded a spot is, from 0 (open) to 1 (dense woodland).
func _woodland_at(x: float, z: float) -> float:
	return smoothstep(-0.05, 0.55, _woodland.get_noise_2d(x, z))


func _scatter_on_hills(hills: Hills, pine: Mesh, leafy: Mesh, bush: Mesh, rock: Mesh) -> void:
	var map_size := Hills.MAP_SIZE
	var pines: Array[Transform3D] = []
	var leafies: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	for i in hill_attempts:
		var x := _rng.randf_range(-hill_reach, map_size + hill_reach)
		var z := _rng.randf_range(-hill_reach, map_size + hill_reach)
		# Keep off the map and a narrow strip around it.
		if x > -2.0 and z > -2.0 and x < map_size + 2.0 and z < map_size + 2.0:
			continue
		var y := hills.height_at(x, z)
		var wooded := _woodland_at(x, z)
		var roll := _rng.randf()
		if roll < 0.06:
			rocks.append(_placement(x, y, z, 0.6, 1.8, true))
		elif roll < 0.16:
			bushes.append(_placement(x, y, z, 0.7, 1.5, true))
		elif _rng.randf() < wooded:
			# Pines take the high ground, leafy trees the valley floor.
			var pine_share := clampf(y / 30.0, 0.15, 0.85)
			if _rng.randf() < pine_share:
				pines.append(_placement(x, y, z, 0.8, 1.6, false))
			else:
				leafies.append(_placement(x, y, z, 0.8, 1.5, false))
	_add_multimesh(pine, pines)
	_add_multimesh(leafy, leafies)
	_add_multimesh(bush, bushes)
	_add_multimesh(rock, rocks)


func _scatter_on_map(pine: Mesh, leafy: Mesh) -> void:
	var centre := CityGrid.SIZE / 2
	var pine_cells: Array[Vector2i] = []
	var leafy_cells: Array[Vector2i] = []
	var pines: Array[Transform3D] = []
	var leafies: Array[Transform3D] = []
	for cy in CityGrid.SIZE.y:
		for cx in CityGrid.SIZE.x:
			var cell := Vector2i(cx, cy)
			if maxi(absi(cx - centre.x), absi(cy - centre.y)) <= clearing_radius:
				continue
			var pos := CityGrid.cell_center(cell)
			if _rng.randf() >= _woodland_at(pos.x, pos.z) * map_tree_density:
				continue
			# Small enough, and close enough to the tile's middle, to stay
			# inside its own tile.
			var x := pos.x + _rng.randf_range(-0.25, 0.25)
			var z := pos.z + _rng.randf_range(-0.25, 0.25)
			if _rng.randf() < 0.35:
				pine_cells.append(cell)
				pines.append(_placement(x, 0.0, z, 0.55, 0.75, false))
			else:
				leafy_cells.append(cell)
				leafies.append(_placement(x, 0.0, z, 0.5, 0.65, false))
	_remember_map_trees(_add_multimesh(pine, pines), pine_cells)
	_remember_map_trees(_add_multimesh(leafy, leafies), leafy_cells)


func _remember_map_trees(multimesh: MultiMesh, cells: Array[Vector2i]) -> void:
	for i in cells.size():
		_map_trees[cells[i]] = [multimesh, i]


## A random turn and size at a position. `squash` also varies the height on
## its own, for bushes and rocks.
func _placement(x: float, y: float, z: float, min_scale: float, max_scale: float,
		squash: bool) -> Transform3D:
	var size := _rng.randf_range(min_scale, max_scale)
	var height := size * (_rng.randf_range(0.6, 1.1) if squash else _rng.randf_range(0.9, 1.2))
	var turn := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
	return Transform3D(turn.scaled(Vector3(size, height, size)), Vector3(x, y, z))


func _add_multimesh(mesh: Mesh, transforms: Array[Transform3D]) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	add_child(instance)
	return multimesh


## A trunk with a crown on top, as one mesh with two surfaces.
func _tree_mesh(crown: Mesh, crown_y: float, crown_color: Color, trunk_height: float) -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14
	trunk.bottom_radius = 0.2
	trunk.height = trunk_height
	trunk.radial_segments = 6
	trunk.rings = 1
	var mesh := ArrayMesh.new()
	_add_surface(mesh, trunk, trunk_height / 2.0, TRUNK_COLOR)
	_add_surface(mesh, crown, crown_y, crown_color)
	return mesh


func _single_mesh(shape: Mesh, y: float, color: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_add_surface(mesh, shape, y, color)
	return mesh


## Copy a primitive into `mesh` as a new surface, lifted by `y`.
func _add_surface(mesh: ArrayMesh, shape: Mesh, y: float, color: Color) -> void:
	var tool := SurfaceTool.new()
	tool.append_from(shape, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.0)))
	tool.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1,
			BuildingMeshFactory.get_material(color))


func _cone(radius: float, height: float) -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 7
	cone.rings = 1
	return cone


func _ball(radius: float, height: float, segments: int, rings: int) -> SphereMesh:
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = height
	ball.radial_segments = segments
	ball.rings = rings
	return ball
