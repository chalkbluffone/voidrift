class_name SpaceNukesSpawner

## Spawner for Space Nukes.
## 4-arg spawn signature: (pos, direction, params, follow_source).
## Fires one or more auto-targeted rockets; each rocket explodes in an AoE burst.

var _parent_node: Node
var _active_instances: Array = []

const LAUNCH_ARC_MIN_DEG: float = 18.0
const LAUNCH_ARC_MAX_DEG: float = 52.0
const BASE_TARGETING_RADIUS: float = 500.0


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(
	spawn_pos: Vector2,
	direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	_active_instances = _active_instances.filter(
		func(inst: Variant) -> bool: return is_instance_valid(inst) and inst.is_inside_tree()
	)

	var targeting_center: Vector2 = spawn_pos
	if is_instance_valid(follow_source):
		targeting_center = follow_source.global_position

	var size_mult: float = maxf(0.2, float(params.get("size_mult", 1.0)))
	var targeting_radius: float = BASE_TARGETING_RADIUS * size_mult

	var targets: Array[Node2D] = EffectUtils.find_enemies_in_range(_parent_node.get_tree(), targeting_center, targeting_radius)
	if targets.is_empty():
		return null

	var rockets_per_volley: int = maxi(1, int(params.get("projectile_count", 1)))
	var rockets_to_fire: int = mini(rockets_per_volley, targets.size())
	var launch_arc_min_deg: float = float(params.get("launch_arc_min_deg", LAUNCH_ARC_MIN_DEG))
	var launch_arc_max_deg: float = float(params.get("launch_arc_max_deg", LAUNCH_ARC_MAX_DEG))
	if launch_arc_max_deg < launch_arc_min_deg:
		var swap: float = launch_arc_min_deg
		launch_arc_min_deg = launch_arc_max_deg
		launch_arc_max_deg = swap
	var effect_script: GDScript = load("res://effects/space_nukes/space_nukes_effect.gd")

	var first_instance: Node2D = null
	for i in range(rockets_to_fire):
		var target: Node2D = targets[i]
		if not is_instance_valid(target):
			continue

		var target_pos: Vector2 = target.global_position
		var travel_dir: Vector2 = (target_pos - spawn_pos).normalized()
		if travel_dir.is_zero_approx():
			travel_dir = direction.normalized()
			if travel_dir.is_zero_approx():
				travel_dir = Vector2.RIGHT

		# Randomized exit arc so missiles leave the ship with a natural rocket curve.
		var arc_sign: float = -1.0 if randf() < 0.5 else 1.0
		var arc_radians: float = deg_to_rad(randf_range(launch_arc_min_deg, launch_arc_max_deg)) * arc_sign
		var launch_dir: Vector2 = travel_dir.rotated(arc_radians).normalized()

		var instance: Node2D = effect_script.new()
		instance.z_index = -1
		_parent_node.add_child(instance)

		if params and instance.has_method("setup"):
			instance.setup(params)

		if instance.has_method("launch"):
			instance.launch(spawn_pos, launch_dir, target, target_pos, follow_source)

		_active_instances.append(instance)
		if first_instance == null:
			first_instance = instance

	return first_instance


func cleanup() -> void:
	for inst in _active_instances:
		if is_instance_valid(inst):
			inst.queue_free()
	_active_instances.clear()
