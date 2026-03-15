extends Node2D
class_name StraightLineNegotiator

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/gameplay/projectile.tscn")

@export var damage: float = 14.0
@export var projectile_speed: float = 1100.0
@export var piercing: int = 3
@export var lifetime: float = 1.1
@export var size_mult: float = 1.0
@export var size: float = 550.0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 0.0

@export var color_core: Color = Color(1.0, 0.96, 0.9, 1.0)
@export var color_glow: Color = Color(0.35, 0.95, 1.0, 1.0)
@export var glow_strength: float = 1.4
@export var needle_length_px: float = 28.0
@export var needle_width_px: float = 2.0
@export var trail_alpha: float = 0.35

@onready var ObjectPool: Node = get_node("/root/ObjectPool")
var _projectile: Node2D = null
var _spawn_pos: Vector2 = Vector2.ZERO


func setup(params: Dictionary) -> StraightLineNegotiator:
	for key in params:
		if key in self:
			set(key, params[key])
	return self


func fire_from(spawn_pos: Vector2, direction: Vector2, stats_component: Node = null, follow_source: Node2D = null) -> void:
	var origin: Vector2 = EffectUtils.source_edge_origin(follow_source, direction, spawn_pos)
	var projectile: Node2D = ObjectPool.acquire("projectile", PROJECTILE_SCENE)
	projectile.z_index = -1
	projectile.initialize(
		damage,
		direction.normalized(),
		projectile_speed,
		piercing,
		size_mult,
		stats_component,
		{},
		crit_chance,
		crit_damage
	)
	projectile.global_position = origin
	projectile._lifetime = lifetime

	var sprite: Sprite2D = projectile.get_node_or_null("Sprite2D")
	if sprite:
		sprite.visible = false

	var tracer: _NeedleTracer = _NeedleTracer.new()
	tracer.color_core = color_core
	tracer.color_glow = color_glow
	tracer.glow_strength = glow_strength
	tracer.needle_length_px = needle_length_px
	tracer.needle_width_px = needle_width_px
	tracer.trail_alpha = trail_alpha
	projectile.add_child(tracer)

	get_tree().current_scene.add_child(projectile)
	_projectile = projectile
	_spawn_pos = origin


func _process(_delta: float) -> void:
	if _projectile == null:
		return
	if not is_instance_valid(_projectile):
		queue_free()
		return
	if size > 0.0 and _projectile.global_position.distance_to(_spawn_pos) >= size:
		ObjectPool.release("projectile", _projectile)
		_projectile = null
		queue_free()


class _NeedleTracer extends NeonProjectileVisual:
	var needle_length_px: float = 28.0
	var needle_width_px: float = 2.0
	var trail_alpha: float = 0.35

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var length: float = maxf(6.0, needle_length_px)
		var width: float = maxf(1.0, needle_width_px)

		for i in range(3, 0, -1):
			var t: float = float(i) / 3.0
			var glow_w: float = width * (1.0 + t * 2.0)
			draw_line(Vector2.ZERO, Vector2.RIGHT * length, _glow_color(t, 0.13), glow_w, true)

		draw_line(
			Vector2.ZERO,
			Vector2.RIGHT * length,
			Color(color_core.r, color_core.g, color_core.b, 0.96),
			width,
			true
		)

		draw_line(
			Vector2.LEFT * (length * 0.65),
			Vector2.ZERO,
			Color(color_glow.r, color_glow.g, color_glow.b, clampf(trail_alpha, 0.0, 0.9)),
			maxf(1.0, width * 0.65),
			true
		)
