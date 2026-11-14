class_name Inventions
extends RefCounted
## Inventions: permanent improvements bought once with Crowns. Each needs
## the city to have reached a tier, and some need an earlier invention.
## CitySim reads them each day. They are where a rich city's Crowns go.
## All numbers are tuning values.

## An invention was bought.
signal changed

const CROP_ROTATION := &"crop_rotation"
const IMPROVED_BOILERS := &"improved_boilers"
const REINFORCED_GEARS := &"reinforced_gears"
const DOUBLE_GLAZING := &"double_glazing"
const DEEP_SHAFTS := &"deep_shafts"
const PENNY_POST := &"penny_post"
const FILTER_STACKS := &"filter_stacks"
const STANDARD_PARTS := &"standard_parts"
const COLD_STORES := &"cold_stores"
const STEAM_MAINS := &"steam_mains"

## What CitySim applies once each is owned.
const CROP_FACTOR := 1.2
const BOILER_COAL_FACTOR := 0.75
const GEARS_BREAKDOWN_FACTOR := 0.5
const SHAFT_FACTOR := 1.25
const POST_TAX_FACTOR := 1.1
const FILTER_SMOG_FACTOR := 0.7
const PARTS_EXTRA_REACH := 3
const STORES_FACTOR := 1.5
const MAINS_FACTOR := 1.5

## The inventions in menu order: id, name, cost in Crowns, city tier needed,
## invention needed first (or empty), what it does.
const LIST: Array[Array] = [
	[CROP_ROTATION, "Crop Rotation", 150, 0, &"", "Glasshouses grow a fifth more Food."],
	[IMPROVED_BOILERS, "Improved Boilers", 300, 1, &"", "Machines burn a quarter less Coal."],
	[REINFORCED_GEARS, "Reinforced Gears", 300, 1, &"", "Machines break down half as often."],
	[DOUBLE_GLAZING, "Double Glazing", 300, 1, &"", "Homes burn no extra Coal in winter."],
	[DEEP_SHAFTS, "Deep Shafts", 400, 1, &"", "Coal Pits dig a quarter more."],
	[PENNY_POST, "Penny Post", 400, 1, &"", "Taxes bring in a tenth more."],
	[FILTER_STACKS, "Filter Stacks", 800, 2, IMPROVED_BOILERS, "Buildings give off 30% less smog."],
	[STANDARD_PARTS, "Standard Parts", 800, 2, REINFORCED_GEARS,
			"Mechanic's Yards reach 3 tiles further."],
	[COLD_STORES, "Cold Stores", 1000, 2, &"", "Every stockpile holds half again as much."],
	[STEAM_MAINS, "Steam Mains", 2500, 3, IMPROVED_BOILERS, "Power Stations raise half again as much Steam."],
]

## The inventions of the game in play, for the HUD's read-outs. Set by Main
## at the start of every game.
static var current: Inventions

var _owned: Dictionary[StringName, bool] = {}


## The Coal a machine of this kind burns a day, given `inventions` (which
## may be null). Homes are not machines and are unaffected. Never less than
## 1 for a machine that burns any.
static func machine_coal(def: BuildingDef, inventions: Inventions) -> int:
	if def.coal_per_day <= 0 or def.housing > 0:
		return def.coal_per_day
	if inventions == null or not inventions.has(IMPROVED_BOILERS):
		return def.coal_per_day
	return maxi(1, roundi(def.coal_per_day * BOILER_COAL_FACTOR))


func has(invention: StringName) -> bool:
	return _owned.get(invention, false)


## Why `invention` cannot be bought right now; empty if it can.
func blocked_reason(invention: StringName, city: CityState) -> String:
	var entry := _entry(invention)
	if entry.is_empty():
		return "Unknown"
	if has(invention):
		return "Owned"
	var tier: int = entry[3]
	if city.tier < tier:
		return "Needs a %s" % CityState.TIER_NAMES[tier]
	var needs: StringName = entry[4]
	if needs != &"" and not has(needs):
		return "Needs %s" % _entry(needs)[1]
	var cost: int = entry[2]
	if not city.can_afford(cost):
		return "Needs %d Crowns" % cost
	return ""


## Buy an invention, paying for it. True if it was bought.
func buy(invention: StringName, city: CityState) -> bool:
	if not blocked_reason(invention, city).is_empty():
		return false
	var cost: int = _entry(invention)[2]
	city.crowns -= cost
	_owned[invention] = true
	changed.emit()
	return true


func _entry(invention: StringName) -> Array:
	for entry: Array in LIST:
		if entry[0] == invention:
			return entry
	return []


func to_save() -> Array:
	var owned := []
	for entry: Array in LIST:
		if has(entry[0]):
			owned.append(String(entry[0]))
	return owned


func from_save(data: Array) -> void:
	_owned.clear()
	for id: Variant in data:
		var invention := StringName(str(id))
		if not _entry(invention).is_empty():
			_owned[invention] = true
	changed.emit()
