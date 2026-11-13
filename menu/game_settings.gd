class_name GameSettings
extends RefCounted
## The player's settings: three volume levels, kept in a small file and
## applied to the audio buses. The Ambience and Effects buses are created in
## code, so the project needs no bus layout file.

const PATH := "user://settings.cfg"
const SECTION := "audio"
const AMBIENCE_BUS := &"Ambience"
const EFFECTS_BUS := &"Effects"
## The settings, in menu order: key in the file, label, audio bus.
const VOLUMES: Array[Array] = [
	["master", "Overall volume", &"Master"],
	["ambience", "Wind and city", AMBIENCE_BUS],
	["effects", "Sound effects", EFFECTS_BUS],
]

## Volume per key, from 0 (silent) to 1 (full).
static var _levels: Dictionary[String, float] = {}
static var _loaded: bool = false


## Make sure the buses exist, and read and apply the saved levels. Safe to
## call more than once; call it before playing anything.
static func ensure_ready() -> void:
	for bus: StringName in [AMBIENCE_BUS, EFFECTS_BUS]:
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
			_levels[key] = clampf(float(file.get_value(SECTION, key, 1.0)), 0.0, 1.0)
	for volume: Array in VOLUMES:
		_apply(volume[0], volume[2])


static func get_volume(key: String) -> float:
	return _levels.get(key, 1.0)


## Change one volume level, apply it at once and remember it.
static func set_volume(key: String, level: float) -> void:
	_levels[key] = clampf(level, 0.0, 1.0)
	for volume: Array in VOLUMES:
		if volume[0] == key:
			_apply(key, volume[2])
	var file := ConfigFile.new()
	for volume: Array in VOLUMES:
		file.set_value(SECTION, volume[0], get_volume(volume[0]))
	file.save(PATH)


static func _apply(key: String, bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	var level := get_volume(key)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
	# The Master bus's mute belongs to the M key; silence it by volume alone.
	if bus != &"Master":
		AudioServer.set_bus_mute(index, level <= 0.0)
