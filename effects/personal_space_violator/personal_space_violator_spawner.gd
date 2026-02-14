class_name PersonalSpaceViolatorSpawner

## Spawner for the Personal Space Violator shotgun weapon.
## 4-arg spawn signature: (pos, direction, params, follow_source).
## Fires a cone burst of neon glowing pellets toward the nearest enemy.

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(
	spawn_pos: Vector2,
	direction: Vector2,
	params: Dictionary = {},
	_follow_source: Node2D = null
) -> Node2D:
	"""
	Spawn a PersonalSpaceViolator shotgun blast.
	Fires multiple pellets in a cone pattern toward the target direction.

	Args:
		spawn_pos:     World position to spawn at
		direction:     Direction vector toward target (will be normalized)
		params:        Flat parameter dictionary from WeaponDataFlattener
		follow_source: Player node (not used for flight, but kept for consistency)

	Returns:
		The spawned PersonalSpaceViolator container node, or null if no enemies.
	"""
	# Only fire when there's an actual enemy target
	var enemies: Array = _parent_node.get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null

	# Find nearest enemy and override the direction to aim at it
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy in enemies:
		if not enemy is Node2D:
			continue
		if not is_instance_valid(enemy):
			continue
		var dist: float = spawn_pos.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy as Node2D
	if nearest:
		direction = (nearest.global_position - spawn_pos).normalized()

	var scene: PackedScene = load("res://effects/personal_space_violator/PersonalSpaceViolator.tscn")
	var instance: Node2D = scene.instantiate()
	instance.z_index = -1
	_parent_node.add_child(instance)

	if params and instance.has_method("setup"):
		instance.setup(params)

	if instance.has_method("fire_burst"):
		instance.fire_burst(spawn_pos, direction.normalized())

	return instance


func cleanup() -> void:
	"""Called when weapon is unequipped."""
	pass
