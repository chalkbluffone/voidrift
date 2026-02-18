extends BasePickup

## StardustPickup - Rare permanent currency dropped by loot freighters.
## Uses the same pickup behavior as XP and credits (player's PickupRange area).
## Calls ProgressionManager.add_stardust() on collection.

@export var stardust_amount: int = 1


func initialize(amount: int) -> void:
	stardust_amount = amount


func _apply_effect() -> void:
	ProgressionManager.add_stardust(stardust_amount)
