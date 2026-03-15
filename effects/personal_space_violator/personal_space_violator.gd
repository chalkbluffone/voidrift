extends Node2D
class_name PersonalSpaceViolator

## Personal Space Violator — Neon shotgun blast.
## Fires a wide cone of standard projectiles (proven collision system).
## Replaces their sprite with neon glow visuals and applies distance-based falloff.
##
## KEY DESIGN: Uses the existing projectile.tscn scene for each pellet. This
## guarantees working collision detection — no dynamic Area2D creation.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/gameplay/projectile.tscn")
const LASER_BULLET_TEXTURE_PATH: String = "res://assets/lasers/laser_bullet_green.png"

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

# --- Visual ---
@export var color_glow: Color = Color(0.224, 1.0, 0.078, 1.0)
@export var sprite_scale: float = 0.315
@export var edge_fade_start_ratio: float = 0.85
@export var edge_fade_duration: float = 0.08
@export var crit_chance: float = 0.0
@export var crit_damage: float = 0.0

# --- Internal ---
@onready var ObjectPool: Node = get_node("/root/ObjectPool")
var _pellets: Array = []  # Array of projectile node refs
var _spawn_origin: Vector2 = Vector2.ZERO
var _stats_component: Node = null
var _rng: RandomNumberGenerator = null
var _source_node: Node2D = null
var _runtime_size_mult: float = 1.0
var _laser_bullet_texture: Texture2D = null
var _fading_pellet_ids: Dictionary = {}


func _ready() -> void:
	_laser_bullet_texture = ResourceLoader.load(LASER_BULLET_TEXTURE_PATH) as Texture2D


func setup(params: Dictionary) -> PersonalSpaceViolator:
	for key in params:
		if key in self:
			set(key, params[key])
	if params.has("projectile_count"):
		pellet_count = int(params["projectile_count"])
	if params.has("projectile_speed"):
		pellet_speed = float(params["projectile_speed"])
	if params.has("size_mult"):
		_runtime_size_mult = float(params["size_mult"])
	return self


func set_source(source: Node2D) -> void:
	_source_node = source
	if source and source.has_node("StatsComponent"):
		_stats_component = source.get_node("StatsComponent")


func fire_burst(origin: Vector2, direction: Vector2) -> void:
	if _rng == null:
		var game_seed: Node = get_node_or_null("/root/GameSeed")
		_rng = game_seed.rng("personal_space_violator") if game_seed else RandomNumberGenerator.new()
	_spawn_origin = EffectUtils.source_edge_origin(_source_node, direction, origin)
	global_position = _spawn_origin

	var base_angle: float = direction.angle()
	var half_spread: float = deg_to_rad(spread_degrees) / 2.0

	for i in range(pellet_count):
		var t: float = 0.0
		if pellet_count > 1:
			t = float(i) / float(pellet_count - 1)
		var angle: float = base_angle - half_spread + (half_spread * 2.0 * t)
		# Random jitter for organic shotgun feel
		angle += _rng.randf_range(-deg_to_rad(3.0), deg_to_rad(3.0))
		var spd: float = pellet_speed * _rng.randf_range(0.9, 1.1)
		_spawn_pellet(angle, spd)


func _spawn_pellet(angle: float, speed: float) -> void:
	var dir: Vector2 = Vector2(cos(angle), sin(angle))

	# Use the PROVEN projectile scene — guaranteed working collision
	var pellet: Node2D = ObjectPool.acquire("projectile", PROJECTILE_SCENE)
	pellet.z_index = -1

	# Initialize with standard projectile API
	var style: Dictionary = {"color": color_glow}
	pellet.initialize(damage, dir, speed, 0, _runtime_size_mult, _stats_component, style, crit_chance, crit_damage)
	pellet._lifetime = lifetime
	pellet.global_position = _spawn_origin

	# Hide default sprite only when custom texture visual is available.
	var sprite: Node = pellet.get_node_or_null("Sprite2D")
	if sprite and _laser_bullet_texture:
		sprite.visible = false

	if _laser_bullet_texture:
		var visual: _PelletSpriteVisual = _PelletSpriteVisual.new()
		visual.texture_asset = _laser_bullet_texture
		visual.sprite_scale = sprite_scale
		visual.color_glow = color_glow
		pellet.add_child(visual)

	_attach_spark_trail(pellet)

	# Add to scene tree (same as WeaponComponent._spawn_projectile)
	get_tree().current_scene.add_child(pellet)

	_pellets.append(pellet)


func _attach_spark_trail(pellet: Node2D) -> void:
	var spark_color: Color = Color(color_glow.r, color_glow.g, color_glow.b, 0.9)
	var trail: Node2D = EffectUtils.create_particles(pellet, {
		"amount": 8,
		"lifetime": 0.18,
		"local_coords": false,
		"emitting": true,
		"one_shot": false,
		"explosiveness": 0.0,
		"randomness": 0.6,
		"direction": Vector2.ZERO,
		"spread": 180.0,
		"initial_velocity_min": 2.0,
		"initial_velocity_max": 12.0,
		"gravity": Vector2.ZERO,
		"damping_min": 8.0,
		"damping_max": 20.0,
		"scale_amount_min": 0.4,
		"scale_amount_max": 1.0,
		"color": spark_color,
		"color_ramp": EffectUtils.make_gradient([
			[0.0, Color(1.0, 1.0, 1.0, 1.0)],
			[0.4, spark_color],
			[1.0, Color(spark_color.r, spark_color.g, spark_color.b, 0.0)],
		]),
		"texture": EffectUtils.get_white_pixel_texture(1),
	})
	trail.z_index = -2


func _process(_delta: float) -> void:
	# Update distance falloff on all living pellets
	var to_remove: Array = []
	for pellet in _pellets:
		if not is_instance_valid(pellet):
			_fading_pellet_ids.erase(pellet.get_instance_id())
			to_remove.append(pellet)
			continue
		# Continuously update damage based on travel distance
		var dist: float = pellet.global_position.distance_to(_spawn_origin)
		pellet.damage = damage * _calculate_falloff(dist)
		_maybe_start_edge_fade(pellet, dist)

	for p in to_remove:
		_pellets.erase(p)

	# Self-destruct when all pellets are gone
	if _pellets.is_empty():
		queue_free()


func _maybe_start_edge_fade(pellet: Node2D, distance: float) -> void:
	var pellet_id: int = pellet.get_instance_id()
	if _fading_pellet_ids.has(pellet_id):
		return
	var max_distance: float = pellet.speed * lifetime
	if max_distance <= 0.0:
		return
	var clamped_ratio: float = clampf(edge_fade_start_ratio, 0.0, 0.99)
	var fade_start_distance: float = max_distance * clamped_ratio
	if distance < fade_start_distance:
		return
	_fading_pellet_ids[pellet_id] = true
	var tween: Tween = pellet.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(pellet, "modulate:a", 0.0, maxf(0.01, edge_fade_duration))


func _calculate_falloff(distance: float) -> float:
	if distance <= falloff_start:
		return 1.0
	elif distance >= falloff_end:
		return falloff_min_mult
	else:
		var t: float = (distance - falloff_start) / (falloff_end - falloff_start)
		return lerp(1.0, falloff_min_mult, t)



# --- Sprite visual (replaces bullet sprite) ---

class _PelletSpriteVisual extends NeonProjectileVisual:
	var texture_asset: Texture2D = null
	var sprite_scale: float = 0.315
	var _sprite: Sprite2D = null

	func _ready() -> void:
		_sprite = Sprite2D.new()
		_sprite.texture = texture_asset
		_sprite.centered = true
		_sprite.scale = Vector2.ONE * maxf(0.01, sprite_scale)
		# PNG top is the projectile nose; rotate so top points along travel direction.
		_sprite.rotation = PI * 0.5
		_sprite.modulate = Color(color_glow.r, color_glow.g, color_glow.b, 1.0)
		_sprite.material = _make_additive_material()
		add_child(_sprite)

	func _make_additive_material() -> CanvasItemMaterial:
		var additive_mat: CanvasItemMaterial = CanvasItemMaterial.new()
		additive_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		return additive_mat

	func _draw() -> void:
		# Sprite-only rendering avoids heavy procedural draw calls.
		return
