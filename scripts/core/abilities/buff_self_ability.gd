class_name BuffSelfAbility
extends BaseAbility

## BuffSelfAbility - Captain ability that applies temporary stat buffs to the player.
## Supports: stat multiplier buffs, invulnerability, heal_percent.
## Effects dict example: {"damage": 1.0, "invulnerable": true, "heal_percent": 0.3}

# Track applied buffs so we can reverse them on expire
var _applied_multipliers: Dictionary = {}
var _granted_invulnerability: bool = false


func _activate() -> void:
	if not _owner_stats:
		return

	for key in effects:
		var value: Variant = effects[key]

		if key == "invulnerable" and value == true:
			_granted_invulnerability = true
			if _owner_ship and _owner_ship.has_method("_set_invincible"):
				_owner_ship._set_invincible(true)
			continue

		if key == "heal_percent":
			var max_hp: float = _owner_stats.get_stat(_owner_stats.STAT_MAX_HP)
			var heal_amount: float = max_hp * float(value)
			if _owner_ship and _owner_ship.has_method("heal"):
				_owner_ship.heal(heal_amount)
			continue

		# Everything else is a stat multiplier buff
		var amount: float = float(value)
		_owner_stats.add_multiplier_bonus(key, amount)
		_applied_multipliers[key] = amount


func _on_expire() -> void:
	if not _owner_stats:
		return

	# Remove stat buffs
	for key in _applied_multipliers:
		_owner_stats.add_multiplier_bonus(key, -_applied_multipliers[key])
	_applied_multipliers.clear()

	# Remove invulnerability
	if _granted_invulnerability:
		_granted_invulnerability = false
		if _owner_ship and _owner_ship.has_method("_set_invincible"):
			_owner_ship._set_invincible(false)
