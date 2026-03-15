extends Node2D
class_name SpaceLasers

## Space Lasers — Fires neon-red laser bolts that bounce between enemies.
## Each bolt travels to the nearest enemy and on hit ricochets to the next
## closest target within bounce_range, up to projectile_bounces times.
## Projectile count scales with the projectile_count stat.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/gameplay/projectile.tscn")
const LASER_BULLET_TEXTURE: Texture2D = preload("res://assets/lasers/laser_bullet.png")

# --- Stats ---
@export var damage: float = 5.0
@export var burst_count: int = 1
@export var burst_interval: float = 0.04
@export var projectile_speed: float = 750.0
@export var lifetime: float = 1.5
@export var bounce_count: int = 2
@export var bounce_range: float = 400.0
@export var size_mult: float = 1.0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 0.0

# --- Visual ---
@export var color_core: Color = Color(1.0, 0.13, 0.13, 1.0)
@export var color_glow: Color = Color(1.0, 0.0, 0.0, 1.0)
@export var glow_strength: float = 1.5
@export var bolt_length: float = 12.0
@export var bolt_width: float = 2.0
@export var use_texture_driven_color: bool = false
@export var sprite_scale: float = 0.42
@export var sprite_width_mult: float = 0.50
@export var front_rotation_offset_deg: float = 90.0
@export var enable_glow_overlay: bool = true
@export var glow_overlay_scale_mult: float = 1.65
@export var glow_overlay_alpha: float = 0.35
@export var spread_angle_deg: float = 3.0

@onready var FrameCache: Node = get_node("/root/FrameCache")
@onready var GameSeed: Node = get_node("/root/GameSeed")
@onready var ObjectPool: Node = get_node("/root/ObjectPool")

# --- Internal ---
var _stats_component: Node = null
var _active_projectiles: Array = []
var _burst_queue: int = 0
var _burst_timer: float = 0.0
var _fire_origin: Vector2 = Vector2.ZERO
var _fire_direction: Vector2 = Vector2.RIGHT
var _rng: RandomNumberGenerator = null
var _follow_source: Node2D = null
var _target_queue: Array[Node2D] = []
var _target_index: int = 0
var _source_collision_radius: float = GameConfig.DEFAULT_COLLISION_RADIUS


func setup(params: Dictionary) -> SpaceLasers:
	for key in params:
		if key in self:
			set(key, params[key])
	if params.has("projectile_count"):
		burst_count = maxi(1, int(params["projectile_count"]))
	if params.has("projectile_bounces"):
		bounce_count = maxi(0, int(params["projectile_bounces"]))
	return self


func fire_from(spawn_pos: Vector2, direction: Vector2, stats_component: Node = null, follow_source: Node2D = null, targets: Variant = null) -> void:
	if _rng == null:
		_rng = GameSeed.rng("space_lasers")
	_stats_component = stats_component
	_follow_source = follow_source
	_source_collision_radius = _resolve_source_collision_radius()
	_fire_origin = spawn_pos
	_fire_direction = direction.normalized()
	if _fire_direction.is_zero_approx():
		_fire_direction = Vector2.RIGHT
	_set_fire_origin_from_source_edge(_fire_direction)

	# Build target queue from provided list
	_target_queue.clear()
	if targets is Array:
		for t in targets:
			if t is Node2D and is_instance_valid(t):
				_target_queue.append(t)
	_target_index = 0

	# Aim first bolt at the first target
	_aim_at_current_target()
	_spawn_bolt(_fire_origin, _fire_direction, bounce_count)
	_target_index += 1
	_burst_queue = burst_count - 1
	_burst_timer = burst_interval


func _process(delta: float) -> void:
	# Handle burst queue — fire remaining bolts at intervals
	if _burst_queue > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_aim_at_current_target()
			var spread_angle: float = _rng.randf_range(deg_to_rad(-spread_angle_deg), deg_to_rad(spread_angle_deg))
			var bolt_dir: Vector2 = _fire_direction.rotated(spread_angle)
			_spawn_bolt(_fire_origin, bolt_dir, bounce_count)
			_target_index += 1
			_burst_queue -= 1
			_burst_timer = burst_interval

	# Clean up dead projectile references
	var to_remove: Array = []
	for proj in _active_projectiles:
		if not is_instance_valid(proj):
			to_remove.append(proj)
	for p in to_remove:
		_active_projectiles.erase(p)

	# Self-destruct when burst is done and all projectiles are gone
	if _burst_queue <= 0 and _active_projectiles.is_empty():
		queue_free()


func _aim_at_current_target() -> void:
	## Aim at the next target in the queue, cycling through enemies.
	## Updates fire origin from the ship collision edge in shot direction.
	if is_instance_valid(_follow_source):
		_source_collision_radius = _resolve_source_collision_radius()

	# Prune dead targets from queue
	var i: int = _target_queue.size() - 1
	while i >= 0:
		if not is_instance_valid(_target_queue[i]):
			_target_queue.remove_at(i)
			if _target_index > i:
				_target_index -= 1
		i -= 1

	if _target_queue.is_empty():
		# No targets left — try to find any enemy
		var fallback: Node2D = EffectUtils.find_nearest_enemy(get_tree(), _fire_origin)
		if fallback:
			_target_queue.append(fallback)
			_target_index = 0
		_set_fire_origin_from_source_edge(_fire_direction)
		return

	# Wrap index to cycle through targets
	var idx: int = _target_index % _target_queue.size()
	var target: Node2D = _target_queue[idx]
	var dir: Vector2 = (target.global_position - _fire_origin).normalized()
	if not dir.is_zero_approx():
		_fire_direction = dir

	_set_fire_origin_from_source_edge(_fire_direction)


func _set_fire_origin_from_source_edge(direction: Vector2) -> void:
	if is_instance_valid(_follow_source):
		var dir: Vector2 = direction.normalized()
		if dir.is_zero_approx():
			dir = Vector2.RIGHT
		var center: Vector2 = _follow_source.global_position
		_fire_origin = center + dir * _source_collision_radius
		global_position = _fire_origin
	else:
		global_position = _fire_origin


func _resolve_source_collision_radius() -> float:
	if not is_instance_valid(_follow_source):
		return GameConfig.DEFAULT_COLLISION_RADIUS

	var collision: CollisionShape2D = _follow_source.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return GameConfig.DEFAULT_COLLISION_RADIUS

	var base_radius: float = GameConfig.DEFAULT_COLLISION_RADIUS
	if collision.shape is CircleShape2D:
		var circle: CircleShape2D = collision.shape as CircleShape2D
		base_radius = circle.radius
	elif collision.shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = collision.shape as CapsuleShape2D
		base_radius = capsule.radius + capsule.height * 0.5
	elif collision.shape is RectangleShape2D:
		var rect: RectangleShape2D = collision.shape as RectangleShape2D
		base_radius = rect.size.length() * 0.5

	var scale_factor: float = maxf(absf(_follow_source.global_scale.x), absf(_follow_source.global_scale.y))
	return maxf(1.0, base_radius * scale_factor)


func _spawn_bolt(origin: Vector2, direction: Vector2, bounces_remaining: int) -> void:
	var projectile: Node2D = ObjectPool.acquire("projectile", PROJECTILE_SCENE)
	projectile.z_index = -1
	projectile.initialize(
		damage,
		direction.normalized(),
		projectile_speed,
		0,  # piercing — bounces handle multi-hit instead
		size_mult,
		_stats_component,
		{},
		crit_chance,
		crit_damage
	)
	projectile.global_position = origin
	projectile._lifetime = lifetime

	# Hide default sprite, add neon laser visual
	var sprite: Sprite2D = projectile.get_node_or_null("Sprite2D")
	if sprite:
		sprite.visible = false

	var visual: _LaserBulletVisual = _LaserBulletVisual.new()
	visual.bullet_texture = LASER_BULLET_TEXTURE
	visual.use_texture_driven_color = use_texture_driven_color
	visual.bolt_length = bolt_length
	visual.bolt_width = bolt_width
	visual.color_core = color_core
	visual.color_glow = color_glow
	visual.glow_strength = glow_strength
	visual.sprite_scale = sprite_scale
	visual.sprite_width_mult = sprite_width_mult
	visual.front_rotation_offset_rad = deg_to_rad(front_rotation_offset_deg)
	visual.enable_glow_overlay = enable_glow_overlay
	visual.glow_overlay_scale_mult = glow_overlay_scale_mult
	visual.glow_overlay_alpha = glow_overlay_alpha
	projectile.add_child(visual)

	get_tree().current_scene.add_child(projectile)
	_active_projectiles.append(projectile)

	# Connect hit signal for bounce mechanic
	if bounces_remaining > 0 and projectile.has_signal("hit_enemy"):
		var callback: Callable = _on_bolt_hit.bind(projectile, bounces_remaining)
		projectile.hit_enemy.connect(callback, CONNECT_ONE_SHOT)


func _on_bolt_hit(enemy: Node2D, _damage_info: Dictionary, source_projectile: Node2D, bounces_remaining: int) -> void:
	if bounces_remaining <= 0:
		return
	if not is_instance_valid(source_projectile):
		return

	var hit_pos: Vector2 = source_projectile.global_position

	# Find nearest enemy within bounce range, excluding the one we just hit
	var nearest: Node2D = null
	var nearest_dist: float = bounce_range
	var enemies: Array = FrameCache.enemies
	for enemy_any in enemies:
		if not is_instance_valid(enemy_any):
			continue
		var e: Node2D = enemy_any as Node2D
		if not e:
			continue
		if e == enemy:
			continue
		var dist: float = hit_pos.distance_to(e.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = e

	if nearest == null:
		return

	var bounce_dir: Vector2 = (nearest.global_position - hit_pos).normalized()
	if bounce_dir.is_zero_approx():
		bounce_dir = Vector2.RIGHT

	# Defer spawn to avoid modifying physics state during query flush
	call_deferred("_spawn_bolt", hit_pos, bounce_dir, bounces_remaining - 1)


## Laser bullet visual with additive sprite front and compact rear spark trail.
## Projectile node rotation controls travel direction. The PNG top is treated
## as the forward-facing tip via front_rotation_offset_rad.
class _LaserBulletVisual extends NeonProjectileVisual:
	var bullet_texture: Texture2D = null
	var use_texture_driven_color: bool = false
	var bolt_length: float = 12.0
	var bolt_width: float = 2.0
	var sprite_scale: float = 0.42
	var sprite_width_mult: float = 0.50
	var front_rotation_offset_rad: float = PI * 0.5
	var enable_glow_overlay: bool = true
	var glow_overlay_scale_mult: float = 1.65
	var glow_overlay_alpha: float = 0.35

	var _sprite: Sprite2D = null
	var _glow_sprite: Sprite2D = null

	func _ready() -> void:
		_build_glow_sprite()
		_build_sprite()

	func _build_glow_sprite() -> void:
		if not enable_glow_overlay:
			return
		_glow_sprite = Sprite2D.new()
		_glow_sprite.texture = bullet_texture
		_glow_sprite.centered = true
		_glow_sprite.scale = Vector2(
			maxf(0.01, sprite_scale * sprite_width_mult * glow_overlay_scale_mult),
			maxf(0.01, sprite_scale * glow_overlay_scale_mult)
		)
		_glow_sprite.rotation = front_rotation_offset_rad
		_glow_sprite.material = _make_additive_material()
		_glow_sprite.modulate = Color(
			color_glow.r,
			color_glow.g,
			color_glow.b,
			clampf(glow_overlay_alpha, 0.0, 1.0)
		)
		add_child(_glow_sprite)

	func _build_sprite() -> void:
		_sprite = Sprite2D.new()
		_sprite.texture = bullet_texture
		_sprite.centered = true
		_sprite.scale = Vector2(
			maxf(0.01, sprite_scale * sprite_width_mult),
			maxf(0.01, sprite_scale)
		)
		_sprite.rotation = front_rotation_offset_rad
		_sprite.material = _make_additive_material()
		if use_texture_driven_color:
			_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			_sprite.modulate = Color(color_core.r, color_core.g, color_core.b, 0.95)
		add_child(_sprite)

	func _make_additive_material() -> CanvasItemMaterial:
		var mat: CanvasItemMaterial = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		return mat

	func _draw() -> void:
		# Keep rendering sprite-only to avoid Metal fence stalls from heavy
		# procedural capsule primitives on large projectile counts.
		return
