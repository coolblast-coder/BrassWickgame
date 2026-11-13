class_name InfoPanel
extends PanelContainer
## Details of the selected building: road access, residents, workers, what it
## uses (Coal, Food, Steam) and makes, smog and condition, with a Repair
## button when it is broken. Staffing, output and supply figures are as of the
## last simulated day.

## The Repair button was clicked for the building on show.
signal repair_pressed
## The Switch off / Switch on button was clicked for the building on show.
signal power_pressed

var _label: Label
var _repair_button: Button
var _power_button: Button


func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	_label = Label.new()
	column.add_child(_label)
	_repair_button = Button.new()
	_repair_button.text = "F  Repair (%d Crowns)" % CitySim.REPAIR_COST
	_repair_button.focus_mode = Control.FOCUS_NONE
	_repair_button.pressed.connect(func() -> void: repair_pressed.emit())
	column.add_child(_repair_button)
	_power_button = Button.new()
	_power_button.focus_mode = Control.FOCUS_NONE
	_power_button.pressed.connect(func() -> void: power_pressed.emit())
	column.add_child(_power_button)
	hide()


## Show details for `building`, or hide the panel if it is null or gone.
func show_building(building: Building) -> void:
	if building == null or not is_instance_valid(building) or building.is_queued_for_deletion():
		hide()
		return
	_label.text = describe(building)
	_repair_button.visible = building.broken
	_power_button.visible = building.def.workers > 0
	_power_button.text = "P  Switch on" if building.paused else "P  Switch off"
	show()


static func describe(building: Building) -> String:
	var def := building.def
	var lines: PackedStringArray = [def.display_name]

	if def.id == &"town_hall":
		lines.append("Roads must lead back here.")
		lines.append("Cannot be demolished.")
		return "\n".join(lines)

	if building.road_access:
		lines.append("Road access: yes")
	else:
		lines.append("Road access: NONE - not working")
		lines.append("  Needs a road, edge to edge, that leads to the Town Hall.")

	if def.housing > 0:
		lines.append("Residents: %d / %d" % [building.residents, def.housing])

	if def.wants_goods:
		lines.append("Residents expect Goods from the %s tier on." % CityState.TIER_NAMES[CitySim.GOODS_TIER])

	if building.paused:
		lines.append("SWITCHED OFF - takes no workers, makes nothing")
	if def.workers > 0:
		var priority := " (staffed first)" if def.essential else ""
		lines.append("Workers: %d / %d%s" % [building.staff, def.workers, priority])

	if def.coal_per_day > 0:
		var coal_line := "Coal: burns %d per day" % def.coal_per_day
		if building.road_access and not building.fuelled:
			coal_line += " - got NONE yesterday"
		lines.append(coal_line)

	if def.steam_per_day > 0:
		var steam_line := "Steam: uses %d per day from the %s tier on" % [
				def.steam_per_day, CityState.TIER_NAMES[CitySim.STEAM_TIER]]
		if building.road_access and not building.powered:
			steam_line += " - got NONE yesterday, did not run"
		lines.append(steam_line)

	if def.food_per_day > 0:
		var food_line := "Food: uses %d per day" % def.food_per_day
		if building.road_access and not building.fuelled:
			food_line += " - got NONE yesterday, stayed shut"
		lines.append(food_line)

	# Actual figures from the last day, so staffing, smog, strikes, breakdowns
	# and Coal shortages are all already counted.
	_append_output(lines, "Food", building.food_made, def.food_output)
	_append_output(lines, "Coal", building.coal_made, def.coal_output)
	_append_output(lines, "Crowns", building.crowns_made, def.crowns_output)
	_append_output(lines, "Water", building.water_made, def.water_output)
	_append_output(lines, "Goods", building.goods_made, def.goods_output)
	_append_output(lines, "Steam", building.steam_made, def.steam_output)

	if building.smoggy:
		if def.food_output > 0:
			lines.append("Smog: heavy here - grows half as much")
		else:
			lines.append("Smog: heavy here")
	lines.append("Upkeep: %d Crowns per day" % CitySim.UPKEEP_BY_TIER[BuildingCard.city_tier])
	if def.storage > 0:
		lines.append("Room for %d more of every resource." % def.storage)
	if def.trade_coal > 0:
		lines.append("Sells up to %d spare Coal a day for %d Crowns," % [def.trade_coal, def.trade_crowns])
		lines.append("  never dropping stock below %d Coal." % CitySim.TRADE_COAL_RESERVE)
		lines.append("Sold: %d Crowns of Coal yesterday" % building.crowns_made)
	if def.citywide_calm > 0.0:
		lines.append("Lowers Unrest by %.0f a day across the city." % def.citywide_calm)
	if def.unique:
		lines.append("Only one can stand in the city.")
	var condition := " while it runs" if def.workers > 0 else ""
	if def.calming:
		lines.append("Calms homes within %d tiles%s." % [def.effect_range, condition])
	if def.smog_clear_per_day > 0:
		lines.append("Clears smog within %d tiles%s." % [def.effect_range, condition])
	if def.repairs:
		lines.append("Repairs breakdowns within %d tiles for free," % def.effect_range)
		lines.append("  at the end of each day, while staffed.")
	if building.broken:
		lines.append("Condition: BROKEN DOWN - not working")
		lines.append("  Repair it, or wait for a Mechanic's Yard in range.")
	elif def.can_break:
		lines.append("Condition: good")
	return "\n".join(lines)


static func _append_output(lines: PackedStringArray, resource: String, made: int,
		full_output: int) -> void:
	if full_output <= 0:
		return
	lines.append("Output: %d %s yesterday (max %d)" % [made, resource, full_output])
