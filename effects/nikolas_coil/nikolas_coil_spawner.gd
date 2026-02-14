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
	var enemies: Array = _parent_node.get_tree().get_nodes_in_group("enemies")
	var has_target: bool = false
	var closest_dist: float = 99999.0
	for enemy in enemies:
		if enemy is Node2D and is_instance_valid(enemy):
			var d: float = spawn_pos.distance_to(enemy.global_position)
			if d < closest_dist:
				closest_dist = d
			if d < search_radius:
				has_target = true
				break
	if not has_target:
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
