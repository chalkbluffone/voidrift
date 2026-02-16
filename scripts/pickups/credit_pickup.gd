extends BasePickup

## CreditPickup - Dropped by enemies, magnetically attracted to player.
## Uses player's pickup_radius stat for magnet range.

@export var credit_amount: int = 1


func _on_pickup_ready() -> void:
	pass


func initialize(amount: int) -> void:
	credit_amount = amount


func _apply_effect() -> void:
	GameManager.add_credits(credit_amount)
