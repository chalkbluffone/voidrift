extends BasePickup

## CreditPickup - Dropped by enemies, instantly attracted to player.
## Always flies to player immediately (no PickupRange required).

@export var credit_amount: int = 1

var _player: Node2D = null


func _on_pickup_ready() -> void:
	# Find and instantly attract to the player
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node2D
		attract_to(_player)
	else:
		# Retry next frame if player not found yet
		call_deferred("_deferred_find_player")


func _deferred_find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node2D
		attract_to(_player)


func initialize(amount: int) -> void:
	credit_amount = amount


func _apply_effect() -> void:
	ProgressionManager.add_credits(credit_amount)
