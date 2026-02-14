class_name BrokenTractorBeamSpawner

## Spawner for the Broken Tractor Beam weapon.
## 4-arg signature to match _fire_beam_weapon dispatch.
## Direction is ignored — the beam auto-targets the nearest enemy.

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(
	spawn_pos: Vector2,
	_direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	## Spawn a tractor beam effect from the given position.
	## Returns null if no enemies are in range.

	# Pre-check: any enemies within search radius?
	var search_radius: float = float(params.get("search_radius", params.get("size", 300.0)))
	var enemies: Array = _parent_node.get_tree().get_nodes_in_group("enemies")
	var has_target: bool = false
	for enemy in enemies:
		if enemy is Node2D and is_instance_valid(enemy):
			var d: float = spawn_pos.distance_to(enemy.global_position)
			if d < search_radius:
				has_target = true
				break

	if not has_target:
		return null

	var beam: Node2D = load("res://effects/broken_tractor_beam/BrokenTractorBeam.tscn").instantiate()
	beam.z_index = -1

	# Add to scene tree first so _ready() runs
	_parent_node.call_deferred("add_child", beam)

	# Configure from params
	if params:
		beam.setup(params)

	if follow_source:
		beam.set_follow_source(follow_source)

	# Activate after setup (deferred so the node is in the tree)
	beam.call_deferred("activate")
	return beam
