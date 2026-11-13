class_name BuildingCatalog
extends RefCounted
## The list of buildable things. The build menu groups them by category and
## lists each group in the order given here.

## Menu names of BuildingDef.Category, in the same order.
const CATEGORY_NAMES: Array[String] = ["Roads", "Housing", "Food & Coal", "Industry", "Services"]

const PATHS: Array[String] = [
	"res://buildings/defs/road.tres",
	"res://buildings/defs/tenement.tres",
	"res://buildings/defs/glasshouse.tres",
	"res://buildings/defs/coal_pit.tres",
	"res://buildings/defs/pump_station.tres",
	"res://buildings/defs/brassworks.tres",
	"res://buildings/defs/mechanic_yard.tres",
	"res://buildings/defs/tea_garden.tres",
	"res://buildings/defs/townhouse.tres",
	"res://buildings/defs/market.tres",
	"res://buildings/defs/workshop.tres",
	"res://buildings/defs/power_station.tres",
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
