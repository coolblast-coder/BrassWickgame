class_name BuildingCard
extends PanelContainer
## The hover card: a description of a building in the build menu, or a short
## summary of a building on the map. It never takes mouse input.

const WIDTH := 320.0

## The city's tier, kept up to date by the HUD, so a card can say whether a
## building is still locked.
static var city_tier: int = 0

var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = WIDTH - 20.0
	margin.add_child(_label)
	hide()


## Describe a kind of building: what it is for, then its numbers.
func show_def(def: BuildingDef) -> void:
	_show_text(describe_def(def))


## Summarise a building standing on the map.
func show_building(building: Building) -> void:
	_show_text(describe_building(building))


func _show_text(text: String) -> void:
	_label.text = text
	# Collapse to nothing and let it grow back upward to fit the new text;
	# on its own a card grows for longer text but never shrinks again.
	offset_top = offset_bottom
	show()


static func describe_def(def: BuildingDef) -> String:
	var lines: PackedStringArray = []
	if def.is_road:
		lines.append("%s  -  %d Crowns per tile" % [def.display_name, def.cost])
		lines.append("%d Crowns per tile across water" % def.water_cost)
	elif def.cost > 0:
		lines.append("%s  -  %d Crowns" % [def.display_name, def.cost])
	else:
		lines.append(def.display_name)
	if def.tier > city_tier:
		lines.append("LOCKED: unlocks when the city becomes a %s (%d citizens)" % [
				CityState.TIER_NAMES[def.tier], CityState.TIER_POPULATION[def.tier]])
	if not def.description.is_empty():
		lines.append("")
		lines.append(def.description)
	lines.append("")
	lines.append("Size: %d x %d tiles" % [def.footprint.x, def.footprint.y])
	if def.housing > 0:
		lines.append("Houses %d citizens" % def.housing)
	if def.workers > 0:
		lines.append("Needs %d workers%s" % [def.workers, ", staffed first" if def.essential else ""])
	if def.coal_per_day > 0:
		lines.append("Burns %d Coal a day%s" % [
				def.coal_per_day, ", twice that in winter" if def.housing > 0 else ""])
	if def.food_per_day > 0:
		lines.append("Uses %d Food a day" % def.food_per_day)
	if def.food_output > 0:
		lines.append("Makes %d Food a day" % def.food_output)
		lines.append("  a quarter more in autumn, a quarter less in winter")
	if def.coal_output > 0:
		lines.append("Makes %d Coal a day" % def.coal_output)
	if def.crowns_output > 0:
		lines.append("Makes %d Crowns a day" % def.crowns_output)
	if def.water_output > 0:
		lines.append("Makes %d Water a day" % def.water_output)
	if def.steam_per_day > 0:
		lines.append("Uses %d Steam a day from the %s tier on" % [
				def.steam_per_day, CityState.TIER_NAMES[CitySim.STEAM_TIER]])
	if def.steam_output > 0:
		lines.append("Makes %d Steam a day" % def.steam_output)
	if def.goods_output > 0:
		lines.append("Makes %d Goods a day" % def.goods_output)
	if def.wants_goods:
		lines.append("Residents expect Goods from the %s tier on" % CityState.TIER_NAMES[CitySim.GOODS_TIER])
	if def.seam_bonus > 0.0:
		lines.append("Up to +%d%% output on a coal seam" % roundi(def.seam_bonus * 100.0))
	if def.fertile_bonus > 0.0:
		lines.append("Up to +%d%% output on fertile soil" % roundi(def.fertile_bonus * 100.0))
	if def.riverside_bonus > 0.0:
		lines.append("+%d%% output beside the river" % roundi(def.riverside_bonus * 100.0))
	if def.land_value > 0.0:
		lines.append("Homes within %d tiles pay %d%% more tax" % [
				def.land_value_range, roundi(def.land_value * 100.0)])
	elif def.land_value < 0.0:
		lines.append("Homes within %d tiles pay %d%% less tax" % [
				def.land_value_range, roundi(-def.land_value * 100.0)])
	if def.storage > 0:
		lines.append("Room for %d more of every resource" % def.storage)
	if def.trade_coal > 0:
		lines.append("Sells up to %d Coal a day for %d Crowns" % [def.trade_coal, def.trade_crowns])
	if def.calming:
		lines.append("Calms homes within %d tiles" % def.effect_range)
	if def.smog_clear_per_day > 0:
		lines.append("Clears smog within %d tiles" % def.effect_range)
	if def.repairs:
		lines.append("Repairs machines within %d tiles" % def.effect_range)
	if def.citywide_calm > 0.0:
		lines.append("Lowers Unrest by %.0f a day, city-wide" % def.citywide_calm)
	if def.smog_per_day > 0:
		lines.append("Smog: %s" % _smog_word(def.smog_per_day))
	if def.can_break:
		lines.append("Can break down")
	if def.unique:
		lines.append("One per city")
	if def.demolishable and not def.is_road:
		lines.append("Upkeep: %d Crowns a day" % CitySim.UPKEEP_BY_TIER[city_tier])
	return "\n".join(lines)


static func describe_building(building: Building) -> String:
	var def := building.def
	var lines: PackedStringArray = [def.display_name]
	if not def.demolishable:
		lines.append(def.description)
		return "\n".join(lines)
	if not building.road_access:
		lines.append("No road access - not working")
	elif building.broken:
		lines.append("Broken down - not working")
	elif building.paused:
		lines.append("Switched off")
	if def.housing > 0:
		lines.append("Residents: %d / %d" % [building.residents, def.housing])
	if def.workers > 0:
		lines.append("Workers: %d / %d" % [building.staff, def.workers])
	lines.append("Click for details")
	return "\n".join(lines)


static func _smog_word(amount: int) -> String:
	if amount >= 8:
		return "heavy"
	if amount >= 3:
		return "moderate"
	return "light"
