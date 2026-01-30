extends Node2D
class_name RadiantArc

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
@export var follow_mode: int = 0  # 0=fixed, 1=aim_dir, 2=movement_vec
@export var seed_offset: float = 0.0

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
	_update_shader_uniforms()


func _process(delta: float) -> void:
	if not _is_active:
		return
	
	_elapsed += delta
	
	# Check if effect is done
	if _elapsed >= duration:
		_is_active = false
		queue_free()
		return
	
	# Update position if moving forward
	if speed > 0.0:
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
		
		# Taper logic
		var actual_thickness = thickness
		if taper > 0.8:
			# Comma shape (thick start, thin end)
			actual_thickness = thickness * (1.1 - pow(t, 2.0))
		else:
			# Crescent shape (sine wave profile)
			actual_thickness = thickness * (0.3 + 0.7 * sin(t * PI))
		
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
	- noise_strength, uv_scroll_speed, rotation_offset_deg
	- follow_mode, seed_offset
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
