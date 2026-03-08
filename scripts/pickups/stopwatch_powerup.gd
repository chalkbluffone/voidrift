extends BasePowerUp

## StopwatchPowerUp - Freezes all enemies in place for a duration.
## Gold stopwatch visual. Duration scaled by powerup_multiplier stat.
## Collecting another stopwatch while active refreshes the timer (enemies stay frozen).


func _on_pickup_ready() -> void:
	_symbol = "\u23F1"
	_symbol_font_size = 24
	super._on_pickup_ready()


func _apply_powerup_effect(player: Node2D, multiplier: float) -> void:
	var duration: float = GameConfig.POWERUP_STOPWATCH_DURATION * multiplier
	var tree: SceneTree = get_tree()

	# Freeze all current enemies
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	for enemy: Node in enemies:
		if is_instance_valid(enemy) and "is_frozen" in enemy:
			enemy.is_frozen = true

	# Set global freeze flag so newly spawned enemies also freeze
	tree.set_meta("stopwatch_freeze_active", true)

	# Start/refresh timer — old timer callbacks harmlessly no-op via generation counter
	var generation: int = _get_freeze_generation(tree) + 1
	tree.set_meta("stopwatch_freeze_generation", generation)

	tree.create_timer(duration).timeout.connect(func() -> void:
		if not is_instance_valid(tree):
			return
		if not tree.has_meta("stopwatch_freeze_generation"):
			return
		if int(tree.get_meta("stopwatch_freeze_generation")) != generation:
			return  # A newer stopwatch replaced this one
		# Unfreeze all enemies
		var current_enemies: Array[Node] = tree.get_nodes_in_group("enemies")
		for enemy: Node in current_enemies:
			if is_instance_valid(enemy) and "is_frozen" in enemy:
				enemy.is_frozen = false
		tree.remove_meta("stopwatch_freeze_generation")
		tree.remove_meta("stopwatch_freeze_active")
	)


## Get the current freeze generation counter from the SceneTree.
func _get_freeze_generation(tree: SceneTree) -> int:
	if tree.has_meta("stopwatch_freeze_generation"):
		return int(tree.get_meta("stopwatch_freeze_generation"))
	return 0
