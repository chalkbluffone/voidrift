extends Node2D
class_name ArcEffectBase

## Base class for crescent-arc weapon effects (RadiantArc, SnarkyComeback, …).
## Owns the shared mesh generation, hitbox bubble system, particle emitter,
## shader parameter plumbing, damage handling, and debug visualisation.
##
## Subclasses override:
##   _get_shader_path() -> String
##   _process(delta)              – movement / lifetime logic
##   _compute_sweep_and_alpha()   – returns {sweep: float, alpha: float}
##   _on_ready_hook()             – extra setup after base _ready()
##   _on_sweep_completed_hitbox() – (optional) called per-frame when sweep done
##   _on_sweep_completed_particles() – (optional) full-arc emission override


# ── Debug inner classes ───────────────────────────────────────────────────

class DebugCircle extends Node2D:
	var radius: float = 10.0
	var color: Color = Color(0, 1, 0, 0.5)

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color, 2.0)
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, color.a * 0.3))


class DebugCapsule extends Node2D:
	var capsule_radius: float = 5.0
	var capsule_height: float = 20.0
	var color: Color = Color(1, 1, 0, 0.5)

	func _draw() -> void:
		var half_length: float = max(0.0, capsule_height * 0.5 - capsule_radius)
		if half_length > 0:
			draw_arc(Vector2(0, -half_length), capsule_radius, PI, TAU, 16, color, 2.0)
			draw_arc(Vector2(0, half_length), capsule_radius, 0, PI, 16, color, 2.0)
			draw_line(Vector2(-capsule_radius, -half_length), Vector2(-capsule_radius, half_length), color, 2.0)
			draw_line(Vector2(capsule_radius, -half_length), Vector2(capsule_radius, half_length), color, 2.0)
		else:
			draw_arc(Vector2.ZERO, capsule_radius, 0, TAU, 32, color, 2.0)
		var fill_color: Color = Color(color.r, color.g, color.b, color.a * 0.3)
		if half_length > 0:
			draw_circle(Vector2(0, -half_length), capsule_radius, fill_color)
			draw_circle(Vector2(0, half_length), capsule_radius, fill_color)
			draw_rect(Rect2(-capsule_radius, -half_length, capsule_radius * 2, half_length * 2), fill_color)
		else:
			draw_circle(Vector2.ZERO, capsule_radius, fill_color)


# ── Shape exports ─────────────────────────────────────────────────────────

@export var arc_angle_deg: float = 90.0
@export var radius: float = 42.0
@export var thickness: float = 18.0
@export var taper: float = 0.5
@export var length_scale: float = 0.75
@export var distance: float = 25.0

# ── Timing / animation ───────────────────────────────────────────────────

@export var duration: float = 0.8
@export var fade_in: float = 0.08
@export var fade_out: float = 0.15
@export var sweep_speed: float = 1.2

# ── Color and glow ───────────────────────────────────────────────────────

@export var color_a: Color = Color(0.0, 1.0, 1.0, 1.0)
@export var color_b: Color = Color(1.0, 0.0, 1.0, 1.0)
@export var color_c: Color = Color(0.0, 0.5, 1.0, 1.0)
@export var glow_strength: float = 3.0
@export var core_strength: float = 1.2
@export var noise_strength: float = 0.3
@export var uv_scroll_speed: float = 3.0

# ── Visual effects ────────────────────────────────────────────────────────

@export var chromatic_aberration: float = 0.0
@export var pulse_strength: float = 0.0
@export var pulse_speed: float = 8.0
@export var electric_strength: float = 0.0
@export var electric_frequency: float = 20.0
@export var electric_speed: float = 15.0
@export var gradient_offset: float = 0.0

# ── Control ───────────────────────────────────────────────────────────────

@export var rotation_offset_deg: float = 0.0
@export var seed_offset: float = 0.0
@export var damage: float = 25.0

# ── Particles ─────────────────────────────────────────────────────────────

@export var particles_enabled: bool = true
@export var particles_amount: int = 20
@export var particles_size: float = 3.0
@export var particles_speed: float = 30.0
@export var particles_lifetime: float = 0.4
@export var particles_spread: float = 0.3
@export var particles_drag: float = 1.0
@export var particles_outward: float = 0.7
@export var particles_radius: float = 1.0
@export var particles_color: Color = Color(1.0, 1.0, 1.0, 0.8)

# ── Internal state ────────────────────────────────────────────────────────

var _hit_targets: Array = []
var _hitbox: Area2D = null
var _hitbox_collisions: Array[CollisionShape2D] = []
var _hitbox_count: int = 0
var _blade_collision: CollisionShape2D = null

var _debug_draw: bool = false
var _debug_circles: Array[Node2D] = []
var _blade_debug: Node2D = null

var _particles: CPUParticles2D = null

var _elapsed: float = 0.0
var _is_active: bool = true
var _mesh_instance: MeshInstance2D = null
var _shader_material: ShaderMaterial = null


# ══════════════════════════════════════════════════════════════════════════
#  VIRTUAL METHODS — override in subclasses
# ══════════════════════════════════════════════════════════════════════════

## Return the res:// path to the .gdshader for this effect.
func _get_shader_path() -> String:
	return ""


## Called at the end of base _ready() so subclasses can do extra init
## (e.g., store start position, force distance=0, etc.).
func _on_ready_hook() -> void:
	pass


## Return sweep_progress (0-1) and alpha (0-1) for this frame.
## Called from update_shader_uniforms().  Subclasses control how the sweep
## and fade behave differently.
func _compute_sweep_and_alpha() -> Dictionary:
	## Default: RadiantArc-style — sweep fills in 70% of duration, fade in/out.
	var base_sweep_duration: float = duration * 0.7
	var sweep_duration: float = base_sweep_duration / max(sweep_speed, 0.1)
	var sweep_progress: float = clamp(_elapsed / sweep_duration, 0.0, 1.0)

	var alpha: float = 1.0
	if _elapsed < fade_in:
		alpha = _elapsed / fade_in
	elif _elapsed > duration - fade_out:
		alpha = 1.0 - (_elapsed - (duration - fade_out)) / fade_out

	return {"sweep": sweep_progress, "alpha": alpha}


## Optional: override to add custom hitbox behaviour when sweep is done
## (e.g., enable all collisions). Return true to skip default per-bubble
## visibility logic.
func _on_sweep_completed_hitbox() -> bool:
	return false


## Optional: override to add full-arc emission after sweep completes.
## Return true to skip the default sweep-based particle emission.
func _on_sweep_completed_particles(_alpha: float) -> bool:
	return false


# ══════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Find or create MeshInstance2D
	_mesh_instance = null
	for child in get_children():
		if child is MeshInstance2D:
			_mesh_instance = child
			break
	for child in get_children():
		if child is Polygon2D:
			child.queue_free()

	if not _mesh_instance:
		_mesh_instance = MeshInstance2D.new()
		add_child(_mesh_instance)

	if not _mesh_instance.texture:
		_mesh_instance.texture = EffectUtils.get_white_pixel_texture()

	if not _mesh_instance.material:
		_shader_material = ShaderMaterial.new()
		var shader_path: String = _get_shader_path()
		if not shader_path.is_empty():
			_shader_material.shader = load(shader_path)
		_mesh_instance.material = _shader_material
	else:
		_shader_material = _mesh_instance.material

	_generate_arc_mesh()
	call_deferred("_create_hitbox")
	if particles_enabled:
		_create_particles()
	_update_shader_uniforms()

	_on_ready_hook()


# ══════════════════════════════════════════════════════════════════════════
#  SETUP / PUBLIC API
# ══════════════════════════════════════════════════════════════════════════

## Configure from a flat parameter dictionary.  Returns self for chaining.
func setup(params: Dictionary) -> ArcEffectBase:
	for key in params:
		if key in self:
			set(key, params[key])

	if is_node_ready():
		_generate_arc_mesh()
		_update_shader_uniforms()
		_recreate_particles()

	return self


func get_damage() -> float:
	return damage


func set_debug_draw(enabled: bool) -> void:
	_debug_draw = enabled
	if not enabled:
		for debug in _debug_circles:
			debug.visible = false
		if _blade_debug:
			_blade_debug.visible = false


# ══════════════════════════════════════════════════════════════════════════
#  MESH GENERATION
# ══════════════════════════════════════════════════════════════════════════

func _generate_arc_mesh() -> void:
	if not _mesh_instance:
		return

	var vertices: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()

	var arc_rad: float = deg_to_rad(arc_angle_deg)
	var segments: int = int(max(16, arc_angle_deg / 3.0))
	var inner_radius: float = radius

	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = -arc_rad * 0.5 + arc_rad * t

		var taper_profile: float = sin(t * PI)
		var adjusted_taper: float = pow(taper_profile, 1.0 - taper * 0.8)
		var actual_thickness: float = max(0.0, thickness * adjusted_taper)

		var current_outer_r: float = inner_radius + actual_thickness
		var current_inner_r: float = inner_radius

		var cos_a: float = cos(angle)
		var sin_a: float = sin(angle)
		var dir: Vector2 = Vector2(cos_a, sin_a)

		var p_in: Vector2 = dir * current_inner_r * length_scale + Vector2(distance, 0.0)
		var p_out: Vector2 = dir * current_outer_r * length_scale + Vector2(distance, 0.0)

		vertices.push_back(p_in)
		uvs.push_back(Vector2(t, 1.0))
		vertices.push_back(p_out)
		uvs.push_back(Vector2(t, 0.0))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs

	var am: ArrayMesh = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	_mesh_instance.mesh = am


# ══════════════════════════════════════════════════════════════════════════
#  HITBOX
# ══════════════════════════════════════════════════════════════════════════

func _create_hitbox() -> void:
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 4
	_hitbox.collision_mask = 8
	_hitbox.monitoring = true
	_hitbox.monitorable = true
	add_child(_hitbox)

	var arc_rad: float = deg_to_rad(arc_angle_deg)
	var mid_radius: float = (radius + thickness * 0.5) * length_scale
	var arc_length: float = arc_rad * mid_radius

	var collision_radius: float = thickness * 0.4 * length_scale
	var spacing: float = collision_radius * 1.5
	_hitbox_count = max(3, int(ceil(arc_length / spacing)) + 1)

	_hitbox_collisions.clear()

	for i in range(_hitbox_count):
		var collision: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = collision_radius
		collision.shape = circle
		collision.disabled = true
		_hitbox.add_child(collision)
		_hitbox_collisions.append(collision)

	var blade_thickness: float = thickness * 0.25 * length_scale
	var blade_length: float = (radius + thickness) * length_scale
	_blade_collision = CollisionShape2D.new()
	var capsule: CapsuleShape2D = CapsuleShape2D.new()
	capsule.radius = blade_thickness
	capsule.height = blade_length + blade_thickness * 2
	_blade_collision.shape = capsule
	_blade_collision.disabled = true
	_hitbox.add_child(_blade_collision)

	_hitbox.area_entered.connect(_on_hitbox_area_entered)


func _update_hitbox_position(sweep_progress: float) -> void:
	if _hitbox_collisions.is_empty():
		return

	var arc_rad: float = deg_to_rad(arc_angle_deg)
	var sweep_edge: float = sweep_progress * 1.8
	var tail_length: float = 0.5

	## Let subclass override all-visible behavior
	var skip_visibility: bool = _on_sweep_completed_hitbox()

	if _debug_draw and _debug_circles.size() < _hitbox_count:
		var base_rad: float = thickness * 0.4 * length_scale
		for i in range(_debug_circles.size(), _hitbox_count):
			var debug: Node2D = _create_debug_circle(Vector2.ZERO, base_rad)
			debug.visible = false
			_debug_circles.append(debug)

	for i in range(_hitbox_count):
		var collision: CollisionShape2D = _hitbox_collisions[i]
		var t: float = float(i) / float(_hitbox_count - 1) if _hitbox_count > 1 else 0.5

		var angle: float = -arc_rad * 0.5 + arc_rad * t

		var taper_profile: float = sin(t * PI)
		var adjusted_taper: float = pow(taper_profile, 1.0 - taper * 0.8)
		var current_thickness: float = thickness * adjusted_taper
		var current_mid_r: float = radius + current_thickness * 0.5

		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var pos: Vector2 = dir * current_mid_r * length_scale + Vector2(distance, 0.0)
		collision.position = pos

		if collision.shape is CircleShape2D:
			collision.shape.radius = max(current_thickness * 0.4 * length_scale, 2.0)

		if skip_visibility:
			collision.disabled = false
		else:
			var dist_from_edge: float = sweep_edge - t
			var part_visible: bool = (dist_from_edge >= 0.0) and (dist_from_edge <= tail_length) and (sweep_progress > 0.0)
			collision.disabled = not part_visible

		if _debug_draw and i < _debug_circles.size():
			var debug: Node2D = _debug_circles[i]
			debug.position = pos
			debug.visible = not collision.disabled
			if debug.get_child_count() > 0:
				var circle_vis: Node2D = debug.get_child(0)
				if circle_vis is DebugCircle:
					(circle_vis as DebugCircle).radius = collision.shape.radius
					circle_vis.queue_redraw()

	_update_blade_position(sweep_progress, sweep_edge, arc_rad)


func _update_blade_position(sweep_progress: float, sweep_edge: float, arc_rad: float) -> void:
	if not _blade_collision:
		return

	var leading_t: float = clamp(sweep_edge, 0.0, 1.0)
	var leading_angle: float = -arc_rad * 0.5 + arc_rad * leading_t
	var blade_visible: bool = (sweep_progress > 0.0) and (sweep_edge <= 1.0)

	var arc_center: Vector2 = Vector2(distance, 0.0)
	var blade_length: float = (radius + thickness) * length_scale
	var half_blade: float = blade_length * 0.5

	var dir: Vector2 = Vector2(cos(leading_angle), sin(leading_angle))
	var pos: Vector2 = arc_center + dir * half_blade

	_blade_collision.position = pos
	_blade_collision.rotation = leading_angle + PI / 2
	_blade_collision.disabled = not blade_visible

	if _debug_draw:
		if not _blade_debug:
			_blade_debug = _create_blade_debug()
		_blade_debug.position = pos
		_blade_debug.rotation = leading_angle + PI / 2
		_blade_debug.visible = blade_visible
		if _blade_debug.get_child_count() > 0:
			_blade_debug.get_child(0).queue_redraw()
	elif _blade_debug:
		_blade_debug.visible = false


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area in _hit_targets:
		return
	_hit_targets.append(area)
	if area.has_method("take_damage"):
		area.take_damage(damage, self)
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage, self)


# ══════════════════════════════════════════════════════════════════════════
#  PARTICLES
# ══════════════════════════════════════════════════════════════════════════

func _create_particles() -> void:
	_particles = CPUParticles2D.new()
	_particles.amount = particles_amount
	_particles.lifetime = particles_lifetime
	_particles.one_shot = false
	_particles.explosiveness = 0.0
	_particles.randomness = 1.0
	_particles.emitting = false

	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS
	_particles.emission_points = PackedVector2Array([Vector2(100, 0)])
	_particles.emission_normals = PackedVector2Array([Vector2(1, 0)])

	_particles.spread = 20.0 + particles_spread * 70.0
	_particles.initial_velocity_min = particles_speed * 0.5
	_particles.initial_velocity_max = particles_speed * 2.0

	var drag_multiplier: float = clamp(particles_drag, 0.0, 2.0)
	_particles.damping_min = 30.0 * drag_multiplier
	_particles.damping_max = 120.0 * drag_multiplier

	_particles.scale_amount_min = particles_size * 0.3
	_particles.scale_amount_max = particles_size * 1.2

	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.4, 0.6))
	scale_curve.add_point(Vector2(1.0, 0.0))
	_particles.scale_amount_curve = scale_curve

	_particles.angular_velocity_min = -180.0
	_particles.angular_velocity_max = 180.0
	_particles.gravity = Vector2.ZERO

	var color_ramp: Gradient = Gradient.new()
	var use_arc_colors: bool = particles_color == Color(1.0, 1.0, 1.0, 0.8) or particles_color.is_equal_approx(Color.WHITE)
	if use_arc_colors:
		color_ramp.set_color(0, Color(1.0, 1.0, 0.9, 1.0))
		color_ramp.add_point(0.15, Color(color_a.r, color_a.g, color_a.b, 1.0))
		color_ramp.add_point(0.5, Color(color_b.r, color_b.g, color_b.b, 0.7))
		color_ramp.set_color(1, Color(color_c.r * 0.5, color_c.g * 0.5, color_c.b * 0.5, 0.0))
	else:
		var bright: Color = Color(min(particles_color.r + 0.4, 1.0), min(particles_color.g + 0.4, 1.0), min(particles_color.b + 0.3, 1.0), 1.0)
		color_ramp.set_color(0, bright)
		color_ramp.add_point(0.2, particles_color)
		color_ramp.set_color(1, Color(particles_color.r * 0.3, particles_color.g * 0.3, particles_color.b * 0.3, 0.0))
	_particles.color_ramp = color_ramp

	_particles.texture = EffectUtils.get_white_pixel_texture()

	add_child(_particles)


func _update_particles(sweep_progress: float, alpha: float) -> void:
	if not _particles:
		return

	## Let subclass handle full-arc emission if sweep is complete
	if _on_sweep_completed_particles(alpha):
		return

	var arc_rad: float = deg_to_rad(arc_angle_deg)
	var sweep_edge: float = sweep_progress * 1.8
	var tail_length: float = 0.5

	var should_emit: bool = sweep_edge > 0.0 and sweep_edge <= 1.3
	_particles.emitting = should_emit
	_particles.modulate.a = alpha

	if not should_emit:
		_particles.emission_points = PackedVector2Array([Vector2(9999, 9999)])
		_particles.emission_normals = PackedVector2Array([Vector2(1, 0)])
		return

	var emission_points: PackedVector2Array = PackedVector2Array()
	var emission_normals: PackedVector2Array = PackedVector2Array()
	@warning_ignore("integer_division")
	var num_points: int = maxi(8, particles_amount / 2)

	for i in range(num_points):
		var t: float = randf()
		var dist_from_edge: float = sweep_edge - t
		var point_visible: bool = dist_from_edge >= 0.0 and dist_from_edge <= tail_length

		if not point_visible:
			continue

		var angle: float = -arc_rad * 0.5 + arc_rad * t
		var base_r: float = radius + thickness * clamp(particles_radius, 0.0, 1.0)
		var r_variation: float = thickness * 0.3 * (randf() * 2.0 - 1.0)
		var spawn_r: float = (base_r + r_variation) * length_scale
		spawn_r = clamp(spawn_r, radius * length_scale, (radius + thickness) * length_scale)

		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var pos: Vector2 = dir * spawn_r + Vector2(distance, 0.0)
		emission_points.append(pos)

		var tangent: Vector2 = Vector2(-sin(angle), cos(angle))
		var outward_ratio: float = clamp(particles_outward, 0.0, 1.0)
		var normal_vec: Vector2 = (dir * outward_ratio - tangent * (1.0 - outward_ratio)).normalized()
		emission_normals.append(normal_vec)

	if emission_points.is_empty():
		var t: float = clamp(sweep_edge - tail_length * 0.5, 0.0, 1.0)
		var angle: float = -arc_rad * 0.5 + arc_rad * t
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var spawn_r: float = (radius + thickness * particles_radius) * length_scale
		emission_points.append(dir * spawn_r + Vector2(distance, 0.0))
		emission_normals.append(dir)

	_particles.emission_points = emission_points
	_particles.emission_normals = emission_normals


func _recreate_particles() -> void:
	if _particles:
		_particles.queue_free()
		_particles = null
	if particles_enabled:
		_create_particles()


# ══════════════════════════════════════════════════════════════════════════
#  SHADER UNIFORMS
# ══════════════════════════════════════════════════════════════════════════

func _update_shader_uniforms() -> void:
	if not _shader_material:
		return

	var sweep_alpha: Dictionary = _compute_sweep_and_alpha()
	var sweep_progress: float = float(sweep_alpha.get("sweep", 0.0))
	var alpha: float = float(sweep_alpha.get("alpha", 1.0))
	var progress: float = clamp(_elapsed / max(duration, 0.001), 0.0, 1.0)

	_update_hitbox_position(sweep_progress)
	_update_particles(sweep_progress, alpha)

	_shader_material.set_shader_parameter("color_a", color_a)
	_shader_material.set_shader_parameter("color_b", color_b)
	_shader_material.set_shader_parameter("color_c", color_c)
	_shader_material.set_shader_parameter("glow_strength", glow_strength)
	_shader_material.set_shader_parameter("core_strength", core_strength)
	_shader_material.set_shader_parameter("noise_strength", noise_strength)
	_shader_material.set_shader_parameter("uv_scroll_speed", uv_scroll_speed)
	_shader_material.set_shader_parameter("progress", progress)
	_shader_material.set_shader_parameter("alpha", alpha)
	_shader_material.set_shader_parameter("sweep_progress", sweep_progress)
	_shader_material.set_shader_parameter("seed_offset", seed_offset)
	_shader_material.set_shader_parameter("chromatic_aberration", chromatic_aberration)
	_shader_material.set_shader_parameter("pulse_strength", pulse_strength)
	_shader_material.set_shader_parameter("pulse_speed", pulse_speed)
	_shader_material.set_shader_parameter("electric_strength", electric_strength)
	_shader_material.set_shader_parameter("electric_frequency", electric_frequency)
	_shader_material.set_shader_parameter("electric_speed", electric_speed)
	_shader_material.set_shader_parameter("gradient_offset", gradient_offset)


# ══════════════════════════════════════════════════════════════════════════
#  DEBUG HELPERS
# ══════════════════════════════════════════════════════════════════════════

func _create_blade_debug() -> Node2D:
	var debug_node: Node2D = Node2D.new()
	add_child(debug_node)

	var capsule_visual: DebugCapsule = DebugCapsule.new()
	if _blade_collision and _blade_collision.shape is CapsuleShape2D:
		var shape: CapsuleShape2D = _blade_collision.shape as CapsuleShape2D
		capsule_visual.capsule_radius = shape.radius
		capsule_visual.capsule_height = shape.height
	else:
		var blade_thickness: float = thickness * 0.25 * length_scale
		var blade_length: float = (radius + thickness) * length_scale
		capsule_visual.capsule_radius = blade_thickness
		capsule_visual.capsule_height = blade_length + blade_thickness * 2
	debug_node.add_child(capsule_visual)

	return debug_node


func _create_debug_circle(pos: Vector2, rad: float) -> Node2D:
	var debug_node: Node2D = Node2D.new()
	debug_node.position = pos
	add_child(debug_node)

	var circle_visual: DebugCircle = DebugCircle.new()
	circle_visual.radius = rad
	circle_visual.color = Color(0, 1, 0, 0.5)
	debug_node.add_child(circle_visual)

	return debug_node


## Emit particles along the full arc (utility for subclasses that need
## continuous full-arc emission after the initial sweep completes).
func _emit_particles_full_arc(alpha: float) -> void:
	if not _particles:
		return
	_particles.emitting = true
	_particles.modulate.a = alpha

	var arc_rad: float = deg_to_rad(arc_angle_deg)
	var full_points: PackedVector2Array = PackedVector2Array()
	var full_normals: PackedVector2Array = PackedVector2Array()
	@warning_ignore("integer_division")
	var full_count: int = maxi(8, particles_amount / 2)

	for i in range(full_count):
		var t: float = randf()
		var angle: float = -arc_rad * 0.5 + arc_rad * t

		var base_r: float = radius + thickness * clamp(particles_radius, 0.0, 1.0)
		var r_variation: float = thickness * 0.3 * (randf() * 2.0 - 1.0)
		var spawn_r: float = (base_r + r_variation) * length_scale
		spawn_r = clamp(spawn_r, radius * length_scale, (radius + thickness) * length_scale)

		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var pos: Vector2 = dir * spawn_r + Vector2(distance, 0.0)
		full_points.append(pos)

		var tangent: Vector2 = Vector2(-sin(angle), cos(angle))
		var outward_ratio: float = clamp(particles_outward, 0.0, 1.0)
		var normal_vec: Vector2 = (dir * outward_ratio - tangent * (1.0 - outward_ratio)).normalized()
		full_normals.append(normal_vec)

	if full_points.is_empty():
		full_points.append(Vector2(distance + radius * length_scale, 0.0))
		full_normals.append(Vector2(1, 0))

	_particles.emission_points = full_points
	_particles.emission_normals = full_normals
