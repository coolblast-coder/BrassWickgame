class_name SaveGame
extends RefCounted
## Reads and writes the single save file. The file is JSON, so it can be
## inspected; each part of the game turns itself into a Dictionary and back
## with its own to_save() / from_save().
##
## Loading works by restarting the scene: load_from_disk() leaves the data in
## `pending`, and Main applies it as the fresh scene starts.

const PATH := "user://brasswick_save.json"
## Raised whenever the saved layout changes in a way old files cannot be
## read; a file with another number is refused.
const VERSION := 2

## Save data waiting to be applied by the next scene start; empty for none.
static var pending: Dictionary = {}
## The map seed the player asked for on the title screen, used for every
## new city until it is changed; -1 means a fresh random map each time.
static var chosen_map_seed: int = -1
## Random maps use seeds below this, to keep them short enough to pass on.
const RANDOM_SEED_LIMIT := 1000000


## The seed for a new city's map: the one the player chose, or a random one.
static func new_map_seed() -> int:
	return chosen_map_seed if chosen_map_seed >= 0 else randi() % RANDOM_SEED_LIMIT


## Turn what the player typed into a seed: digits are used as they are, any
## other text is turned into a number, and nothing at all means random (-1).
static func seed_from_text(text: String) -> int:
	text = text.strip_edges()
	if text.is_empty():
		return -1
	if text.is_valid_int() and text.to_int() >= 0:
		return text.to_int()
	return absi(hash(text)) % 2147483647


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


## Write `data` to the save file. False if the file could not be written.
static func write(data: Dictionary) -> bool:
	data["version"] = VERSION
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveGame: cannot write %s (error %d)" % [PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true


## Read the save file into `pending`. False if there is none, or it is
## damaged, or it is from an incompatible version.
static func load_from_disk() -> bool:
	if not exists():
		return false
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_warning("SaveGame: %s is not a valid save" % PATH)
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION:
		push_warning("SaveGame: %s is from another version" % PATH)
		return false
	pending = data
	return true
