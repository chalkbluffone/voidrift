class_name IonWakeSpawner

const ION_WAKE_SCENE: PackedScene = preload("res://effects/ion_wake/IonWake.tscn")

## Angular spread between extra wakes (degrees).
const WAKE_SPREAD_DEG: float = 30.0

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


## Spawn IonWake effect(s).
## When projectile_count > 1, staggers spawns evenly across the cooldown
## interval so wakes trail behind the ship rather than stacking on one spot.
##
## Args:
##     spawn_pos: World position to spawn at (ship center)
##     params: Dictionary of parameter overrides including:
##         - spawn_angle_degrees: Angle relative to ship (0=forward, 180=behind)
##         - spawn_distance: Distance from ship center
##         - projectile_count: Number of wake circles to drop
##         - cooldown: Weapon cooldown (used to compute stagger interval)
##     follow_source: Node2D (ship) to get rotation for relative positioning
##
## Returns:
##     The first spawned IonWake instance (spawned immediately)
func spawn(
	spawn_pos: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	var count: int = maxi(1, int(params.get("projectile_count", 1)))
	var cooldown: float = maxf(0.1, float(params.get("cooldown", 1.5)))

	# Spawn the first wake immediately
	var first_wake: Node2D = _spawn_single(0, count, params, spawn_pos, follow_source)

	# Schedule the rest evenly across the cooldown interval
	if count > 1:
		var interval: float = cooldown / float(count)
		for i: int in range(1, count):
			var delay: float = interval * float(i)
			# Capture follow_source + index; position is read at fire time from the source
			_parent_node.get_tree().create_timer(delay, false).timeout.connect(
				_on_staggered_spawn.bind(i, count, params, follow_source)
			)

	return first_wake


func _on_staggered_spawn(
	index: int,
	count: int,
	params: Dictionary,
	follow_source: Node2D
) -> void:
	if not is_instance_valid(_parent_node) or not _parent_node.is_inside_tree():
		return
	var spawn_pos: Vector2 = Vector2.ZERO
	if is_instance_valid(follow_source):
		spawn_pos = follow_source.global_position
	_spawn_single(index, count, params, spawn_pos, follow_source)


func _spawn_single(
	index: int,
	count: int,
	params: Dictionary,
	spawn_pos: Vector2,
	follow_source: Node2D
) -> Node2D:
	var base_angle: float = float(params.get("spawn_angle_degrees", 180.0))
	var spawn_distance: float = float(params.get("spawn_distance", 16.0))

	# Fan offset: e.g. 3 wakes → -30°, 0°, +30°
	var angle_offset: float = 0.0
	if count > 1:
		angle_offset = lerpf(
			-WAKE_SPREAD_DEG * float(count - 1) / 2.0,
			WAKE_SPREAD_DEG * float(count - 1) / 2.0,
			float(index) / float(count - 1)
		)

	var wake_angle: float = base_angle + angle_offset

	var wake: Node2D = ION_WAKE_SCENE.instantiate()
	wake.z_index = -2
	wake.z_as_relative = false
	_parent_node.add_child(wake)

	if params:
		wake.setup(params)

	if is_instance_valid(follow_source) and wake.has_method("set_source"):
		wake.set_source(follow_source)

	# Calculate offset from ship center
	var offset: Vector2 = Vector2.ZERO
	if is_instance_valid(follow_source):
		var angle_rad: float = deg_to_rad(wake_angle)
		var direction: Vector2 = Vector2.RIGHT.rotated(follow_source.rotation + angle_rad)
		offset = direction * spawn_distance

	wake.spawn_at(spawn_pos + offset)
	return wake
