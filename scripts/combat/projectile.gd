extends Area2D

## Projectile - Base projectile that moves, deals damage, and self-destructs.

signal hit_enemy(enemy: Node2D, damage_info: Dictionary)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var RunManager: Node = get_node("/root/RunManager")
@onready var FileLogger: Node = get_node("/root/FileLogger")

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


func _ready() -> void:
	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Apply size to collision reach only (not visual scale)
	if collision_shape and collision_shape.shape is CircleShape2D:
		var base_radius: float = collision_shape.shape.radius
		collision_shape.shape = collision_shape.shape.duplicate()
		collision_shape.shape.radius = base_radius * size_mult
	
	# Set rotation to match direction
	rotation = direction.angle()
	
	# Debug sprite texture info
	var tex_info: String = "null"
	if sprite.texture:
		tex_info = "size=%s" % sprite.texture.get_size()
	FileLogger.log_debug("Projectile", "Ready at %s scale: %s visible: %s sprite_tex: %s z_index: %d" % [global_position, scale, visible, tex_info, z_index])


func _process(delta: float) -> void:
	# Move in direction
	position += direction * speed * delta
	
	# Lifetime
	_lifetime -= delta
	if _lifetime <= 0:
		queue_free()


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
		queue_free()


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
	# Calculate damage with crits
	var damage_info: Dictionary = {"damage": damage, "is_crit": false, "is_overcrit": false}
	
	if _stats:
		damage_info = _stats.calculate_damage(damage, _weapon_crit_chance, _weapon_crit_damage)
		
		# Try lifesteal
		_stats.roll_lifesteal()
	
	# Apply damage to enemy
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage_info.damage, self)
		RunManager.record_damage_dealt(damage_info.damage)
	
	hit_enemy.emit(enemy, damage_info)
	
	# Check piercing
	_hits_remaining -= 1
	if _hits_remaining <= 0:
		queue_free()
