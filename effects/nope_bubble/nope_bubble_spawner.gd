class_name NopeBubbleSpawner

## Spawner for the Nope Bubble shield weapon.
## Maintains a single persistent bubble instance around the player ship.
## Each cooldown tick regenerates one layer instead of creating a new effect.

var _parent_node: Node
var _active_bubble: Node2D = null


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(spawn_pos: Vector2, params: Dictionary = {}, follow_source: Node2D = null) -> Node2D:
	# If bubble already exists and is valid, just update params — regen is self-managed
	if is_instance_valid(_active_bubble):
		if params:
			_active_bubble.setup(params)
		return _active_bubble
	
	# Create a new bubble
	var scene: PackedScene = load("res://effects/nope_bubble/NopeBubble.tscn")
	if scene == null:
		push_warning("NopeBubbleSpawner: Failed to load NopeBubble.tscn")
		return null
	
	var instance: Node2D = scene.instantiate()
	_parent_node.add_child(instance)
	
	if params:
		instance.setup(params)
	
	instance.spawn_at(spawn_pos)
	
	if follow_source:
		instance.set_follow_source(follow_source)
		# Register the bubble's damage interceptor on the ship
		if follow_source.has_method("register_damage_interceptor"):
			follow_source.register_damage_interceptor(instance.intercept_damage)
	
	# Track cleanup
	instance.tree_exiting.connect(_on_bubble_destroyed)
	_active_bubble = instance
	
	return instance


func _on_bubble_destroyed() -> void:
	_active_bubble = null


func cleanup() -> void:
	"""Destroy the active bubble. Called when weapon is unequipped."""
	if is_instance_valid(_active_bubble):
		_active_bubble.queue_free()
	_active_bubble = null
