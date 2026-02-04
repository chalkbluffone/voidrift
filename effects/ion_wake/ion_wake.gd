extends Node2D
class_name IonWake

## Ion Wake - A planar shockwave ring that expands outward from the ship
## Inspired by the classic sci-fi "Saturn ring explosion" effect


# === SHAPE PARAMETERS ===
@export var inner_radius: float = 20.0  # Starting radius
@export var outer_radius: float = 200.0  # Maximum expansion radius
@export var ring_thickness: float = 30.0  # Thickness of the ring band
@export var expansion_speed: float = 300.0  # How fast the ring expands (pixels/sec)

# === TIMING ===
@export var duration: float = 1.0  # Total lifetime
@export var fade_in: float = 0.05  # Fade-in time at start
@export var fade_out: float = 0.3  # Fade-out time at end

# === COLORS ===
@export var color_inner: Color = Color(0.4, 0.8, 1.0, 1.0)  # Inner/trailing color
@export var color_outer: Color = Color(0.1, 0.3, 0.8, 1.0)  # Outer color  
@export var color_edge: Color = Color(0.9, 0.95, 1.0, 1.0)  # Leading edge highlight

# === VISUAL ===
@export var glow_strength: float = 2.0  # Overall brightness
@export var edge_sharpness: float = 2.0  # How sharp the ring edges are
@export var edge_glow: float = 1.0  # Leading edge brightness

# === STATS ===
@export var damage: float = 15.0  # Damage dealt to enemies

# Movement tracking
var _follow_source: Node2D = null

# Damage tracking
var _hit_targets: Array = []
var _hitbox: Area2D = null
var _hitbox_collision: CollisionShape2D = null

# Internal state
var _elapsed: float = 0.0
var _is_active: bool = true
var _mesh_instance: MeshInstance2D
var _shader_material: ShaderMaterial
var _current_radius: float = 0.0


## Load weapon parameters from a dictionary (typically from weapons.json).
func load_from_data(data: Dictionary) -> void:
	# Stats
	var stats = data.get("stats", {})
	damage = stats.get("damage", damage)
	duration = stats.get("duration", duration)
	
	# Shape
	var shape = data.get("shape", {})
	inner_radius = shape.get("inner_radius", inner_radius)
	outer_radius = shape.get("outer_radius", outer_radius)
	ring_thickness = shape.get("ring_thickness", ring_thickness)
	expansion_speed = shape.get("expansion_speed", expansion_speed)
	
	# Motion/Timing
	var motion = data.get("motion", {})
	fade_in = motion.get("fade_in", fade_in)
	fade_out = motion.get("fade_out", fade_out)
	
	# Visual
	var visual = data.get("visual", {})
	color_inner = _parse_color(visual.get("color_inner", ""), color_inner)
	color_outer = _parse_color(visual.get("color_outer", ""), color_outer)
	color_edge = _parse_color(visual.get("color_edge", ""), color_edge)
	glow_strength = visual.get("glow_strength", glow_strength)
	edge_sharpness = visual.get("edge_sharpness", edge_sharpness)
	edge_glow = visual.get("edge_glow", edge_glow)


func _parse_color(hex_string: String, fallback: Color) -> Color:
	if hex_string.is_empty():
		return fallback
	var hex = hex_string.trim_prefix("#")
	if hex.length() == 6:
		return Color(hex)
	elif hex.length() == 8:
		return Color.from_string(hex_string, fallback)
	return fallback


func _ready() -> void:
	# Create MeshInstance2D
	_mesh_instance = MeshInstance2D.new()
	add_child(_mesh_instance)
	
	# Texture for UVs
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_mesh_instance.texture = ImageTexture.create_from_image(img)
	
	# Create shader material
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = load("res://effects/ion_wake/ion_wake.gdshader")
	_mesh_instance.material = _shader_material
	
	_current_radius = inner_radius
	_generate_ring_mesh()
	call_deferred("_create_hitbox")
	_update_shader_uniforms()


func _create_hitbox() -> void:
	"""Create an Area2D hitbox as an expanding ring."""
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 4  # Player weapons layer
	_hitbox.collision_mask = 8   # Enemies layer
	_hitbox.monitoring = true
	_hitbox.monitorable = true
	add_child(_hitbox)
	
	# Circle collision that expands with the ring
	_hitbox_collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = inner_radius + ring_thickness * 0.5
	_hitbox_collision.shape = circle
	_hitbox.add_child(_hitbox_collision)
	
	_hitbox.area_entered.connect(_on_hitbox_area_entered)


func _generate_ring_mesh() -> void:
	"""Generate the ring mesh procedurally with UVs."""
	if not _mesh_instance:
		return
	
	var vertices = PackedVector2Array()
	var uvs = PackedVector2Array()
	var segments = 64
	
	# Triangle strip: Inner, Outer alternating around the ring
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = t * TAU
		var dir = Vector2(cos(angle), sin(angle))
		
		# Inner vertex (UV.x = 1, trailing edge)
		vertices.push_back(dir * _current_radius)
		uvs.push_back(Vector2(1.0, t))
		
		# Outer vertex (UV.x = 0, leading edge)
		vertices.push_back(dir * (_current_radius + ring_thickness))
		uvs.push_back(Vector2(0.0, t))
	
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
	
	# Calculate alpha: fade in then fade out
	var alpha = 1.0
	if _elapsed < fade_in:
		alpha = _elapsed / fade_in
	elif _elapsed > duration - fade_out:
		alpha = 1.0 - (_elapsed - (duration - fade_out)) / fade_out
	
	_shader_material.set_shader_parameter("color_inner", color_inner)
	_shader_material.set_shader_parameter("color_outer", color_outer)
	_shader_material.set_shader_parameter("color_edge", color_edge)
	_shader_material.set_shader_parameter("glow_strength", glow_strength)
	_shader_material.set_shader_parameter("edge_sharpness", edge_sharpness)
	_shader_material.set_shader_parameter("edge_glow", edge_glow)
	_shader_material.set_shader_parameter("alpha", alpha)


func _update_hitbox() -> void:
	"""Update the hitbox to match the current ring radius."""
	if _hitbox_collision and _hitbox_collision.shape is CircleShape2D:
		_hitbox_collision.shape.radius = _current_radius + ring_thickness * 0.5


func _on_hitbox_area_entered(area: Area2D) -> void:
	"""Handle collision with enemies/targets."""
	if area in _hit_targets:
		return
	
	_hit_targets.append(area)
	
	if area.has_method("take_damage"):
		area.take_damage(damage, self)
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage, self)


func get_damage() -> float:
	return damage


func _process(delta: float) -> void:
	if not _is_active:
		return
	
	_elapsed += delta
	
	if _elapsed >= duration:
		_is_active = false
		queue_free()
		return
	
	# Follow source position
	if _follow_source and is_instance_valid(_follow_source):
		global_position = _follow_source.global_position
	
	# Expand the ring
	_current_radius += expansion_speed * delta
	_current_radius = min(_current_radius, outer_radius)
	
	_generate_ring_mesh()
	_update_hitbox()
	_update_shader_uniforms()


func setup(params: Dictionary) -> IonWake:
	"""Set up the effect from a parameter dictionary."""
	for key in params:
		if key in self:
			set(key, params[key])
	
	if is_node_ready():
		_current_radius = inner_radius
		_generate_ring_mesh()
		_update_shader_uniforms()
	
	return self


func spawn_at(spawn_pos: Vector2) -> IonWake:
	"""Position the effect at a spawn point."""
	global_position = spawn_pos
	return self


func set_follow_source(source: Node2D) -> IonWake:
	"""Set a source node to follow."""
	_follow_source = source
	return self
