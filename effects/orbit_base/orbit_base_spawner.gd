class_name OrbitBaseSpawner

## Stub spawner for orbit-type weapons.
## Replace with a weapon-specific spawner when implementing the weapon.

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(
	_spawn_pos: Vector2,
	params: Dictionary = {},
	_follow_source: Node2D = null
) -> Node2D:
	"""
	Spawn an orbit-type weapon effect (stub).

	Args:
		spawn_pos: World position to spawn at
		params: Dictionary of parameter overrides
		follow_source: Optional Node2D to track

	Returns:
		null (not yet implemented)
	"""
	push_warning("OrbitBaseSpawner: spawn() not yet implemented for params: %s" % str(params))
	return null
