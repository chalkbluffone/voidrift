class_name RadiantArcSpawner

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn_from_config(
	spawn_pos: Vector2,
	direction: Vector2,
	config: RadiantArcConfig
) -> RadiantArc:
	"""
	Spawn a RadiantArc effect at the given position with direction and config.
	
	Args:
		spawn_pos: World position to spawn at
		direction: Direction vector (will be normalized)
		config: RadiantArcConfig resource with all parameters
	
	Returns:
		The spawned RadiantArc instance
	"""
	var arc = load("res://effects/radiant_arc/RadiantArc.tscn").instantiate()
	_parent_node.add_child(arc)
	
	config.apply_to(arc)
	arc.spawn_from(spawn_pos, direction.normalized())
	
	return arc


func spawn(
	spawn_pos: Vector2,
	direction: Vector2,
	params: Dictionary = {}
) -> RadiantArc:
	"""
	Spawn a RadiantArc effect with inline parameters.
	
	Args:
		spawn_pos: World position to spawn at
		direction: Direction vector (will be normalized)
		params: Dictionary of parameter overrides
	
	Returns:
		The spawned RadiantArc instance
	"""
	var arc = load("res://effects/radiant_arc/RadiantArc.tscn").instantiate()
	_parent_node.add_child(arc)
	
	if params:
		arc.setup(params)
	
	arc.spawn_from(spawn_pos, direction.normalized())
	
	return arc
