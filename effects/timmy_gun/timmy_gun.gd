extends Node2D
class_name TimmyGun

## Timmy Gun — Burst-fire machine gun that fires rapid neon-blue rounds.
## Each bullet can ricochet off enemies, bouncing to hit additional targets.
## Uses the proven projectile.tscn for collision; replaces the sprite with
## a custom neon glow visual.

const PROJECTILE_SCENE := preload("res://scenes/gameplay/projectile.tscn")

# --- Stats ---
@export var damage: float = 8.0
@export var burst_count: int = 5
@export var burst_interval: float = 0.06
@export var projectile_speed: float = 900.0
@export var lifetime: float = 1.5
@export var bounce_count: int = 1
@export var bounce_range: float = 400.0
@export var size_mult: float = 1.0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 0.0

# --- Visual ---
@export var color_core: Color = Color(0.8, 0.87, 1.0, 1.0)
@export var color_glow: Color = Color(0.0, 0.73, 1.0, 1.0)
@export var glow_strength: float = 2.0
@export var bullet_radius: float = 2.5

# --- Internal ---
var _stats_component: Node = null
var _active_projectiles: Array = []
var _burst_queue: int = 0
var _burst_timer: float = 0.0
var _fire_origin: Vector2 = Vector2.ZERO
var _fire_direction: Vector2 = Vector2.RIGHT

@onready var FileLogger: Node = get_node_or_null("/root/FileLogger")
@onready var GameManager: Node = get_node_or_null("/root/GameManager")


func setup(params: Dictionary) -> TimmyGun:
	for key in params:
		if key in self:
			set(key, params[key])
	# Map common stat names to our exports
	if params.has("projectile_count"):
		burst_count = maxi(1, int(params["projectile_count"]))
	if params.has("projectile_bounces"):
		bounce_count = maxi(0, int(params["projectile_bounces"]))
	return self


func fire_from(spawn_pos: Vector2, direction: Vector2, stats_component: Node = null) -> void:
	_stats_component = stats_component
	_fire_origin = spawn_pos
	_fire_direction = direction.normalized()
	if _fire_direction.is_zero_approx():
		_fire_direction = Vector2.RIGHT
	global_position = spawn_pos

	# Fire first bullet immediately, queue the rest
	_spawn_bullet(_fire_origin, _fire_direction, bounce_count)
	_burst_queue = burst_count - 1
	_burst_timer = burst_interval

	FileLogger.log_info("TimmyGun", "Burst started: %d rounds from %s dir=%s bounces=%d" % [burst_count, str(spawn_pos), str(_fire_direction), bounce_count])


func _process(delta: float) -> void:
	# Handle burst queue — fire remaining bullets at intervals
	if _burst_queue > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			# Add slight random spread to each burst bullet for machine-gun feel
			var spread_angle: float = randf_range(deg_to_rad(-4.0), deg_to_rad(4.0))
			var bullet_dir: Vector2 = _fire_direction.rotated(spread_angle)
			_spawn_bullet(_fire_origin, bullet_dir, bounce_count)
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


func _spawn_bullet(origin: Vector2, direction: Vector2, bounces_remaining: int) -> void:
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

	# Hide default sprite, add neon glow visual
	var sprite: Sprite2D = projectile.get_node_or_null("Sprite2D")
	if sprite:
		sprite.visible = false

	var glow: _NeonBullet = _NeonBullet.new()
	glow.bullet_radius = bullet_radius * size_mult
	glow.color_core = color_core
	glow.color_glow = color_glow
	glow.glow_strength = glow_strength
	projectile.add_child(glow)

	get_tree().current_scene.add_child(projectile)
	_active_projectiles.append(projectile)

	# Connect hit signal for bounce mechanic
	if bounces_remaining > 0 and projectile.has_signal("hit_enemy"):
		var callback: Callable = _on_bullet_hit.bind(projectile, bounces_remaining)
		projectile.hit_enemy.connect(callback, CONNECT_ONE_SHOT)


func _on_bullet_hit(enemy: Node2D, _damage_info: Dictionary, source_projectile: Node2D, bounces_remaining: int) -> void:
	if bounces_remaining <= 0:
		return
	if not is_instance_valid(source_projectile):
		return

	var hit_pos: Vector2 = source_projectile.global_position

	# Find nearest enemy within bounce range, excluding the one we just hit
	var nearest: Node2D = null
	var nearest_dist: float = bounce_range
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_any in enemies:
		if not enemy_any is Node2D or not is_instance_valid(enemy_any):
			continue
		var e: Node2D = enemy_any as Node2D
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

	# Spawn a new bounced bullet
	_spawn_bullet(hit_pos, bounce_dir, bounces_remaining - 1)


class _NeonBullet extends Node2D:
	## Tiny glowing neon-blue bullet visual. Drawn procedurally.
	var bullet_radius: float = 2.5
	var color_core: Color = Color(0.8, 0.87, 1.0, 1.0)
	var color_glow: Color = Color(0.0, 0.73, 1.0, 1.0)
	var glow_strength: float = 2.0

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var r: float = maxf(1.0, bullet_radius)

		# Outer glow layers (3 concentric rings, fading out)
		for i in range(3, 0, -1):
			var t: float = float(i) / 3.0
			var glow_r: float = r * (1.0 + t * 3.0)
			var alpha: float = 0.12 * t * glow_strength
			draw_circle(Vector2.ZERO, glow_r, Color(color_glow.r, color_glow.g, color_glow.b, alpha))

		# Bright glow ring
		draw_circle(Vector2.ZERO, r * 1.4, Color(color_glow.r, color_glow.g, color_glow.b, 0.55))

		# Core
		draw_circle(Vector2.ZERO, r * 0.85, color_core)

		# Hot center
		draw_circle(Vector2.ZERO, r * 0.35, Color(1.0, 1.0, 1.0, 0.92))
