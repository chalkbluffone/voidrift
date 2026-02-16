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
	var nearest: Node2D = EffectUtils.find_nearest_enemy(_parent_node.get_tree(), spawn_pos)
	if nearest == null:
		return null
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
