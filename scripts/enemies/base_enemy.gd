class_name BaseEnemy
extends CharacterBody2D

## BaseEnemy - Basic enemy that chases the player and drops XP on death.

signal died(enemy: BaseEnemy, position: Vector2)

# --- Stats ---
@export var max_hp: float = 25.0
@export var move_speed: float = 70.0
@export var contact_damage: float = 4.0
@export var xp_value: float = 1.0
@export var credit_value: int = 1
@export var stardust_value: int = 0

var current_hp: float = 25.0
var _is_dying: bool = false
var enemy_type: String = "normal"  # "normal", "elite", "boss"

# --- References ---
var _target: Node2D = null
var _hitbox: Area2D = null
@onready var RunManager: Node = get_node("/root/RunManager")
@onready var GameConfig: Node = get_node("/root/GameConfig")

# --- Knockback ---
var _knockback_velocity: Vector2 = Vector2.ZERO

# --- Contact Damage ---
var _damage_cooldown: float = 0.0

# --- Flow Field ---
var _flow_field: FlowField = null

# --- Smoothed Direction ---
var _current_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp
	_find_player()
	_find_flow_field()
	
	# Ensure HitboxArea is connected and monitoring
	_hitbox = get_node_or_null("HitboxArea") as Area2D
	if _hitbox:
		_hitbox.monitoring = true
		_hitbox.monitorable = true



func _physics_process(delta: float) -> void:
	_process_knockback(delta)
	_process_movement(delta)
	move_and_slide()
	_process_contact_damage(delta)
	_check_arena_bounds()


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
					_damage_cooldown = GameConfig.ENEMY_CONTACT_DAMAGE_INTERVAL
				return
	
	# Method 2: Check Area2D overlapping (backup)
	if _hitbox:
		var overlapping_bodies: Array[Node2D] = _hitbox.get_overlapping_bodies()
		for body: Node2D in overlapping_bodies:
			if body.is_in_group("player") and body.has_method("take_damage"):
				var damage_dealt: float = body.take_damage(contact_damage, self)
				if damage_dealt > 0:
					_damage_cooldown = GameConfig.ENEMY_CONTACT_DAMAGE_INTERVAL
				return


func _find_player() -> void:
	# Find player in scene
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0]


func _find_flow_field() -> void:
	var fields: Array[Node] = get_tree().get_nodes_in_group("flow_field")
	if fields.size() > 0:
		_flow_field = fields[0] as FlowField


func _process_movement(delta: float) -> void:
	if not _target:
		_find_player()
		return
	if not _flow_field:
		_find_flow_field()

	# Flow field direction (routes around obstacles via precomputed BFS)
	var desired_dir: Vector2 = Vector2.ZERO
	if _flow_field:
		desired_dir = _flow_field.get_direction(global_position)

	# Fallback to direct chase when field has no data for this cell
	if desired_dir.length_squared() < 0.001:
		desired_dir = (_target.global_position - global_position).normalized()

	# Smoothly interpolate toward desired direction to avoid jerky turns
	if _current_dir.length_squared() < 0.001:
		_current_dir = desired_dir
	else:
		_current_dir = _current_dir.lerp(desired_dir, minf(1.0, GameConfig.ENEMY_TURN_SPEED * delta)).normalized()

	var chase_velocity: Vector2 = _current_dir * move_speed

	# Separation force prevents enemy stacking
	var separation: Vector2 = _get_separation_force()

	velocity = chase_velocity + _knockback_velocity + separation

	# Face movement direction
	if velocity.length() > 10:
		rotation = velocity.angle()


## Compute a repulsion force away from nearby enemies to prevent stacking.
## Uses distance-squared checks for performance.
func _get_separation_force() -> Vector2:
	var sep_radius: float = GameConfig.ENEMY_SEPARATION_RADIUS
	var sep_radius_sq: float = sep_radius * sep_radius
	var sep_strength: float = GameConfig.ENEMY_SEPARATION_STRENGTH
	var force: Vector2 = Vector2.ZERO
	var my_pos: Vector2 = global_position

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy: Node in enemies:
		if enemy == self:
			continue
		if not enemy is Node2D:
			continue
		var other_pos: Vector2 = (enemy as Node2D).global_position
		var diff: Vector2 = my_pos - other_pos
		var dist_sq: float = diff.length_squared()
		if dist_sq < sep_radius_sq and dist_sq > 0.01:
			# Strength inversely proportional to distance
			var dist: float = sqrt(dist_sq)
			var proximity: float = 1.0 - (dist / sep_radius)
			force += diff.normalized() * proximity * sep_strength

	return force


func _process_knockback(delta: float) -> void:
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, GameConfig.ENEMY_KNOCKBACK_FRICTION * delta * 100)


## Despawn enemies that wander too far outside the arena boundary.
func _check_arena_bounds() -> void:
	var despawn_radius: float = GameConfig.ARENA_RADIUS + GameConfig.ENEMY_DESPAWN_BUFFER
	if global_position.length() > despawn_radius:
		queue_free()


func take_damage(amount: float, _source: Node = null) -> void:
	if _is_dying:
		return
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
	_is_dying = true
	
	# Record kill
	RunManager.record_kill(enemy_type)
	
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


func get_stardust_value() -> int:
	return stardust_value
