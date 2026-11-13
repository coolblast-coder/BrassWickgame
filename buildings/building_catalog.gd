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
	"res://buildings/defs/warehouse.tres",
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

## Things that exist but cannot be built by the player.
const OTHER_PATHS: Array[String] = [
	"res://buildings/defs/town_hall.tres",
]

static var _defs: Array[BuildingDef] = []
static var _by_id: Dictionary[StringName, BuildingDef] = {}


static func all() -> Array[BuildingDef]:
	if _defs.is_empty():
		for path in PATHS:
			var def := load(path) as BuildingDef
			if def == null:
				push_error("BuildingCatalog: could not load %s" % path)
				continue
			_defs.append(def)
	return _defs


## The definition with this id, buildable or not; null if there is none.
static func by_id(id: StringName) -> BuildingDef:
	if _by_id.is_empty():
		for def in all():
			_by_id[def.id] = def
		for path in OTHER_PATHS:
			var def := load(path) as BuildingDef
			if def != null:
				_by_id[def.id] = def
	return _by_id.get(id)
