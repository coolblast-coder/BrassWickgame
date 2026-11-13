class_name DayNight
extends Node
## Light that follows the clock: each in-game day ends in dusk and a short
## night before the next morning. The sun dims and turns blue, the sky
## darkens, and lit windows glow brighter.
##
## At fast speed a day lasts only a few seconds, and a night every few
## seconds would be a strobe, so the cycle fades out and the city stays in
## daylight. N switches the cycle off and on.

## Where in the day (0 to 1) dusk begins, night is full, and dawn ends.
const DUSK_START := 0.66
const NIGHT_START := 0.8
const DAWN_START := 0.93
## How quickly the cycle fades in or out when the speed or the switch
## changes, per second.
const BLEND_SPEED := 1.5

const NIGHT_SUN_COLOR := Color(0.5, 0.62, 1.0)
const DUSK_SUN_COLOR := Color(1.0, 0.68, 0.42)
const NIGHT_SUN_ENERGY := 0.22
const NIGHT_AMBIENT_ENERGY := 0.4
const NIGHT_SKY_TOP := Color(0.03, 0.05, 0.12)
const NIGHT_SKY_HORIZON := Color(0.12, 0.14, 0.22)
const NIGHT_FOG := Color(0.1, 0.12, 0.18)
## Brightness of lit windows by day and at night.
const WINDOW_GLOW_DAY := 0.6
const WINDOW_GLOW_NIGHT := 2.4

## Switched with N.
var enabled: bool = true

var _sun: DirectionalLight3D
var _environment: Environment
var _sky: ProceduralSkyMaterial
var _clock: GameClock
## How strongly the cycle shows, from 0 (always day) to 1; eased over time.
var _strength: float = 1.0

# The daytime look, read from the scene so it stays the single source.
var _day_sun_color: Color
var _day_sun_energy: float
var _day_ambient_energy: float
var _day_sky_top: Color
var _day_sky_horizon: Color
var _day_ground_horizon: Color
var _day_fog: Color


## Called once by Main.
func setup(sun: DirectionalLight3D, environment: Environment, clock: GameClock) -> void:
	_sun = sun
	_environment = environment
	_clock = clock
	_day_sun_color = sun.light_color
	_day_sun_energy = sun.light_energy
	_day_ambient_energy = environment.ambient_light_energy
	_day_fog = environment.fog_light_color
	if environment.sky != null:
		_sky = environment.sky.sky_material as ProceduralSkyMaterial
	if _sky != null:
		_day_sky_top = _sky.sky_top_color
		_day_sky_horizon = _sky.sky_horizon_color
		_day_ground_horizon = _sky.ground_horizon_color


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_N:
		enabled = not enabled


func _process(delta: float) -> void:
	if _clock == null:
		return
	var wanted := 1.0 if enabled and _clock.speed == GameClock.NORMAL_SPEED else 0.0
	_strength = move_toward(_strength, wanted, BLEND_SPEED * delta)

	var time := _clock.day_progress()
	var night := smoothstep(DUSK_START, NIGHT_START, time) * (1.0 - smoothstep(DAWN_START, 1.0, time))
	night *= _strength
	# Warm light on the way into the night, gone once it is dark.
	var dusk := smoothstep(DUSK_START - 0.12, DUSK_START + 0.04, time) * (1.0 - night) * _strength
	dusk *= 1.0 - smoothstep(DAWN_START, 1.0, time)

	_show(night, dusk)


## The scene's environment and the window material outlive this node (they
## are shared resources), so put the daytime look back before leaving:
## otherwise a restart at night would take the night for the day.
func _exit_tree() -> void:
	if _environment != null:
		_show(0.0, 0.0)


## Light the scene for a moment that is `night` dark and `dusk` warm, each
## from 0 to 1.
func _show(night: float, dusk: float) -> void:
	if is_instance_valid(_sun):
		_sun.light_color = _day_sun_color.lerp(DUSK_SUN_COLOR, dusk * 0.7).lerp(NIGHT_SUN_COLOR, night)
		_sun.light_energy = lerpf(_day_sun_energy, NIGHT_SUN_ENERGY, night)
	_environment.ambient_light_energy = lerpf(_day_ambient_energy, NIGHT_AMBIENT_ENERGY, night)
	_environment.fog_light_color = _day_fog.lerp(NIGHT_FOG, night)
	if _sky != null:
		_sky.sky_top_color = _day_sky_top.lerp(NIGHT_SKY_TOP, night)
		var horizon := _day_sky_horizon.lerp(DUSK_SUN_COLOR, dusk * 0.5).lerp(NIGHT_SKY_HORIZON, night)
		_sky.sky_horizon_color = horizon
		_sky.ground_horizon_color = _day_ground_horizon.lerp(NIGHT_SKY_HORIZON, night)
	BuildingMeshFactory.set_window_glow(lerpf(WINDOW_GLOW_DAY, WINDOW_GLOW_NIGHT, night))
