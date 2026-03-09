extends BasePowerUp

## GravityWellPickup - Power-up that instantly vacuums ALL uncollected drops
## on the map to the player. Skips other power-ups (they require physical touch).
## Purple neon visual. Space-themed adaptation of Megabonk's magnet powerup.


func _on_pickup_ready() -> void:
	_symbol = "\u25CE"
	_symbol_font_size = 22
	super._on_pickup_ready()


func _apply_powerup_effect(player: Node2D, _multiplier: float) -> void:
	## Vacuum all drops (XP, Credits, Stardust) to the player. Skip other power-ups.
	var all_pickups: Array[Node] = get_tree().get_nodes_in_group("pickups")
	for pickup: Node in all_pickups:
		if pickup == self:
			continue
		if not is_instance_valid(pickup):
			continue
		# Skip other power-ups — they require physical touch
		if pickup.is_in_group("powerups"):
			continue
		if pickup is BasePickup:
			var bp: BasePickup = pickup as BasePickup
			bp.attract_to(player)
			# Boost speed for satisfying vacuum effect
			bp._current_speed = GameConfig.GRAVITY_WELL_VACUUM_SPEED
