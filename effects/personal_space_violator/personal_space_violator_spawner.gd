class_name PersonalSpaceViolatorSpawner

## Spawner for the Personal Space Violator shotgun weapon.
## 4-arg spawn signature: (pos, direction, params, follow_source).
## Fires a cone burst of neon glowing pellets toward the nearest enemy.

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


## Spawn a PersonalSpaceViolator shotgun blast.
## Fires multiple pellets in a cone pattern toward the target direction.
##
## Args:
##     spawn_pos:     World position to spawn at
##     direction:     Direction vector toward target (will be normalized)
##     params:        Flat parameter dictionary from WeaponDataFlattener
##     follow_source: Player node (not used for flight, but kept for consistency)
##
## Returns:
##     The spawned PersonalSpaceViolator container node, or null if no enemies.
func spawn(
	spawn_pos: Vector2,
	direction: Vector2,
	params: Dictionary = {},
	_follow_source: Node2D = null
) -> Node2D:
	# Only fire when there's an actual enemy target
	var nearest: Node2D = EffectUtils.find_nearest_enemy(_parent_node.get_tree(), spawn_pos)
	if nearest == null:
		return null
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


## Called when weapon is unequipped.
func cleanup() -> void:
	pass
