extends BasePickup

## GravityWellPickup - Rare enemy drop that instantly vacuums ALL uncollected
## pickups on the map to the player. Space-themed adaptation of Megabonk's magnet powerup.

var _player_ref: Node2D = null


func _on_pickup_ready() -> void:
	# Find player for fixed-radius attraction check
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = players[0] as Node2D


func _process(delta: float) -> void:
	super._process(delta)
	# Use fixed magnet radius — Gravity Well orbs are easy to grab
	if _player_ref and is_instance_valid(_player_ref):
		_check_fixed_radius_attraction(_player_ref)


func _get_fixed_magnet_radius() -> float:
	return GameConfig.PICKUP_MAGNET_RADIUS * 2.0


func _apply_effect() -> void:
	## Vacuum ALL pickups on the map to the player.
	if not _player_ref or not is_instance_valid(_player_ref):
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player_ref = players[0] as Node2D
	if not _player_ref:
		return

	var all_pickups: Array[Node] = get_tree().get_nodes_in_group("pickups")
	for pickup: Node in all_pickups:
		if pickup == self:
			continue
		if not is_instance_valid(pickup):
			continue
		if pickup is BasePickup:
			var bp: BasePickup = pickup as BasePickup
			bp.attract_to(_player_ref)
			# Boost speed for satisfying vacuum effect
			bp._current_speed = GameConfig.GRAVITY_WELL_VACUUM_SPEED * 0.5
