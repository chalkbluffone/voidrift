extends Node2D
class_name SnarkyComeback

## Snarky Comeback - A radiant arc that behaves like a boomerang projectile.
## Looks identical to RadiantArc (same shader, mesh, particles, hitbox) but
## flies outward toward a target, spinning continuously, then reverses and
## returns to the player. Deals damage on both outward and return passes.


## Simple debug circle drawer
class DebugCircle extends Node2D:
	var radius: float = 10.0
	var color: Color = Color(0, 1, 0, 0.5)

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color, 2.0)
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, color.a * 0.3))


# ── Radiant Arc Visual Exports (identical to RadiantArc) ──────────────────

# Shape
@export var arc_angle_deg: float = 200.0
@export var radius: float = 42.0
@export var thickness: float = 18.0
@export var taper: float = 0.5
@export var length_scale: float = 0.75
@export var distance: float = 25.0

# Timing / animation
@export var duration: float = 5.0  # Max lifetime safety net
@export var fade_in: float = 0.08
@export var fade_out: float = 0.30
@export var sweep_speed: float = 1.2

# Color and glow
@export var color_a: Color = Color(0.0, 1.0, 1.0, 1.0)
@export var color_b: Color = Color(1.0, 0.0, 1.0, 1.0)
@export var color_c: Color = Color(0.0, 0.5, 1.0, 1.0)
@export var glow_strength: float = 3.0
@export var core_strength: float = 1.2
@export var noise_strength: float = 0.3
@export var uv_scroll_speed: float = 3.0

# Visual effects
@export var chromatic_aberration: float = 0.0
@export var pulse_strength: float = 0.0
@export var pulse_speed: float = 8.0
@export var electric_strength: float = 0.0
@export var electric_frequency: float = 20.0
@export var electric_speed: float = 15.0
@export var gradient_offset: float = 0.0

# Control
@export var rotation_offset_deg: float = 0.0
@export var seed_offset: float = 0.0
@export var damage: float = 10.0

# Particles
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

# ── Boomerang Motion Exports ─────────────────────────────────────────────

@export var projectile_speed: float = 400.0  ## Travel speed (pixels/sec)
@export var max_range: float = 500.0         ## Distance before reversing (base, scaled by size)
@export var spin_speed: float = 1.0          ## Full rotations per second
@export var return_radius: float = 30.0      ## How close to player before self-destruct
@export var size_mult: float = 1.0           ## Multiplier from size stat — scales max_range

# ── Internal State ────────────────────────────────────────────────────────

# Boomerang motion
var _direction: Vector2 = Vector2.RIGHT
var _returning: bool = false
var _source: Node2D = null
var _distance_traveled: float = 0.0
var _hit_targets: Array = []
var _spin_angle: float = 0.0  # Accumulated spin rotation
var _return_time: float = 0.0  # Time spent returning (for linear acceleration)

# Visuals
var _mesh_instance: MeshInstance2D = null
var _shader_material: ShaderMaterial = null
var _particles: CPUParticles2D = null

# Hitbox
var _hitbox: Area2D = null
var _hitbox_collisions: Array[CollisionShape2D] = []
var _hitbox_count: int = 0
var _blade_collision: CollisionShape2D = null

# Debug
var _debug_draw: bool = false
var _debug_circles: Array[Node2D] = []
var _blade_debug: Node2D = null

# Timing
var _elapsed: float = 0.0
var _is_active: bool = true
var _sweep_completed: bool = false  # Whether initial sweep animation finished


# ══════════════════════════════════════════════════════════════════════════
#  SETUP
# ══════════════════════════════════════════════════════════════════════════

func setup(params: Dictionary) -> SnarkyComeback:
	"""Configure from a flat parameter dictionary (from weapon_component flatten)."""
	for key in params:
		if key in self:
			set(key, params[key])

	if is_node_ready():
		_generate_arc_mesh()
		_update_shader_uniforms()
		_recreate_particles()

	return self


func set_direction(direction: Vector2) -> void:
	_direction = direction.normalized()


func set_source(source: Node2D) -> void:
	_source = source


func spawn_from(spawn_pos: Vector2, direction: Vector2) -> void:
	global_position = spawn_pos
	_direction = direction.normalized()
	# Initial visual rotation aligns mesh "forward" with travel direction
	_spin_angle = _direction.angle()


# ══════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Force distance to 0 so the arc is centered on the node origin.
	# This prevents bobbing when spinning — the node moves in a straight line
	# and the mesh orbits around its own center rather than an offset point.
	distance = 0.0

	# Create MeshInstance2D
	_mesh_instance = MeshInstance2D.new()
	add_child(_mesh_instance)

	# White pixel texture for UVs
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_mesh_instance.texture = ImageTexture.create_from_image(img)

	# Shader material — local copy with full_visible uniform for boomerang mode
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = load("res://effects/snarky_comeback/snarky_comeback.gdshader")
	_mesh_instance.material = _shader_material

	_generate_arc_mesh()
	call_deferred("_create_hitbox")
	if particles_enabled:
		_create_particles()
	_update_shader_uniforms()


func _process(delta: float) -> void:
	if not _is_active:
		return

	_elapsed += delta

	# Safety timeout — generous 10s
	if _elapsed >= 10.0:
		_is_active = false
		queue_free()
		return

	# ── Boomerang movement ────────────────────────────────────────────
	# Animation feel: fast launch, subtle brake only in last 20% before apex,
	# brief hang, then snappy ease-in return (like a whip crack coming back).
	if not _returning:
		# Outward pass — full speed with a late braking zone near apex
		var total_range: float = max_range * size_mult
		var progress: float = clampf(_distance_traveled / total_range, 0.0, 1.0)
		var speed_mult: float = 1.6
		if progress > 0.8:
			# Last 20%: smooth brake from 1.6 down to 0.3 (ease-out curve)
			var brake_t: float = (progress - 0.8) / 0.2  # 0→1 over last 20%
			speed_mult = lerpf(1.6, 0.3, brake_t * brake_t)
		var move_amount: float = projectile_speed * speed_mult * delta
		global_position += _direction * move_amount
		_distance_traveled += move_amount

		if _distance_traveled >= total_range:
			_returning = true
			_return_time = 0.0
			_hit_targets.clear()  # Allow re-hitting on return
	else:
		# Return pass — snappy ease-in: brief hang then whip back
		_return_time += delta
		# Ramps from 0.3x → 1.6x over ~0.6s (smoothstep ease-in), then
		# continues a gentle linear climb past 1.6x so it always catches up
		var t: float = _return_time
		var ramp_duration: float = 0.6
		var return_mult: float
		if t < ramp_duration:
			# Ease-in from 0.3 to 1.6 using smoothstep-style curve
			var nt: float = t / ramp_duration  # normalized 0→1
			var eased: float = nt * nt * (3.0 - 2.0 * nt)  # smoothstep
			return_mult = lerpf(0.3, 1.6, eased)
		else:
			# Past the ramp: gentle linear growth so it can't be outrun
			return_mult = 1.6 + (t - ramp_duration) * 0.3
		var return_speed: float = projectile_speed * return_mult
		if _source and is_instance_valid(_source):
			_direction = ((_source.global_position) - global_position).normalized()
		var move_amount: float = return_speed * delta
		global_position += _direction * move_amount

		# Check arrival
		if _source and is_instance_valid(_source):
			var dist_to_source: float = global_position.distance_to(_source.global_position)
			if dist_to_source <= return_radius:
				_is_active = false
				queue_free()
				return
		else:
			# Source gone — just self-destruct
			_is_active = false
			queue_free()
			return

	# ── Spin ──────────────────────────────────────────────────────────
	_spin_angle += spin_speed * TAU * delta
	rotation = _spin_angle

	# ── Shader uniforms ───────────────────────────────────────────────
	_update_shader_uniforms()


# ══════════════════════════════════════════════════════════════════════════
#  MESH GENERATION  (identical to RadiantArc)
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
		var actual_thickness: float = thickness * adjusted_taper
		actual_thickness = max(0.0, actual_thickness)

		var current_outer_r: float = inner_radius + actual_thickness
		var current_inner_r: float = inner_radius

		var cos_a: float = cos(angle)
		var sin_a: float = sin(angle)
		var dir: Vector2 = Vector2(cos_a, sin_a)

		# Inner vertex (V=1.0)
		var p_in: Vector2 = dir * current_inner_r * length_scale + Vector2(distance, 0.0)
		# Outer vertex (V=0.0)
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
#  SHADER UNIFORMS
# ══════════════════════════════════════════════════════════════════════════

func _update_shader_uniforms() -> void:
	if not _shader_material:
		return

	# Progress — for a boomerang we keep the arc fully "alive" the whole time.
	# Use a short initial sweep, then hold at 1.0.
	var sweep_duration: float = 0.4 / max(sweep_speed, 0.1)
	var sweep_progress: float = clamp(_elapsed / sweep_duration, 0.0, 1.0)
	if sweep_progress >= 1.0:
		_sweep_completed = true

	# If sweep completed, enable full_visible so the entire arc stays rendered
	if _sweep_completed:
		sweep_progress = 1.0
		_shader_material.set_shader_parameter("full_visible", 1.0)

	var progress: float = clamp(_elapsed / max(duration, 0.001), 0.0, 1.0)

	# Alpha: fade in quickly, hold, fade out when returning and close to source
	var alpha: float = 1.0
	if _elapsed < fade_in:
		alpha = _elapsed / fade_in
	elif _returning and _source and is_instance_valid(_source):
		var dist_to_source: float = global_position.distance_to(_source.global_position)
		if dist_to_source < return_radius * 3.0:
			alpha = clamp(dist_to_source / (return_radius * 3.0), 0.0, 1.0)

	# Update hitbox positions
	_update_hitbox_position(sweep_progress)
	# Update particles
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
#  HITBOX
# ══════════════════════════════════════════════════════════════════════════

func _create_hitbox() -> void:
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 4  # Player weapons layer
	_hitbox.collision_mask = 8   # Enemies layer
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

	# Blade capsule
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

	# Once sweep is complete, enable all collisions (whole arc is visible)
	var all_visible: bool = _sweep_completed

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

		if all_visible:
			collision.disabled = false
		else:
			var dist_from_edge: float = sweep_edge - t
			var part_visible: bool = (dist_from_edge >= 0.0) and (dist_from_edge <= tail_length) and (sweep_progress > 0.0)
			collision.disabled = not part_visible

	_update_blade_position(sweep_progress, sweep_edge, arc_rad)


func _update_blade_position(sweep_progress: float, sweep_edge: float, arc_rad: float) -> void:
	if not _blade_collision:
		return

	if _sweep_completed:
		# Keep blade disabled once sweep is done — bubbles cover the full arc
		_blade_collision.disabled = true
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


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area in _hit_targets:
		return

	_hit_targets.append(area)

	if area.has_method("take_damage"):
		area.take_damage(damage, self)
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage, self)


func get_damage() -> float:
	return damage


# ══════════════════════════════════════════════════════════════════════════
#  PARTICLES  (identical to RadiantArc)
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

	var pixel_img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	pixel_img.fill(Color.WHITE)
	_particles.texture = ImageTexture.create_from_image(pixel_img)

	add_child(_particles)


func _update_particles(sweep_progress: float, alpha: float) -> void:
	if not _particles:
		return

	var arc_rad: float = deg_to_rad(arc_angle_deg)

	if _sweep_completed:
		# After initial sweep, emit along the full arc continuously
		_particles.emitting = true
		_particles.modulate.a = alpha

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
			var normal: Vector2 = (dir * outward_ratio - tangent * (1.0 - outward_ratio)).normalized()
			full_normals.append(normal)

		if full_points.is_empty():
			full_points.append(Vector2(distance + radius * length_scale, 0.0))
			full_normals.append(Vector2(1, 0))

		_particles.emission_points = full_points
		_particles.emission_normals = full_normals
		return

	# During initial sweep — same logic as RadiantArc
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
		var normal: Vector2 = (dir * outward_ratio - tangent * (1.0 - outward_ratio)).normalized()
		emission_normals.append(normal)

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
#  DEBUG
# ══════════════════════════════════════════════════════════════════════════

## Debug capsule drawer for blade
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


func set_debug_draw(enabled: bool) -> void:
	_debug_draw = enabled
	if not enabled:
		for debug in _debug_circles:
			debug.visible = false
		if _blade_debug:
			_blade_debug.visible = false
