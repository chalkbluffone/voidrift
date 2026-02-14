class_name SpaceNapalmSpawner

## Spawner for Space Napalm — incendiary projectile + AoE fire weapon.
## 4-arg spawn signature: (pos, direction, params, follow_source).
## Targets the densest enemy cluster to maximize AoE overlap.
## Tracks active instances to enforce projectile_count limit.

var _parent_node: Node
var _active_instances: Array = []
var _max_active: int = 1


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(
	spawn_pos: Vector2,
	direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	"""
	Spawn a SpaceNapalm projectile aimed at the densest enemy cluster.

	Args:
		spawn_pos:     World position to spawn at
		direction:     Direction vector (will be overridden by cluster targeting)
		params:        Flat parameter dictionary from weapon_component flatten
		follow_source: Player node

	Returns:
		The spawned SpaceNapalm instance, or null if no enemies or at max instances.
	"""
	# Only fire when enemies exist
	var enemies: Array = _parent_node.get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null

	# Purge dead references and enforce projectile count limit
	_active_instances = _active_instances.filter(
		func(inst: Node) -> bool: return is_instance_valid(inst) and inst.is_inside_tree()
	)
	var max_count: int = int(params.get("projectile_count", _max_active))
	if max_count < 1:
		max_count = 1
	if _active_instances.size() >= max_count:
		return null

	# Find the closest enemy to the player
	var best_target: Vector2 = Vector2.ZERO
	var best_dist: float = INF

	for enemy in enemies:
		if not enemy is Node2D or not is_instance_valid(enemy):
			continue
		var dist: float = spawn_pos.distance_to((enemy as Node2D).global_position)
		if dist < best_dist:
			best_dist = dist
			best_target = (enemy as Node2D).global_position

	if best_dist == INF:
		return null

	# Aim at the best cluster position
	direction = (best_target - spawn_pos).normalized()

	var scene: PackedScene = load("res://effects/space_napalm/SpaceNapalm.tscn")
	var instance: Node2D = scene.instantiate()
	instance.z_index = -1
	_parent_node.add_child(instance)

	if params:
		instance.setup(params)

	instance.spawn_from(spawn_pos, direction)
	instance.set_target(best_target)

	if follow_source:
		instance.set_source(follow_source)

	_active_instances.append(instance)
	return instance


func cleanup() -> void:
	"""Destroy all active instances. Called when weapon is unequipped."""
	for inst in _active_instances:
		if is_instance_valid(inst):
			inst.queue_free()
	_active_instances.clear()
