class_name GameSettings
extends RefCounted
## The player's settings, kept in a small file between sessions: the volume
## levels, a few options, and which key does what.
##
## The Ambience, Effects and Music buses, and the input actions for the keys
## that can be changed, are all set up in code here, so nothing depends on a
## bus layout file or on the project's input map being edited by hand.

const PATH := "user://settings.cfg"
const AUDIO := "audio"
const OPTIONS := "options"
const KEYBOARD := "keys"
const AMBIENCE_BUS := &"Ambience"
const EFFECTS_BUS := &"Effects"
const MUSIC_BUS := &"Music"
## The volumes, in menu order: key in the file, label, audio bus.
const VOLUMES: Array[Array] = [
	["master", "Overall volume", &"Master"],
	["ambience", "Wind and city", AMBIENCE_BUS],
	["effects", "Sound effects", EFFECTS_BUS],
	["music", "Music", MUSIC_BUS],
]
## The keys that can be changed, in menu order: input action, what it does,
## the key it starts on. Camera actions also keep the arrow keys.
const KEYS: Array[Array] = [
	[&"cam_forward", "Move the view up", KEY_W],
	[&"cam_back", "Move the view down", KEY_S],
	[&"cam_left", "Move the view left", KEY_A],
	[&"cam_right", "Move the view right", KEY_D],
	[&"cam_rotate_left", "Turn the view left", KEY_Q],
	[&"cam_rotate_right", "Turn the view right", KEY_E],
	[&"time_pause", "Pause or resume", KEY_SPACE],
	[&"time_speed", "Change speed", KEY_TAB],
	[&"build_rotate", "Rotate the building in hand", KEY_R],
	[&"demolish_mode", "Demolish", KEY_X],
	[&"repair", "Repair, or put out a fire", KEY_F],
	[&"toggle_power", "Switch a workplace off or on", KEY_P],
	[&"upgrade", "Upgrade the selected building", KEY_U],
	[&"move_building", "Move the selected building", KEY_V],
	[&"overlay_cycle", "Next overlay", KEY_O],
	[&"stats", "Statistics", KEY_G],
	[&"policies", "Policies", KEY_T],
	[&"inventions", "Inventions", KEY_I],
	[&"mute", "Mute all sound", KEY_M],
	[&"day_night", "Day and night cycle on or off", KEY_N],
]
## Keys with a fixed job, which nothing else may be put on.
const RESERVED_KEYS: Array[int] = [
	KEY_ESCAPE, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,
	KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10,
	KEY_F11, KEY_F12, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META,
]
const CAMERA_SPEED_MIN := 0.5
const CAMERA_SPEED_MAX := 2.0

## Whether pushing the mouse against the edge of the window moves the view.
static var edge_pan: bool = true
## Whether each day ends in a night.
static var day_night: bool = true
## Multiplier on how fast the view moves.
static var camera_speed: float = 1.0

## Volume per key, from 0 (silent) to 1 (full).
static var _levels: Dictionary[String, float] = {}
## The key each action is on, as a physical keycode.
static var _keys: Dictionary[StringName, int] = {}
static var _loaded: bool = false


## Make sure the buses and input actions exist, and read and apply what was
## saved. Safe to call more than once; call it before playing anything.
static func ensure_ready() -> void:
	for bus: StringName in [AMBIENCE_BUS, EFFECTS_BUS, MUSIC_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")
	if not _loaded:
		_loaded = true
		var file := ConfigFile.new()
		# A missing file just means the defaults are used.
		file.load(PATH)
		for volume: Array in VOLUMES:
			var key: String = volume[0]
			_levels[key] = clampf(float(file.get_value(AUDIO, key, 1.0)), 0.0, 1.0)
		edge_pan = bool(file.get_value(OPTIONS, "edge_pan", true))
		day_night = bool(file.get_value(OPTIONS, "day_night", true))
		camera_speed = clampf(float(file.get_value(OPTIONS, "camera_speed", 1.0)),
				CAMERA_SPEED_MIN, CAMERA_SPEED_MAX)
		for entry: Array in KEYS:
			var action: StringName = entry[0]
			var saved := int(file.get_value(KEYBOARD, String(action), entry[2]))
			_keys[action] = entry[2] if saved in RESERVED_KEYS else saved
	for volume: Array in VOLUMES:
		_apply_volume(volume[0], volume[2])
	for entry: Array in KEYS:
		_apply_key(entry[0], _keys[entry[0]])


static func get_volume(key: String) -> float:
	return _levels.get(key, 1.0)


## Change one volume level, apply it at once and remember it.
static func set_volume(key: String, level: float) -> void:
	_levels[key] = clampf(level, 0.0, 1.0)
	for volume: Array in VOLUMES:
		if volume[0] == key:
			_apply_volume(key, volume[2])
	_save()


static func set_edge_pan(on: bool) -> void:
	edge_pan = on
	_save()


static func set_day_night(on: bool) -> void:
	day_night = on
	_save()


static func set_camera_speed(speed: float) -> void:
	camera_speed = clampf(speed, CAMERA_SPEED_MIN, CAMERA_SPEED_MAX)
	_save()


## The key an action is on, as a physical keycode.
static func get_key(action: StringName) -> int:
	return _keys.get(action, KEY_NONE)


## The name of the key an action is on, for buttons and hints: "P", "Space".
static func key_label(action: StringName) -> String:
	return OS.get_keycode_string(get_key(action))


## True if a key has a fixed job and cannot be given to an action.
static func is_reserved(keycode: int) -> bool:
	return keycode in RESERVED_KEYS


## Put an action on a key. If another action was on that key, the two swap,
## so no key ever does two things. False if the key is reserved.
static func set_key(action: StringName, keycode: int) -> bool:
	if is_reserved(keycode) or not _keys.has(action):
		return false
	var previous: int = _keys[action]
	for other: StringName in _keys:
		if other != action and _keys[other] == keycode:
			_keys[other] = previous
			_apply_key(other, previous)
	_keys[action] = keycode
	_apply_key(action, keycode)
	_save()
	return true


## Put every action back on the key it started on.
static func reset_keys() -> void:
	for entry: Array in KEYS:
		_keys[entry[0]] = entry[2]
		_apply_key(entry[0], entry[2])
	_save()


static func _apply_volume(key: String, bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	var level := get_volume(key)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
	# The Master bus's mute belongs to the mute key; silence it by volume alone.
	if bus != &"Master":
		AudioServer.set_bus_mute(index, level <= 0.0)


## Make `keycode` the key for an action, creating the action if the
## project's input map does not have it. Arrow keys on the action are left
## alone, so the camera keeps them whatever its letters are changed to.
static func _apply_key(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null and not key.physical_keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			InputMap.action_erase_event(action, event)
	var pressed := InputEventKey.new()
	pressed.physical_keycode = keycode as Key
	InputMap.action_add_event(action, pressed)


static func _save() -> void:
	var file := ConfigFile.new()
	for volume: Array in VOLUMES:
		file.set_value(AUDIO, volume[0], get_volume(volume[0]))
	file.set_value(OPTIONS, "edge_pan", edge_pan)
	file.set_value(OPTIONS, "day_night", day_night)
	file.set_value(OPTIONS, "camera_speed", camera_speed)
	for entry: Array in KEYS:
		file.set_value(KEYBOARD, String(entry[0]), get_key(entry[0]))
	file.save(PATH)
