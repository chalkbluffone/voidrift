extends BasePowerUp

## SpeedPowerUp - Temporarily boosts player movement speed.
## Blue lightning bolt visual. Duration scaled by powerup_multiplier stat.
## Collecting another speed power-up while active refreshes the timer.


func _on_pickup_ready() -> void:
	_symbol = "\u26A1"
	_symbol_font_size = 26
	super._on_pickup_ready()


func _apply_powerup_effect(player: Node2D, multiplier: float) -> void:
	var duration: float = GameConfig.POWERUP_SPEED_BOOST_DURATION * multiplier
	var bonus: float = GameConfig.POWERUP_SPEED_BOOST_AMOUNT

	if not player.has_method("get_stats"):
		return
	var stats: Node = player.get_stats()
	if not stats or not stats.has_method("add_multiplier_bonus"):
		return

	# If a speed boost is already active, remove the old bonus first
	if player.has_meta("speed_boost_active"):
		var old_bonus: float = float(player.get_meta("speed_boost_bonus"))
		stats.add_multiplier_bonus("movement_speed", -old_bonus)

	# Apply new bonus
	stats.add_multiplier_bonus("movement_speed", bonus)
	player.set_meta("speed_boost_active", true)
	player.set_meta("speed_boost_bonus", bonus)

	# Start/refresh timer — old timer callbacks harmlessly no-op via generation counter
	var generation: int = int(player.get_meta("speed_boost_generation", 0)) + 1
	player.set_meta("speed_boost_generation", generation)

	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if not is_instance_valid(player):
			return
		if not player.has_meta("speed_boost_generation"):
			return
		if int(player.get_meta("speed_boost_generation")) != generation:
			return  # A newer boost replaced this one
		var current_bonus: float = float(player.get_meta("speed_boost_bonus"))
		stats.add_multiplier_bonus("movement_speed", -current_bonus)
		player.remove_meta("speed_boost_active")
		player.remove_meta("speed_boost_bonus")
		player.remove_meta("speed_boost_generation")
	)
