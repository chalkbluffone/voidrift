extends Node2D
class_name RadiantArc


## Simple debug circle drawer
class DebugCircle extends Node2D:
	var radius: float = 10.0
	var color: Color = Color(0, 1, 0, 0.5)
	
	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color, 2.0)
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, color.a * 0.3))


# Exported parameters for full configurability
@export var arc_angle_deg: float = 90.0
@export var radius: float = 42.0
@export var thickness: float = 18.0
@export var taper: float = 0.5  # Thickness falloff (0-1)
@export var length_scale: float = 0.75
@export var distance: float = 25.0  # Medium distance offset (unchanged)
@export var speed: float = 0.0  # Travel speed forward
@export var duration: float = 0.8  # Longer duration for slower feel
@export var fade_in: float = 0.08  # Fade-in time
@export var fade_out: float = 0.15  # Fade-out time
@export var sweep_speed: float = 1.2  # Slower blade animation

# Color and glow parameters
@export var color_a: Color = Color(0.0, 1.0, 1.0, 1.0)  # Cyan
@export var color_b: Color = Color(1.0, 0.0, 1.0, 1.0)  # Magenta
@export var color_c: Color = Color(0.0, 0.5, 1.0, 1.0)  # Deep Blue
@export var glow_strength: float = 3.0
@export var core_strength: float = 1.2
@export var noise_strength: float = 0.3
@export var uv_scroll_speed: float = 3.0

# Control parameters
@export var rotation_offset_deg: float = 0.0
@export var seed_offset: float = 0.0
@export var damage: float = 25.0  # Damage dealt to enemies

# Movement tracking - arc follows source's movement direction
var _follow_source: Node2D = null  # Reference to player/ship to track movement
var _source_last_pos: Vector2 = Vector2.ZERO

# Damage tracking
var _hit_targets: Array = []  # Track what we've already hit
var _hitbox: Area2D = null
var _hitbox_collisions: Array[CollisionShape2D] = []  # Multiple collision shapes along arc
var _hitbox_count: int = 0  # Calculated dynamically based on arc size
var _blade_collision: CollisionShape2D = null  # Single capsule for the sweeping blade

# Debug visualization
var _debug_draw: bool = false
var _debug_circles: Array[Node2D] = []  # Debug circles for each hitbox
var _blade_debug: Node2D = null  # Debug for blade capsule

# Internal state
var _elapsed: float = 0.0
var _is_active: bool = true
var _mesh_instance: MeshInstance2D
var _shader_material: ShaderMaterial
var _start_pos: Vector2
var _start_rotation: float
var _aim_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	# Find or create MeshInstance2D child
	var children = get_children()
	_mesh_instance = null
	for child in children:
		if child is MeshInstance2D:
			_mesh_instance = child
			break
	
	# Cleanup any old Polygon2D
	for child in children:
		if child is Polygon2D:
			child.queue_free()
	
	if not _mesh_instance:
		_mesh_instance = MeshInstance2D.new()
		add_child(_mesh_instance)
	
	# Texture fix for UVs
	if not _mesh_instance.texture:
		var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_mesh_instance.texture = ImageTexture.create_from_image(img)
	
	# Create shader material if not exists
	if not _mesh_instance.material:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = load("res://effects/radiant_arc/radiant_arc.gdshader")
		_mesh_instance.material = _shader_material
	else:
		_shader_material = _mesh_instance.material
	
	_start_pos = global_position
	_start_rotation = rotation
	_generate_arc_mesh()
	# Defer hitbox creation to ensure physics system is ready
	call_deferred("_create_hitbox")
	_update_shader_uniforms()


func _create_hitbox() -> void:
	"""Create an Area2D hitbox with multiple collision shapes along the arc and a sweeping blade."""
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 4  # Player weapons layer
	_hitbox.collision_mask = 8   # Enemies layer
	_hitbox.monitoring = true
	_hitbox.monitorable = true
	add_child(_hitbox)
	
	# Calculate arc length at the middle of the thickness
	var arc_rad = deg_to_rad(arc_angle_deg)
	var mid_radius = (radius + thickness * 0.5) * length_scale
	var arc_length = arc_rad * mid_radius
	
	# Collision radius based on average thickness (accounting for taper)
	# Use a smaller radius for better coverage
	var collision_radius = thickness * 0.4 * length_scale
	
	# Calculate how many bubbles we need for full coverage along the arc
	# Overlap factor of 1.5 means bubbles overlap by 50% of their diameter
	var spacing = collision_radius * 1.5
	_hitbox_count = max(3, int(ceil(arc_length / spacing)) + 1)
	
	_hitbox_collisions.clear()
	
	for i in range(_hitbox_count):
		var collision = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = collision_radius
		collision.shape = circle
		collision.disabled = true  # Start disabled
		_hitbox.add_child(collision)
		_hitbox_collisions.append(collision)
	
	# Create blade collision - a single capsule that sweeps from arc center to outer edge
	# This catches enemies inside the arc radius
	var blade_thickness = thickness * 0.25 * length_scale  # Thin blade radius
	var blade_length = (radius + thickness) * length_scale  # From arc center to outer edge
	_blade_collision = CollisionShape2D.new()
	var capsule = CapsuleShape2D.new()
	capsule.radius = blade_thickness
	capsule.height = blade_length + blade_thickness * 2  # Total height of capsule
	_blade_collision.shape = capsule
	_blade_collision.disabled = true  # Start disabled
	_hitbox.add_child(_blade_collision)
	
	# Connect signal for hit detection
	_hitbox.area_entered.connect(_on_hitbox_area_entered)


func _update_hitbox_position(sweep_progress: float) -> void:
	"""Update all hitbox positions along the arc, enabling only the visible ones."""
	if _hitbox_collisions.is_empty():
		return
	
	var arc_rad = deg_to_rad(arc_angle_deg)
	
	# Match shader's sweep behavior: sweep_edge = sweep_progress * 1.8
	# This extends the range so the sweep can fully exit the arc
	var sweep_edge = sweep_progress * 1.8
	var tail_length = 0.5  # Match shader's tail_length
	
	# Create debug circles lazily if needed
	if _debug_draw and _debug_circles.size() < _hitbox_count:
		var base_rad = thickness * 0.4 * length_scale
		for i in range(_debug_circles.size(), _hitbox_count):
			var debug = _create_debug_circle(Vector2.ZERO, base_rad)
			debug.visible = false
			_debug_circles.append(debug)
	
	# Distribute collision shapes evenly along the arc
	for i in range(_hitbox_count):
		var collision = _hitbox_collisions[i]
		
		# Each hitbox covers a portion of the arc
		# t represents the position along the arc (0 to 1)
		var t = float(i) / float(_hitbox_count - 1) if _hitbox_count > 1 else 0.5
		
		# Calculate angle position on the arc
		var angle = -arc_rad * 0.5 + arc_rad * t
		
		# Position at the middle of the arc thickness, accounting for taper
		var taper_profile = sin(t * PI)
		var adjusted_taper = pow(taper_profile, 1.0 - taper * 0.8)
		var current_thickness = thickness * adjusted_taper
		var current_mid_r = radius + current_thickness * 0.5
		
		var dir = Vector2(cos(angle), sin(angle))
		var pos = dir * current_mid_r * length_scale + Vector2(distance, 0.0)
		collision.position = pos
		
		# Adjust collision radius based on taper at this position
		if collision.shape is CircleShape2D:
			collision.shape.radius = max(current_thickness * 0.4 * length_scale, 2.0)
		
		# Match shader visibility: visible when between (sweep_edge - tail_length) and sweep_edge
		# dist_from_edge = sweep_edge - t
		# visible when dist_from_edge is between 0 and tail_length
		var dist_from_edge = sweep_edge - t
		var part_visible = (dist_from_edge >= 0.0) and (dist_from_edge <= tail_length) and (sweep_progress > 0.0)
		collision.disabled = not part_visible
		
		# Update debug circles if enabled
		if _debug_draw and i < _debug_circles.size():
			var debug = _debug_circles[i]
			debug.position = pos
			debug.visible = part_visible
			# Update debug circle radius to match collision
			if debug.get_child_count() > 0:
				var circle_vis = debug.get_child(0) as DebugCircle
				if circle_vis:
					circle_vis.radius = collision.shape.radius
					circle_vis.queue_redraw()
	
	# Update blade collisions - position along radial line at the leading edge
	_update_blade_position(sweep_progress, sweep_edge, arc_rad)


func _update_blade_position(sweep_progress: float, sweep_edge: float, arc_rad: float) -> void:
	"""Update the blade capsule - a radial line that sweeps with the leading edge."""
	if not _blade_collision:
		return
	
	# Calculate the angle of the leading edge
	# sweep_edge goes from 0 to ~1.8, but the actual arc is 0 to 1
	var leading_t = clamp(sweep_edge, 0.0, 1.0)
	var leading_angle = -arc_rad * 0.5 + arc_rad * leading_t
	
	# Blade is only visible during the active sweep (not during tail fade-out)
	var blade_visible = (sweep_progress > 0.0) and (sweep_edge <= 1.0)
	
	# The blade extends from arc center to the outer edge
	# Arc center is at (distance, 0) in local coordinates
	var arc_center = Vector2(distance, 0.0)
	var blade_length = (radius + thickness) * length_scale
	var half_blade = blade_length * 0.5
	
	# Direction from arc center outward at leading angle
	var dir = Vector2(cos(leading_angle), sin(leading_angle))
	# Position blade center at arc_center + half the blade length in the radial direction
	var pos = arc_center + dir * half_blade
	
	_blade_collision.position = pos
	# Rotate so the capsule points along the radial direction
	# Capsule's default orientation is vertical (Y-axis), so add PI/2 to point along the angle
	_blade_collision.rotation = leading_angle + PI / 2
	_blade_collision.disabled = not blade_visible
	
	# Create/update debug visualization for blade
	if _debug_draw:
		if not _blade_debug:
			_blade_debug = _create_blade_debug()
		_blade_debug.position = pos
		_blade_debug.rotation = leading_angle + PI / 2
		_blade_debug.visible = blade_visible
		# Force redraw
		if _blade_debug.get_child_count() > 0:
			_blade_debug.get_child(0).queue_redraw()
	elif _blade_debug:
		_blade_debug.visible = false


## Debug capsule drawer for blade
class DebugCapsule extends Node2D:
	var capsule_radius: float = 5.0
	var capsule_height: float = 20.0
	var color: Color = Color(1, 1, 0, 0.5)
	
	func _draw() -> void:
		# Capsule height is total height including the rounded ends
		var half_length = max(0.0, capsule_height * 0.5 - capsule_radius)
		
		# Draw outline
		if half_length > 0:
			# Draw the two end semicircles
			draw_arc(Vector2(0, -half_length), capsule_radius, PI, TAU, 16, color, 2.0)
			draw_arc(Vector2(0, half_length), capsule_radius, 0, PI, 16, color, 2.0)
			# Draw the connecting lines
			draw_line(Vector2(-capsule_radius, -half_length), Vector2(-capsule_radius, half_length), color, 2.0)
			draw_line(Vector2(capsule_radius, -half_length), Vector2(capsule_radius, half_length), color, 2.0)
		else:
			# It's basically a circle
			draw_arc(Vector2.ZERO, capsule_radius, 0, TAU, 32, color, 2.0)
		
		# Fill with semi-transparent
		var fill_color = Color(color.r, color.g, color.b, color.a * 0.3)
		if half_length > 0:
			draw_circle(Vector2(0, -half_length), capsule_radius, fill_color)
			draw_circle(Vector2(0, half_length), capsule_radius, fill_color)
			draw_rect(Rect2(-capsule_radius, -half_length, capsule_radius * 2, half_length * 2), fill_color)
		else:
			draw_circle(Vector2.ZERO, capsule_radius, fill_color)


func _create_blade_debug() -> Node2D:
	"""Create a visible capsule for debugging the blade hitbox."""
	var debug_node = Node2D.new()
	add_child(debug_node)
	
	var capsule_visual = DebugCapsule.new()
	if _blade_collision and _blade_collision.shape is CapsuleShape2D:
		var shape = _blade_collision.shape as CapsuleShape2D
		capsule_visual.capsule_radius = shape.radius
		capsule_visual.capsule_height = shape.height
	else:
		# Fallback values if shape not ready
		var blade_thickness = thickness * 0.25 * length_scale
		var blade_length = (radius + thickness) * length_scale
		capsule_visual.capsule_radius = blade_thickness
		capsule_visual.capsule_height = blade_length + blade_thickness * 2
	debug_node.add_child(capsule_visual)
	
	return debug_node


func _create_debug_circle(pos: Vector2, rad: float) -> Node2D:
	"""Create a visible circle for debugging hitbox positions."""
	var debug_node = Node2D.new()
	debug_node.position = pos
	add_child(debug_node)
	
	# Use a simple draw call
	var circle_visual = DebugCircle.new()
	circle_visual.radius = rad
	circle_visual.color = Color(0, 1, 0, 0.5)  # Semi-transparent green
	debug_node.add_child(circle_visual)
	
	return debug_node


func set_debug_draw(enabled: bool) -> void:
	"""Enable or disable debug hitbox visualization."""
	_debug_draw = enabled
	if not enabled:
		# Hide all debug circles
		for debug in _debug_circles:
			debug.visible = false
		if _blade_debug:
			_blade_debug.visible = false


func _generate_hitbox_polygon() -> PackedVector2Array:
	"""Generate a polygon that approximates the arc shape for collision."""
	var points = PackedVector2Array()
	var arc_rad = deg_to_rad(arc_angle_deg)
	var segments = 8  # Fewer segments for collision, we don't need high precision
	
	var inner_radius = radius
	
	# Outer edge (going one direction)
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = -arc_rad * 0.5 + arc_rad * t
		
		# Apply same taper as visual mesh
		var taper_profile = sin(t * PI)
		var adjusted_taper = pow(taper_profile, 1.0 - taper * 0.8)
		var current_outer_r = inner_radius + thickness * adjusted_taper
		
		var dir = Vector2(cos(angle), sin(angle))
		var p = dir * current_outer_r * length_scale + Vector2(distance, 0.0)
		points.push_back(p)
	
	# Inner edge (going back)
	for i in range(segments, -1, -1):
		var t = float(i) / float(segments)
		var angle = -arc_rad * 0.5 + arc_rad * t
		var dir = Vector2(cos(angle), sin(angle))
		var p = dir * inner_radius * length_scale + Vector2(distance, 0.0)
		points.push_back(p)
	
	return points


func _on_hitbox_area_entered(area: Area2D) -> void:
	"""Handle collision with enemies/targets."""
	# Skip if already hit this target
	if area in _hit_targets:
		return
	
	_hit_targets.append(area)
	
	# Deal damage if the target can take it
	if area.has_method("take_damage"):
		area.take_damage(damage, self)
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage, self)


func get_damage() -> float:
	"""Return the damage value for this arc."""
	return damage


func _process(delta: float) -> void:
	if not _is_active:
		return
	
	_elapsed += delta
	
	# Check if effect is done
	if _elapsed >= duration:
		_is_active = false
		queue_free()
		return
	
	# Follow source's movement direction
	if _follow_source and is_instance_valid(_follow_source):
		var current_pos = _follow_source.global_position
		var move_delta = current_pos - _source_last_pos
		
		# Only update rotation if there's actual movement
		if move_delta.length_squared() > 0.01:
			var move_dir = move_delta.normalized()
			rotation = move_dir.angle() + deg_to_rad(rotation_offset_deg)
		
		# Arc stays attached to source position
		global_position = current_pos + Vector2.RIGHT.rotated(rotation) * distance
		_source_last_pos = current_pos
	elif speed > 0.0:
		# Fallback: Update position if moving forward (no source tracking)
		var direction = Vector2.RIGHT.rotated(rotation)
		global_position = _start_pos + direction * speed * _elapsed
	
	# Update shader uniforms each frame
	_update_shader_uniforms()


func _generate_arc_mesh() -> void:
	"""Generate the crescent arc mesh procedurally with UVs."""
	if not _mesh_instance:
		return
	
	var vertices = PackedVector2Array()
	var uvs = PackedVector2Array()
	
	var arc_rad = deg_to_rad(arc_angle_deg)
	var segments = int(max(16, arc_angle_deg / 3.0))
	
	var inner_radius = radius
	
	# Generate triangle strip: Inner, Outer, Inner, Outer
	for i in range(segments + 1):
		var t = float(i) / float(segments) # 0.0 to 1.0 along arc
		var angle = -arc_rad * 0.5 + arc_rad * t
		
		# Taper logic - always taper to points at both ends
		# Use sine wave profile that starts and ends at zero
		var taper_profile = sin(t * PI)  # 0 at start, 1 at middle, 0 at end
		
		# Apply taper parameter to control how much of the middle is at full width
		# taper = 0: very thin, pointy arc
		# taper = 1: mostly full width except at very tips
		var adjusted_taper = pow(taper_profile, 1.0 - taper * 0.8)
		var actual_thickness = thickness * adjusted_taper
		
		actual_thickness = max(0.0, actual_thickness)
		
		var current_outer_r = inner_radius + actual_thickness
		var current_inner_r = inner_radius
		
		var cos_a = cos(angle)
		var sin_a = sin(angle)
		var dir = Vector2(cos_a, sin_a)
		
		# Inner vertex (V=1.0)
		var p_in = dir * current_inner_r * length_scale
		p_in += Vector2(distance, 0.0)
		
		# Outer vertex (V=0.0)
		var p_out = dir * current_outer_r * length_scale
		p_out += Vector2(distance, 0.0)
		
		vertices.push_back(p_in)
		uvs.push_back(Vector2(t, 1.0))
		
		vertices.push_back(p_out)
		uvs.push_back(Vector2(t, 0.0))
		
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	_mesh_instance.mesh = am



func _update_shader_uniforms() -> void:
	"""Update shader uniforms based on current state."""
	if not _shader_material:
		return
	
	var progress = _elapsed / max(duration, 0.001)
	
	# Calculate alpha: fade in then fade out
	var alpha = 1.0
	if _elapsed < fade_in:
		alpha = _elapsed / fade_in
	elif _elapsed > duration - fade_out:
		alpha = 1.0 - (_elapsed - (duration - fade_out)) / fade_out
	
	# Optional sweep growth: arc expands from 0 to full angle
	# Sweep animation: controlled by sweep_speed
	# sweep_speed 1.0 = sweep completes in 70% of duration
	# sweep_speed 2.0 = sweep completes in 35% of duration (twice as fast)
	var base_sweep_duration = duration * 0.7
	var sweep_duration = base_sweep_duration / max(sweep_speed, 0.1)
	var sweep_progress = clamp(_elapsed / sweep_duration, 0.0, 1.0)
	
	# Update hitbox position to follow the sweep
	_update_hitbox_position(sweep_progress)
	
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


func setup(params: Dictionary) -> RadiantArc:
	"""
	Convenience method to set up the effect from a parameter dictionary.
	Returns self for chaining.
	
	Expected keys:
	- arc_angle_deg, radius, thickness, taper, length_scale
	- distance, speed, duration, fade_in, fade_out
	- color_a, color_b, color_c, glow_strength, core_strength
	- noise_strength, uv_scroll_speed, rotation_offset_deg, seed_offset
	"""
	for key in params:
		if key in self:
			set(key, params[key])
	
	if is_node_ready():
		_generate_arc_mesh()
		_update_shader_uniforms()
	
	return self


func set_direction(direction: Vector2) -> RadiantArc:
	"""Set the aim direction and apply rotation."""
	_aim_direction = direction.normalized()
	rotation = _aim_direction.angle() + deg_to_rad(rotation_offset_deg)
	return self


func spawn_from(spawn_pos: Vector2, direction: Vector2) -> RadiantArc:
	"""Position and orient the effect from a spawn point."""
	global_position = spawn_pos + direction * distance
	set_direction(direction)
	_start_pos = global_position
	_start_rotation = rotation
	return self


func set_follow_source(source: Node2D) -> RadiantArc:
	"""Set a source node to follow. Arc will track this node's movement direction."""
	_follow_source = source
	if source:
		_source_last_pos = source.global_position
	return self
