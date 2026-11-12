class_name BuildingDef
extends Resource
## Static description of one kind of building. One .tres per building lives in
## res://buildings/defs/. Numbers come from the design doc and are tuning values.

## Which placeholder model BuildingMeshFactory assembles for this building.
## New styles go at the end: the .tres files store the number, not the name.
# New styles go at the end: the .tres files store the number.
enum Style { TENEMENT, GLASSHOUSE, COAL_PIT, BRASSWORKS, MECHANIC_YARD, TEA_GARDEN, ROAD, TOWN_HALL,
		TOWNHOUSE, MARKET, TAVERN, SMOG_SCRUBBER,
		AIRSHIP_DOCK, CLOCKTOWER }

@export var id: StringName
@export var display_name: String = ""
## Size in tiles before rotation: x along world +X, y along world +Z.
@export var footprint: Vector2i = Vector2i(1, 1)
@export var style: Style = Style.TENEMENT
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
## Workers needed for full output.
@export var workers: int = 0
## Coal burned per day while connected to the road network.
@export var coal_per_day: int = 0
## Food used per day while staffed (Tavern). Citizens eat first; if what is
## left does not cover this, the building stays shut for the day.
@export var food_per_day: int = 0
## Daily output at full staff. Short-staffed buildings produce in proportion.
@export var food_output: int = 0
@export var coal_output: int = 0
@export var crowns_output: int = 0

## Spare Coal sold per day at full staff, and the Crowns that much earns
## (Airship Dock). Only Coal above CitySim.TRADE_COAL_RESERVE is sold.
@export var trade_coal: int = 0
@export var trade_crowns: int = 0

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
