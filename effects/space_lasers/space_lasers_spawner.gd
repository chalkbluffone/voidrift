class_name SpaceLasersSpawner

## Spawner for the Space Lasers bouncing laser weapon.
## 4-arg spawn signature: (pos, direction, params, follow_source).
## Aims at nearest enemy, instantiates SpaceLasers scene, fires burst of laser bolts.

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(
	spawn_pos: Vector2,
	direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	var targeting_range: float = GameConfig.WEAPON_TARGETING_RANGE
	var targets: Array[Node2D] = EffectUtils.find_enemies_in_range(_parent_node.get_tree(), spawn_pos, targeting_range)
	if targets.is_empty():
		return null
	direction = (targets[0].global_position - spawn_pos).normalized()

	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	var scene: PackedScene = load("res://effects/space_lasers/SpaceLasers.tscn")
	var instance: Node2D = scene.instantiate()
	instance.z_index = -1
	_parent_node.add_child(instance)

	if params and instance.has_method("setup"):
		instance.setup(params)

	var stats_component: Node = null
	if is_instance_valid(follow_source) and follow_source.has_node("StatsComponent"):
		stats_component = follow_source.get_node("StatsComponent")

	if instance.has_method("fire_from"):
		instance.fire_from(spawn_pos, direction, stats_component, follow_source, targets)

	return instance


func cleanup() -> void:
	pass
