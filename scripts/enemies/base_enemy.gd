class_name BaseEnemy
extends CharacterBody2D

## BaseEnemy - Basic enemy that chases the player and drops XP on death.

signal died(enemy: BaseEnemy, position: Vector2)

# --- Stats ---
@export var max_hp: float = 20.0
@export var move_speed: float = 100.0
@export var contact_damage: float = 10.0
@export var xp_value: float = 10.0
@export var credit_value: int = 1

var current_hp: float = 20.0
var enemy_type: String = "normal"  # "normal", "elite", "boss"

# --- References ---
var _target: Node2D = null
var _hitbox: Area2D = null
@onready var GameManager: Node = get_node("/root/GameManager")
@onready var FileLogger: Node = get_node("/root/FileLogger")

# --- Knockback ---
var _knockback_velocity: Vector2 = Vector2.ZERO
const KNOCKBACK_FRICTION: float = 8.0

# --- Contact Damage ---
var _damage_cooldown: float = 0.0
const DAMAGE_INTERVAL: float = 0.5  # Deal damage every 0.5 seconds while touching


func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp
	_find_player()
	
	# Ensure HitboxArea is connected and monitoring
	_hitbox = get_node_or_null("HitboxArea") as Area2D
	if _hitbox:
		_hitbox.monitoring = true
		_hitbox.monitorable = true
		FileLogger.log_debug("BaseEnemy", "HitboxArea ready: layer=%d mask=%d" % [_hitbox.collision_layer, _hitbox.collision_mask])


func _physics_process(delta: float) -> void:
	_process_knockback(delta)
	_process_movement(delta)
	move_and_slide()
	_process_contact_damage(delta)


func _process_contact_damage(delta: float) -> void:
	# Cooldown timer
	if _damage_cooldown > 0:
		_damage_cooldown -= delta
		return
	
	# Method 1: Check move_and_slide collisions
	for i: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider is Node2D:
			var body: Node2D = collider as Node2D
			if body.is_in_group("player") and body.has_method("take_damage"):
				var damage_dealt: float = body.take_damage(contact_damage, self)
				if damage_dealt > 0:
					FileLogger.log_info("BaseEnemy", "Contact damage via collision: %.0f" % damage_dealt)
					_damage_cooldown = DAMAGE_INTERVAL
				return
	
	# Method 2: Check Area2D overlapping (backup)
	if _hitbox:
		var overlapping_bodies: Array[Node2D] = _hitbox.get_overlapping_bodies()
		for body: Node2D in overlapping_bodies:
			if body.is_in_group("player") and body.has_method("take_damage"):
				var damage_dealt: float = body.take_damage(contact_damage, self)
				if damage_dealt > 0:
					FileLogger.log_info("BaseEnemy", "Contact damage via area: %.0f" % damage_dealt)
					_damage_cooldown = DAMAGE_INTERVAL
				return


func _find_player() -> void:
	# Find player in scene
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0]


func _process_movement(_delta: float) -> void:
	if not _target:
		_find_player()
		return
	
	# Chase player
	var direction: Vector2 = (_target.global_position - global_position).normalized()
	var chase_velocity: Vector2 = direction * move_speed
	
	# Combine with knockback
	velocity = chase_velocity + _knockback_velocity
	
	# Face movement direction
	if velocity.length() > 10:
		rotation = velocity.angle()


func _process_knockback(delta: float) -> void:
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta * 100)


func take_damage(amount: float, _source: Node = null) -> void:
	current_hp -= amount
	
	# Visual feedback
	_flash_damage()
	
	if current_hp <= 0:
		_die()


func _flash_damage() -> void:
	var sprite: Node = get_node_or_null("Sprite2D")
	if sprite:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.05)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func _die() -> void:
	# Record kill
	GameManager.record_kill(enemy_type)
	
	# Emit signal for XP spawning
	died.emit(self, global_position)
	
	# Remove from scene
	queue_free()


func apply_knockback(force: Vector2) -> void:
	_knockback_velocity += force


func apply_slow(amount: float, duration: float) -> void:
	## Temporarily reduces move_speed by amount (fraction, e.g. 0.5 = 50% slower)
	## for the given duration in seconds.
	var original_speed: float = move_speed
	move_speed = move_speed * (1.0 - clampf(amount, 0.0, 0.9))
	# Restore after duration
	get_tree().create_timer(duration).timeout.connect(
		func() -> void:
			if is_instance_valid(self):
				move_speed = original_speed
	)


func get_xp_value() -> float:
	return xp_value


func get_credit_value() -> int:
	return credit_value
