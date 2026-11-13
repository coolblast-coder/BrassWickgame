extends Node3D
## Root of the game scene. Wires the independent pieces together.

## The logical map: which building stands on which tile.
var grid := CityGrid.new()
## The city's stockpiles: Crowns, Coal, Food, Population.
var city := CityState.new()
## Smog per tile.
var smog := SmogMap.new()
## Day-by-day record of the city's figures, for the statistics screen.
var history := CityHistory.new()

## Set when buildings or roads change; road access is refreshed once per frame
## at most, however many tiles changed (a dragged road adds many at once).
var _road_access_dirty: bool = false
var _sim: CitySim
var _events: CityEvents
var _game_over: bool = false
## Set when an event has sounded today, so the day bell stays quiet.
var _event_sounded: bool = false
## True if opening the menu paused the clock, so closing it resumes.
var _paused_by_menu: bool = false

@onready var _tile_cursor: TileCursor = $TileCursor
@onready var _hud: HUD = $HUD
@onready var _buildings: Node3D = $Buildings
@onready var _build_controller: BuildController = $BuildController
@onready var _clock: GameClock = $GameClock
@onready var _overlay: OverlayView = $OverlayView
@onready var _walkers: Walkers = $Walkers
@onready var _airships: Airships = $Airships
@onready var _hills: Hills = $Hills
@onready var _vegetation: Vegetation = $Vegetation
@onready var _sound: SoundPlayer = $Sound
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _season_view: SeasonView = $SeasonView
@onready var _wind_vane: WindVane = $WindVane
@onready var _day_night: DayNight = $DayNight
@onready var _sun: DirectionalLight3D = $Sun
@onready var _world_environment: WorldEnvironment = $WorldEnvironment
@onready var _ground: MeshInstance3D = $GridView


func _ready() -> void:
	_tile_cursor.cell_changed.connect(_hud.show_cell)
	_tile_cursor.cell_changed.connect(_on_cell_hovered)
	_build_controller.setup(grid, city, _tile_cursor, _buildings)
	_build_controller.mode_changed.connect(_hud.show_build_mode)
	_build_controller.selection_changed.connect(_hud.show_selection)
	_hud.repair_pressed.connect(_build_controller.repair_selected)
	_hud.power_pressed.connect(_build_controller.toggle_selected_power)
	_hud.power_pressed.connect(func() -> void: _sound.play(&"click", -8.0))
	_hud.restart_pressed.connect(func() -> void: get_tree().reload_current_scene())
	_hud.build_bar.slot_pressed.connect(_build_controller.select_slot)
	_hud.build_bar.demolish_pressed.connect(_build_controller.toggle_demolish)
	_hud.top_bar.bind_clock(_clock)
	_hud.bind_city(city)
	_hud.bind_history(history)
	_hud.bind_advisor(grid)
	_hud.jump_requested.connect(_camera_rig.focus_on)
	_hud.game_menu.toggled.connect(_on_menu_toggled)
	_hud.game_menu.save_pressed.connect(save_game)
	_hud.game_menu.load_pressed.connect(load_game)
	_hud.game_menu.main_menu_pressed.connect(
			func() -> void: get_tree().change_scene_to_file("res://menu/main_menu.tscn"))
	_sim = CitySim.new(grid, city, smog)
	_events = CityEvents.new(grid, city, _sim, smog)
	_hud.bind_events(_events)
	_overlay.setup(smog, grid)
	_overlay.mode_changed.connect(_on_overlay_mode_changed)
	_hud.build_bar.overlay_pressed.connect(_overlay.cycle)
	_walkers.setup(grid, city, _clock)
	_airships.setup(city, _clock)
	_clock.day_ended.connect(_on_day_ended)
	city.changed.connect(func() -> void: _sound.set_city_size(city.population))
	_build_controller.feedback.connect(_on_build_feedback)
	_hud.build_bar.clicked.connect(func() -> void: _sound.play(&"click", -8.0))
	_events.event_fired.connect(_on_event_sounded)
	city.tier_reached.connect(func(_tier: int) -> void: _on_event_sounded("", ""))
	grid.buildings_changed.connect(func() -> void: _road_access_dirty = true)
	_place_town_hall()
	_vegetation.setup(grid, _hills)
	var ground_materials: Array[ShaderMaterial] = [
		_ground.get_surface_override_material(0) as ShaderMaterial, _hills.ground_material()]
	_season_view.setup(ground_materials, _vegetation)
	_wind_vane.position = grid.town_hall.position
	_day_night.setup(_sun, _world_environment.environment, _clock)
	_show_season(true)
	if not SaveGame.pending.is_empty():
		_apply_save(SaveGame.pending)
		SaveGame.pending = {}


func _process(_delta: float) -> void:
	if _road_access_dirty:
		_road_access_dirty = false
		_refresh_road_access()


## Tell the HUD which building the mouse is over, for its hover card. Roads
## are skipped: there are too many of them to be worth a card each.
func _on_cell_hovered(cell: Vector2i, in_bounds: bool) -> void:
	var building: Building = grid.building_at(cell) if in_bounds else null
	if building != null and building.def.is_road:
		building = null
	_hud.show_hover(building)


func _on_overlay_mode_changed(_mode: OverlayView.Mode) -> void:
	_hud.build_bar.set_overlay_name(_overlay.mode_name())
	_hud.show_legend(_overlay.legend())


## Dress the landscape for the clock's season and turn the wind to match.
func _show_season(instant: bool) -> void:
	var season := Seasons.of_day(_clock.day)
	_season_view.show_season(season, instant)
	smog.wind = Seasons.WIND[season]
	_wind_vane.set_wind(smog.wind, instant)


## The game stands still while the menu is open.
func _on_menu_toggled(open: bool) -> void:
	if open:
		_paused_by_menu = not _clock.paused
		if _paused_by_menu:
			_clock.toggle_pause()
	elif _paused_by_menu:
		_paused_by_menu = false
		if _clock.paused:
			_clock.toggle_pause()


## F9: save the game to the single save file.
func save_game() -> void:
	if _game_over:
		return
	var buildings := []
	for building in grid.all_buildings:
		buildings.append(building.to_save())
	var saved := SaveGame.write({
		"clock": _clock.to_save(),
		"city": city.to_save(),
		"events": _events.to_save(),
		"smog": smog.to_save(),
		"history": history.to_save(),
		"cleared_trees": _vegetation.to_save(),
		"buildings": buildings,
	})
	if saved:
		_hud.show_notice("Game saved", "Day %d. Press F10 to load it." % _clock.day)
	else:
		_hud.show_notice("Could not save", "The save file could not be written.")
	_sound.play(&"click" if saved else &"error", -6.0)


## F10: load the save file, by restarting the scene with it.
func load_game() -> void:
	if SaveGame.load_from_disk():
		get_tree().reload_current_scene()
	else:
		_hud.show_notice("Nothing to load", "There is no saved game yet. Press F9 to save.")
		_sound.play(&"error", -10.0)


## Rebuild a saved city in this freshly started scene.
func _apply_save(data: Dictionary) -> void:
	# Buildings first, in their saved order: it decides workers and Coal.
	for entry: Variant in data.get("buildings", []):
		if not entry is Dictionary:
			continue
		var def := BuildingCatalog.by_id(StringName(str(entry.get("id", ""))))
		# The Town Hall is already in place.
		if def == null or not def.demolishable:
			continue
		var origin := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var steps := int(entry.get("rotation", 0))
		if not grid.can_place(Building.cells_for(def, origin, steps)):
			continue
		_build_controller.place_building(def, origin, steps).from_save(entry)
	_vegetation.from_save(data.get("cleared_trees", []))
	smog.from_save(data.get("smog", []))
	smog.mark_buildings(grid.all_buildings)
	city.from_save(data.get("city", {}))
	_events.from_save(data.get("events", {}))
	history.from_save(data.get("history", {}))
	_clock.from_save(data.get("clock", {}))
	city.day = _clock.day
	_show_season(true)
	_refresh_road_access()
	_hud.sync_after_load()
	_hud.show_notice("Game loaded", "Day %d. Paused: press Space to carry on." % _clock.day)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F9:
			save_game()
			return
		if event.physical_keycode == KEY_F10:
			load_game()
			return
	# Development aids: F1 to F4 fire each event at once, to test them without
	# waiting for the dice, F6 unlocks the next city tier, and F7 skips to the
	# next season. Not in exported builds.
	if not OS.is_debug_build() or _game_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				_events.fire(CityEvents.Type.BURST_BOILER, _clock.day)
			KEY_F2:
				_events.fire(CityEvents.Type.COAL_STRIKE, _clock.day)
			KEY_F3:
				_events.fire(CityEvents.Type.SMOG_STORM, _clock.day)
			KEY_F4:
				_events.fire(CityEvents.Type.AIRSHIP_TRADER, _clock.day)
			KEY_F7:
				# Skip to the first day of the next season.
				_clock.day += Seasons.days_until_next(_clock.day)
				city.day = _clock.day
				_show_season(false)
				# Refreshes the day shown in the top bar.
				_clock.state_changed.emit()
			KEY_F6:
				# Jump to the next city tier without growing into it.
				if city.tier + 1 < CityState.TIER_POPULATION.size():
					city.peak_population = CityState.TIER_POPULATION[city.tier + 1]
					city.update_tier()


func _on_day_ended(day: int) -> void:
	# The simulation reads each building's road access, so make sure it is
	# current even if something was built earlier this same frame.
	if _road_access_dirty:
		_road_access_dirty = false
		_refresh_road_access()
	var broken_before := _count_broken()
	_event_sounded = false
	_sim.run_day(day)
	history.record(city)
	if city.days_at_max_unrest >= CitySim.WALKOUT_DAYS:
		_end_game(day)
		return
	_events.day_passed(day)
	# Announce a change of season, once the seasons matter.
	var season := Seasons.of_day(day + 1)
	if season != Seasons.of_day(day):
		_show_season(false)
		var news := "The wind has turned: watch where the smog goes."
		if city.tier >= Seasons.FROM_TIER:
			news = Seasons.EFFECTS[season] + "\n" + news
		_hud.show_notice("%s has come" % Seasons.NAMES[season], news)
		_on_event_sounded("", "")
	# One sound per day at most: an event's whistle, else a new breakdown,
	# else the day bell.
	if _event_sounded:
		pass
	elif _count_broken() > broken_before:
		_sound.play(&"breakdown", -4.0)
	else:
		_sound.play(&"day_bell", -12.0)


func _count_broken() -> int:
	var broken := 0
	for building in grid.all_buildings:
		if building.broken:
			broken += 1
	return broken


func _on_event_sounded(_title: String, _message: String) -> void:
	_event_sounded = true
	_sound.play(&"event", -3.0)


## Sounds for the player's own actions. Repeated ones vary in pitch a little.
func _on_build_feedback(sound: StringName) -> void:
	match sound:
		&"error":
			_sound.play(sound, -10.0)
		&"road":
			_sound.play(sound, -6.0, 0.15)
		_:
			_sound.play(sound, -3.0, 0.08)


## The Great Walkout: stop time, put the tools away and show the score.
func _end_game(days_survived: int) -> void:
	_game_over = true
	_clock.stop()
	_build_controller.shut_down()
	_hud.build_bar.enabled = false
	_sound.play(&"game_over")
	_hud.show_game_over(city.peak_population, days_survived)


## The Town Hall is placed for the player in the middle of the map.
func _place_town_hall() -> void:
	var def := load("res://buildings/defs/town_hall.tres") as BuildingDef
	var origin := (CityGrid.SIZE - def.footprint) / 2
	grid.town_hall = _build_controller.place_building(def, origin, 0)


## Work out which roads lead back to the Town Hall and tell every building
## whether that network reaches it.
func _refresh_road_access() -> void:
	grid.recompute_connectivity()
	for child in _buildings.get_children():
		var building := child as Building
		if building != null and not building.is_queued_for_deletion():
			building.set_road_access(grid.has_road_access(building))
