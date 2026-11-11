class_name BuildingDef
extends Resource
## Static description of one kind of building. One .tres per building lives in
## res://buildings/defs/. Numbers come from the design doc and are tuning values.

## Which placeholder model BuildingMeshFactory assembles for this building.
## New styles go at the end: the .tres files store the number, not the name.
enum Style { TENEMENT, GLASSHOUSE, COAL_PIT, BRASSWORKS, MECHANIC_YARD, TEA_GARDEN, ROAD, TOWN_HALL }

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

@export_group("Economy (unused until the simulation milestone)")
@export var cost: int = 0
@export var workers: int = 0
@export var coal_per_day: int = 0
