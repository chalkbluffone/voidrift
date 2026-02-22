class_name SpinCycleSpawner

## Spawner for the Spin Cycle persistent AoE weapon.
## Maintains a single active instance and updates it on re-fire.

var _parent_node: Node
var _active_spin_cycle: Node2D = null


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(
	spawn_pos: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	if is_instance_valid(_active_spin_cycle):
		if params and _active_spin_cycle.has_method("setup"):
			_active_spin_cycle.setup(params)
		if follow_source and _active_spin_cycle.has_method("set_follow_source"):
			_active_spin_cycle.set_follow_source(follow_source)
		return _active_spin_cycle

	var scene: PackedScene = load("res://effects/spin_cycle/SpinCycle.tscn")
	if scene == null:
		push_warning("SpinCycleSpawner: Failed to load SpinCycle.tscn")
		return null

	var instance: Node2D = scene.instantiate()
	instance.z_index = -1
	_parent_node.add_child(instance)

	if params and instance.has_method("setup"):
		instance.setup(params)
	if instance.has_method("spawn_at"):
		instance.spawn_at(spawn_pos)
	else:
		instance.global_position = spawn_pos

	if follow_source and instance.has_method("set_follow_source"):
		instance.set_follow_source(follow_source)

	instance.tree_exiting.connect(_on_spin_cycle_destroyed)
	_active_spin_cycle = instance
	return instance


func _on_spin_cycle_destroyed() -> void:
	_active_spin_cycle = null


func cleanup() -> void:
	if is_instance_valid(_active_spin_cycle):
		_active_spin_cycle.queue_free()
	_active_spin_cycle = null
