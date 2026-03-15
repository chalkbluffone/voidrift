extends Area2D

## Projectile - Base projectile that moves, deals damage, and self-destructs.
## Supports object pooling — use ObjectPool.release() instead of queue_free().

signal hit_enemy(enemy: Node2D, damage_info: Dictionary)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var RunManager: Node = get_node("/root/RunManager")
@onready var _object_pool: Node = get_node("/root/ObjectPool")

var damage: float = 10.0
var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var piercing: int = 0  # Number of enemies to pass through
var size_mult: float = 1.0
var _stats: Node = null

var _weapon_crit_chance: float = 0.0
var _weapon_crit_damage: float = 0.0

var _hits_remaining: int = 1
var _lifetime: float = GameConfig.PROJECTILE_DEFAULT_LIFETIME
var _hit_enemy_ids: Dictionary = {}
var _base_collision_radius: float = 0.0
var _initialized: bool = false


func _ready() -> void:
	if not _initialized:
		_initialized = true
		add_to_group("projectiles")
		# Connect signals only once — they persist across pool cycles
		body_entered.connect(_on_body_entered)
		area_entered.connect(_on_area_entered)
		# Store base collision radius for reset
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape = collision_shape.shape.duplicate()
			_base_collision_radius = collision_shape.shape.radius

	# Apply size to collision reach
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = _base_collision_radius * size_mult

	# Set rotation to match direction
	rotation = direction.angle()


func _process(delta: float) -> void:
	# Move in direction
	position += direction * speed * delta
	
	# Lifetime
	_lifetime -= delta
	if _lifetime <= 0:
		_return_to_pool()


## Reset this projectile to a clean state for pool reuse.
## Called automatically by ObjectPool.acquire() before the node is returned.
func reset() -> void:
	_hit_enemy_ids.clear()
	_lifetime = GameConfig.PROJECTILE_DEFAULT_LIFETIME
	_hits_remaining = 1
	damage = 10.0
	direction = Vector2.RIGHT
	speed = 400.0
	piercing = 0
	size_mult = 1.0
	_stats = null
	_weapon_crit_chance = 0.0
	_weapon_crit_damage = 0.0
	modulate = Color.WHITE
	rotation = 0.0
	scale = Vector2.ONE
	z_index = 0
	# Re-enable monitoring (may have been deferred-disabled)
	monitoring = true
	monitorable = true
	# Reset collision shape to base radius
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = _base_collision_radius
	# Reset sprite visibility + style (weapon effects hide it and add custom visuals)
	if sprite:
		sprite.visible = true
		sprite.modulate = Color.WHITE
		sprite.region_enabled = false
	# Remove dynamically-added visual children (NeonProjectileVisual subclasses)
	for child in get_children():
		if child == collision_shape or child == sprite:
			continue
		remove_child(child)
		child.queue_free()
	# Disconnect any one-shot hit_enemy connections from weapon bounce mechanics
	for conn in hit_enemy.get_connections():
		hit_enemy.disconnect(conn["callable"])


func initialize(p_damage: float, p_direction: Vector2, p_speed: float, p_piercing: int, p_size: float, stats: Node = null, style: Dictionary = {}, weapon_crit_chance: float = 0.0, weapon_crit_damage: float = 0.0) -> void:
	damage = p_damage
	direction = p_direction.normalized()
	speed = p_speed
	piercing = p_piercing
	size_mult = p_size
	_stats = stats
	_weapon_crit_chance = weapon_crit_chance
	_weapon_crit_damage = weapon_crit_damage
	_hits_remaining = piercing + 1
	rotation = direction.angle()
	_apply_style(style)


func _apply_style(style: Dictionary) -> void:
	if not is_instance_valid(sprite):
		return
	if style.has("color"):
		sprite.modulate = style["color"]
	if style.has("region"):
		if not sprite.texture:
			return
		var tex_size: Vector2 = sprite.texture.get_size()
		if tex_size.x < 32 or tex_size.y < 32:
			return
		var region_idx: int = int(style["region"])
		sprite.region_enabled = true
		# Assumes the bullet sheet contains variants in a horizontal strip of 32x32 tiles.
		sprite.region_rect = Rect2(region_idx * 32, 0, 32, 32)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		_hit_enemy(body)
	elif body.is_in_group("obstacles"):
		# Hit obstacle, destroy projectile
		_return_to_pool()


func _on_area_entered(area: Area2D) -> void:
	# Direct enemy Area2D (e.g., TestTarget)
	if area.is_in_group("enemies"):
		_hit_enemy(area)
		return
	# Child hitbox Area2D (e.g., BaseEnemy's HitboxArea)
	var parent: Node = area.get_parent()
	if parent and parent.is_in_group("enemies"):
		_hit_enemy(parent)


func _hit_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return

	var enemy_id: int = enemy.get_instance_id()
	if _hit_enemy_ids.has(enemy_id):
		return
	_hit_enemy_ids[enemy_id] = true

	# Calculate damage with crits
	var damage_info: Dictionary = {"damage": damage, "is_crit": false, "is_overcrit": false}
	
	if _stats:
		damage_info = _stats.calculate_damage(damage, _weapon_crit_chance, _weapon_crit_damage)
		
		# Try lifesteal
		_stats.roll_lifesteal()
	
	# Apply damage to enemy
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage_info.damage, self, damage_info)
		RunManager.record_damage_dealt(damage_info.damage)
	
	hit_enemy.emit(enemy, damage_info)
	
	# Check piercing
	_hits_remaining -= 1
	if _hits_remaining <= 0:
		_return_to_pool()


func _return_to_pool() -> void:
	_object_pool.release("projectile", self)
