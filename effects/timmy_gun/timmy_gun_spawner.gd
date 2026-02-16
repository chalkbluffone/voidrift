class_name TimmyGunSpawner

## Spawner for the Timmy Gun burst-fire machine gun.
## 4-arg spawn signature: (pos, direction, params, follow_source).
## Finds nearest enemy, aims, instantiates TimmyGun scene, fires burst.

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(
	spawn_pos: Vector2,
	direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	var enemies: Array = _parent_node.get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null

	# Target nearest enemy
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

	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	var scene: PackedScene = load("res://effects/timmy_gun/TimmyGun.tscn")
	var instance: Node2D = scene.instantiate()
	instance.z_index = -1
	_parent_node.add_child(instance)

	if params and instance.has_method("setup"):
		instance.setup(params)

	var stats_component: Node = null
	if is_instance_valid(follow_source) and follow_source.has_node("StatsComponent"):
		stats_component = follow_source.get_node("StatsComponent")

	if instance.has_method("fire_from"):
		instance.fire_from(spawn_pos, direction, stats_component)

	return instance


func cleanup() -> void:
	pass
