class_name BuildingDef
extends Resource
## Static description of one kind of building. One .tres per building lives in
## res://buildings/defs/. Numbers come from the design doc and are tuning values.

## Which placeholder model BuildingMeshFactory assembles for this building.
## New styles go at the end: the .tres files store the number, not the name.
# New styles go at the end: the .tres files store the number.
enum Style { TENEMENT, GLASSHOUSE, COAL_PIT, BRASSWORKS, MECHANIC_YARD, TEA_GARDEN, ROAD, TOWN_HALL,
		TOWNHOUSE, MARKET, TAVERN, SMOG_SCRUBBER,
		AIRSHIP_DOCK, CLOCKTOWER, PUMP_STATION, WORKSHOP,
		POWER_STATION, WAREHOUSE }

## Which group of the build menu this building is listed under. New
## categories go at the end, and need a name in BuildingCatalog.
enum Category { INFRASTRUCTURE, HOUSING, SUPPLY, INDUSTRY, SERVICES }

@export var id: StringName
@export var display_name: String = ""
## A sentence or two for the build menu's hover card: what it is for and
## what to watch out for. Numbers are added to the card from the fields below.
@export_multiline var description: String = ""
## Size in tiles before rotation: x along world +X, y along world +Z.
@export var footprint: Vector2i = Vector2i(1, 1)
@export var style: Style = Style.TENEMENT
@export var category: Category = Category.INFRASTRUCTURE
## The city tier (index into CityState.TIER_NAMES) at which this building
## becomes available. 0 is available from the start.
@export var tier: int = 0
## Main colour of the placeholder model.
@export var color: Color = Color.WHITE
## Roads carry the connection to the Town Hall and can be laid by dragging.
@export var is_road: bool = false
## False for things the player must not remove (the Town Hall).
@export var demolishable: bool = true
## Only one of these may stand in the city at a time (Clocktower).
@export var unique: bool = false

@export_group("Economy")
@export var cost: int = 0
## Citizens this building can house.
@export var housing: int = 0
## Residents here expect Goods once the city is a City (Townhouse).
@export var wants_goods: bool = false
## Workers needed for full output.
@export var workers: int = 0
## Essential buildings (Food, Coal, Water, Steam) get their workers before
## all others, whatever order things were built in.
@export var essential: bool = false
## Coal burned per day while connected to the road network.
@export var coal_per_day: int = 0
## Steam used per day once the city is a Metropolis. Without it the
## building does not run. It is drawn from the stock left by earlier days.
@export var steam_per_day: int = 0
## Food used per day while staffed (Tavern). Citizens eat first; if what is
## left does not cover this, the building stays shut for the day.
@export var food_per_day: int = 0
## Daily output at full staff. Short-staffed buildings produce in proportion.
@export var food_output: int = 0
@export var coal_output: int = 0
@export var crowns_output: int = 0
@export var water_output: int = 0
@export var goods_output: int = 0
@export var steam_output: int = 0

## Spare Coal sold per day at full staff, and the Crowns that much earns
## (Airship Dock). Only Coal above CitySim.TRADE_COAL_RESERVE is sold.
@export var trade_coal: int = 0
@export var trade_crowns: int = 0

## Extra room for every stockpile while connected (Warehouse).
@export var storage: int = 0

@export_group("Breakdowns")
## Machines can break down; a broken one produces nothing until repaired.
@export var can_break: bool = false
## Repairs broken buildings within `effect_range` for free (Mechanic's Yard).
@export var repairs: bool = false

@export_group("Smog and area effects")
## Smog added per day around the building, on days it runs.
@export var smog_per_day: int = 0
## Extra smog cleared per day on tiles within `effect_range` (Tea Garden,
## Smog Scrubber).
@export var smog_clear_per_day: int = 0
## Lowers Unrest for homes within `effect_range` (Tea Garden, Tavern).
## Area effects of a building that needs workers only apply on days it ran.
@export var calming: bool = false
## Unrest removed per day across the whole city while connected (Clocktower).
@export var citywide_calm: float = 0.0
## Reach of this building's area effect, in tiles from the edge of its
## footprint; diagonals count the same as straight lines.
@export var effect_range: int = 0
