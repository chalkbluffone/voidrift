extends BasePowerUp

## HealthPowerUp - Restores a fraction of the player's max HP.
## Red heart visual. Amount scaled by powerup_multiplier stat.


func _on_pickup_ready() -> void:
	_symbol = "\u2764"
	_symbol_font_size = 28
	super._on_pickup_ready()


func _apply_powerup_effect(player: Node2D, multiplier: float) -> void:
	var max_hp: float = player.get_stat("max_hp")
	var heal_amount: float = max_hp * GameConfig.POWERUP_HEALTH_RESTORE_FRACTION * multiplier
	var has_overheal: bool = player.get_stat("overheal") > 0.0
	if player.has_method("heal"):
		player.heal(heal_amount, has_overheal)
