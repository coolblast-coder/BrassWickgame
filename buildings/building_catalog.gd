class_name BuildingCatalog
extends RefCounted
## The list of buildable things, in build-bar order.

const PATHS: Array[String] = [
	"res://buildings/defs/road.tres",
	"res://buildings/defs/tenement.tres",
	"res://buildings/defs/glasshouse.tres",
	"res://buildings/defs/coal_pit.tres",
	"res://buildings/defs/brassworks.tres",
	"res://buildings/defs/mechanic_yard.tres",
	"res://buildings/defs/tea_garden.tres",
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
