class_name Hills
extends MeshInstance3D
## Decorative hills around the map, so the city sits in a valley. The playable
## area stays flat: the mesh has a hole exactly where the map is, and its
## height is zero along that edge, so it joins the flat ground without a seam.

const GROUND_SHADER := preload("res://grid/grid.gdshader")

## World size of the playable map along one side (the map is square).
const MAP_SIZE: float = CityGrid.SIZE.x * CityGrid.TILE_SIZE

## How far the hills reach beyond the map edge, in world units.
@export var reach: float = 240.0
## Size of one mesh square, in world units. Must divide the map size and the
## reach evenly so the mesh lines up with the map edge.
@export var step: float = 4.0
## Flat strip just outside the map before the ground starts to rise.
@export var flat_margin: float = 6.0
## Distance from the map over which the hills reach their full height.
@export var rise_distance: float = 90.0
## Height of the lowest and highest hilltops, in world units.
@export var min_height: float = 6.0
@export var max_height: float = 42.0
## Same number, same hills.
@export var noise_seed: int = 1869

var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.011
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	mesh = _build_mesh()
	# The same grass as the map, without tile lines.
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("line_strength", 0.0)
	material_override = material


## Ground height at a world position: zero on the map and just around it,
## rising into rolling hills further out.
func height_at(x: float, z: float) -> float:
	var outside := Vector2(
			maxf(maxf(-x, x - MAP_SIZE), 0.0),
			maxf(maxf(-z, z - MAP_SIZE), 0.0)).length()
	var rise := smoothstep(flat_margin, flat_margin + rise_distance, outside)
	if rise <= 0.0:
		return 0.0
	var rolling := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	return rise * lerpf(min_height, max_height, rolling)


func _build_mesh() -> ArrayMesh:
	var per_side := roundi((MAP_SIZE + reach * 2.0) / step)
	var row := per_side + 1
	var start := -reach
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in row:
		for xi in row:
			var x := start + xi * step
			var z := start + zi * step
			tool.add_vertex(Vector3(x, height_at(x, z), z))
	for zi in per_side:
		for xi in per_side:
			var x := start + xi * step
			var z := start + zi * step
			# Leave a hole where the flat map is.
			if x >= 0.0 and z >= 0.0 and x + step <= MAP_SIZE and z + step <= MAP_SIZE:
				continue
			var i := zi * row + xi
			tool.add_index(i)
			tool.add_index(i + 1)
			tool.add_index(i + row)
			tool.add_index(i + 1)
			tool.add_index(i + row + 1)
			tool.add_index(i + row)
	tool.generate_normals()
	return tool.commit()
