class_name ProjectileBaseSpawner

## Stub spawner for projectile-type weapons.
## Replace with a weapon-specific spawner when implementing the weapon.

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


## Spawn a projectile-type weapon effect (stub).
##
## Args:
##     spawn_pos: World position to spawn at
##     direction: Direction vector (will be normalized)
##     params: Dictionary of parameter overrides
##     follow_source: Optional Node2D to track
##
## Returns:
##     null (not yet implemented)
func spawn(
	_spawn_pos: Vector2,
	_direction: Vector2,
	params: Dictionary = {},
	_follow_source: Node2D = null
) -> Node2D:
	push_warning("ProjectileBaseSpawner: spawn() not yet implemented for params: %s" % str(params))
	return null
