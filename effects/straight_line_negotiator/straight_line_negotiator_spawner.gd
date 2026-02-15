class_name StraightLineNegotiatorSpawner

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(
	spawn_pos: Vector2,
	_direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	var enemies: Array = _parent_node.get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null

	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy_any in enemies:
		if not enemy_any is Node2D:
			continue
		if not is_instance_valid(enemy_any):
			continue
		var enemy: Node2D = enemy_any as Node2D
		var dist: float = spawn_pos.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	if nearest == null:
		return null

	var direction: Vector2 = (nearest.global_position - spawn_pos).normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	var scene: PackedScene = load("res://effects/straight_line_negotiator/StraightLineNegotiator.tscn")
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
