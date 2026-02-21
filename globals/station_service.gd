extends Node

## StationService - Handles space station buff generation and application.
## Autoload singleton: StationService

## Emitted when a station is fully charged and buff selection should begin.
## @param options: Array of buff choices (Array[Dictionary])
signal station_buff_triggered(options: Array)

## Emitted when the player selects or ignores a buff.
## @param buff: The selected buff (Dictionary, empty if ignored)
signal station_buff_completed(buff: Dictionary)

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var FileLogger: Node = get_node("/root/FileLogger")


## Generate buff options for a completed station.
## @param luck: Player's luck stat value
## @return Array of buff option dictionaries
func generate_buff_options(luck: float) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var used_stats: Array[String] = []
	
	for i in range(GameConfig.STATION_BUFF_OPTION_COUNT):
		var option: Dictionary = _generate_single_buff(luck, used_stats)
		if not option.is_empty():
			options.append(option)
			used_stats.append(String(option.get("stat", "")))
	
	return options


## Generate a single buff option.
func _generate_single_buff(luck: float, exclude_stats: Array[String]) -> Dictionary:
	var rarity: String = _roll_station_rarity(luck)
	
	# Pick a random stat not already used
	var available_stats: Array[String] = []
	for stat_name in GameConfig.STATION_BUFFABLE_STATS:
		if stat_name not in exclude_stats:
			available_stats.append(stat_name)
	
	if available_stats.is_empty():
		return {}
	
	var stat: String = available_stats[randi() % available_stats.size()]
	
	# Calculate bonus amount based on rarity
	var range_data: Dictionary = GameConfig.STATION_BUFF_RANGES.get(rarity, {"min": 0.02, "max": 0.04})
	var min_val: float = float(range_data.get("min", 0.02))
	var max_val: float = float(range_data.get("max", 0.04))
	var amount: float = randf_range(min_val, max_val)
	
	# Round to 2 decimal places for cleaner display
	amount = snappedf(amount, 0.01)
	
	# Determine if this is a flat or multiplier stat
	var is_flat: bool = stat in GameConfig.STATION_FLAT_STATS
	
	return {
		"stat": stat,
		"amount": amount,
		"rarity": rarity,
		"is_flat": is_flat,
		"display_name": GameConfig.STATION_STAT_DISPLAY_NAMES.get(stat, stat),
		"color": GameConfig.STATION_RARITY_COLORS.get(rarity, Color.WHITE),
	}


## Roll rarity for a station buff, influenced by luck.
## Uses same luck model as UpgradeService but with station-specific weights.
func _roll_station_rarity(luck: float) -> String:
	var w: Dictionary = {
		"uncommon": float(GameConfig.STATION_RARITY_WEIGHTS.get("uncommon", 50.0)),
		"rare": float(GameConfig.STATION_RARITY_WEIGHTS.get("rare", 30.0)),
		"epic": float(GameConfig.STATION_RARITY_WEIGHTS.get("epic", 15.0)),
		"legendary": float(GameConfig.STATION_RARITY_WEIGHTS.get("legendary", 5.0)),
	}
	
	# Apply luck scaling (same model as UpgradeService)
	var luck_factor: float = 1.0 + (clampf(luck, 0.0, float(GameConfig.RARITY_LUCK_MAX)) / float(GameConfig.RARITY_LUCK_FACTOR_DIVISOR))
	
	# Station rarities start at uncommon, so we use adjusted exponents
	var rarity_exponents: Dictionary = {
		"uncommon": 0,  # No luck boost for base rarity
		"rare": 1,
		"epic": 2,
		"legendary": 3,
	}
	
	for rarity_key in rarity_exponents.keys():
		var rarity_exp: int = int(rarity_exponents.get(rarity_key, 0))
		if rarity_exp > 0:
			w[rarity_key] = float(w.get(rarity_key, 0.0)) * pow(luck_factor, rarity_exp)
	
	# Roll from weighted pool
	var total: float = 0.0
	for key in w.keys():
		total += w.get(key, 0.0)
	
	if total <= 0.0:
		return "uncommon"
	
	var roll: float = randf() * total
	var acc: float = 0.0
	
	# Order from lowest to highest rarity
	var order: Array[String] = ["uncommon", "rare", "epic", "legendary"]
	for key in order:
		acc += w.get(key, 0.0)
		if roll <= acc:
			return key
	
	return "uncommon"


## Apply a buff to the player's stats.
## @param buff: The buff dictionary from generate_buff_options
## @param stats_component: The player's StatsComponent
func apply_buff(buff: Dictionary, stats_component: Node) -> void:
	if buff.is_empty():
		FileLogger.log_info("StationService", "Player ignored station buff")
		station_buff_completed.emit({})
		return
	
	var stat: String = String(buff.get("stat", ""))
	var amount: float = float(buff.get("amount", 0.0))
	var is_flat: bool = bool(buff.get("is_flat", false))
	
	if stat.is_empty() or not stats_component:
		push_error("StationService: Invalid buff or missing stats component")
		station_buff_completed.emit({})
		return
	
	# Apply the bonus
	if is_flat:
		stats_component.add_flat_bonus(stat, amount)
	else:
		stats_component.add_multiplier_bonus(stat, amount)
	
	FileLogger.log_info("StationService", "Applied %s buff +%.0f%% %s (%s)" % [
		String(buff.get("rarity", "uncommon")),
		amount * 100.0,
		stat,
		"flat" if is_flat else "mult"
	])
	
	station_buff_completed.emit(buff)


## Trigger the buff selection UI for a completed station.
## @param player_luck: The player's current luck stat
func trigger_buff_selection(player_luck: float) -> void:
	var options: Array[Dictionary] = generate_buff_options(player_luck)
	
	if options.is_empty():
		push_error("StationService: Failed to generate buff options")
		return
	
	# Pause game and trigger UI
	RunManager.set_station_buff_state()
	station_buff_triggered.emit(options)
