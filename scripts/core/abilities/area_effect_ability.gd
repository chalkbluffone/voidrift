class_name AreaEffectAbility
extends BaseAbility

## AreaEffectAbility - Captain ability that affects enemies in range.
## Supports: enemy_slow (speed multiplier reduction).
## radius == 0 means screen-wide (all enemies in the scene tree group "enemies").

var _affected_enemies: Array[Node] = []
var _slow_amount: float = 0.0


func _activate() -> void:
	_slow_amount = float(effects.get("enemy_slow", 0.0))
	if _slow_amount <= 0.0:
		return

	# Gather enemies: radius 0 = all enemies on screen
	var radius_value: float = float(effects.get("radius", 0.0))
	var enemies: Array[Node] = []

	if radius_value <= 0.0:
		# Screen-wide: grab all enemies via FrameCache
		enemies.assign(FrameCache.enemies)
	else:
		# Distance-based from player via spatial grid
		if _owner_ship and _owner_ship is Node2D:
			var owner_pos: Vector2 = (_owner_ship as Node2D).global_position
			var nearby: Array[Node2D] = FrameCache.enemy_grid.query_radius(owner_pos, radius_value)
			for enemy: Node2D in nearby:
				enemies.append(enemy)

	# Apply slow to each enemy
	for enemy in enemies:
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(_slow_amount, duration)
			_affected_enemies.append(enemy)


func _on_expire() -> void:
	# Enemies handle their own slow timer via apply_slow(amount, duration),
	# so we just clear our tracking list.
	_affected_enemies.clear()
	_slow_amount = 0.0
