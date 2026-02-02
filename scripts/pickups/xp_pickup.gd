extends BasePickup

## XPPickup - Dropped by enemies, magnetically attracted to player.
## Uses player's pickup_radius stat for magnet range.

@export var xp_amount: float = 10.0


func _on_pickup_ready() -> void:
	FileLogger.log_debug("XPPickup", "Spawned at %s" % global_position)


func initialize(amount: float) -> void:
	xp_amount = amount


func _apply_effect() -> void:
	GameManager.add_xp(xp_amount)
