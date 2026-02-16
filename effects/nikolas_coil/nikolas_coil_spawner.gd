class_name NikolasCoilSpawner

## Spawner for Nikola's Coil chain lightning weapon.
## 3-arg signature: spawn(spawn_pos, params, follow_source)
## No direction needed — the arc auto-targets nearest enemy.

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(
	spawn_pos: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	## Spawn a chain lightning effect from the given position.
	## Returns null if no enemies are in range (arc requires a target).

	# Pre-check: are any enemies in range? Skip spawning entirely if not.
	var search_radius: float = float(params.get("search_radius", 300.0))
	if not EffectUtils.has_enemy_in_range(_parent_node.get_tree(), spawn_pos, search_radius):
		return null

	var coil = load("res://effects/nikolas_coil/NikolasCoil.tscn").instantiate()
	coil.z_index = -1
	_parent_node.add_child(coil)

	if params:
		coil.setup(params)

	# Apply bounces from params if present
	var bounces: int = int(params.get("projectile_bounces", 3))
	coil.set_max_bounces(bounces)

	if follow_source:
		coil.set_follow_source(follow_source)

	coil.fire_from(spawn_pos)
	return coil
