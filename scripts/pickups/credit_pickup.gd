extends Area2D

## CreditPickup - Dropped by enemies, magnetically attracted to player.

@export var credit_amount: int = 1

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
	FileLogger.log_debug("CreditPickup", "Spawned at %s with %d credits" % [global_position, credit_amount])


func _process(delta: float) -> void:
	if _is_attracted and _target:
		_current_speed = minf(_current_speed + GameConfig.PICKUP_MAGNET_ACCELERATION * delta, GameConfig.PICKUP_MAGNET_SPEED)
		var direction: Vector2 = (_target.global_position - global_position).normalized()
		position += direction * _current_speed * delta


func initialize(amount: int) -> void:
	credit_amount = amount


func attract_to(target: Node2D) -> void:
	_target = target
	_is_attracted = true


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()


func _on_area_entered(area: Area2D) -> void:
	# Check if entering player's pickup range
	if area.name == "PickupRange":
		var player: Node2D = area.get_parent()
		if player and player.is_in_group("player"):
			attract_to(player)


func _collect() -> void:
	FileLogger.log_info("CreditPickup", "Collected %d credits!" % credit_amount)
	GameManager.add_credits(credit_amount)
	queue_free()
