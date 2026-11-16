class_name SaveGame
extends RefCounted
## Reads and writes the save files: three slots the player saves to by hand
## and one the game writes by itself every few days. The files are JSON, so
## they can be inspected; each part of the game turns itself into a
## Dictionary and back with its own to_save() / from_save().
##
## Loading works by restarting the scene: load_from_disk() leaves the data in
## `pending`, and Main applies it as the fresh scene starts.

## Raised whenever the saved layout changes in a way old files cannot be
## read; a file with another number is refused.
const VERSION := 2
## The slots, in menu order. The last is the autosave.
const SLOTS: Array[String] = ["1", "2", "3", "auto"]
const AUTOSAVE := "auto"
## Random maps use seeds below this, to keep them short enough to pass on.
const RANDOM_SEED_LIMIT := 1000000

## Save data waiting to be applied by the next scene start; empty for none.
static var pending: Dictionary = {}
## The map seed the player asked for on the title screen, used for every
## new city until it is changed; -1 means a fresh random map each time.
static var chosen_map_seed: int = -1
## The slot last saved to or loaded from by hand; F9 saves there again.
static var last_slot: String = "1"


## The seed for a new city's map: the one the player chose, or a random one.
static func new_map_seed() -> int:
	if chosen_map_seed >= 0:
		return chosen_map_seed
	# A scenario brings its own map, so everyone plays it on the same ground.
	if GameRules.scenario_seed() >= 0:
		return GameRules.scenario_seed()
	return randi() % RANDOM_SEED_LIMIT


## Turn what the player typed into a seed: digits are used as they are, any
## other text is turned into a number, and nothing at all means random (-1).
static func seed_from_text(text: String) -> int:
	text = text.strip_edges()
	if text.is_empty():
		return -1
	if text.is_valid_int() and text.to_int() >= 0:
		return text.to_int()
	return absi(hash(text)) % 2147483647


## What a slot is called in menus.
static func slot_name(slot: String) -> String:
	return "Autosave" if slot == AUTOSAVE else "Slot %s" % slot


## The file a slot is kept in. Slot 1 keeps the name the single save file
## had before there were slots, so an older save turns up there.
static func path(slot: String) -> String:
	return "user://brasswick_save.json" if slot == "1" else "user://brasswick_save_%s.json" % slot


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(path(slot))


static func any_exists() -> bool:
	for slot in SLOTS:
		if exists(slot):
			return true
	return false


## Write `data` to a slot. `data` should carry a "summary" of the city for
## the menus. False if the file could not be written.
static func write(data: Dictionary, slot: String) -> bool:
	data["version"] = VERSION
	var file := FileAccess.open(path(slot), FileAccess.WRITE)
	if file == null:
		push_warning("SaveGame: cannot write %s (error %d)" % [path(slot), FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	if slot != AUTOSAVE:
		last_slot = slot
	return true


## Read a slot into `pending`. False if it is empty, damaged, or from an
## incompatible version.
static func load_from_disk(slot: String) -> bool:
	var data := _read(slot)
	if data.is_empty():
		return false
	pending = data
	if slot != AUTOSAVE:
		last_slot = slot
	return true


## The slot saved most recently, by hand or by the game; empty if there is
## nothing to load.
static func latest_slot() -> String:
	var latest := ""
	var latest_time := -1.0
	for slot in SLOTS:
		var summary: Dictionary = _read(slot).get("summary", {})
		var saved_at := float(summary.get("saved_at", 0.0))
		if not _read(slot).is_empty() and saved_at > latest_time:
			latest = slot
			latest_time = saved_at
	return latest


## One line about what a slot holds, for the menus.
static func describe(slot: String) -> String:
	if not exists(slot):
		return "%s: empty" % slot_name(slot)
	var data := _read(slot)
	if data.is_empty():
		return "%s: cannot be read by this version" % slot_name(slot)
	var summary: Dictionary = data.get("summary", {})
	if summary.is_empty():
		return "%s: a saved city" % slot_name(slot)
	return "%s: day %d, %s of %d   (%s, %s)   %s" % [
			slot_name(slot), int(summary.get("day", 0)), str(summary.get("tier", "")),
			int(summary.get("population", 0)), str(summary.get("scenario", "")),
			str(summary.get("difficulty", "")), str(summary.get("date", ""))]


## True if a slot holds a save this version can load.
static func is_loadable(slot: String) -> bool:
	return not _read(slot).is_empty()


## A slot's contents, or an empty Dictionary if there is nothing usable.
static func _read(slot: String) -> Dictionary:
	if not exists(slot):
		return {}
	var file := FileAccess.open(path(slot), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION:
		return {}
	return data
