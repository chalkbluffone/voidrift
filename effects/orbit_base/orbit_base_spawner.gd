class_name OrbitBaseSpawner

## Spawner for orbit-type weapons (PSP-9000 prototype).
## Maintains a single persistent orbit effect and updates it on re-fire.

var _parent_node: Node
var _active_orbit: Node2D = null
var FileLogger: Node = null


func _init(parent: Node) -> void:
	_parent_node = parent
	if _parent_node:
		FileLogger = _parent_node.get_node_or_null("/root/FileLogger")


func spawn(
	spawn_pos: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	if is_instance_valid(_active_orbit):
		if params:
			_active_orbit.setup(params)
		if follow_source:
			_active_orbit.set_follow_source(follow_source)
		if FileLogger:
			FileLogger.log_debug("OrbitBaseSpawner", "Updated active PSP orbit instance")
		return _active_orbit

	var scene: PackedScene = load("res://effects/orbit_base/OrbitBase.tscn")
	if scene == null:
		push_warning("OrbitBaseSpawner: Failed to load OrbitBase.tscn")
		return null

	var instance: Node2D = scene.instantiate()
	instance.z_index = 1
	_parent_node.add_child(instance)

	if params:
		instance.setup(params)
	instance.spawn_at(spawn_pos)

	if follow_source:
		instance.set_follow_source(follow_source)

	instance.tree_exiting.connect(_on_orbit_destroyed)
	_active_orbit = instance
	if FileLogger:
		FileLogger.log_info("OrbitBaseSpawner", "Spawned PSP orbit instance")
	return instance


func _on_orbit_destroyed() -> void:
	_active_orbit = null


func cleanup() -> void:
	if is_instance_valid(_active_orbit):
		_active_orbit.queue_free()
	_active_orbit = null
