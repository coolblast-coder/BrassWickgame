class_name BuildingCatalog
extends RefCounted
## The list of buildable things, in build-bar order. The first KEYS_PER_ROW
## are picked with keys 1 to 7 and sit on the lower row of the build bar; the
## rest are picked with Shift + the number and sit on the upper row.

const KEYS_PER_ROW := 7

const PATHS: Array[String] = [
	"res://buildings/defs/road.tres",
	"res://buildings/defs/tenement.tres",
	"res://buildings/defs/glasshouse.tres",
	"res://buildings/defs/coal_pit.tres",
	"res://buildings/defs/brassworks.tres",
	"res://buildings/defs/mechanic_yard.tres",
	"res://buildings/defs/tea_garden.tres",
	"res://buildings/defs/townhouse.tres",
	"res://buildings/defs/market.tres",
	"res://buildings/defs/tavern.tres",
	"res://buildings/defs/smog_scrubber.tres",
	"res://buildings/defs/airship_dock.tres",
	"res://buildings/defs/clocktower.tres",
]

static var _defs: Array[BuildingDef] = []


static func all() -> Array[BuildingDef]:
	if _defs.is_empty():
		for path in PATHS:
			var def := load(path) as BuildingDef
			if def == null:
				push_error("BuildingCatalog: could not load %s" % path)
				continue
			_defs.append(def)
	return _defs
