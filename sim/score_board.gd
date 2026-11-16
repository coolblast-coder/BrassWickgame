class_name ScoreBoard
extends RefCounted
## The player's own records, kept in a small file between sessions. A city
## is entered when it ends in the Great Walkout and when its scenario is won
## or lost. Records are ranked by peak population, then by days.

const PATH := "user://brasswick_scores.json"
## Only this many records are kept; the lowest drop off.
const MAX_RECORDS := 30

## What to say about the record just entered ("Record 3 of 12"), for the
## result screen; empty if nothing has been entered this session.
static var last_note: String = ""


## Every record, best first.
static func all() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not FileAccess.file_exists(PATH):
		return records
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return records
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		for entry: Variant in parsed:
			if entry is Dictionary:
				records.append(entry)
	return records


## Enter the city in play under `outcome` ("Walkout", "Won", "Out of time").
## Returns its rank, counting from 1, or 0 if it could not be saved.
static func enter(city: CityState, outcome: String, map_seed: int) -> int:
	var record := {
		"peak": city.peak_population,
		"days": city.day,
		"outcome": outcome,
		"scenario": GameRules.scenario_name(),
		"difficulty": GameRules.difficulty_name(),
		"twists": ", ".join(GameRules.twist_names()),
		"seed": map_seed,
		"date": Time.get_date_string_from_system(),
	}
	var records := all()
	records.append(record)
	records.sort_custom(_better)
	var rank := records.find(record) + 1
	if records.size() > MAX_RECORDS:
		records.resize(MAX_RECORDS)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		last_note = ""
		return 0
	file.store_string(JSON.stringify(records))
	file.close()
	if rank == 1 and records.size() > 1:
		last_note = "A new best: record 1 of %d" % records.size()
	else:
		last_note = "Record %d of %d" % [rank, records.size()]
	return rank


## One record as a line of text for the records list.
static func describe(record: Dictionary) -> String:
	var line := "%d citizens, %d days   %s, %s, %s" % [
			int(record.get("peak", 0)), int(record.get("days", 0)),
			str(record.get("scenario", "")), str(record.get("difficulty", "")),
			str(record.get("outcome", ""))]
	var twists := str(record.get("twists", ""))
	if not twists.is_empty():
		line += "   [%s]" % twists
	return "%s   %s" % [line, str(record.get("date", ""))]


static func _better(a: Dictionary, b: Dictionary) -> bool:
	var peak_a := int(a.get("peak", 0))
	var peak_b := int(b.get("peak", 0))
	if peak_a != peak_b:
		return peak_a > peak_b
	return int(a.get("days", 0)) > int(b.get("days", 0))
