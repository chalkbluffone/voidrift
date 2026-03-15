class_name RadiantArcSpawner

const RADIANT_ARC_SCENE: PackedScene = preload("res://effects/radiant_arc/RadiantArc.tscn")

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


## Spawn RadiantArc effect(s).
## When projectile_count > 1, staggers spawns evenly across the cooldown
## interval and fans them out angularly so arcs cascade visibly.
##
## Args:
##     spawn_pos: World position to spawn at
##     direction: Direction vector (will be normalized)
##     params: Dictionary of parameter overrides including:
##         - projectile_count: Number of arcs to spawn
##         - cooldown: Weapon cooldown (used to compute stagger interval)
##     follow_source: Optional Node2D to track movement direction (e.g., player ship)
##
## Returns:
##     The first spawned RadiantArc instance
func spawn(
	spawn_pos: Vector2,
	direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> RadiantArc:
	var count: int = maxi(1, int(params.get("projectile_count", 1)))
	var cooldown: float = maxf(0.1, float(params.get("cooldown", 1.0)))
	var dir_normalized: Vector2 = direction.normalized()

	var first_arc: RadiantArc = _spawn_single(0, count, params, spawn_pos, dir_normalized, follow_source)

	if count > 1:
		var interval: float = cooldown / float(count)
		for i: int in range(1, count):
			var delay: float = interval * float(i)
			_parent_node.get_tree().create_timer(delay, false).timeout.connect(
				_on_staggered_spawn.bind(i, count, params, follow_source)
			)

	return first_arc


func _on_staggered_spawn(
	index: int,
	count: int,
	params: Dictionary,
	follow_source: Node2D
) -> void:
	if not is_instance_valid(_parent_node) or not _parent_node.is_inside_tree():
		return
	var spawn_pos: Vector2 = Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	if is_instance_valid(follow_source):
		spawn_pos = follow_source.global_position
		direction = Vector2.RIGHT.rotated(follow_source.rotation)
	_spawn_single(index, count, params, spawn_pos, direction, follow_source)


func _spawn_single(
	index: int,
	count: int,
	params: Dictionary,
	spawn_pos: Vector2,
	direction: Vector2,
	follow_source: Node2D
) -> RadiantArc:
	var spread_deg: float = GameConfig.RADIANT_ARC_SPREAD_DEG
	var angle_offset: float = 0.0
	if count > 1:
		angle_offset = deg_to_rad(lerpf(
			-spread_deg * float(count - 1) / 2.0,
			spread_deg * float(count - 1) / 2.0,
			float(index) / float(count - 1)
		))

	var arc_dir: Vector2 = direction.rotated(angle_offset)

	var arc: RadiantArc = RADIANT_ARC_SCENE.instantiate()
	arc.z_index = -1
	_parent_node.add_child(arc)

	# Set sweep_reversed BEFORE setup() so _generate_arc_mesh() builds correct UVs
	if index % 2 == 1:
		arc.sweep_reversed = true

	if params:
		arc.setup(params)

	# Per-arc visual variation: unique seed + gradient offset (shader-only, order doesn't matter)
	var base_seed: float = float(params.get("seed_offset", 81.0))
	arc.seed_offset = base_seed + float(index) * 37.0
	arc.gradient_offset = float(index) * 0.15

	arc.spawn_from(spawn_pos, arc_dir)
	arc.set_angle_offset(angle_offset)

	if is_instance_valid(follow_source):
		arc.set_follow_source(follow_source)

	return arc
