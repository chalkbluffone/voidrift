extends BasePickup

## XPPickup - Dropped by enemies, magnetically attracted to player.
## Uses player's pickup_radius stat for magnet range.

@export var xp_amount: float = 1.0


func _on_pickup_ready() -> void:
	pass


func initialize(amount: float) -> void:
	xp_amount = amount


func _apply_effect() -> void:
	ProgressionManager.add_xp(xp_amount)
