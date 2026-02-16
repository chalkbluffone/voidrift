class_name SnarkyComebackSpawner

## Spawner for the Snarky Comeback boomerang weapon.
## 4-arg spawn signature: (pos, direction, params, follow_source).
## Tracks active instances to enforce projectile_count limit.

var _parent_node: Node
var _active_instances: Array = []  # Track live boomerangs
var _max_active: int = 1  # Default; overridden by projectile_count stat


func _init(parent: Node) -> void:
	_parent_node = parent


## Spawn a SnarkyComeback boomerang effect.
## Only fires if there is at least one enemy in range.
##
## Args:
##     spawn_pos:     World position to spawn at
##     direction:     Direction vector toward target (will be normalized)
##     params:        Flat parameter dictionary from weapon_component flatten
##     follow_source: Player node — the boomerang returns here
##
## Returns:
##     The spawned SnarkyComeback instance, or null if no enemies in range
##     or if already at max active instances.
func spawn(
	spawn_pos: Vector2,
	direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> SnarkyComeback:
	# Only fire when there's an actual enemy target — and aim at the nearest one
	var nearest: Node2D = EffectUtils.find_nearest_enemy(_parent_node.get_tree(), spawn_pos)
	if nearest == null:
		return null
	direction = (nearest.global_position - spawn_pos).normalized()

	# Purge dead references and enforce projectile count limit
	_active_instances = _active_instances.filter(func(inst: Node) -> bool: return is_instance_valid(inst) and inst.is_inside_tree())
	# Update max active from params if available (base + upgrades)
	var max_count: int = int(params.get("projectile_count", _max_active))
	if max_count < 1:
		max_count = 1
	if _active_instances.size() >= max_count:
		return null

	var scene: PackedScene = load("res://effects/snarky_comeback/SnarkyComeback.tscn")
	var instance: SnarkyComeback = scene.instantiate()
	instance.z_index = -1
	_parent_node.add_child(instance)

	if params:
		instance.setup(params)

	instance.spawn_from(spawn_pos, direction.normalized())

	if follow_source:
		instance.set_source(follow_source)

	_active_instances.append(instance)
	return instance


## Destroy all active boomerangs. Called when weapon is unequipped.
func cleanup() -> void:
	for inst in _active_instances:
		if is_instance_valid(inst):
			inst.queue_free()
	_active_instances.clear()
