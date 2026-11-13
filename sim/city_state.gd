class_name CityState
extends RefCounted
## The city's stockpiles. Citizens are a number, not agents.
## Starting values come from the design doc and are tuning values.

## Emitted whenever any value below changes.
signal changed
## The city grew into a new tier, unlocking buildings.
signal tier_reached(tier: int)

## The city's tiers, and the peak population at which each is reached.
## A city never drops back a tier.
const TIER_NAMES: Array[String] = ["Village", "Town", "City", "Metropolis"]
const TIER_POPULATION: Array[int] = [0, 100, 400, 1000]
## What changes for the player on reaching each tier, for the banner.
const TIER_NEWS: Array[String] = [
	"",
	"Citizens now need Water every day: build Pump Stations.",
	"Townhouse residents now expect Goods: build Workshops. Upkeep doubles to 2 Crowns per building.",
	"Workshops, Smog Scrubbers, Airship Docks and the Clocktower now run on Steam: build Power Stations.",
]

var crowns: int = 600:
	set(value):
		crowns = value
		changed.emit()

var coal: int = 50:
	set(value):
		coal = value
		changed.emit()

var food: int = 50:
	set(value):
		food = value
		changed.emit()

## Needed by citizens from the Town tier on.
var water: int = 0:
	set(value):
		water = value
		changed.emit()

## Wanted by Townhouse residents from the City tier on.
var goods: int = 0:
	set(value):
		goods = value
		changed.emit()

## Drives the advanced buildings from the Metropolis tier on.
var steam: int = 0:
	set(value):
		steam = value
		changed.emit()

var population: int = 0:
	set(value):
		population = value
		changed.emit()

## How many citizens the connected homes can hold.
var housing_capacity: int = 0:
	set(value):
		housing_capacity = value
		changed.emit()

## Half the population, as of the last day.
var workers_total: int = 0:
	set(value):
		workers_total = value
		changed.emit()

## Workers with a job, as of the last day. The rest are idle.
var workers_employed: int = 0:
	set(value):
		workers_employed = value
		changed.emit()


## The city's one pressure meter, from 0 to 100. Every failure pushes it up.
var unrest: float = 0.0:
	set(value):
		unrest = value
		changed.emit()

## What moved Unrest on the last simulated day, one line per cause, for the
## top bar's tooltip. Set by CitySim.
var unrest_causes: PackedStringArray = PackedStringArray()

## Days in a row that have ended with Unrest at 100. Set by CitySim.
var days_at_max_unrest: int = 0
## The most citizens the city has ever held: half of the final score.
var peak_population: int = 0
## Index into TIER_NAMES. Set by CitySim from the peak population.
var tier: int = 0


func tier_name() -> String:
	return TIER_NAMES[tier]


## Raise the tier to match the peak population, announcing each step.
func update_tier() -> void:
	while tier + 1 < TIER_POPULATION.size() and peak_population >= TIER_POPULATION[tier + 1]:
		tier += 1
		tier_reached.emit(tier)

## How much each stockpile changed over the last simulated day. Set by
## CitySim, which emits `changed` itself afterwards.
var crowns_change: int = 0
var coal_change: int = 0
var food_change: int = 0
var water_change: int = 0
var goods_change: int = 0
var steam_change: int = 0

## Shortages over the last simulated day. Also set by CitySim.
## Citizens who went without Food.
var hungry_citizens: int = 0
## Citizens who went without Water.
var thirsty_citizens: int = 0
## Townhouse residents who went without Goods.
var citizens_without_goods: int = 0
## Buildings that stood idle for want of Steam.
var unpowered_buildings: int = 0
## Homes that got no Coal for heating.
var cold_homes: int = 0
## Machines that got no Coal and produced nothing.
var stopped_machines: int = 0
## Buildings that were broken down during the last simulated day.
var broken_buildings: int = 0


func can_afford(cost: int) -> bool:
	return crowns >= cost
