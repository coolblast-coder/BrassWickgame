class_name Policies
extends RefCounted
## The Town Hall's policies: standing rules the player can switch on and
## off, each with a benefit and a cost. They become available at the Town
## tier, and one that has just been changed cannot be changed again for a
## few days. CitySim reads them each day. All numbers are tuning values.

## A policy was switched on or off.
signal changed

## The city tier from which policies can be set (Town).
const FROM_TIER := 1
## Days before a policy that was just changed can be changed again.
const COOLDOWN_DAYS := 5

const RATIONING := &"rationing"
const DOUBLE_SHIFTS := &"double_shifts"
const CURFEW := &"curfew"
const HEAVY_TAXES := &"heavy_taxes"
const CLEAN_AIR := &"clean_air"

## What CitySim applies while each policy is on.
const RATION_FOOD_FACTOR := 0.75
const RATION_UNREST := 3.0
const SHIFT_OUTPUT_FACTOR := 1.25
const SHIFT_UNREST := 4.0
const SHIFT_BREAKDOWN_FACTOR := 1.5
const CURFEW_UNREST := -4.0
const CURFEW_TAX_FACTOR := 0.75
const TAX_FACTOR := 1.5
const TAX_UNREST := 3.0
const CLEAN_SMOG_FACTOR := 0.5
const CLEAN_OUTPUT_FACTOR := 0.85

## The policies in menu order: id, name, benefit, cost.
const LIST: Array[Array] = [
	[RATIONING, "Rationing", "Citizens eat a quarter less Food.", "+3 Unrest a day."],
	[DOUBLE_SHIFTS, "Double shifts", "Every workplace makes a quarter more.",
			"+4 Unrest a day, and machines break down half again as often."],
	[CURFEW, "Curfew", "-4 Unrest a day.", "Taxes bring in a quarter less."],
	[HEAVY_TAXES, "Heavy taxes", "Taxes bring in half again as much.", "+3 Unrest a day."],
	[CLEAN_AIR, "Clean Air Act", "Buildings give off half the smog.",
			"Smoky buildings make 15% less."],
]

var _active: Dictionary[StringName, bool] = {}
## The day each policy was last changed.
var _changed_on: Dictionary[StringName, int] = {}


func is_on(policy: StringName) -> bool:
	return _active.get(policy, false)


## Days until `policy` can be changed again; 0 if it can be changed now.
func days_locked(policy: StringName, day: int) -> int:
	if not _changed_on.has(policy):
		return 0
	return maxi(0, _changed_on[policy] + COOLDOWN_DAYS - day)


## Switch a policy on or off, if it is not locked. True if it changed.
func toggle(policy: StringName, day: int) -> bool:
	if days_locked(policy, day) > 0:
		return false
	_active[policy] = not is_on(policy)
	_changed_on[policy] = day
	changed.emit()
	return true


func to_save() -> Dictionary:
	var data := {}
	for entry: Array in LIST:
		var policy: StringName = entry[0]
		data[String(policy)] = {"on": is_on(policy), "changed_on": _changed_on.get(policy, -COOLDOWN_DAYS)}
	return data


func from_save(data: Dictionary) -> void:
	_active.clear()
	_changed_on.clear()
	for entry: Array in LIST:
		var policy: StringName = entry[0]
		var saved: Variant = data.get(String(policy))
		if saved is Dictionary:
			_active[policy] = bool(saved.get("on", false))
			_changed_on[policy] = int(saved.get("changed_on", -COOLDOWN_DAYS))
	changed.emit()
