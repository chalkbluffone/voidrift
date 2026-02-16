class_name BasePickup
extends Area2D

## BasePickup - Base class for all collectible pickups.
## Handles magnetic attraction to player and collection on contact.
## Subclasses override _apply_effect() to define what happens on collection.

var _target: Node2D = null
var _current_speed: float = 0.0
var _is_attracted: bool = false

@onready var ProgressionManager: Node = get_node("/root/ProgressionManager")
@onready var GameConfig: Node = get_node("/root/GameConfig")
@onready var FileLogger: Node = get_node("/root/FileLogger")


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_on_pickup_ready()


## Override in subclasses for additional setup.
func _on_pickup_ready() -> void:
	pass


func _process(delta: float) -> void:
	if _is_attracted and _target:
		_current_speed = minf(_current_speed + GameConfig.PICKUP_MAGNET_ACCELERATION * delta, GameConfig.PICKUP_MAGNET_SPEED)
		var direction: Vector2 = (_target.global_position - global_position).normalized()
		position += direction * _current_speed * delta


func attract_to(target: Node2D) -> void:
	_target = target
	_is_attracted = true


## Override in subclasses to use fixed magnet radius instead of player's PickupRange.
## Return > 0 to use fixed radius, or <= 0 to use default PickupRange detection.
func _get_fixed_magnet_radius() -> float:
	return 0.0  # Default: use player's PickupRange area


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()


func _on_area_entered(area: Area2D) -> void:
	# Standard pickups use player's PickupRange area for attraction
	if _get_fixed_magnet_radius() <= 0.0:
		if area.name == "PickupRange":
			var player: Node = area.get_parent()
			if player and player.is_in_group("player"):
				attract_to(player)


## For pickups with fixed magnet radius - call this from _process in subclass.
func _check_fixed_radius_attraction(player: Node2D) -> void:
	if _is_attracted:
		return
	var fixed_radius: float = _get_fixed_magnet_radius()
	if fixed_radius > 0.0:
		var distance: float = global_position.distance_to(player.global_position)
		if distance <= fixed_radius:
			attract_to(player)


func _collect() -> void:
	_apply_effect()
	queue_free()


## Override in subclasses to define collection behavior.
func _apply_effect() -> void:
	push_warning("BasePickup._apply_effect() not overridden!")
