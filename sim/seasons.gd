class_name Seasons
extends RefCounted
## The calendar. A year is four seasons of DAYS_PER_SEASON days, starting in
## spring on day 1. From the Town tier on, each season changes the rules a
## little; before that the seasons pass without effect.
## All constants are tuning values, and are copied in tools/balance_model.py.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const DAYS_PER_SEASON := 12
const NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]

## The city tier from which the seasons have any effect (Town).
const FROM_TIER := 1
## Multiplier on Food grown, by season.
const FOOD_FACTOR: Array[float] = [1.0, 1.0, 1.25, 0.75]
## Multiplier on the Coal a home burns, by season.
const HOME_COAL_FACTOR: Array[int] = [1, 1, 1, 2]
## Multiplier on the Water citizens need, by season.
const WATER_FACTOR: Array[float] = [1.0, 1.25, 1.0, 1.0]
## The way the wind blows in each season, as a step on the grid: (1, 0) is
## towards +X. Smog drifts with it. Unlike the rules above, the wind turns
## with the calendar from day 1, whatever the city's tier.
const WIND: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1)]
## What each season does, for the HUD.
const EFFECTS: Array[String] = [
	"No effect: a good time to build.",
	"Citizens need a quarter more Water.",
	"Harvest: Glasshouses grow a quarter more. Stock up for winter.",
	"Homes burn twice the Coal, and Glasshouses grow a quarter less.",
]


## The season on a given day (days count from 1).
static func of_day(day: int) -> Season:
	@warning_ignore("integer_division")
	return (((maxi(day, 1) - 1) / DAYS_PER_SEASON) % 4) as Season


## The day within its season, from 1 to DAYS_PER_SEASON.
static func day_in_season(day: int) -> int:
	return (maxi(day, 1) - 1) % DAYS_PER_SEASON + 1


## Days from `day` until the next season begins.
static func days_until_next(day: int) -> int:
	return DAYS_PER_SEASON - day_in_season(day) + 1


## The season after the one `day` falls in.
static func next_after(day: int) -> Season:
	return ((of_day(day) + 1) % 4) as Season


## The season whose rules apply on `day` for a city of this tier: before the
## seasons take effect, every day is treated as spring.
static func in_effect(day: int, tier: int) -> Season:
	return of_day(day) if tier >= FROM_TIER else Season.SPRING


## For the top bar: "Winter 3/12".
static func label(day: int) -> String:
	return "%s %d/%d" % [NAMES[of_day(day)], day_in_season(day), DAYS_PER_SEASON]
