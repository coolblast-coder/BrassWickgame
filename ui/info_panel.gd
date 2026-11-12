class_name InfoPanel
extends PanelContainer
## Details of the selected building: road access, workers, output, Coal, smog
## and condition, with a Repair button when it is broken. Staffing, output and
## Coal figures are as of the last simulated day.

## The Repair button was clicked for the building on show.
signal repair_pressed

var _label: Label
var _repair_button: Button


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
	hide()


## Show details for `building`, or hide the panel if it is null or gone.
func show_building(building: Building) -> void:
	if building == null or not is_instance_valid(building) or building.is_queued_for_deletion():
		hide()
		return
	_label.text = describe(building)
	_repair_button.visible = building.broken
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

	if def.workers > 0:
		lines.append("Workers: %d / %d" % [building.staff, def.workers])

	if def.coal_per_day > 0:
		var coal_line := "Coal: burns %d per day" % def.coal_per_day
		if building.road_access and not building.fuelled:
			coal_line += " - got NONE yesterday"
		lines.append(coal_line)

	# Actual figures from the last day, so staffing, smog, strikes, breakdowns
	# and Coal shortages are all already counted.
	_append_output(lines, "Food", building.food_made, def.food_output)
	_append_output(lines, "Coal", building.coal_made, def.coal_output)
	_append_output(lines, "Crowns", building.crowns_made, def.crowns_output)

	if building.smoggy:
		if def.food_output > 0:
			lines.append("Smog: heavy here - grows half as much")
		else:
			lines.append("Smog: heavy here")
	lines.append("Upkeep: %d Crowns per day" % CitySim.UPKEEP_PER_BUILDING)
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
