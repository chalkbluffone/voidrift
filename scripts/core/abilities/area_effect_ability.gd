class_name AreaEffectAbility
extends BaseAbility

## AreaEffectAbility - Captain ability that affects enemies in range.
## Supports: enemy_slow (speed multiplier reduction), convert_enemies (subjugation).
## radius == 0 means screen-wide (all enemies in the scene tree group "enemies").

var _affected_enemies: Array[Node] = []
var _slow_amount: float = 0.0
var _convert_max: int = 0
var _converted_enemies: Array[Node] = []


func _activate() -> void:
	_slow_amount = float(effects.get("enemy_slow", 0.0))
	_convert_max = int(effects.get("convert_enemies", 0))

	if _slow_amount <= 0.0 and _convert_max <= 0:
		return

	var enemies: Array[Node] = _gather_enemies()

	# Apply slow to each enemy
	if _slow_amount > 0.0:
		for enemy: Node in enemies:
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(_slow_amount, duration)
				_affected_enemies.append(enemy)

	# Convert enemies (subjugation)
	if _convert_max > 0:
		var converted_count: int = 0
		for enemy: Node in enemies:
			if converted_count >= GameConfig.SUBJUGATION_MAX_TARGETS:
				break
			if enemy.has_method("subjugate"):
				enemy.subjugate(duration, GameConfig.SUBJUGATION_DAMAGE_MULT)
				_converted_enemies.append(enemy)
				converted_count += 1


func _gather_enemies() -> Array[Node]:
	## Gather enemies within radius. radius == 0 means all enemies.
	var radius_value: float = self.radius
	var enemies: Array[Node] = []

	if radius_value <= 0.0:
		enemies.assign(FrameCache.enemies)
	else:
		if _owner_ship and _owner_ship is Node2D:
			var owner_pos: Vector2 = (_owner_ship as Node2D).global_position
			var nearby: Array[Node2D] = FrameCache.enemy_grid.query_radius(owner_pos, radius_value)
			for enemy: Node2D in nearby:
				enemies.append(enemy)
	return enemies


func _on_expire() -> void:
	# Revert subjugated enemies
	for enemy: Node in _converted_enemies:
		if is_instance_valid(enemy) and enemy.has_method("unsubjugate"):
			enemy.unsubjugate()
	_converted_enemies.clear()

	# Clear slow tracking
	_affected_enemies.clear()
	_slow_amount = 0.0
	_convert_max = 0
