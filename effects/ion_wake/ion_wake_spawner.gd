class_name IonWakeSpawner

const IonWakeScript := preload("res://effects/ion_wake/ion_wake.gd")

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(
	spawn_pos: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	"""
	Spawn an IonWake effect.
	
	Args:
		spawn_pos: World position to spawn at (center of the ring)
		params: Dictionary of parameter overrides
		follow_source: Optional Node2D to track position (e.g., player ship)
	
	Returns:
		The spawned IonWake instance
	"""
	var wake = load("res://effects/ion_wake/IonWake.tscn").instantiate()
	_parent_node.add_child(wake)
	
	if params:
		wake.setup(params)
	
	wake.spawn_at(spawn_pos)
	
	if follow_source:
		wake.set_follow_source(follow_source)
	
	return wake
