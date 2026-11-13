class_name GameClock
extends Node
## In-game time. One day lasts SECONDS_PER_DAY at 1x speed; the simulation
## updates once each time a day ends.

## Emitted when a day finishes. `day` is the number of the day that just ended.
signal day_ended(day: int)
## Emitted when the clock is paused, resumed, or changes speed.
signal state_changed

const SECONDS_PER_DAY := 10.0
const NORMAL_SPEED := 1
const FAST_SPEED := 3

## The current day, starting at 1.
var day: int = 1
var paused: bool = false
## True once the game is over; the clock never runs again.
var stopped: bool = false
## Time multiplier: NORMAL_SPEED or FAST_SPEED.
var speed: int = NORMAL_SPEED

## Seconds (at 1x) elapsed in the current day.
var _elapsed: float = 0.0


func _process(delta: float) -> void:
	if paused:
		return
	_elapsed += delta * speed
	while _elapsed >= SECONDS_PER_DAY:
		_elapsed -= SECONDS_PER_DAY
		day += 1
		day_ended.emit(day - 1)
		if paused:
			# A listener ended the game; do not run any further days.
			_elapsed = 0.0
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("time_pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("time_speed"):
		toggle_speed()
		get_viewport().set_input_as_handled()


## How far through the current day we are, from 0 to 1.
func day_progress() -> float:
	return clampf(_elapsed / SECONDS_PER_DAY, 0.0, 1.0)


## Halt time for good (game over). Pause and speed stop responding.
func stop() -> void:
	stopped = true
	paused = true
	state_changed.emit()


func toggle_pause() -> void:
	if stopped:
		return
	paused = not paused
	state_changed.emit()


func toggle_speed() -> void:
	if stopped:
		return
	speed = NORMAL_SPEED if speed == FAST_SPEED else FAST_SPEED
	state_changed.emit()


func to_save() -> Dictionary:
	return {"day": day, "elapsed": _elapsed, "speed": speed}


## Restore the saved time. A loaded game always starts paused.
func from_save(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	_elapsed = clampf(float(data.get("elapsed", 0.0)), 0.0, SECONDS_PER_DAY - 0.01)
	speed = FAST_SPEED if int(data.get("speed", NORMAL_SPEED)) == FAST_SPEED else NORMAL_SPEED
	paused = true
	state_changed.emit()
