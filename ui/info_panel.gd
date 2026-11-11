class_name InfoPanel
extends PanelContainer
## Details of the selected building: road access, workers, output, Coal and
## condition. Staffing and Coal figures are as of the last simulated day.

var _label: Label


func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	_label = Label.new()
	margin.add_child(_label)
	hide()


## Show details for `building`, or hide the panel if it is null or gone.
func show_building(building: Building) -> void:
	if building == null or not is_instance_valid(building) or building.is_queued_for_deletion():
		hide()
		return
	_label.text = describe(building)
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
		lines.append("Houses: %d citizens" % def.housing)

	var staffing := 1.0
	if def.workers > 0:
		lines.append("Workers: %d / %d" % [building.staff, def.workers])
		staffing = float(building.staff) / def.workers

	if def.coal_per_day > 0:
		var coal_line := "Coal: burns %d per day" % def.coal_per_day
		if building.road_access and not building.fuelled:
			coal_line += " - got NONE yesterday"
		lines.append(coal_line)

	var working := building.road_access and building.fuelled
	_append_output(lines, "Food", def.food_output, staffing, working)
	_append_output(lines, "Coal", def.coal_output, staffing, working)
	_append_output(lines, "Crowns", def.crowns_output, staffing, working)

	lines.append("Upkeep: %d Crowns per day" % CitySim.UPKEEP_PER_BUILDING)
	lines.append("Condition: good")
	return "\n".join(lines)


static func _append_output(lines: PackedStringArray, resource: String, full_output: int,
		staffing: float, working: bool) -> void:
	if full_output <= 0:
		return
	var now := roundi(full_output * staffing) if working else 0
	lines.append("Output: %d %s per day (max %d)" % [now, resource, full_output])
