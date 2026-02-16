class_name IonWakeSpawner

const IonWakeScript: GDScript = preload("res://effects/ion_wake/ion_wake.gd")

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


## Spawn an IonWake effect.
## Note: projectile_count is used by the weapon system as a fire rate multiplier,
## not as a spawn count parameter.
##
## Args:
##     spawn_pos: World position to spawn at (ship center)
##     params: Dictionary of parameter overrides including:
##         - spawn_angle_degrees: Angle relative to ship (0=forward, 180=behind, 90=right, 270=left)
##         - spawn_distance: Distance from ship center
##     follow_source: Node2D (ship) to get rotation for relative positioning
##
## Returns:
##     The spawned IonWake instance
func spawn(
	spawn_pos: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	var wake: Node = load("res://effects/ion_wake/IonWake.tscn").instantiate()
	wake.z_index = -2  # Render below enemies and ship
	wake.z_as_relative = false
	_parent_node.add_child(wake)
	
	if params:
		wake.setup(params)
	
	# Get spawn position parameters (relative to ship)
	var spawn_angle_degrees: float = params.get("spawn_angle_degrees", 180.0)  # 0=forward, 180=behind
	var spawn_distance: float = params.get("spawn_distance", 16.0)
	
	# Calculate offset from ship center
	var offset: Vector2 = Vector2.ZERO
	if follow_source:
		# Convert angle to radians and make it relative to ship's rotation
		# 0 degrees = forward (ship's facing direction)
		# 180 degrees = behind
		# 90 degrees = right side
		# 270 degrees = left side
		var angle_rad: float = deg_to_rad(spawn_angle_degrees)
		var direction: Vector2 = Vector2.RIGHT.rotated(follow_source.rotation + angle_rad)
		offset = direction * spawn_distance
	
	wake.spawn_at(spawn_pos + offset)
	
	return wake
