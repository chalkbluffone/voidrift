extends Node2D
class_name NikolasCoil

## Nikola's Coil — Tesla chain lightning effect.
## Fires an instant arc to the nearest enemy, then cascades to successive targets.
## Each chain segment is a procedural quad-strip mesh rendered with the lightning shader.
## Segments track enemy positions every frame.  Fork branches sprout at junction points.

# --- Exported Parameters ---

# Stats
@export var damage: float = 10.0
@export var duration: float = 0.6  # Total effect lifetime
@export var cooldown: float = 1.2

# Shape
@export var arc_width: float = 8.0        # Base width of each bolt segment in pixels
@export var search_radius: float = 300.0  # Max range to find first target AND chain hops

# Motion / Timing
@export var cascade_delay: float = 0.08   # Seconds between each chain hop reveal
@export var hold_time: float = 0.30       # How long all segments stay fully visible
@export var fade_in: float = 0.04         # Per-segment fade-in
@export var fade_out: float = 0.15        # Per-segment fade-out

# Visual
@export var color_core: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var color_glow: Color = Color(0.27, 0.53, 1.0, 1.0)
@export var color_fringe: Color = Color(0.53, 0.27, 0.8, 1.0)
@export var glow_strength: float = 4.0
@export var bolt_width: float = 0.5
@export var jaggedness: float = 0.7
@export var branch_intensity: float = 0.3
@export var flicker_speed: float = 30.0

# Fork branches
@export var fork_count: int = 3           # Forks per junction point
@export var fork_length_min: float = 20.0
@export var fork_length_max: float = 60.0

# Spark particles
@export var sparks_enabled: bool = true
@export var sparks_amount: int = 10
@export var sparks_speed: float = 120.0
@export var sparks_lifetime: float = 0.15
@export var sparks_size: float = 2.0

# --- Internal State ---
var _follow_source: Node2D = null
var _origin: Vector2 = Vector2.ZERO
var _chain_targets: Array[Node2D] = []  # Ordered list of enemy targets
var _segments: Array[Dictionary] = []   # {mesh, material, revealed}
var _fork_segments: Array[Dictionary] = []  # Small fork branch meshes
var _impact_effects: Array[Dictionary] = []  # {molten, embers, glow_particles, flash, light} per target

var _elapsed: float = 0.0
var _is_active: bool = true
var _hit_targets: Array = []
var _max_bounces: int = 3
var _shader_res: Resource = null
var _white_tex: ImageTexture = null

# Ship-to-first-enemy segment fades much faster
const SHIP_ARC_HOLD: float = 0.06
const SHIP_ARC_FADE_OUT: float = 0.08

# How often to re-randomise fork offsets (seconds)
const FORK_JITTER_INTERVAL: float = 0.06
var _fork_jitter_timer: float = 0.0

# Zigzag displacement seed — changes periodically for jitter
var _zigzag_seed: float = 0.0
const ZIGZAG_JITTER_INTERVAL: float = 0.04
var _zigzag_timer: float = 0.0


func load_from_data(data: Dictionary) -> void:
	var stats: Dictionary = data.get("stats", {})
	damage = float(stats.get("damage", damage))
	duration = float(stats.get("duration", duration))
	cooldown = float(stats.get("cooldown", cooldown))

	var shape: Dictionary = data.get("shape", {})
	arc_width = float(shape.get("arc_width", arc_width))
	search_radius = float(shape.get("search_radius", search_radius))

	var motion: Dictionary = data.get("motion", {})
	cascade_delay = float(motion.get("cascade_delay", cascade_delay))
	hold_time = float(motion.get("hold_time", hold_time))
	fade_in = float(motion.get("fade_in", fade_in))
	fade_out = float(motion.get("fade_out", fade_out))

	var visual: Dictionary = data.get("visual", {})
	color_core = EffectUtils.parse_color(visual.get("color_core", ""), color_core)
	color_glow = EffectUtils.parse_color(visual.get("color_glow", ""), color_glow)
	color_fringe = EffectUtils.parse_color(visual.get("color_fringe", ""), color_fringe)
	glow_strength = float(visual.get("glow_strength", glow_strength))
	bolt_width = float(visual.get("bolt_width", bolt_width))
	jaggedness = float(visual.get("jaggedness", jaggedness))
	branch_intensity = float(visual.get("branch_intensity", branch_intensity))
	flicker_speed = float(visual.get("flicker_speed", flicker_speed))

	var sparks: Dictionary = data.get("sparks", {})
	sparks_enabled = bool(sparks.get("enabled", sparks_enabled))
	sparks_amount = int(sparks.get("amount", sparks_amount))
	sparks_speed = float(sparks.get("speed", sparks_speed))
	sparks_lifetime = float(sparks.get("lifetime", sparks_lifetime))
	sparks_size = float(sparks.get("size", sparks_size))


func setup(params: Dictionary) -> NikolasCoil:
	for key in params:
		if key in self:
			set(key, params[key])
	return self


func set_follow_source(source: Node2D) -> NikolasCoil:
	_follow_source = source
	return self


func set_max_bounces(bounces: int) -> NikolasCoil:
	_max_bounces = bounces
	return self


func fire_from(origin_pos: Vector2) -> NikolasCoil:
	_origin = origin_pos
	global_position = Vector2.ZERO  # World space

	# Cache resources once
	_shader_res = load("res://effects/nikolas_coil/nikolas_coil.gdshader")
	_white_tex = EffectUtils.get_white_pixel_texture()

	# Find chain targets
	_chain_targets = _find_chain_targets(_origin, _max_bounces, search_radius)

	if _chain_targets.is_empty():
		_is_active = false
		queue_free()
		return self

	# Create one empty mesh segment per chain link
	for i in range(_chain_targets.size()):
		var seg: Dictionary = _create_segment(i)
		_segments.append(seg)

	# Create impact effects at each target
	if sparks_enabled:
		for ti in range(_chain_targets.size()):
			var target: Node2D = _chain_targets[ti]
			# Get incoming direction for directional spray
			var incoming_dir: Vector2 = Vector2.DOWN
			if ti == 0:
				incoming_dir = (target.global_position - _origin).normalized()
			else:
				incoming_dir = (target.global_position - _chain_targets[ti - 1].global_position).normalized()
			var impact: Dictionary = _create_impact_effect(target.global_position, incoming_dir)
			_impact_effects.append(impact)

	# Create fork branches at each junction point
	_create_fork_branches()

	# Calculate total duration
	var cascade_total: float = cascade_delay * max(_segments.size() - 1, 0)
	duration = maxf(duration, cascade_total + hold_time + fade_out)

	_elapsed = 0.0
	_is_active = true
	return self


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if not _is_active:
		return

	_elapsed += delta

	# Track ship position
	if _follow_source and is_instance_valid(_follow_source):
		_origin = _follow_source.global_position

	# Build live chain points from current enemy positions
	var chain_points: Array[Vector2] = []
	chain_points.append(_origin)
	for target in _chain_targets:
		if is_instance_valid(target):
			chain_points.append(target.global_position)
		else:
			# Target died — keep last known position
			chain_points.append(chain_points[chain_points.size() - 1])

	# Update each segment
	for i in range(_segments.size()):
		var seg: Dictionary = _segments[i]
		var reveal_time: float = cascade_delay * i
		var seg_elapsed: float = _elapsed - reveal_time

		if seg_elapsed < 0.0:
			_set_segment_alpha(seg, 0.0)
			continue

		# First reveal: impact effects + damage
		if not seg.get("revealed", false):
			seg["revealed"] = true
			if i < _impact_effects.size():
				_activate_impact(i)
			if i < _chain_targets.size():
				var target_node: Node2D = _chain_targets[i]
				if is_instance_valid(target_node) and target_node not in _hit_targets:
					_hit_targets.append(target_node)
					_deal_damage(target_node)

		# Rebuild mesh every frame to track moving enemies
		var from_pos: Vector2 = chain_points[i]
		var to_pos: Vector2 = chain_points[i + 1] if (i + 1) < chain_points.size() else from_pos
		_rebuild_segment_mesh(seg, from_pos, to_pos)

		# Update impact effects to follow target
		if i < _impact_effects.size():
			_update_impact_position(i, to_pos)

		# Segment 0 (ship→first enemy) fades much faster
		var seg_hold: float = hold_time if i > 0 else SHIP_ARC_HOLD
		var seg_fade_out: float = fade_out if i > 0 else SHIP_ARC_FADE_OUT

		# Per-segment alpha: fade in → hold → fade out
		var seg_alpha: float = 1.0
		if seg_elapsed < fade_in:
			seg_alpha = seg_elapsed / maxf(fade_in, 0.001)

		var cascade_total: float = cascade_delay * maxf(float(_segments.size() - 1), 0.0)
		var fade_start: float = cascade_total + seg_hold - reveal_time
		if seg_elapsed > fade_start:
			seg_alpha = 1.0 - clampf((seg_elapsed - fade_start) / maxf(seg_fade_out, 0.001), 0.0, 1.0)

		_set_segment_alpha(seg, seg_alpha)

		# Pass real time for flicker animation
		var mat: ShaderMaterial = seg.get("material") as ShaderMaterial
		if mat:
			mat.set_shader_parameter("elapsed_time", _elapsed)

	# Update fork branches (track live positions + periodic re-jitter)
	_fork_jitter_timer += delta
	var do_jitter: bool = _fork_jitter_timer >= FORK_JITTER_INTERVAL
	if do_jitter:
		_fork_jitter_timer = 0.0
	_update_fork_branches(chain_points, do_jitter)

	# Update zigzag seed periodically for bolt jitter
	_zigzag_timer += delta
	if _zigzag_timer >= ZIGZAG_JITTER_INTERVAL:
		_zigzag_timer = 0.0
		_zigzag_seed = randf() * 1000.0

	# Fade impact lights
	_update_impact_lights()

	# Done?
	if _elapsed >= duration:
		_is_active = false
		queue_free()


# =============================================================================
# TARGET ACQUISITION
# =============================================================================

func _find_chain_targets(origin: Vector2, max_bounces: int, radius: float) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var visited: Array[Node2D] = []
	var current_pos: Vector2 = origin
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")

	for _i in range(max_bounces):
		var best_target: Node2D = null
		var best_dist: float = radius
		for enemy in enemies:
			if not enemy is Node2D or not is_instance_valid(enemy):
				continue
			if enemy in visited:
				continue
			var dist: float = current_pos.distance_to(enemy.global_position)
			if dist < best_dist:
				best_dist = dist
				best_target = enemy as Node2D
		if best_target == null:
			break
		targets.append(best_target)
		visited.append(best_target)
		current_pos = best_target.global_position

	return targets


# =============================================================================
# SEGMENTS — created once, mesh rebuilt every frame
# =============================================================================

func _create_segment(index: int) -> Dictionary:
	var mesh_inst: MeshInstance2D = MeshInstance2D.new()
	add_child(mesh_inst)
	mesh_inst.texture = _white_tex

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _shader_res
	mat.set_shader_parameter("color_core", color_core)
	mat.set_shader_parameter("color_glow", color_glow)
	mat.set_shader_parameter("color_fringe", color_fringe)
	mat.set_shader_parameter("glow_strength", glow_strength)
	mat.set_shader_parameter("bolt_width", bolt_width)
	mat.set_shader_parameter("jaggedness", jaggedness)
	mat.set_shader_parameter("branch_intensity", branch_intensity)
	mat.set_shader_parameter("flicker_speed", flicker_speed)
	mat.set_shader_parameter("segment_seed", float(index) * 17.3 + 5.7)
	mat.set_shader_parameter("alpha", 0.0)
	mat.set_shader_parameter("elapsed_time", 0.0)
	mesh_inst.material = mat

	return {
		"mesh": mesh_inst,
		"material": mat,
		"revealed": false,
	}


func _rebuild_segment_mesh(seg: Dictionary, from_pos: Vector2, to_pos: Vector2) -> void:
	var mesh_inst: MeshInstance2D = seg.get("mesh") as MeshInstance2D
	if not mesh_inst:
		return
	var direction: Vector2 = to_pos - from_pos
	var length: float = direction.length()
	if length < 1.0:
		mesh_inst.visible = false
		return

	var dir_norm: Vector2 = direction.normalized()
	var perp: Vector2 = Vector2(-dir_norm.y, dir_norm.x)
	var half_width: float = arc_width * 3.5  # Wide enough for fringe to render
	# Moderate subdivision count — not too dense
	var subdivisions: int = maxi(6, int(length / 25.0))

	# Build zigzag-displaced center points
	# Use absolute displacement based on arc_width, NOT segment length
	var max_displace: float = arc_width * jaggedness * 1.5
	var center_points: PackedVector2Array = PackedVector2Array()
	for i in range(subdivisions + 1):
		var t: float = float(i) / float(subdivisions)
		var base_pos: Vector2 = from_pos + direction * t
		# Pin endpoints, ease in/out from ends
		var endpoint_falloff: float = smoothstep(0.0, 0.15, t) * smoothstep(1.0, 0.85, t)
		# Only displace every other point for natural lightning kinks
		var noise_val: float = 0.0
		if i % 2 == 1:
			noise_val = _pseudo_noise(float(i) * 3.7 + _zigzag_seed) * 2.0 - 1.0
		var displacement: float = noise_val * max_displace * endpoint_falloff
		center_points.push_back(base_pos + perp * displacement)

	var vertices: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()

	for i in range(subdivisions + 1):
		var t: float = float(i) / float(subdivisions)
		var pos: Vector2 = center_points[i]
		vertices.push_back(pos + perp * half_width)
		uvs.push_back(Vector2(t, 0.0))
		vertices.push_back(pos - perp * half_width)
		uvs.push_back(Vector2(t, 1.0))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs

	var am: ArrayMesh = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	mesh_inst.mesh = am


func _set_segment_alpha(seg: Dictionary, seg_alpha: float) -> void:
	var mat: ShaderMaterial = seg.get("material") as ShaderMaterial
	if mat:
		mat.set_shader_parameter("alpha", clampf(seg_alpha, 0.0, 1.0))
	var mesh_node: MeshInstance2D = seg.get("mesh") as MeshInstance2D
	if mesh_node:
		mesh_node.visible = seg_alpha > 0.001


# =============================================================================
# FORK BRANCHES — small jagged offshoots at each junction
# =============================================================================

func _create_fork_branches() -> void:
	if branch_intensity <= 0.0 or fork_count <= 0:
		return

	for target_idx in range(_chain_targets.size()):
		for _f in range(fork_count):
			var fork_mesh: MeshInstance2D = MeshInstance2D.new()
			add_child(fork_mesh)
			fork_mesh.texture = _white_tex

			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = _shader_res
			mat.set_shader_parameter("color_core", color_core)
			mat.set_shader_parameter("color_glow", color_glow)
			mat.set_shader_parameter("color_fringe", color_fringe)
			mat.set_shader_parameter("glow_strength", glow_strength * 0.6)
			mat.set_shader_parameter("bolt_width", bolt_width * 0.5)
			mat.set_shader_parameter("jaggedness", minf(jaggedness * 1.5, 1.0))
			mat.set_shader_parameter("branch_intensity", 0.0)  # No sub-branches on forks
			mat.set_shader_parameter("flicker_speed", flicker_speed * 1.3)
			mat.set_shader_parameter("segment_seed", float(target_idx * fork_count + _f) * 7.1 + 33.3)
			mat.set_shader_parameter("alpha", 0.0)
			mat.set_shader_parameter("elapsed_time", 0.0)
			fork_mesh.material = mat
			fork_mesh.visible = false

			var angle_offset: float = randf_range(-PI * 0.6, PI * 0.6)
			var fork_length: float = randf_range(fork_length_min, fork_length_max)

			_fork_segments.append({
				"mesh": fork_mesh,
				"material": mat,
				"target_idx": target_idx,
				"angle_offset": angle_offset,
				"fork_length": fork_length,
			})


func _update_fork_branches(chain_points: Array[Vector2], do_jitter: bool) -> void:
	for fork in _fork_segments:
		var target_idx: int = fork["target_idx"]
		var seg_reveal_time: float = cascade_delay * target_idx
		var seg_elapsed: float = _elapsed - seg_reveal_time

		if seg_elapsed < 0.0:
			fork["mesh"].visible = false
			continue

		# Re-randomise direction periodically for a flickery look
		if do_jitter:
			fork["angle_offset"] = randf_range(-PI * 0.6, PI * 0.6)
			fork["fork_length"] = randf_range(fork_length_min, fork_length_max)

		# Fork alpha follows parent segment, dimmed by branch_intensity
		var seg_hold: float = hold_time
		var seg_fade_out_val: float = fade_out
		var seg_alpha: float = 1.0

		if seg_elapsed < fade_in:
			seg_alpha = seg_elapsed / maxf(fade_in, 0.001)
		var cascade_total: float = cascade_delay * maxf(float(_segments.size() - 1), 0.0)
		var fade_start: float = cascade_total + seg_hold - seg_reveal_time
		if seg_elapsed > fade_start:
			seg_alpha = 1.0 - clampf((seg_elapsed - fade_start) / maxf(seg_fade_out_val, 0.001), 0.0, 1.0)

		seg_alpha *= branch_intensity

		var mat: ShaderMaterial = fork["material"] as ShaderMaterial
		if mat:
			mat.set_shader_parameter("alpha", clampf(seg_alpha, 0.0, 1.0))
			mat.set_shader_parameter("elapsed_time", _elapsed)

		var fork_mesh: MeshInstance2D = fork["mesh"] as MeshInstance2D
		fork_mesh.visible = seg_alpha > 0.001

		if seg_alpha <= 0.001:
			continue

		# Fork sprouts from the target point (chain_points[target_idx + 1])
		var point_idx: int = target_idx + 1
		if point_idx < 1 or point_idx >= chain_points.size():
			continue

		var fork_origin: Vector2 = chain_points[point_idx]
		var incoming_dir: Vector2 = (chain_points[point_idx] - chain_points[point_idx - 1]).normalized()
		var base_angle: float = incoming_dir.angle()
		var fork_angle: float = base_angle + fork["angle_offset"]
		var fork_end: Vector2 = fork_origin + Vector2.from_angle(fork_angle) * fork["fork_length"]

		_rebuild_fork_mesh(fork_mesh, fork_origin, fork_end)


func _rebuild_fork_mesh(mesh_inst: MeshInstance2D, from_pos: Vector2, to_pos: Vector2) -> void:
	var direction: Vector2 = to_pos - from_pos
	var length: float = direction.length()
	if length < 1.0:
		mesh_inst.visible = false
		return
	var dir_norm: Vector2 = direction.normalized()
	var perp: Vector2 = Vector2(-dir_norm.y, dir_norm.x)
	var half_width: float = arc_width * 2.5  # Narrower than main bolt

	var subdivisions: int = maxi(4, int(length / 20.0))
	var max_displace: float = arc_width * jaggedness * 1.0

	var center_points: PackedVector2Array = PackedVector2Array()
	for i in range(subdivisions + 1):
		var t: float = float(i) / float(subdivisions)
		var base_pos: Vector2 = from_pos + direction * t
		var endpoint_falloff: float = smoothstep(0.0, 0.15, t) * smoothstep(1.0, 0.85, t)
		var noise_val: float = 0.0
		if i % 2 == 1:
			noise_val = _pseudo_noise(float(i) * 5.1 + _zigzag_seed + 77.7) * 2.0 - 1.0
		var displacement: float = noise_val * max_displace * endpoint_falloff
		center_points.push_back(base_pos + perp * displacement)

	var vertices: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()

	for i in range(subdivisions + 1):
		var t: float = float(i) / float(subdivisions)
		var pos: Vector2 = center_points[i]
		var taper: float = 1.0 - t * 0.7  # Taper toward tip
		vertices.push_back(pos + perp * half_width * taper)
		uvs.push_back(Vector2(t, 0.0))
		vertices.push_back(pos - perp * half_width * taper)
		uvs.push_back(Vector2(t, 1.0))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs

	var am: ArrayMesh = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	mesh_inst.mesh = am


# =============================================================================
# DAMAGE
# =============================================================================

func _deal_damage(target: Node2D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)


# =============================================================================
# IMPACT EFFECTS — molten spray, embers, glow, flash
# =============================================================================

func _create_impact_effect(impact_pos: Vector2, incoming_dir: Vector2) -> Dictionary:
	## Create a multi-layer impact effect that looks like molten material spraying off.
	## Returns dict with all particle systems and the light.
	var result: Dictionary = {}

	# --- Layer 1: Molten spray (fast, bright, directional) ---
	var molten: CPUParticles2D = CPUParticles2D.new()
	molten.global_position = impact_pos
	molten.amount = sparks_amount * 2
	molten.lifetime = sparks_lifetime * 3.0
	molten.one_shot = true
	molten.explosiveness = 0.85
	molten.randomness = 0.7
	molten.emitting = false

	# Spray outward from impact, biased away from bolt direction
	var spray_dir: Vector2 = -incoming_dir  # Away from bolt source
	molten.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	molten.emission_sphere_radius = arc_width * 0.3
	molten.direction = spray_dir
	molten.spread = 70.0  # Cone

	molten.initial_velocity_min = sparks_speed * 0.8
	molten.initial_velocity_max = sparks_speed * 2.5
	molten.damping_min = 100.0
	molten.damping_max = 250.0
	molten.gravity = Vector2(0, 40.0)  # Slight downward pull for molten drip feel

	molten.scale_amount_min = sparks_size * 0.6
	molten.scale_amount_max = sparks_size * 2.0

	var molten_scale_curve: Curve = Curve.new()
	molten_scale_curve.add_point(Vector2(0.0, 0.5))
	molten_scale_curve.add_point(Vector2(0.15, 1.0))
	molten_scale_curve.add_point(Vector2(0.5, 0.7))
	molten_scale_curve.add_point(Vector2(1.0, 0.0))
	molten.scale_amount_curve = molten_scale_curve

	# Color: white flash → bright yellow → orange → dark red → gone
	var molten_ramp: Gradient = Gradient.new()
	molten_ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	molten_ramp.add_point(0.1, Color(1.0, 0.95, 0.6, 1.0))   # Hot white-yellow
	molten_ramp.add_point(0.3, Color(1.0, 0.7, 0.15, 1.0))    # Bright orange
	molten_ramp.add_point(0.6, Color(0.9, 0.35, 0.05, 0.8))   # Deep orange-red
	molten_ramp.set_color(1, Color(0.3, 0.08, 0.02, 0.0))     # Dark ember fade
	molten.color_ramp = molten_ramp

	molten.texture = EffectUtils.get_white_pixel_texture()

	add_child(molten)
	result["molten"] = molten

	# --- Layer 2: Slow ember drops (heavier, fall with gravity) ---
	var embers: CPUParticles2D = CPUParticles2D.new()
	embers.global_position = impact_pos
	embers.amount = int(sparks_amount * 0.8)
	embers.lifetime = sparks_lifetime * 5.0  # Longer lived
	embers.one_shot = true
	embers.explosiveness = 0.6
	embers.randomness = 0.9
	embers.emitting = false

	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = arc_width * 0.8
	embers.direction = Vector2.ZERO
	embers.spread = 180.0

	embers.initial_velocity_min = sparks_speed * 0.2
	embers.initial_velocity_max = sparks_speed * 0.8
	embers.damping_min = 80.0
	embers.damping_max = 200.0
	embers.gravity = Vector2(0, 80.0)  # Heavier drip

	embers.scale_amount_min = sparks_size * 0.3
	embers.scale_amount_max = sparks_size * 1.2

	var ember_scale_curve: Curve = Curve.new()
	ember_scale_curve.add_point(Vector2(0.0, 1.0))
	ember_scale_curve.add_point(Vector2(0.3, 0.8))
	ember_scale_curve.add_point(Vector2(0.7, 0.4))
	ember_scale_curve.add_point(Vector2(1.0, 0.0))
	embers.scale_amount_curve = ember_scale_curve

	# Color: orange → deep red → dark
	var ember_ramp: Gradient = Gradient.new()
	ember_ramp.set_color(0, Color(1.0, 0.6, 0.1, 1.0))       # Bright orange
	ember_ramp.add_point(0.3, Color(0.95, 0.4, 0.05, 0.9))    # Orange-red
	ember_ramp.add_point(0.6, Color(0.6, 0.15, 0.02, 0.6))    # Deep red
	ember_ramp.set_color(1, Color(0.2, 0.05, 0.01, 0.0))      # Dark
	embers.color_ramp = ember_ramp
	embers.texture = EffectUtils.get_white_pixel_texture()

	add_child(embers)
	result["embers"] = embers

	# --- Layer 3: Hot glow burst (few large soft particles at center) ---
	var glow_p: CPUParticles2D = CPUParticles2D.new()
	glow_p.global_position = impact_pos
	glow_p.amount = 4
	glow_p.lifetime = sparks_lifetime * 2.5
	glow_p.one_shot = true
	glow_p.explosiveness = 1.0
	glow_p.randomness = 0.3
	glow_p.emitting = false

	glow_p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	glow_p.emission_sphere_radius = 2.0
	glow_p.direction = Vector2.ZERO
	glow_p.spread = 180.0
	glow_p.initial_velocity_min = 5.0
	glow_p.initial_velocity_max = 20.0
	glow_p.damping_min = 50.0
	glow_p.damping_max = 100.0
	glow_p.gravity = Vector2.ZERO

	glow_p.scale_amount_min = sparks_size * 4.0
	glow_p.scale_amount_max = sparks_size * 8.0

	var glow_scale_curve: Curve = Curve.new()
	glow_scale_curve.add_point(Vector2(0.0, 0.3))
	glow_scale_curve.add_point(Vector2(0.1, 1.0))
	glow_scale_curve.add_point(Vector2(0.4, 0.6))
	glow_scale_curve.add_point(Vector2(1.0, 0.0))
	glow_p.scale_amount_curve = glow_scale_curve

	var glow_ramp: Gradient = Gradient.new()
	glow_ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.6))
	glow_ramp.add_point(0.2, Color(1.0, 0.85, 0.4, 0.5))     # Hot yellow
	glow_ramp.add_point(0.5, Color(0.9, 0.5, 0.1, 0.25))      # Warm orange
	glow_ramp.set_color(1, Color(0.5, 0.15, 0.03, 0.0))       # Fade
	glow_p.color_ramp = glow_ramp

	# Soft circular texture for glow blobs
	var glow_img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var dx: float = (float(x) - 7.5) / 7.5
			var dy: float = (float(y) - 7.5) / 7.5
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a  # Quadratic falloff for soft edge
			glow_img.set_pixel(x, y, Color(1, 1, 1, a))
	glow_p.texture = ImageTexture.create_from_image(glow_img)

	add_child(glow_p)
	result["glow_particles"] = glow_p

	# --- Layer 4: Flash particles (tiny bright white sparks, very fast) ---
	var flash: CPUParticles2D = CPUParticles2D.new()
	flash.global_position = impact_pos
	flash.amount = sparks_amount
	flash.lifetime = sparks_lifetime * 0.6
	flash.one_shot = true
	flash.explosiveness = 1.0
	flash.randomness = 0.5
	flash.emitting = false

	flash.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	flash.emission_sphere_radius = arc_width * 0.2
	flash.direction = Vector2.ZERO
	flash.spread = 180.0
	flash.initial_velocity_min = sparks_speed * 1.5
	flash.initial_velocity_max = sparks_speed * 4.0
	flash.damping_min = 300.0
	flash.damping_max = 600.0
	flash.gravity = Vector2.ZERO

	flash.scale_amount_min = sparks_size * 0.15
	flash.scale_amount_max = sparks_size * 0.5

	var flash_scale_curve: Curve = Curve.new()
	flash_scale_curve.add_point(Vector2(0.0, 1.0))
	flash_scale_curve.add_point(Vector2(0.3, 0.5))
	flash_scale_curve.add_point(Vector2(1.0, 0.0))
	flash.scale_amount_curve = flash_scale_curve

	var flash_ramp: Gradient = Gradient.new()
	flash_ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	flash_ramp.add_point(0.3, Color(color_glow.r, color_glow.g, color_glow.b, 0.8))
	flash_ramp.set_color(1, Color(color_glow.r * 0.5, color_glow.g * 0.5, color_glow.b * 0.5, 0.0))
	flash.color_ramp = flash_ramp
	flash.texture = EffectUtils.get_white_pixel_texture()

	add_child(flash)
	result["flash"] = flash

	# --- PointLight2D for impact glow (warm orange) ---
	var light: PointLight2D = PointLight2D.new()
	light.global_position = impact_pos
	light.color = Color(1.0, 0.7, 0.2, 1.0)  # Warm orange-yellow
	light.energy = 0.0  # Will brighten on reveal
	light.texture_scale = 0.8
	light.shadow_enabled = false
	# Create a soft radial gradient texture for the light
	var light_img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var dx: float = (float(x) - 31.5) / 31.5
			var dy: float = (float(y) - 31.5) / 31.5
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a * a  # Cubic falloff
			light_img.set_pixel(x, y, Color(1, 1, 1, a))
	light.texture = ImageTexture.create_from_image(light_img)

	add_child(light)
	result["light"] = light
	result["light_energy"] = 2.5  # Target energy on reveal
	result["light_timer"] = 0.0
	result["activated"] = false

	return result


func _activate_impact(index: int) -> void:
	## Start all impact particles and flash the light.
	var impact: Dictionary = _impact_effects[index]
	impact["activated"] = true
	impact["light_timer"] = 0.0

	for key in ["molten", "embers", "glow_particles", "flash"]:
		var p: CPUParticles2D = impact.get(key) as CPUParticles2D
		if p:
			p.emitting = true

	var light: PointLight2D = impact.get("light") as PointLight2D
	if light:
		light.energy = impact.get("light_energy", 2.5)


func _update_impact_position(index: int, pos: Vector2) -> void:
	## Move all impact sub-nodes to follow the target.
	var impact: Dictionary = _impact_effects[index]
	for key in ["molten", "embers", "glow_particles", "flash"]:
		var p: CPUParticles2D = impact.get(key) as CPUParticles2D
		if p:
			p.global_position = pos
	var light: PointLight2D = impact.get("light") as PointLight2D
	if light:
		light.global_position = pos


func _update_impact_lights() -> void:
	## Fade impact lights out over time.
	for impact in _impact_effects:
		if not impact.get("activated", false):
			continue
		impact["light_timer"] = impact.get("light_timer", 0.0) + get_process_delta_time()
		var light: PointLight2D = impact.get("light") as PointLight2D
		if light:
			# Quick flash then fade over ~0.3s
			var lt: float = impact["light_timer"]
			var peak: float = impact.get("light_energy", 2.5)
			if lt < 0.05:
				light.energy = lerpf(0.0, peak, lt / 0.05)
			else:
				light.energy = lerpf(peak, 0.0, clampf((lt - 0.05) / 0.3, 0.0, 1.0))


# =============================================================================
# UTILITY
# =============================================================================

func _pseudo_noise(x: float) -> float:
	## Fast deterministic pseudo-random 0..1 from a float seed.
	return fmod(sin(x * 12.9898 + 78.233) * 43758.5453, 1.0)



