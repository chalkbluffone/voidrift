class_name AoEBaseSpawner

## Spawner for AoE-type persistent aura weapons.
## Maintains a single active aura around the player and updates its params live.

var _parent_node: Node
var _active_aura: Node2D = null


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(
	spawn_pos: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	if is_instance_valid(_active_aura):
		if params and _active_aura.has_method("setup"):
			_active_aura.setup(params)
		if follow_source and _active_aura.has_method("set_follow_source"):
			_active_aura.set_follow_source(follow_source)
		return _active_aura

	var scene: PackedScene = load("res://effects/aoe_base/AoEBase.tscn")
	if scene == null:
		push_warning("AoEBaseSpawner: Failed to load AoEBase.tscn")
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

	instance.tree_exiting.connect(_on_aura_destroyed)
	_active_aura = instance
	return instance


func _on_aura_destroyed() -> void:
	_active_aura = null


func cleanup() -> void:
	if is_instance_valid(_active_aura):
		_active_aura.queue_free()
	_active_aura = null
