class_name CityState
extends RefCounted
## The city's stockpiles. Citizens are a number, not agents.
## Starting values come from the design doc and are tuning values.

## Emitted whenever any value below changes.
signal changed

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

var population: int = 0:
	set(value):
		population = value
		changed.emit()

## How many citizens the connected Tenements can hold.
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

## How much each stockpile changed over the last simulated day. Set by
## CitySim, which emits `changed` itself afterwards.
var crowns_change: int = 0
var coal_change: int = 0
var food_change: int = 0

## Shortages over the last simulated day. Also set by CitySim.
## Citizens who went without Food.
var hungry_citizens: int = 0
## Tenements that got no Coal for heating.
var cold_homes: int = 0
## Machines that got no Coal and produced nothing.
var stopped_machines: int = 0
## Buildings that were broken down during the last simulated day.
var broken_buildings: int = 0


func can_afford(cost: int) -> bool:
	return crowns >= cost
