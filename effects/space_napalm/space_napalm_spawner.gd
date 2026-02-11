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

	# Find the densest cluster: score each enemy position by neighbor count within AoE radius
	var aoe_radius: float = float(params.get("aoe_radius", 80.0))
	var size_mult: float = float(params.get("size_mult", 1.0))
	var effective_radius: float = aoe_radius * size_mult

	var best_target: Vector2 = Vector2.ZERO
	var best_score: int = 0

	# Valid enemy positions
	var enemy_positions: Array[Vector2] = []
	for enemy in enemies:
		if not enemy is Node2D or not is_instance_valid(enemy):
			continue
		enemy_positions.append((enemy as Node2D).global_position)

	if enemy_positions.is_empty():
		return null

	# Score each enemy position by how many neighbors are within the AoE radius
	for i in range(enemy_positions.size()):
		var pos: Vector2 = enemy_positions[i]
		var score: int = 0
		for j in range(enemy_positions.size()):
			if pos.distance_to(enemy_positions[j]) <= effective_radius:
				score += 1
		if score > best_score:
			best_score = score
			best_target = pos

	# Aim at the best cluster position
	direction = (best_target - spawn_pos).normalized()

	var scene: PackedScene = load("res://effects/space_napalm/SpaceNapalm.tscn")
	var instance: Node2D = scene.instantiate()
	_parent_node.add_child(instance)

	if params:
		instance.setup(params)

	instance.spawn_from(spawn_pos, direction)
	instance.set_target(best_target)

	if follow_source:
		instance.set_source(follow_source)

	_active_instances.append(instance)
	return instance
