extends Area2D

## XPPickup - Dropped by enemies, magnetically attracted to player.

@export var xp_amount: float = 10.0

var _target: Node2D = null
var _current_speed: float = 0.0
var _is_attracted: bool = false

@onready var GameManager: Node = get_node("/root/GameManager")
@onready var GameConfig: Node = get_node("/root/GameConfig")
@onready var FileLogger: Node = get_node("/root/FileLogger")


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	FileLogger.log_debug("XPPickup", "Spawned at %s, collision_layer: %d, collision_mask: %d" % [global_position, collision_layer, collision_mask])


func _process(delta: float) -> void:
	if _is_attracted and _target:
		_current_speed = minf(_current_speed + GameConfig.PICKUP_MAGNET_ACCELERATION * delta, GameConfig.PICKUP_MAGNET_SPEED)
		var direction := (_target.global_position - global_position).normalized()
		position += direction * _current_speed * delta


func initialize(amount: float) -> void:
	xp_amount = amount


func attract_to(target: Node2D) -> void:
	_target = target
	_is_attracted = true
	FileLogger.log_debug("XPPickup", "Attracted to player at %s" % target.global_position)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()


func _on_area_entered(area: Area2D) -> void:
	FileLogger.log_debug("XPPickup", "Area entered: %s" % area.name)
	# Check if entering player's pickup range
	if area.name == "PickupRange":
		var player := area.get_parent()
		if player and player.is_in_group("player"):
			attract_to(player)


func _collect() -> void:
	GameManager.add_xp(xp_amount)
	queue_free()
