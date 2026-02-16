extends Area2D
class_name TestTarget

## A simple target dummy for the weapon test lab.
## Can take damage, shows visual feedback, and moves toward ship.

@export var max_hp: float = 100.0
@export var move_speed: float = 50.0

var current_hp: float = 100.0
var target_node: Node2D = null  # The ship to move toward
var _target_radius: float = 20.0  # Ship collision radius
var enemy_type: String = "normal"  # "normal" or "boss"
var _knockback_velocity: Vector2 = Vector2.ZERO
const KNOCKBACK_FRICTION: float = 8.0

@onready var visual: ColorRect = $Visual
@onready var hp_label: Label = $HPLabel


func _ready() -> void:
	current_hp = max_hp
	_update_visual()
	add_to_group("enemies")
	collision_layer = 8  # Enemy layer — detectable by player weapons and shield bubble
	
	# Connect area signals for detecting radiant arc damage
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	# Process knockback decay
	if _knockback_velocity.length() > 1.0:
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta * 100)
		global_position += _knockback_velocity * delta
	else:
		_knockback_velocity = Vector2.ZERO
	
	if target_node and move_speed > 0:
		var direction: Vector2 = (target_node.global_position - global_position).normalized()
		global_position += direction * move_speed * delta
		
		# Check if we reached the ship
		var distance_to_target: float = global_position.distance_to(target_node.global_position)
		if distance_to_target < _target_radius + 20.0:  # 20 is our radius
			_on_reached_ship()


func _on_area_entered(area: Area2D) -> void:
	# Check if hit by radiant arc or other weapon
	if area.has_method("get_damage"):
		var dmg: float = area.get_damage()
		take_damage(dmg, area)
	elif area.get_parent() and area.get_parent().has_method("get_damage"):
		var dmg: float = area.get_parent().get_damage()
		take_damage(dmg, area.get_parent())


func _on_reached_ship() -> void:
	# Deal contact damage to the ship so Nope Bubble and other defenses can react
	if target_node and target_node.has_method("take_damage"):
		var contact_damage: float = 10.0
		if enemy_type == "boss":
			contact_damage = 30.0
		target_node.take_damage(contact_damage, self)
	queue_free()


func set_target(node: Node2D) -> void:
	target_node = node


func apply_knockback(force: Vector2) -> void:
	_knockback_velocity += force


func take_damage(amount: float, _source = null) -> void:
	current_hp -= amount
	_flash_hit()
	_update_visual()
	
	if current_hp <= 0:
		_on_death()


func _flash_hit() -> void:
	if visual:
		visual.color = Color.WHITE
		get_tree().create_timer(0.05).timeout.connect(_restore_color)


func _restore_color() -> void:
	if is_instance_valid(visual):
		var hp_ratio: float = clamp(current_hp / max_hp, 0.0, 1.0)
		visual.color = Color(1.0, hp_ratio * 0.3, hp_ratio * 0.3, 0.8)


func _update_visual() -> void:
	if hp_label:
		hp_label.text = str(int(max(0, current_hp)))
	
	if visual:
		var hp_ratio: float = clamp(current_hp / max_hp, 0.0, 1.0)
		visual.color = Color(1.0, hp_ratio * 0.3, hp_ratio * 0.3, 0.8)


func _on_death() -> void:
	# Simple death effect - just remove
	queue_free()


func reset() -> void:
	current_hp = max_hp
	_update_visual()
