class_name HUD
extends CanvasLayer
## On-screen interface: top bar, shortage warnings, building info panel,
## build bar with its hint line, and a debug readout of the hovered tile.

@onready var top_bar: TopBar = $TopBar
@onready var build_bar: BuildBar = $BuildBar
@onready var _cell_label: Label = $CellLabel
@onready var _legend_label: Label = $LegendLabel
@onready var _hint_label: Label = $HintLabel
@onready var _warning_label: Label = $WarningLabel
@onready var _info_panel: InfoPanel = $RightColumn/InfoPanel
@onready var _advisor: AdvisorPanel = $RightColumn/AdvisorPanel
@onready var _event_banner: EventBanner = $EventBanner
@onready var _game_over_panel: GameOverPanel = $GameOverPanel
@onready var _card: BuildingCard = $BuildingCard
@onready var _stats_panel: StatsPanel = $StatsPanel
@onready var game_menu: GameMenu = $GameMenu

var _city: CityState
var _events: CityEvents
## The building whose details are shown; null when the panel is closed.
var _selected: Building
## What the mouse is over, for the hover card: a build-menu button's
## building, or a building on the map.
var _hovered_def: BuildingDef
var _hovered_building: Building
## True while no build or demolish tool is in hand.
var _idle: bool = true


## The Repair button in the info panel was clicked.
signal repair_pressed
## The Switch off / on button in the info panel was clicked.
signal power_pressed


## The Restart button on the end screen was clicked.
signal restart_pressed
## An advisor line about a building was clicked: where the camera should go.
signal jump_requested(world_position: Vector3)


func _ready() -> void:
	_info_panel.repair_pressed.connect(func() -> void: repair_pressed.emit())
	_info_panel.power_pressed.connect(func() -> void: power_pressed.emit())
	_game_over_panel.restart_pressed.connect(func() -> void: restart_pressed.emit())
	build_bar.slot_hovered.connect(_on_slot_hovered)
	build_bar.stats_pressed.connect(_stats_panel.toggle)
	build_bar.menu_pressed.connect(game_menu.open)
	_advisor.jump_requested.connect(func(where: Vector3) -> void: jump_requested.emit(where))


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_G:
		_stats_panel.toggle()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE:
		# Esc closes whatever is open; with nothing open, no tool in hand and
		# no building selected, it opens the menu. Otherwise it is left for
		# the build controller, which cancels or deselects.
		if game_menu.visible:
			game_menu.close()
		elif _stats_panel.visible:
			_stats_panel.toggle()
		elif _idle and _selected == null:
			game_menu.open()
		else:
			return
		get_viewport().set_input_as_handled()


## Called once by Main. The advisor reads the map and the city.
func bind_advisor(grid: CityGrid) -> void:
	_advisor.bind(grid, _city)


## Called once by Main. The statistics screen draws from the history.
func bind_history(history: CityHistory) -> void:
	_stats_panel.bind(history, _city)


## Show a short message in the banner used for events.
func show_notice(title: String, message: String = "") -> void:
	_event_banner.show_event(title, message)


## Bring the menu and cards in line with the city after a game is loaded.
func sync_after_load() -> void:
	build_bar.set_tier(_city.tier)
	BuildingCard.city_tier = _city.tier
	_refresh_warnings()


## Cover the HUD with the end screen and the final score.
func show_game_over(peak_population: int, days_survived: int) -> void:
	_event_banner.hide()
	_game_over_panel.show_result(peak_population, days_survived)


## Called once by Main. The top bar and the warning line follow the city.
func bind_city(city: CityState) -> void:
	_city = city
	top_bar.bind_city(city)
	city.changed.connect(_refresh_warnings)
	city.tier_reached.connect(_on_tier_reached)
	# Static, so it would otherwise keep the last game's tier after a restart.
	BuildingCard.city_tier = city.tier
	# Staffing and Coal figures change each day; keep the open panel current.
	city.changed.connect(func() -> void: _info_panel.show_building(_selected))
	_refresh_warnings()


## Called once by Main. Events pop up a notice; lasting ones also appear in
## the warning line until they end.
func bind_events(events: CityEvents) -> void:
	_events = events
	events.event_fired.connect(_event_banner.show_event)
	events.status_changed.connect(_refresh_warnings)


## The city grew into a new tier: unlock its buildings and say so.
func _on_tier_reached(tier: int) -> void:
	build_bar.set_tier(tier)
	BuildingCard.city_tier = tier
	var unlocked: PackedStringArray = []
	for def in BuildingCatalog.all():
		if def.tier == tier:
			unlocked.append(def.display_name)
	var message := "New buildings: %s." % ", ".join(unlocked) if not unlocked.is_empty() else ""
	if not CityState.TIER_NEWS[tier].is_empty():
		message += "\n" + CityState.TIER_NEWS[tier]
	_event_banner.show_event("Brasswick is now a %s" % CityState.TIER_NAMES[tier], message)
	_refresh_card()


func _on_slot_hovered(index: int) -> void:
	_hovered_def = BuildingCatalog.all()[index] if index >= 0 else null
	_refresh_card()


## Tell the HUD which building on the map the mouse is over; null for none.
func show_hover(building: Building) -> void:
	_hovered_building = building
	_refresh_card()


## The hover card describes a build-menu button first; failing that, the
## building under the mouse, but only while no tool is in hand.
func _refresh_card() -> void:
	if _hovered_def != null:
		_card.show_def(_hovered_def)
	elif _idle and is_instance_valid(_hovered_building) \
			and not _hovered_building.is_queued_for_deletion():
		_card.show_building(_hovered_building)
	else:
		_card.hide()


## Show the info panel for `building`; pass null to close it.
func show_selection(building: Building) -> void:
	_selected = building
	_info_panel.show_building(building)


## One line listing every shortage from the last day; empty when all is well.
func _refresh_warnings() -> void:
	var warnings: PackedStringArray = []
	if _city.days_at_max_unrest > 0:
		var days_left := CitySim.WALKOUT_DAYS - _city.days_at_max_unrest
		warnings.append("UNREST AT 100: walkout in %d %s" % [days_left, "day" if days_left == 1 else "days"])
	if _city.crowns < 0:
		warnings.append("In debt: nothing can be built")
	if _city.hungry_citizens > 0:
		warnings.append("Hungry citizens: %d" % _city.hungry_citizens)
	if _city.thirsty_citizens > 0:
		warnings.append("Thirsty citizens: %d" % _city.thirsty_citizens)
	if _city.citizens_without_goods > 0:
		warnings.append("Without Goods: %d" % _city.citizens_without_goods)
	if _city.unpowered_buildings > 0:
		warnings.append("Without Steam: %d" % _city.unpowered_buildings)
	if _city.cold_homes > 0:
		warnings.append("Cold homes: %d" % _city.cold_homes)
	if _city.broken_buildings > 0:
		warnings.append("Broken down: %d" % _city.broken_buildings)
	if _city.stopped_machines > 0:
		warnings.append("Machines stopped, no Coal: %d" % _city.stopped_machines)
	if _events != null:
		if _events.coal_strike_days_left > 0:
			warnings.append("Coal Strike: %d days left" % _events.coal_strike_days_left)
		if _events.smog_storm_days_left > 0:
			warnings.append("Smog Storm: %d days left" % _events.smog_storm_days_left)
	_warning_label.text = "   |   ".join(warnings)


## Show what the active map overlay's colours mean; pass "" to hide it.
func show_legend(text: String) -> void:
	_legend_label.text = text
	_legend_label.visible = not text.is_empty()


func show_cell(cell: Vector2i, in_bounds: bool) -> void:
	if in_bounds:
		_cell_label.text = "Tile: (%d, %d)" % [cell.x, cell.y]
	else:
		_cell_label.text = "Tile: -"


func show_build_mode(mode: BuildController.Mode, def: BuildingDef) -> void:
	build_bar.set_selected(def if mode == BuildController.Mode.PLACING else null)
	build_bar.set_demolishing(mode == BuildController.Mode.DEMOLISHING)
	_idle = mode == BuildController.Mode.IDLE
	_refresh_card()
	match mode:
		BuildController.Mode.PLACING:
			if def.is_road:
				_hint_label.text = "Road (%d Crowns per tile)   |   Click and drag to lay   |   Right click / Esc: cancel" % def.cost
			else:
				var limit := "   |   One per city" if def.unique else ""
				_hint_label.text = "%s (%d Crowns)%s   |   R: rotate   |   Right click / Esc: cancel" % [def.display_name, def.cost, limit]
		BuildController.Mode.DEMOLISHING:
			_hint_label.text = "Demolish   |   Left click: remove   |   Right click / Esc: cancel"
		_:
			_hint_label.text = ""
