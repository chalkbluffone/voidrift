extends Node2D
class_name SpaceLasers

## Space Lasers — Fires neon-red laser bolts that bounce between enemies.
## Each bolt travels to the nearest enemy and on hit ricochets to the next
## closest target within bounce_range, up to projectile_bounces times.
## Projectile count scales with the projectile_count stat.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/gameplay/projectile.tscn")

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
@export var spread_angle_deg: float = 3.0

@onready var FrameCache: Node = get_node("/root/FrameCache")
@onready var GameSeed: Node = get_node("/root/GameSeed")

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
	_fire_origin = spawn_pos
	_fire_direction = direction.normalized()
	if _fire_direction.is_zero_approx():
		_fire_direction = Vector2.RIGHT
	global_position = spawn_pos

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
	## Updates fire origin from player's current position.
	if is_instance_valid(_follow_source):
		_fire_origin = _follow_source.global_position
		global_position = _fire_origin

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
		return

	# Wrap index to cycle through targets
	var idx: int = _target_index % _target_queue.size()
	var target: Node2D = _target_queue[idx]
	var dir: Vector2 = (target.global_position - _fire_origin).normalized()
	if not dir.is_zero_approx():
		_fire_direction = dir


func _spawn_bolt(origin: Vector2, direction: Vector2, bounces_remaining: int) -> void:
	var projectile: Node2D = PROJECTILE_SCENE.instantiate()
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

	var glow: _NeonLaserVisual = _NeonLaserVisual.new()
	glow.bolt_length = bolt_length
	glow.bolt_width = bolt_width
	glow.color_core = color_core
	glow.color_glow = color_glow
	glow.glow_strength = glow_strength
	projectile.add_child(glow)

	get_tree().current_scene.call_deferred("add_child", projectile)
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


## Elongated neon-red laser bolt visual. Drawn procedurally as a stretched
## glowing capsule shape oriented along the projectile's travel direction.
class _NeonLaserVisual extends NeonProjectileVisual:
	var bolt_length: float = 12.0
	var bolt_width: float = 2.0

	func _ready() -> void:
		queue_redraw()

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var l: float = maxf(4.0, bolt_length)
		var w: float = maxf(1.0, bolt_width)

		# Draw along the local X axis (projectile rotation handles direction)
		# Points run from -l to 0 (tail to head)
		var half_w: float = w

		# Outer glow layers (3 concentric elongated ellipses, fading out)
		for i in range(3, 0, -1):
			var t: float = float(i) / 3.0
			var glow_w: float = half_w * (1.0 + t * 3.0)
			var glow_l: float = l * (1.0 + t * 0.5)
			_draw_capsule(Vector2(-glow_l * 0.5, 0.0), glow_l, glow_w, _glow_color(t, 0.10))

		# Bright glow body
		var bright_col: Color = Color(color_glow.r, color_glow.g, color_glow.b, 0.55)
		_draw_capsule(Vector2(-l * 0.45, 0.0), l * 0.9, half_w * 1.4, bright_col)

		# Core beam
		_draw_capsule(Vector2(-l * 0.4, 0.0), l * 0.8, half_w * 0.85, color_core)

		# Hot center line
		var hot_col: Color = Color(1.0, 1.0, 1.0, 0.92)
		_draw_capsule(Vector2(-l * 0.3, 0.0), l * 0.6, half_w * 0.3, hot_col)


	## Draw a filled capsule (rectangle with rounded ends) centered at a position.
	func _draw_capsule(center: Vector2, length: float, radius: float, color: Color) -> void:
		var half_l: float = length * 0.5
		# Central rectangle
		var rect: Rect2 = Rect2(center.x - half_l, center.y - radius, length, radius * 2.0)
		draw_rect(rect, color)
		# End caps (circles)
		draw_circle(Vector2(center.x - half_l, center.y), radius, color)
		draw_circle(Vector2(center.x + half_l, center.y), radius, color)
