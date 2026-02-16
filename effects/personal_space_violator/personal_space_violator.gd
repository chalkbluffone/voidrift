extends Node2D
class_name PersonalSpaceViolator

## Personal Space Violator — Neon shotgun blast.
## Fires a wide cone of standard projectiles (proven collision system).
## Replaces their sprite with neon glow visuals and applies distance-based falloff.
##
## KEY DESIGN: Uses the existing projectile.tscn scene for each pellet. This
## guarantees working collision detection — no dynamic Area2D creation.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/gameplay/projectile.tscn")

# --- Stats ---
@export var damage: float = 18.0
@export var pellet_count: int = 7
@export var pellet_speed: float = 600.0
@export var spread_degrees: float = 45.0
@export var lifetime: float = 0.8

# --- Falloff ---
@export var falloff_start: float = 80.0
@export var falloff_end: float = 350.0
@export var falloff_min_mult: float = 0.15

# --- Shape ---
@export var pellet_radius: float = 0.5

# --- Visual ---
@export var color_core: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var color_glow: Color = Color(0.224, 1.0, 0.078, 1.0)
@export var glow_strength: float = 2.5
@export var bloom_intensity: float = 3.0
@export var pellet_height_px: int = 5

# --- Internal ---
var _pellets: Array = []  # Array of projectile node refs
var _spawn_origin: Vector2 = Vector2.ZERO

@onready var FileLogger: Node = get_node_or_null("/root/FileLogger")


func setup(params: Dictionary) -> PersonalSpaceViolator:
	for key in params:
		if key in self:
			set(key, params[key])
	if params.has("projectile_count"):
		pellet_count = int(params["projectile_count"])
	if params.has("projectile_speed"):
		pellet_speed = float(params["projectile_speed"])
	if params.has("size_mult"):
		pellet_radius *= float(params["size_mult"])
	return self


func fire_burst(origin: Vector2, direction: Vector2) -> void:
	_spawn_origin = origin
	global_position = origin

	var base_angle: float = direction.angle()
	var half_spread: float = deg_to_rad(spread_degrees) / 2.0

	for i in range(pellet_count):
		var t: float = 0.0
		if pellet_count > 1:
			t = float(i) / float(pellet_count - 1)
		var angle: float = base_angle - half_spread + (half_spread * 2.0 * t)
		# Random jitter for organic shotgun feel
		angle += randf_range(-deg_to_rad(3.0), deg_to_rad(3.0))
		var spd: float = pellet_speed * randf_range(0.9, 1.1)
		_spawn_pellet(angle, spd)

	FileLogger.log_info("PersonalSpaceViolator", "Fired %d pellets from %s spread=%.1f deg" % [pellet_count, str(origin), spread_degrees])


func _spawn_pellet(angle: float, speed: float) -> void:
	var dir: Vector2 = Vector2(cos(angle), sin(angle))

	# Use the PROVEN projectile scene — guaranteed working collision
	var pellet: Node2D = PROJECTILE_SCENE.instantiate()
	pellet.z_index = -1

	# Initialize with standard projectile API
	var style: Dictionary = {"color": color_glow}
	pellet.initialize(damage, dir, speed, 0, 1.0, null, style)
	pellet._lifetime = lifetime
	pellet.global_position = _spawn_origin

	# Hide standard bullet sprite, replace with neon glow
	var sprite: Node = pellet.get_node_or_null("Sprite2D")
	if sprite:
		sprite.visible = false

	var glow: _NeonGlow = _NeonGlow.new()
	glow.pellet_radius = pellet_radius
	glow.color_core = color_core
	glow.color_glow = color_glow
	glow.glow_strength = glow_strength
	glow.bloom_intensity = bloom_intensity
	pellet.add_child(glow)

	# Add to scene tree (same as WeaponComponent._spawn_projectile)
	get_tree().current_scene.add_child(pellet)

	_pellets.append(pellet)


func _process(_delta: float) -> void:
	# Update distance falloff on all living pellets
	var to_remove: Array = []
	for pellet in _pellets:
		if not is_instance_valid(pellet):
			to_remove.append(pellet)
			continue
		# Continuously update damage based on travel distance
		var dist: float = pellet.global_position.distance_to(_spawn_origin)
		pellet.damage = damage * _calculate_falloff(dist)

	for p in to_remove:
		_pellets.erase(p)

	# Self-destruct when all pellets are gone
	if _pellets.is_empty():
		queue_free()


func _calculate_falloff(distance: float) -> float:
	if distance <= falloff_start:
		return 1.0
	elif distance >= falloff_end:
		return falloff_min_mult
	else:
		var t: float = (distance - falloff_start) / (falloff_end - falloff_start)
		return lerp(1.0, falloff_min_mult, t)



# --- Neon glow visual (replaces bullet sprite) ---

class _NeonGlow extends Node2D:
	var pellet_radius: float = 0.5
	var color_core: Color = Color.WHITE
	var color_glow: Color = Color(0.224, 1.0, 0.078, 1.0)
	var glow_strength: float = 2.5
	var bloom_intensity: float = 3.0

	func _draw() -> void:
		# Outer bloom layers
		var bloom_layers: int = 4
		for i in range(bloom_layers, 0, -1):
			var t: float = float(i) / float(bloom_layers)
			var r: float = pellet_radius * (1.0 + t * bloom_intensity)
			var alpha: float = 0.15 * t * glow_strength
			draw_circle(Vector2.ZERO, r, Color(color_glow.r, color_glow.g, color_glow.b, alpha))
		# Core glow ring
		draw_circle(Vector2.ZERO, pellet_radius * 1.2, Color(color_glow.r, color_glow.g, color_glow.b, 0.6))
		# Bright core
		draw_circle(Vector2.ZERO, pellet_radius * 0.7, color_core)
		# Hot center dot
		draw_circle(Vector2.ZERO, pellet_radius * 0.3, Color(1.0, 1.0, 1.0, 0.9))
