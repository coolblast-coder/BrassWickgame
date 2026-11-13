class_name SeasonView
extends Node
## Dresses the landscape for the season: the colour of the grass and of the
## trees, and snow in winter. It follows the calendar from the first day,
## whether or not the seasons affect the rules yet.

## Seconds a change of season takes to fade in.
const FADE_SECONDS := 5.0

## The look of each season, in the order of Seasons.Season:
## [grass, dry grass, snow cover 0 to 1, leafy trees, bushes, pines].
const LOOKS: Array[Array] = [
	[Color(0.31, 0.43, 0.2), Color(0.46, 0.46, 0.26), 0.0,
			Color(0.4, 0.55, 0.22), Color(0.4, 0.5, 0.24), Color(0.16, 0.31, 0.19)],
	[Color(0.29, 0.36, 0.19), Color(0.5, 0.45, 0.25), 0.0,
			Color(0.31, 0.43, 0.17), Color(0.36, 0.42, 0.2), Color(0.15, 0.29, 0.18)],
	[Color(0.36, 0.35, 0.18), Color(0.52, 0.41, 0.22), 0.0,
			Color(0.75, 0.45, 0.16), Color(0.55, 0.4, 0.18), Color(0.15, 0.27, 0.17)],
	[Color(0.34, 0.33, 0.2), Color(0.47, 0.4, 0.26), 0.85,
			Color(0.46, 0.4, 0.36), Color(0.5, 0.47, 0.42), Color(0.3, 0.42, 0.36)],
]

var _ground_materials: Array[ShaderMaterial] = []
var _vegetation: Vegetation
## The look on show right now (mid-fade, a blend), in the layout of LOOKS.
var _current: Array = []
var _fade: Tween


## Called once by Main, with every material that uses the ground shader.
func setup(ground_materials: Array[ShaderMaterial], vegetation: Vegetation) -> void:
	_ground_materials = ground_materials
	_vegetation = vegetation


## Change to a season's look: at once, or fading in.
func show_season(season: Seasons.Season, instant: bool = false) -> void:
	var target: Array = LOOKS[season]
	if _fade != null:
		_fade.kill()
	if instant or _current.is_empty():
		_apply(target)
		return
	var from := _current.duplicate()
	_fade = create_tween()
	_fade.tween_method(func(t: float) -> void: _apply(_blend(from, target, t)), 0.0, 1.0, FADE_SECONDS)


func _blend(from: Array, to: Array, t: float) -> Array:
	var look := []
	for i in to.size():
		if to[i] is Color:
			var a: Color = from[i]
			look.append(a.lerp(to[i], t))
		else:
			look.append(lerpf(from[i], to[i], t))
	return look


func _apply(look: Array) -> void:
	_current = look
	for material in _ground_materials:
		material.set_shader_parameter("grass_color", look[0])
		material.set_shader_parameter("dry_grass_color", look[1])
		material.set_shader_parameter("snow_amount", look[2])
	_vegetation.set_foliage(look[3], look[4], look[5])
