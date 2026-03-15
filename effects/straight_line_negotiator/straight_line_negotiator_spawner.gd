class_name StraightLineNegotiatorSpawner

const SCENE: PackedScene = preload("res://effects/straight_line_negotiator/StraightLineNegotiator.tscn")

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(
	spawn_pos: Vector2,
	_direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	if not is_instance_valid(_parent_node) or not _parent_node.is_inside_tree():
		return null

	var origin: Vector2 = spawn_pos
	if is_instance_valid(follow_source):
		origin = follow_source.global_position

	# Compute effective range.
	var base_range: float = float(params.get("size", 0.0))
	var range_mult: float = float(params.get("size_mult", 1.0))
	var max_range: float = base_range * range_mult
	if max_range <= 0.0:
		return null

	# Build target list: unique enemies sorted nearest-first.
	var targets: Array[Node2D] = EffectUtils.find_enemies_in_range(
		_parent_node.get_tree(), origin, max_range
	)
	if targets.is_empty():
		return null

	var projectile_count: int = maxi(1, int(params.get("projectile_count", 1)))
	var cooldown: float = float(params.get("cooldown", 1.0))

	# Fire first shot immediately at nearest target.
	var first: Node2D = _fire_at_target(origin, targets[0], params, follow_source)

	# Schedule remaining shots evenly across the cooldown, cycling through targets.
	if projectile_count > 1 and is_instance_valid(_parent_node) and _parent_node.is_inside_tree():
		var interval: float = cooldown / float(projectile_count)
		for i in range(1, projectile_count):
			var target_index: int = i % targets.size()
			var delay: float = interval * float(i)
			var timer: SceneTreeTimer = _parent_node.get_tree().create_timer(delay, false)
			timer.timeout.connect(
				_fire_delayed.bind(target_index, targets, params, follow_source)
			)

	return first


func _fire_at_target(
	origin: Vector2,
	target: Node2D,
	params: Dictionary,
	follow_source: Node2D
) -> Node2D:
	if not is_instance_valid(_parent_node) or not _parent_node.is_inside_tree():
		return null
	if not is_instance_valid(target):
		return null

	var direction: Vector2 = (target.global_position - origin).normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	var instance: Node2D = SCENE.instantiate()
	instance.z_index = -1
	_parent_node.add_child(instance)

	if params and instance.has_method("setup"):
		instance.setup(params)

	var stats_component: Node = null
	if is_instance_valid(follow_source) and follow_source.has_node("StatsComponent"):
		stats_component = follow_source.get_node("StatsComponent")

	if instance.has_method("fire_from"):
		instance.fire_from(origin, direction, stats_component, follow_source)

	return instance


func _fire_delayed(
	target_index: int,
	targets: Array[Node2D],
	params: Dictionary,
	follow_source: Node2D
) -> void:
	var origin: Vector2 = Vector2.ZERO
	if is_instance_valid(follow_source):
		origin = follow_source.global_position

	# Try the assigned target first; fall back to nearest if it died.
	var target: Node2D = null
	if target_index < targets.size() and is_instance_valid(targets[target_index]):
		target = targets[target_index]
	else:
		target = EffectUtils.find_nearest_enemy(_parent_node.get_tree(), origin)
	if target == null:
		return

	_fire_at_target(origin, target, params, follow_source)


func cleanup() -> void:
	pass
