extends Node2D
class_name SpaceNapalm

## Space Napalm — A volatile incendiary orb that flies to a target position,
## detonates on impact with an explosion burst, then leaves a spreading puddle
## of fire that deals damage over time. Two-phase weapon: projectile → AoE.


# ── Projectile Visual Exports ─────────────────────────────────────────────

@export var proj_color_core: Color = Color(1.0, 1.0, 0.9, 1.0)
@export var proj_color_mid: Color = Color(1.0, 0.6, 0.1, 1.0)
@export var proj_color_edge: Color = Color(0.8, 0.15, 0.0, 1.0)
@export var proj_glow_strength: float = 4.0
@export var proj_morph_speed: float = 3.0
@export var proj_morph_intensity: float = 0.25
@export var proj_size: float = 12.0  ## Radius of the projectile blob in pixels
@export var proj_tail_length: float = 0.35

# ── Fire AoE Visual Exports ──────────────────────────────────────────────

@export var fire_color_core: Color = Color(1.0, 0.95, 0.5, 1.0)
@export var fire_color_mid: Color = Color(1.0, 0.45, 0.05, 1.0)
@export var fire_color_outer: Color = Color(0.6, 0.08, 0.0, 1.0)
@export var fire_color_smoke: Color = Color(0.15, 0.1, 0.08, 0.6)
@export var fire_glow_strength: float = 4.5
@export var fire_flame_speed: float = 3.0
@export var fire_flame_turbulence: float = 0.6

# ── Stats Exports ─────────────────────────────────────────────────────────

@export var damage: float = 12.0        ## Impact damage
@export var burn_damage: float = 5.0    ## Damage per DoT tick
@export var projectile_speed: float = 350.0
@export var aoe_radius: float = 80.0    ## Final fire puddle radius
@export var spread_time: float = 0.8    ## Time to expand from 20% to full radius
@export var burn_duration: float = 3.5  ## How long the fire burns
@export var dot_interval: float = 0.5   ## Seconds between damage ticks
@export var fade_out: float = 0.5       ## Fade-out duration at end of burn
@export var fade_in: float = 0.08
@export var cooldown: float = 1.5
@export var duration: float = 10.0      ## Safety net max lifetime
@export var seed_offset: float = 0.0
@export var size_mult: float = 1.0      ## From size stat — scales aoe_radius

# ── Internal State ────────────────────────────────────────────────────────

enum Phase { PROJECTILE, IMPACT, BURNING, FADEOUT, DONE }

var _phase: int = Phase.PROJECTILE
var _direction: Vector2 = Vector2.RIGHT
var _source: Node2D = null
var _target_pos: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _phase_time: float = 0.0  ## Time within current phase
var _dot_timer: float = 0.0
var _is_active: bool = true


# Projectile visuals
var _proj_mesh: MeshInstance2D = null
var _proj_material: ShaderMaterial = null
var _trail_particles: CPUParticles2D = null

# Fire AoE visuals
var _fire_mesh: MeshInstance2D = null
var _fire_material: ShaderMaterial = null
var _flame_particles: CPUParticles2D = null
var _ember_particles: CPUParticles2D = null
var _smoke_particles: CPUParticles2D = null

# Impact burst
var _burst_particles: CPUParticles2D = null

# Hitboxes
var _proj_hitbox: Area2D = null
var _aoe_hitbox: Area2D = null
var _aoe_collision: CollisionShape2D = null


# ══════════════════════════════════════════════════════════════════════════
#  SETUP
# ══════════════════════════════════════════════════════════════════════════

func setup(params: Dictionary) -> SpaceNapalm:
	"""Configure from a flat parameter dictionary (from weapon_component flatten)."""
	for key in params:
		if key in self:
			set(key, params[key])
	return self


func set_source(source: Node2D) -> void:
	_source = source


func set_target(target_pos: Vector2) -> void:
	_target_pos = target_pos


func spawn_from(spawn_pos: Vector2, direction: Vector2) -> void:
	global_position = spawn_pos
	_direction = direction.normalized()


# ══════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	seed_offset = randf() * 100.0

	# Create projectile visuals
	_create_projectile_mesh()
	_create_trail_particles()
	_create_proj_hitbox()  # Immediate — must exist before first _process

	# Pre-create fire visuals (hidden until impact)
	_create_fire_mesh()
	_create_flame_particles()
	_create_ember_particles()
	_create_smoke_particles()
	_create_burst_particles()
	_create_aoe_hitbox()  # Immediate — monitoring starts disabled anyway

	# Hide fire elements initially
	_fire_mesh.visible = false
	_flame_particles.emitting = false
	_ember_particles.emitting = false
	_smoke_particles.emitting = false
	_burst_particles.emitting = false


func _process(delta: float) -> void:
	if not _is_active:
		return

	_elapsed += delta
	_phase_time += delta

	# Safety timeout
	if _elapsed >= duration:
		_cleanup()
		return

	match _phase:
		Phase.PROJECTILE:
			_process_projectile(delta)
		Phase.IMPACT:
			_process_impact(delta)
		Phase.BURNING:
			_process_burning(delta)
		Phase.FADEOUT:
			_process_fadeout(delta)
		Phase.DONE:
			_cleanup()


# ══════════════════════════════════════════════════════════════════════════
#  PHASE: PROJECTILE FLIGHT
# ══════════════════════════════════════════════════════════════════════════

func _process_projectile(delta: float) -> void:
	# Move toward target
	var move_amount: float = projectile_speed * delta
	global_position += _direction * move_amount

	# Check if we've reached the target position
	var dist_to_target: float = global_position.distance_to(_target_pos)
	if dist_to_target <= move_amount * 2.0:
		_begin_impact()
		return

	# Detonate on first enemy contact (distance check — reliable at any speed)
	var hit_radius: float = proj_size * 2.0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if global_position.distance_to(enemy.global_position) <= hit_radius:
			_target_pos = global_position
			_begin_impact()
			return

	# Safety: if we've traveled further than 2x the original distance, detonate
	if _phase_time > 5.0:
		_begin_impact()
		return

	# Update projectile shader
	_update_proj_shader()

	# Rotate projectile to face travel direction
	_proj_mesh.rotation = _direction.angle()


func _begin_impact() -> void:
	_phase = Phase.IMPACT
	_phase_time = 0.0

	# Snap to target position
	global_position = _target_pos

	# Hide projectile
	_proj_mesh.visible = false
	_trail_particles.emitting = false
	if _proj_hitbox:
		_proj_hitbox.monitoring = false

	# Trigger explosion burst
	_burst_particles.global_position = global_position
	_burst_particles.emitting = true

	# Show fire
	_fire_mesh.visible = true

	# Enable AoE hitbox immediately so physics can start detecting overlaps
	if _aoe_hitbox:
		_aoe_hitbox.monitoring = true
		_update_aoe_radius(aoe_radius * size_mult * 0.5)  # Start at 50% for impact

	# Deal impact damage to anything at the blast site
	_deal_impact_damage()


# ══════════════════════════════════════════════════════════════════════════
#  PHASE: IMPACT (brief explosion flash, ~0.15s)
# ══════════════════════════════════════════════════════════════════════════

func _process_impact(_delta: float) -> void:
	# Brief flash — transition to burning after burst settles
	var effective_radius: float = aoe_radius * size_mult
	var spread_frac: float = clampf(_phase_time / 0.15, 0.0, 0.3)  # Start at 20-30%

	# Update fire shader with initial small radius
	_update_fire_shader(spread_frac, 1.0)

	# Update AoE hitbox to match current spread
	_update_aoe_radius(effective_radius * spread_frac)

	if _phase_time >= 0.15:
		_phase = Phase.BURNING
		_phase_time = 0.0
		_dot_timer = -0.15  # Small delay so physics has time to detect overlaps

		# Start fire particles
		_flame_particles.emitting = true
		_ember_particles.emitting = true
		_smoke_particles.emitting = true

		# Second burst for dramatic "aftershock" as fire spreads
		_burst_particles.emitting = false  # Reset
		_burst_particles.amount = 50
		_burst_particles.lifetime = 0.35
		_burst_particles.initial_velocity_min = 40.0
		_burst_particles.initial_velocity_max = 150.0
		_burst_particles.emitting = true

		# AoE hitbox already enabled from _begin_impact


# ══════════════════════════════════════════════════════════════════════════
#  PHASE: BURNING (spreading fire + DoT)
# ══════════════════════════════════════════════════════════════════════════

func _process_burning(delta: float) -> void:
	var effective_radius: float = aoe_radius * size_mult

	# Spreading: expand from ~20% to 100% over spread_time (ease-out)
	var spread_t: float = clampf(_phase_time / spread_time, 0.0, 1.0)
	var eased_spread: float = 1.0 - (1.0 - spread_t) * (1.0 - spread_t)  # Quadratic ease-out
	var current_radius_frac: float = lerpf(0.2, 1.0, eased_spread)

	# Update fire visuals
	_update_fire_shader(current_radius_frac, 1.0)
	_update_aoe_radius(effective_radius * current_radius_frac)

	# Update particle emission radius to match spread
	var current_pixel_radius: float = effective_radius * current_radius_frac
	_update_particle_emission_radius(current_pixel_radius)

	# DoT ticks
	_dot_timer += delta
	if _dot_timer >= dot_interval:
		_dot_timer -= dot_interval
		_deal_aoe_damage()

	# Transition to fadeout
	if _phase_time >= burn_duration:
		_phase = Phase.FADEOUT
		_phase_time = 0.0


# ══════════════════════════════════════════════════════════════════════════
#  PHASE: FADEOUT
# ══════════════════════════════════════════════════════════════════════════

func _process_fadeout(_delta: float) -> void:
	var t: float = clampf(_phase_time / fade_out, 0.0, 1.0)
	var burn_intensity: float = 1.0 - t

	_update_fire_shader(1.0, burn_intensity)

	# Stop emitting new particles, let existing ones finish
	_flame_particles.emitting = false
	_ember_particles.emitting = false
	_smoke_particles.emitting = false

	# Disable hitbox during fadeout
	if _aoe_hitbox:
		_aoe_hitbox.monitoring = false

	if t >= 1.0:
		_phase = Phase.DONE
		_cleanup()


func _cleanup() -> void:
	_is_active = false
	queue_free()


# ══════════════════════════════════════════════════════════════════════════
#  DAMAGE
# ══════════════════════════════════════════════════════════════════════════

func _deal_impact_damage() -> void:
	"""Deal impact damage to enemies near the detonation point."""
	# Distance-based check — generous radius for the initial blast
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var effective_radius: float = aoe_radius * size_mult * 0.7
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= effective_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)


func _deal_aoe_damage() -> void:
	"""Deal DoT damage to all enemies currently inside the fire zone."""
	if not _aoe_hitbox or not _aoe_hitbox.monitoring:
		return

	var effective_radius: float = aoe_radius * size_mult
	var damaged: Array = []

	# Primary: Area2D overlap — detects enemy HitboxArea children (proven pattern)
	var areas: Array = _aoe_hitbox.get_overlapping_areas()
	for area in areas:
		var parent_node: Node = area.get_parent()
		if parent_node and parent_node.is_in_group("enemies") and parent_node.has_method("take_damage") and not damaged.has(parent_node):
			parent_node.take_damage(burn_damage)
			damaged.append(parent_node)

	# Fallback: distance-based group check (catches anything the area overlap missed)
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if damaged.has(enemy):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= effective_radius and enemy.has_method("take_damage"):
			enemy.take_damage(burn_damage)
			damaged.append(enemy)


# ══════════════════════════════════════════════════════════════════════════
#  PROJECTILE MESH (amorphous fire blob)
# ══════════════════════════════════════════════════════════════════════════

func _create_projectile_mesh() -> void:
	_proj_mesh = MeshInstance2D.new()
	add_child(_proj_mesh)

	# Quad mesh sized to proj_size
	var mesh: QuadMesh = QuadMesh.new()
	var s: float = proj_size * 3.0  # Extra space for tail + glow
	mesh.size = Vector2(s, s)
	_proj_mesh.mesh = mesh

	# White texture for shader
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_proj_mesh.texture = ImageTexture.create_from_image(img)

	# Shader material
	_proj_material = ShaderMaterial.new()
	_proj_material.shader = load("res://effects/space_napalm/space_napalm_projectile.gdshader")
	_proj_mesh.material = _proj_material

	_update_proj_shader()


func _update_proj_shader() -> void:
	if not _proj_material:
		return
	_proj_material.set_shader_parameter("color_core", proj_color_core)
	_proj_material.set_shader_parameter("color_mid", proj_color_mid)
	_proj_material.set_shader_parameter("color_edge", proj_color_edge)
	_proj_material.set_shader_parameter("glow_strength", proj_glow_strength)
	_proj_material.set_shader_parameter("morph_speed", proj_morph_speed)
	_proj_material.set_shader_parameter("morph_intensity", proj_morph_intensity)
	_proj_material.set_shader_parameter("seed_offset", seed_offset)
	_proj_material.set_shader_parameter("alpha", 1.0)
	_proj_material.set_shader_parameter("progress", _elapsed)
	_proj_material.set_shader_parameter("tail_length", proj_tail_length)


# ══════════════════════════════════════════════════════════════════════════
#  FIRE MESH (circular puddle)
# ══════════════════════════════════════════════════════════════════════════

func _create_fire_mesh() -> void:
	_fire_mesh = MeshInstance2D.new()
	add_child(_fire_mesh)

	# Disc mesh — large enough to cover the full AoE radius
	_regenerate_fire_disc()

	# White texture for shader
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_fire_mesh.texture = ImageTexture.create_from_image(img)

	# Shader material
	_fire_material = ShaderMaterial.new()
	_fire_material.shader = load("res://effects/space_napalm/space_napalm_fire.gdshader")
	_fire_mesh.material = _fire_material


func _regenerate_fire_disc() -> void:
	"""Generate a disc mesh matching the full AoE radius for the fire shader."""
	var effective_radius: float = aoe_radius * size_mult
	var segments: int = 48
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	var verts: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	# Center vertex
	verts.append(Vector2.ZERO)
	uvs.append(Vector2(0.5, 0.5))

	# Ring vertices
	for i in range(segments + 1):
		var angle: float = (float(i) / float(segments)) * TAU
		var pos: Vector2 = Vector2(cos(angle), sin(angle)) * effective_radius
		verts.append(pos)
		uvs.append(Vector2(0.5 + cos(angle) * 0.5, 0.5 + sin(angle) * 0.5))

	# Triangles (fan from center)
	for i in range(segments):
		indices.append(0)
		indices.append(i + 1)
		indices.append(i + 2)

	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var arr_mesh: ArrayMesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_fire_mesh.mesh = arr_mesh


func _update_fire_shader(radius_frac: float, burn_intensity: float) -> void:
	if not _fire_material:
		return
	_fire_material.set_shader_parameter("color_core", fire_color_core)
	_fire_material.set_shader_parameter("color_mid", fire_color_mid)
	_fire_material.set_shader_parameter("color_outer", fire_color_outer)
	_fire_material.set_shader_parameter("color_smoke", fire_color_smoke)
	_fire_material.set_shader_parameter("glow_strength", fire_glow_strength)
	_fire_material.set_shader_parameter("flame_speed", fire_flame_speed)
	_fire_material.set_shader_parameter("flame_turbulence", fire_flame_turbulence)
	_fire_material.set_shader_parameter("seed_offset", seed_offset)
	_fire_material.set_shader_parameter("alpha", 1.0)
	_fire_material.set_shader_parameter("progress", _elapsed)
	_fire_material.set_shader_parameter("radius_progress", radius_frac)
	_fire_material.set_shader_parameter("burn_intensity", burn_intensity)


# ══════════════════════════════════════════════════════════════════════════
#  TRAIL PARTICLES (comet tail behind projectile)
# ══════════════════════════════════════════════════════════════════════════

func _create_trail_particles() -> void:
	_trail_particles = CPUParticles2D.new()
	add_child(_trail_particles)

	_trail_particles.emitting = true
	_trail_particles.amount = 35
	_trail_particles.lifetime = 0.35
	_trail_particles.one_shot = false
	_trail_particles.explosiveness = 0.0
	_trail_particles.local_coords = false

	# Emission
	_trail_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_trail_particles.emission_sphere_radius = proj_size * 0.3

	# Motion — particles lag behind the projectile
	_trail_particles.direction = Vector2(-1, 0)  # Backward
	_trail_particles.spread = 25.0
	_trail_particles.initial_velocity_min = 40.0
	_trail_particles.initial_velocity_max = 80.0
	_trail_particles.gravity = Vector2.ZERO
	_trail_particles.damping_min = 30.0
	_trail_particles.damping_max = 50.0

	# Scale: start normal, shrink away
	_trail_particles.scale_amount_min = 2.5
	_trail_particles.scale_amount_max = 4.0
	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.4, 0.7))
	scale_curve.add_point(Vector2(1.0, 0.0))
	_trail_particles.scale_amount_curve = scale_curve

	# Color ramp: bright yellow → orange → red → transparent
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.5, 1.0))
	gradient.add_point(0.25, Color(1.0, 0.6, 0.1, 0.9))
	gradient.add_point(0.6, Color(0.9, 0.2, 0.0, 0.6))
	gradient.set_color(1, Color(0.3, 0.05, 0.0, 0.0))
	_trail_particles.color_ramp = gradient


# ══════════════════════════════════════════════════════════════════════════
#  BURST PARTICLES (explosion on impact)
# ══════════════════════════════════════════════════════════════════════════

func _create_burst_particles() -> void:
	_burst_particles = CPUParticles2D.new()
	add_child(_burst_particles)

	_burst_particles.emitting = false
	_burst_particles.amount = 80
	_burst_particles.lifetime = 0.5
	_burst_particles.one_shot = true
	_burst_particles.explosiveness = 0.95
	_burst_particles.local_coords = false

	# Radial burst
	_burst_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_burst_particles.emission_sphere_radius = 8.0
	_burst_particles.direction = Vector2(0, 0)
	_burst_particles.spread = 180.0
	_burst_particles.initial_velocity_min = 80.0
	_burst_particles.initial_velocity_max = 250.0
	_burst_particles.gravity = Vector2.ZERO
	_burst_particles.damping_min = 60.0
	_burst_particles.damping_max = 150.0

	# Scale — big billowing burst
	_burst_particles.scale_amount_min = 4.0
	_burst_particles.scale_amount_max = 8.0
	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5))
	scale_curve.add_point(Vector2(0.15, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.0))
	_burst_particles.scale_amount_curve = scale_curve

	# Color: white flash → bright orange → deep red → dark smoke → gone
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	gradient.add_point(0.1, Color(1.0, 0.7, 0.15, 1.0))
	gradient.add_point(0.3, Color(0.95, 0.4, 0.02, 0.9))
	gradient.add_point(0.55, Color(0.6, 0.12, 0.0, 0.7))
	gradient.add_point(0.8, Color(0.15, 0.06, 0.02, 0.4))
	gradient.set_color(1, Color(0.05, 0.02, 0.01, 0.0))
	_burst_particles.color_ramp = gradient


# ══════════════════════════════════════════════════════════════════════════
#  FLAME PARTICLES (rising flames from fire zone)
# ══════════════════════════════════════════════════════════════════════════

func _create_flame_particles() -> void:
	_flame_particles = CPUParticles2D.new()
	add_child(_flame_particles)

	_flame_particles.emitting = false
	_flame_particles.amount = 70
	_flame_particles.lifetime = 0.8
	_flame_particles.one_shot = false
	_flame_particles.explosiveness = 0.0
	_flame_particles.local_coords = false

	# Emit from ring matching AoE area
	_flame_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_flame_particles.emission_sphere_radius = aoe_radius * size_mult * 0.5

	# Slight upward drift (heat rise)
	_flame_particles.direction = Vector2(0, -1)
	_flame_particles.spread = 40.0
	_flame_particles.initial_velocity_min = 20.0
	_flame_particles.initial_velocity_max = 50.0
	_flame_particles.gravity = Vector2(0, -25)  # Upward for heat
	_flame_particles.damping_min = 8.0
	_flame_particles.damping_max = 20.0
	_flame_particles.angular_velocity_min = -120.0
	_flame_particles.angular_velocity_max = 120.0

	# Scale: grow then shrink — bigger billowy flames
	_flame_particles.scale_amount_min = 5.0
	_flame_particles.scale_amount_max = 9.0
	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.25, 1.0))
	scale_curve.add_point(Vector2(0.7, 0.6))
	scale_curve.add_point(Vector2(1.0, 0.0))
	_flame_particles.scale_amount_curve = scale_curve

	# Color: yellow → deep orange → red → dark smoke → gone
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.85, 0.2, 0.95))
	gradient.add_point(0.2, Color(1.0, 0.5, 0.05, 0.9))
	gradient.add_point(0.45, Color(0.85, 0.2, 0.0, 0.7))
	gradient.add_point(0.7, Color(0.3, 0.08, 0.02, 0.4))
	gradient.set_color(1, Color(0.08, 0.04, 0.02, 0.0))
	_flame_particles.color_ramp = gradient


# ══════════════════════════════════════════════════════════════════════════
#  EMBER PARTICLES (bright sparks popping from fire)
# ══════════════════════════════════════════════════════════════════════════

func _create_ember_particles() -> void:
	_ember_particles = CPUParticles2D.new()
	add_child(_ember_particles)

	_ember_particles.emitting = false
	_ember_particles.amount = 35
	_ember_particles.lifetime = 0.6
	_ember_particles.one_shot = false
	_ember_particles.explosiveness = 0.0
	_ember_particles.local_coords = false

	_ember_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_ember_particles.emission_sphere_radius = aoe_radius * size_mult * 0.4

	# Embers fly outward and up
	_ember_particles.direction = Vector2(0, -1)
	_ember_particles.spread = 75.0
	_ember_particles.initial_velocity_min = 70.0
	_ember_particles.initial_velocity_max = 180.0
	_ember_particles.gravity = Vector2(0, -20)
	_ember_particles.damping_min = 25.0
	_ember_particles.damping_max = 50.0
	_ember_particles.angular_velocity_min = -360.0
	_ember_particles.angular_velocity_max = 360.0

	# Small bright dots
	_ember_particles.scale_amount_min = 1.0
	_ember_particles.scale_amount_max = 2.0
	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.0))
	_ember_particles.scale_amount_curve = scale_curve

	# Color: bright white/yellow → orange → gone
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 0.8, 1.0))
	gradient.add_point(0.3, Color(1.0, 0.7, 0.2, 0.9))
	gradient.add_point(0.7, Color(1.0, 0.3, 0.0, 0.5))
	gradient.set_color(1, Color(0.5, 0.1, 0.0, 0.0))
	_ember_particles.color_ramp = gradient


# ══════════════════════════════════════════════════════════════════════════
#  SMOKE PARTICLES (dark smoke rising above fire)
# ══════════════════════════════════════════════════════════════════════════

func _create_smoke_particles() -> void:
	_smoke_particles = CPUParticles2D.new()
	add_child(_smoke_particles)

	_smoke_particles.emitting = false
	_smoke_particles.amount = 20
	_smoke_particles.lifetime = 1.5
	_smoke_particles.one_shot = false
	_smoke_particles.explosiveness = 0.0
	_smoke_particles.local_coords = false

	_smoke_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_smoke_particles.emission_sphere_radius = aoe_radius * size_mult * 0.3

	# Slow upward drift
	_smoke_particles.direction = Vector2(0, -1)
	_smoke_particles.spread = 30.0
	_smoke_particles.initial_velocity_min = 12.0
	_smoke_particles.initial_velocity_max = 30.0
	_smoke_particles.gravity = Vector2(0, -18)
	_smoke_particles.damping_min = 3.0
	_smoke_particles.damping_max = 10.0

	# Large, fading puffs
	_smoke_particles.scale_amount_min = 6.0
	_smoke_particles.scale_amount_max = 12.0
	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.4))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 1.2))
	_smoke_particles.scale_amount_curve = scale_curve

	# Color: dark semi-transparent smoke with warm tint
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.25, 0.12, 0.05, 0.35))
	gradient.add_point(0.3, Color(0.18, 0.1, 0.06, 0.3))
	gradient.add_point(0.7, Color(0.12, 0.08, 0.04, 0.18))
	gradient.set_color(1, Color(0.06, 0.04, 0.02, 0.0))
	_smoke_particles.color_ramp = gradient


# ══════════════════════════════════════════════════════════════════════════
#  HITBOXES
# ══════════════════════════════════════════════════════════════════════════

func _create_proj_hitbox() -> void:
	"""Small hitbox that travels with the projectile for impact detection."""
	_proj_hitbox = Area2D.new()
	_proj_hitbox.collision_layer = 4  # Player weapons
	_proj_hitbox.collision_mask = 8   # Enemies
	_proj_hitbox.monitoring = true
	_proj_hitbox.monitorable = true
	add_child(_proj_hitbox)

	var collision: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = proj_size * 1.5  # Generous hitbox for reliable contact
	collision.shape = circle
	_proj_hitbox.add_child(collision)

	_proj_hitbox.body_entered.connect(_on_proj_body_entered)
	_proj_hitbox.area_entered.connect(_on_proj_area_entered)


func _create_aoe_hitbox() -> void:
	"""Circular hitbox for the fire zone — radius grows during spread phase."""
	_aoe_hitbox = Area2D.new()
	_aoe_hitbox.collision_layer = 4  # Player weapons
	_aoe_hitbox.collision_mask = 8   # Enemies
	_aoe_hitbox.monitoring = false   # Starts disabled, enabled on burn phase
	_aoe_hitbox.monitorable = true
	add_child(_aoe_hitbox)

	_aoe_collision = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = aoe_radius * size_mult * 0.2  # Start small
	_aoe_collision.shape = circle
	_aoe_hitbox.add_child(_aoe_collision)


func _update_aoe_radius(new_radius: float) -> void:
	if _aoe_collision and _aoe_collision.shape:
		_aoe_collision.shape.radius = new_radius


func _update_particle_emission_radius(pixel_radius: float) -> void:
	"""Update all fire particle emitters to match the current fire spread."""
	if _flame_particles:
		_flame_particles.emission_sphere_radius = pixel_radius * 0.7
	if _ember_particles:
		_ember_particles.emission_sphere_radius = pixel_radius * 0.5
	if _smoke_particles:
		_smoke_particles.emission_sphere_radius = pixel_radius * 0.4


# ══════════════════════════════════════════════════════════════════════════
#  COLLISION CALLBACKS
# ══════════════════════════════════════════════════════════════════════════

func _on_proj_body_entered(body: Node2D) -> void:
	"""Projectile hit an enemy body — detonate early."""
	if _phase != Phase.PROJECTILE:
		return
	if body.is_in_group("enemies"):
		# Detonate at current position (not target — we hit something on the way)
		_target_pos = global_position
		_begin_impact()


func _on_proj_area_entered(area: Area2D) -> void:
	"""Projectile hit an enemy area — detonate early."""
	if _phase != Phase.PROJECTILE:
		return
	var parent_node: Node = area.get_parent()
	if parent_node and parent_node.is_in_group("enemies"):
		_target_pos = global_position
		_begin_impact()
