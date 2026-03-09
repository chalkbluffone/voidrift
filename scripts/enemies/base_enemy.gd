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

## When true, enemy stops moving (frozen by Stopwatch power-up).
var is_frozen: bool = false

# --- References ---
var _target: Node2D = null
var _hitbox: Area2D = null
@onready var RunManager: Node = get_node("/root/RunManager")
@onready var GameConfig: Node = get_node("/root/GameConfig")
@onready var FrameCache: Node = get_node("/root/FrameCache")
@onready var GameSeed: Node = get_node("/root/GameSeed")

# --- Knockback ---
var _knockback_velocity: Vector2 = Vector2.ZERO

# --- Contact Damage ---
var _damage_cooldown: float = 0.0

# --- Asteroid Overlap ---
var _in_asteroid: bool = false

var _rng: RandomNumberGenerator = null


func _ready() -> void:
	add_to_group("enemies")
	_rng = GameSeed.rng("base_enemy")
	current_hp = max_hp
	_find_player()
	
	# Ensure HitboxArea is connected and monitoring
	_hitbox = get_node_or_null("HitboxArea") as Area2D
	if _hitbox:
		_hitbox.monitoring = true
		_hitbox.monitorable = true

	# Spawn frozen if a stopwatch freeze is currently active
	if get_tree().has_meta("stopwatch_freeze_active"):
		is_frozen = true



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


func _process_movement(_delta: float) -> void:
	if is_frozen:
		velocity = _knockback_velocity
		_update_asteroid_visual(false)
		return
	if not _target:
		_find_player()
		return

	var speed: float = _get_asteroid_adjusted_speed(move_speed)
	var desired_dir: Vector2 = (_target.global_position - global_position).normalized()
	velocity = desired_dir * speed + _knockback_velocity

	# Face movement direction
	if velocity.length() > 10:
		rotation = velocity.angle()


## Check if this enemy overlaps any asteroid and return the adjusted speed.
## Also updates visual feedback (dim sprite when inside asteroid).
func _get_asteroid_adjusted_speed(base_speed: float) -> float:
	var my_pos: Vector2 = global_position
	var asteroids: Array[Node] = FrameCache.asteroids
	for asteroid: Node in asteroids:
		if not asteroid is Node2D:
			continue
		var ast: Node2D = asteroid as Node2D
		@warning_ignore("unsafe_property_access")
		var radius: float = ast.effective_radius
		if my_pos.distance_squared_to(ast.global_position) < radius * radius:
			_update_asteroid_visual(true)
			return base_speed * GameConfig.ENEMY_ASTEROID_SLOW_MULTIPLIER
	_update_asteroid_visual(false)
	return base_speed


## Update sprite visual when entering/leaving an asteroid.
func _update_asteroid_visual(inside: bool) -> void:
	if inside == _in_asteroid:
		return
	_in_asteroid = inside
	var sprite: Node = get_node_or_null("Sprite2D")
	if sprite:
		(sprite as CanvasItem).modulate.a = 0.4 if inside else 1.0


func _process_knockback(delta: float) -> void:
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, GameConfig.ENEMY_KNOCKBACK_FRICTION * delta * 100)


## Despawn enemies that wander too far outside the arena boundary.
## Also teleports enemies back near the player when they exceed the leash radius.
func _check_arena_bounds() -> void:
	# Leash check: teleport back near player if too far away
	if _target and is_instance_valid(_target):
		var leash_radius: float = GameConfig.BOSS_LEASH_RADIUS if enemy_type == "boss" else GameConfig.ENEMY_LEASH_RADIUS
		var dist_to_player: float = global_position.distance_to(_target.global_position)
		if dist_to_player > leash_radius:
			_teleport_near_player()
			return

	# Hard despawn: safety net for enemies outside the arena entirely
	var despawn_radius: float = GameConfig.ARENA_RADIUS + GameConfig.ENEMY_DESPAWN_BUFFER
	if global_position.length() > despawn_radius:
		queue_free()


## Teleport this enemy to a new position near the player (leash respawn).
func _teleport_near_player() -> void:
	if not _target:
		return
	var attempts: int = 10
	for i: int in range(attempts):
		var angle: float = _rng.randf() * TAU
		var dist: float = _rng.randf_range(GameConfig.SPAWN_RADIUS_MIN, GameConfig.SPAWN_RADIUS_MAX)
		var candidate: Vector2 = _target.global_position + Vector2.from_angle(angle) * dist
		# Quick arena bounds check
		if candidate.length() < GameConfig.ARENA_RADIUS:
			global_position = candidate
			reset_physics_interpolation()
			return
	# Fallback: place behind player relative to center
	var behind_dir: Vector2 = -_target.global_position.normalized()
	if behind_dir.length_squared() < 0.01:
		behind_dir = Vector2.RIGHT
	global_position = _target.global_position + behind_dir * GameConfig.SPAWN_RADIUS_MIN
	reset_physics_interpolation()


func take_damage(amount: float, _source: Node = null, damage_info: Dictionary = {}) -> void:
	if _is_dying:
		return
	current_hp -= amount
	
	# Floating damage number
	_spawn_damage_number(amount, damage_info)
	
	# Visual feedback
	_flash_damage()
	
	if current_hp <= 0:
		_die()


const _DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/damage_number.tscn")


func _spawn_damage_number(amount: float, damage_info: Dictionary) -> void:
	@warning_ignore("unsafe_property_access")
	var show_numbers: bool = get_node("/root/PersistenceManager").persistent_data.settings.get("show_damage_numbers", true)
	if not show_numbers:
		return
	
	# Enforce soft cap — remove oldest if exceeded
	var existing: Array[Node] = FrameCache.damage_numbers
	if existing.size() >= GameConfig.DAMAGE_NUMBER_MAX_COUNT:
		if is_instance_valid(existing[0]):
			existing[0].queue_free()
	
	var label: DamageNumber = _DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
	get_tree().current_scene.add_child(label)
	label.setup(amount, damage_info, global_position)


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
