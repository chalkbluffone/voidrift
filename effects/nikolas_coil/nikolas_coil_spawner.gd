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
	## Spawn chain lightning effect(s) from the given position.
	## When projectile_count > 1, spawns multiple coils each targeting a different
	## first enemy. Returns the first coil instance (or null if no enemies in range).

	var search_radius: float = float(params.get("search_radius", 300.0))
	var proj_count: int = maxi(1, int(params.get("projectile_count", 1)))

	# Find sorted targets up-front so each coil can claim a different first enemy
	var sorted_targets: Array[Node2D] = EffectUtils.find_enemies_in_range(_parent_node.get_tree(), spawn_pos, search_radius)
	if sorted_targets.is_empty():
		return null

	var bounces: int = int(params.get("projectile_bounces", 3))
	var first_coil: Node2D = null
	var claimed_first_targets: Array[Node2D] = []

	for i in range(proj_count):
		# Skip if we've exhausted all available first targets
		if i >= sorted_targets.size():
			break

		var coil: Node = load("res://effects/nikolas_coil/NikolasCoil.tscn").instantiate()
		coil.z_index = -1
		_parent_node.add_child(coil)

		if params:
			coil.setup(params)

		coil.set_max_bounces(bounces)
		coil.set_exclude_first_targets(claimed_first_targets.duplicate())

		if follow_source:
			coil.set_follow_source(follow_source)

		coil.fire_from(spawn_pos)

		# Record which enemy this coil claimed as its first target
		if not coil._chain_targets.is_empty():
			claimed_first_targets.append(coil._chain_targets[0])

		if first_coil == null:
			first_coil = coil

	return first_coil
