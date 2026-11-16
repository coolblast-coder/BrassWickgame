extends Node3D
## Root of the game scene. Wires the independent pieces together.

## The logical map: which building stands on which tile.
var grid := CityGrid.new()
## What the ground is made of on each tile.
var terrain := TerrainMap.new()
## The city's stockpiles: Crowns, Coal, Food, Population.
var city := CityState.new()
## Smog per tile.
var smog := SmogMap.new()
## The Town Hall's policies.
var policies := Policies.new()
## The city's inventions.
var inventions := Inventions.new()
## Day-by-day record of the city's figures, for the statistics screen.
var history := CityHistory.new()

## Set when buildings or roads change; road access is refreshed once per frame
## at most, however many tiles changed (a dragged road adds many at once).
var _road_access_dirty: bool = false
var _sim: CitySim
var _council: Council
var _events: CityEvents
var _game_over: bool = false
## Set when an event has sounded today, so the day bell stays quiet.
var _event_sounded: bool = false
## True if opening the menu paused the clock, so closing it resumes.
var _paused_by_menu: bool = false
## True if an event's decision paused the clock, so deciding resumes.
var _paused_by_event: bool = false
## True while a scenario's result is on screen with the clock stopped.
var _paused_by_result: bool = false

## The game saves itself to the autosave slot every this many days.
const AUTOSAVE_DAYS := 10
## How often the guided first game checks whether its task has been done.
const TUTORIAL_CHECK_SECONDS := 1.0
var _tutorial_wait: float = 0.0

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
	# The ground comes first: everything else is placed on it. A loaded game
	# brings its map's seed; a new city gets a fresh one.
	var map_seed := SaveGame.new_map_seed()
	if SaveGame.pending.has("map_seed"):
		map_seed = int(SaveGame.pending["map_seed"])
	terrain.generate(map_seed)
	grid.terrain = terrain
	_tile_cursor.cell_changed.connect(_hud.show_cell)
	_tile_cursor.cell_changed.connect(_on_cell_hovered)
	_build_controller.setup(grid, city, _tile_cursor, _buildings)
	_build_controller.mode_changed.connect(_hud.show_build_mode)
	_build_controller.ground_bonus_changed.connect(_hud.show_ground_bonus)
	_build_controller.reach_note_changed.connect(_hud.show_reach_note)
	_build_controller.undone.connect(_on_undone)
	_build_controller.selection_changed.connect(_hud.show_selection)
	_hud.repair_pressed.connect(_build_controller.repair_selected)
	_hud.power_pressed.connect(_build_controller.toggle_selected_power)
	_hud.upgrade_pressed.connect(_build_controller.upgrade_selected)
	_hud.move_pressed.connect(_build_controller.start_moving)
	_build_controller.move_started.connect(_hud.show_move_hint)
	_hud.power_pressed.connect(func() -> void: _sound.play(&"click", -8.0))
	_hud.restart_pressed.connect(_restart)
	_hud.keep_playing_pressed.connect(_on_keep_playing)
	_hud.main_menu_pressed.connect(
			func() -> void: get_tree().change_scene_to_file("res://menu/main_menu.tscn"))
	_hud.build_bar.slot_pressed.connect(_build_controller.select_slot)
	_hud.build_bar.demolish_pressed.connect(_build_controller.toggle_demolish)
	_hud.top_bar.bind_clock(_clock)
	_hud.bind_city(city)
	_hud.bind_history(history)
	_hud.bind_advisor(grid)
	_hud.jump_requested.connect(_camera_rig.focus_on)
	_hud.minimap.setup(grid, terrain, _camera_rig)
	_hud.minimap.pan_requested.connect(
			func(where: Vector3) -> void: _camera_rig.focus_on(where, false))
	_hud.game_menu.toggled.connect(_on_menu_toggled)
	_hud.game_menu.save_pressed.connect(save_game)
	_hud.game_menu.load_pressed.connect(load_game)
	_hud.game_menu.main_menu_pressed.connect(
			func() -> void: get_tree().change_scene_to_file("res://menu/main_menu.tscn"))
	_sim = CitySim.new(grid, city, smog)
	_sim.policies = policies
	_sim.fire_started.connect(_on_fire_started)
	_sim.burned_down.connect(_on_burned_down)
	_sim.inventions = inventions
	Inventions.current = inventions
	_hud.bind_inventions(inventions)
	_hud.inventions_panel.buy_pressed.connect(_on_invention_pressed)
	_hud.bind_policies(policies)
	_hud.policies_panel.policy_pressed.connect(_on_policy_pressed)
	_council = Council.new(grid, city)
	_hud.bind_council(_council)
	_council.request_finished.connect(_on_request_finished)
	_events = CityEvents.new(grid, city, _sim, smog)
	_hud.bind_events(_events)
	_overlay.setup(smog, grid, _sim.land)
	_overlay.mode_changed.connect(_on_overlay_mode_changed)
	_hud.build_bar.overlay_pressed.connect(_overlay.cycle)
	_walkers.setup(grid, city, _clock)
	_airships.setup(city, _clock, grid)
	_clock.day_ended.connect(_on_day_ended)
	city.changed.connect(func() -> void: _sound.set_city_size(city.population))
	_build_controller.feedback.connect(_on_build_feedback)
	_hud.build_bar.clicked.connect(func() -> void: _sound.play(&"click", -8.0))
	_events.event_fired.connect(func(_title: String, _message: String) -> void: _event_sounded = true)
	_events.choice_offered.connect(_on_choice_offered)
	_events.choice_resolved.connect(_on_choice_resolved)
	city.tier_reached.connect(func(_tier: int) -> void: _on_event_sounded("", ""))
	grid.buildings_changed.connect(func() -> void: _road_access_dirty = true)
	_place_town_hall()
	_vegetation.setup(grid, _hills)
	var map_material := _ground.get_surface_override_material(0) as ShaderMaterial
	map_material.set_shader_parameter("terrain_map", ImageTexture.create_from_image(terrain.to_image()))
	map_material.set_shader_parameter("terrain_amount", 1.0)
	_hud.bind_terrain(terrain)
	_hud.game_menu.set_map_seed(terrain.map_seed)
	var ground_materials: Array[ShaderMaterial] = [map_material, _hills.ground_material()]
	_season_view.setup(ground_materials, _vegetation)
	_wind_vane.position = grid.town_hall.position
	_day_night.setup(_sun, _world_environment.environment, _clock)
	_show_season(true)
	if not SaveGame.pending.is_empty():
		_apply_save(SaveGame.pending)
		SaveGame.pending = {}
	else:
		# A new city starts with what its difficulty allows, and its scenario
		# is still to be decided.
		city.crowns = GameRules.start_crowns()
		GameRules.scenario_settled = false
		Tutorial.reset()
	_hud.game_menu.set_terms(GameRules.difficulty_name())


func _process(delta: float) -> void:
	if _road_access_dirty:
		_road_access_dirty = false
		_refresh_road_access()
	if GameRules.is_tutorial() and not _game_over:
		_tutorial_wait -= delta
		if _tutorial_wait <= 0.0:
			_tutorial_wait = TUTORIAL_CHECK_SECONDS
			_check_tutorial()


## In the guided first game: see whether the task in hand has been done,
## and if so say so and show the next.
func _check_tutorial() -> void:
	var done := Tutorial.advance(city, grid)
	if done.is_empty():
		return
	_sound.play(&"repair", -8.0)
	if Tutorial.finished():
		_hud.show_notice("Task done: %s" % done, "That was the last one. Well done.")
	else:
		_hud.show_notice("Task done: %s" % done, "Next: %s" % Tutorial.TASKS[Tutorial.step][0])
	_hud.refresh_scenario()


## Tell the HUD which building the mouse is over, for its hover card. Roads
## are skipped: there are too many of them to be worth a card each.
func _on_cell_hovered(cell: Vector2i, in_bounds: bool) -> void:
	var building: Building = grid.building_at(cell) if in_bounds else null
	if building != null and building.def.is_road:
		building = null
	_hud.show_hover(building)


func _on_overlay_mode_changed(_mode: OverlayView.Mode) -> void:
	Tutorial.overlay_seen = true
	_hud.build_bar.set_overlay_name(_overlay.mode_name())
	_hud.show_legend(_overlay.legend())


## An event is waiting for a decision: sound the whistle and stop the clock.
func _on_choice_offered(_offer: Dictionary) -> void:
	_on_event_sounded("", "")
	_paused_by_event = not _clock.paused
	if _paused_by_event:
		_clock.toggle_pause()


func _on_choice_resolved() -> void:
	if _paused_by_event:
		_paused_by_event = false
		if _clock.paused:
			_clock.toggle_pause()


## Announce achievements earned just now: each a [name, description] pair
## (empty pairs are skipped). Several at once share one banner.
func _announce(earned: Array) -> void:
	var lines := PackedStringArray()
	for pair: Array in earned:
		if pair.size() == 2:
			lines.append("%s: %s" % [pair[0], pair[1]])
	if lines.is_empty():
		return
	_hud.show_notice("Achievement earned", "\n".join(lines))
	_event_sounded = true
	_sound.play(&"event", -6.0)


## Start the same kind of city again: same difficulty, scenario and seed.
func _restart() -> void:
	SaveGame.pending = {}
	get_tree().reload_current_scene()


## See whether today settled the scenario, and if so stop the clock and say
## how it went. The city itself carries on if the player wants it to.
func _judge_scenario() -> void:
	var outcome := GameRules.judge(city, grid)
	if outcome == 0:
		return
	GameRules.scenario_settled = true
	_paused_by_result = not _clock.paused
	if _paused_by_result:
		_clock.toggle_pause()
	_event_sounded = true
	ScoreBoard.enter(city, "Won" if outcome > 0 else "Out of time", terrain.map_seed)
	# The guided first game is a lesson, not a scenario to be proud of winning.
	if outcome > 0 and not GameRules.is_tutorial():
		_announce([Achievements.earn(&"scenario")])
	if outcome > 0:
		_sound.play(&"event")
		_hud.show_scenario_result("%s: done" % GameRules.scenario_name(),
				"%s\nYou did it. The city is yours to carry on with, for as long as it stands."
				% GameRules.goal_text())
	else:
		_sound.play(&"game_over")
		_hud.show_scenario_result("%s: out of time" % GameRules.scenario_name(),
				"%s\nThe day has passed. You can keep the city going in free play, or try again."
				% GameRules.goal_text())


func _on_keep_playing() -> void:
	if _paused_by_result:
		_paused_by_result = false
		if _clock.paused:
			_clock.toggle_pause()


## The council's request was met, or ran out of time.
func _on_request_finished(success: bool, title: String, message: String) -> void:
	_hud.show_notice(title, message)
	_event_sounded = true
	_sound.play(&"event" if success else &"error", -4.0)


func _on_fire_started(building: Building) -> void:
	_hud.show_notice("Fire!", "The %s is alight. Put it out (select it, then %s), or it will spread." % [
			building.def.display_name, GameSettings.key_label(&"repair")])
	_event_sounded = true
	_sound.play(&"breakdown", -2.0)


func _on_burned_down(display_name: String) -> void:
	_hud.show_notice("Burned down", "The %s has burned to the ground." % display_name)
	_event_sounded = true
	_sound.play(&"demolish", -2.0)


func _on_undone(refund: int) -> void:
	if refund >= 0:
		_hud.show_notice("Undone", "%d Crowns back in the treasury." % refund)
	else:
		_hud.show_notice("Nothing to undo", "Only a building still under construction, or road laid today, can be taken back.")


## A Buy button for an invention was pressed.
func _on_invention_pressed(invention: StringName) -> void:
	if _game_over:
		return
	_sound.play(&"repair" if inventions.buy(invention, city) else &"error", -6.0)


## A policy switch was pressed: change it if the cooldown allows.
func _on_policy_pressed(policy: StringName) -> void:
	if _game_over or city.tier < Policies.FROM_TIER:
		return
	_sound.play(&"click" if policies.toggle(policy, _clock.day) else &"error", -6.0)


## Dress the landscape for the clock's season and turn the wind to match.
func _show_season(instant: bool) -> void:
	var season := Seasons.of_day(_clock.day)
	_season_view.show_season(season, instant)
	smog.wind = Seasons.wind_on(_clock.day)
	_wind_vane.set_wind(smog.wind, instant)
	Building.smoke_drift = Vector3(smog.wind.x, 0.0, smog.wind.y)
	for building in grid.all_buildings:
		building.lean_smoke()


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


## Save the city to a slot by hand: the given one, or the one last used
## (F9).
func save_game(slot: String = "") -> void:
	if _game_over:
		return
	if _events.has_pending():
		_hud.show_notice("Decide first", "The game cannot be saved while an event awaits your decision.")
		return
	if slot.is_empty():
		slot = SaveGame.last_slot
	var saved := _write_save(slot)
	if saved:
		_hud.show_notice("Saved to %s" % SaveGame.slot_name(slot), "Day %d. F10 loads the newest save." % _clock.day)
	else:
		_hud.show_notice("Could not save", "The save file could not be written.")
	_sound.play(&"click" if saved else &"error", -6.0)
	_hud.game_menu.refresh_slots()


## Write the whole city to a slot. True if the file was written.
func _write_save(slot: String) -> bool:
	var buildings := []
	for building in grid.all_buildings:
		buildings.append(building.to_save())
	return SaveGame.write({
		"summary": {
			"day": _clock.day, "population": city.population, "tier": city.tier_name(),
			"scenario": GameRules.scenario_name(), "difficulty": GameRules.difficulty_name(),
			"saved_at": Time.get_unix_time_from_system(),
			"date": Time.get_datetime_string_from_system(false, true).left(16),
		},
		"map_seed": terrain.map_seed,
		"rules": GameRules.to_save(),
		"clock": _clock.to_save(),
		"city": city.to_save(),
		"events": _events.to_save(),
		"smog": smog.to_save(),
		"history": history.to_save(),
		"policies": policies.to_save(),
		"inventions": inventions.to_save(),
		"council": _council.to_save(),
		"cleared_trees": _vegetation.to_save(),
		"buildings": buildings,
	}, slot)


## Load a slot by restarting the scene with it: the given one, or whichever
## was saved most recently (F10).
func load_game(slot: String = "") -> void:
	if slot.is_empty():
		slot = SaveGame.latest_slot()
	if not slot.is_empty() and SaveGame.load_from_disk(slot):
		get_tree().reload_current_scene()
	else:
		_hud.show_notice("Nothing to load", "There is no saved city yet. Press F9 to save.")
		_sound.play(&"error", -10.0)


## Rebuild a saved city in this freshly started scene.
func _apply_save(data: Dictionary) -> void:
	GameRules.from_save(data.get("rules", {}))
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
		if not grid.can_place(Building.cells_for(def, origin, steps), def):
			continue
		_build_controller.place_building(def, origin, steps).from_save(entry)
	_vegetation.from_save(data.get("cleared_trees", []))
	smog.from_save(data.get("smog", []))
	smog.mark_buildings(grid.all_buildings)
	city.from_save(data.get("city", {}))
	_events.from_save(data.get("events", {}))
	history.from_save(data.get("history", {}))
	policies.from_save(data.get("policies", {}))
	inventions.from_save(data.get("inventions", []))
	_council.from_save(data.get("council", {}))
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
	# Development aids: F1 to F5 fire each event at once, to test them without
	# waiting for the dice, F6 unlocks the next city tier, F7 skips to the
	# next season, and F8 sets the selected building on fire. Not in exported
	# builds.
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
			KEY_F5:
				_events.fire(CityEvents.Type.FESTIVAL, _clock.day)
			KEY_F8:
				# Set the selected building alight.
				var target := _build_controller.selected_building
				if is_instance_valid(target) and target.def.demolishable:
					target.set_on_fire(true)
					_on_fire_started(target)
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
	_council.day_passed(day)
	_judge_scenario()
	_announce(Achievements.check(city, grid, inventions, _council))
	# The autosave: quiet, and never while an event is waiting on a choice,
	# since that choice could not be saved with it.
	if day % AUTOSAVE_DAYS == 0 and not _events.has_pending():
		_write_save(SaveGame.AUTOSAVE)
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
	ScoreBoard.enter(city, "Walkout", terrain.map_seed)
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
