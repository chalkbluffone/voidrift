class_name EffectUtils
extends RefCounted

## Shared utility helpers for weapon-effect scripts.
## Usage: preload("res://scripts/core/effect_utils.gd") — NOT an autoload.


# --- Cached white-pixel textures keyed by size ---
static var _white_tex_cache: Dictionary = {}


## Return a lazily-cached square white ImageTexture.
## Most callers use the default 4×4.
static func get_white_pixel_texture(size: int = 4) -> ImageTexture:
	if _white_tex_cache.has(size):
		return _white_tex_cache[size]
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_white_tex_cache[size] = tex
	return tex


## Return the cached enemy list from the FrameCache autoload.
## Return the cached enemy list from the FrameCache autoload.
## Falls back to get_nodes_in_group if cache is empty.
static func _get_enemies(tree: SceneTree) -> Array[Node]:
	var cache: Node = tree.root.get_node_or_null("/root/FrameCache")
	if cache and cache.enemies.size() > 0:
		return cache.enemies
	return tree.get_nodes_in_group("enemies")


## Return the nearest Node2D in the "enemies" group to [param origin],
## or null if the group is empty / all members are invalid.
static func find_nearest_enemy(tree: SceneTree, origin: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy in _get_enemies(tree):
		if not enemy is Node2D or not is_instance_valid(enemy):
			continue
		var dist: float = origin.distance_to((enemy as Node2D).global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy as Node2D
	return nearest


## Return true if at least one valid enemy in the "enemies" group is within
## [param radius] of [param origin].  Useful for pre-checks that skip
## spawning when no targets exist nearby (e.g. nikolas coil, tractor beam).
static func has_enemy_in_range(tree: SceneTree, origin: Vector2, radius: float) -> bool:
	for enemy in _get_enemies(tree):
		if enemy is Node2D and is_instance_valid(enemy):
			if origin.distance_to((enemy as Node2D).global_position) < radius:
				return true
	return false


## Return all valid enemies within [param radius] of [param center], sorted
## nearest-first.  Used by multi-target weapons like Space Nukes.
static func find_enemies_in_range(tree: SceneTree, center: Vector2, radius: float) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for enemy_any in _get_enemies(tree):
		if not enemy_any is Node2D or not is_instance_valid(enemy_any):
			continue
		var enemy: Node2D = enemy_any as Node2D
		if center.distance_to(enemy.global_position) <= radius:
			out.append(enemy)
	out.sort_custom(
		func(a: Node2D, b: Node2D) -> bool:
			return center.distance_to(a.global_position) < center.distance_to(b.global_position)
	)
	return out


## Parse a hex color string like "#00ffff" or "#00ffffcc" into a Color.
## Handles 6-char (RGB) and 8-char (RGBA) hex with optional '#' prefix.
## Returns [param fallback] on empty / unparseable input.
static func parse_color(hex_string: String, fallback: Color) -> Color:
	if hex_string.is_empty():
		return fallback
	# Remove # if present
	var hex: String = hex_string.trim_prefix("#")
	if hex.length() == 6:
		return Color(hex)
	elif hex.length() == 8:
		# RGBA format
		return Color.from_string(hex_string, fallback)
	return fallback


## Create a Gradient from an array of [offset, Color] stop pairs.
## Example: make_gradient([[0.0, Color.WHITE], [0.5, Color.RED], [1.0, Color(0,0,0,0)]])
static func make_gradient(stops: Array) -> Gradient:
	var g: Gradient = Gradient.new()
	var off: PackedFloat32Array = PackedFloat32Array()
	var cols: PackedColorArray = PackedColorArray()
	for stop in stops:
		off.append(float(stop[0]))
		cols.append(stop[1] as Color)
	g.offsets = off
	g.colors = cols
	return g


## Create a Curve from an array of Vector2 points (x = time 0..1, y = value).
static func make_curve(points: Array) -> Curve:
	var c: Curve = Curve.new()
	for pt in points:
		c.add_point(pt as Vector2)
	return c


## Create a CPUParticles2D node, add it to [param parent], and apply all
## key-value pairs from [param config] as properties.
## Returns the configured CPUParticles2D for further customisation.
static func create_cpu_particles(parent: Node, config: Dictionary) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	parent.add_child(p)
	for key in config:
		p.set(key, config[key])
	return p


## Create a GPUParticles2D node with a ParticleProcessMaterial, translating
## CPUParticles2D-style config keys so callers can use the same dictionary
## format as create_cpu_particles(). Returns the configured GPUParticles2D.
static func create_gpu_particles(parent: Node, config: Dictionary) -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticles2D.new()
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	p.process_material = mat
	parent.add_child(p)

	for key in config:
		var value: Variant = config[key]
		# --- Properties that live on the GPUParticles2D node itself ---
		if key in ["amount", "lifetime", "one_shot", "explosiveness", "randomness",
				"emitting", "texture", "z_index", "z_as_relative", "global_position",
				"position", "visible", "local_coords"]:
			# local_coords maps directly (GPUParticles2D has the same property)
			p.set(key, value)
		# --- Emission shape enum translation ---
		elif key == "emission_shape":
			mat.emission_shape = _cpu_to_gpu_emission_shape(int(value)) as ParticleProcessMaterial.EmissionShape
		elif key == "emission_sphere_radius":
			mat.emission_sphere_radius = float(value)
		elif key == "emission_rect_extents":
			var v2: Vector2 = value as Vector2
			mat.emission_box_extents = Vector3(v2.x, v2.y, 0.0)
		elif key == "emission_ring_radius":
			mat.emission_ring_radius = float(value)
		elif key == "emission_ring_inner_radius":
			mat.emission_ring_inner_radius = float(value)
		# --- Vector2 → Vector3 translations ---
		elif key == "direction":
			var v2: Vector2 = value as Vector2
			mat.direction = Vector3(v2.x, v2.y, 0.0)
		elif key == "gravity":
			var v2: Vector2 = value as Vector2
			mat.gravity = Vector3(v2.x, v2.y, 0.0)
		# --- Renamed properties ---
		elif key == "spread":
			mat.spread = float(value)
		elif key == "initial_velocity_min":
			mat.initial_velocity_min = float(value)
		elif key == "initial_velocity_max":
			mat.initial_velocity_max = float(value)
		elif key == "angular_velocity_min":
			mat.angular_velocity_min = float(value)
		elif key == "angular_velocity_max":
			mat.angular_velocity_max = float(value)
		elif key == "damping_min":
			mat.damping_min = float(value)
		elif key == "damping_max":
			mat.damping_max = float(value)
		elif key == "scale_amount_min":
			mat.scale_min = float(value)
		elif key == "scale_amount_max":
			mat.scale_max = float(value)
		elif key == "hue_variation_min":
			mat.hue_variation_min = float(value)
		elif key == "hue_variation_max":
			mat.hue_variation_max = float(value)
		# --- Resource wrappers (Gradient → GradientTexture1D, Curve → CurveTexture) ---
		elif key == "color":
			mat.color = value as Color
		elif key == "color_ramp":
			var grad_tex: GradientTexture1D = GradientTexture1D.new()
			grad_tex.gradient = value as Gradient
			mat.color_ramp = grad_tex
		elif key == "color_initial_ramp":
			var grad_tex: GradientTexture1D = GradientTexture1D.new()
			grad_tex.gradient = value as Gradient
			mat.color_initial_ramp = grad_tex
		elif key == "scale_amount_curve":
			var curve_tex: CurveTexture = CurveTexture.new()
			curve_tex.curve = value as Curve
			mat.scale_curve = curve_tex
		# --- Fallback: try setting on material first, then node ---
		else:
			mat.set(key, value)

	return p


## Map CPUParticles2D.EMISSION_SHAPE_* → ParticleProcessMaterial.EMISSION_SHAPE_*
static func _cpu_to_gpu_emission_shape(cpu_shape: int) -> int:
	match cpu_shape:
		CPUParticles2D.EMISSION_SHAPE_POINT:
			return ParticleProcessMaterial.EMISSION_SHAPE_POINT
		CPUParticles2D.EMISSION_SHAPE_SPHERE, CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE:
			return ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		CPUParticles2D.EMISSION_SHAPE_RECTANGLE:
			return ParticleProcessMaterial.EMISSION_SHAPE_BOX
		CPUParticles2D.EMISSION_SHAPE_RING:
			return ParticleProcessMaterial.EMISSION_SHAPE_RING
		_:
			return ParticleProcessMaterial.EMISSION_SHAPE_POINT


## Create a particle system node using GPU or CPU based on SettingsManager.
## Accepts the same config dictionary as create_cpu_particles().
## Returns Node2D (the common base); callers use .emitting to control it.
static func create_particles(parent: Node, config: Dictionary) -> Node2D:
	var settings: Node = Engine.get_main_loop().root.get_node_or_null("/root/SettingsManager") if Engine.get_main_loop() else null
	var use_gpu: bool = true
	if settings:
		use_gpu = bool(settings.use_gpu_particles)
	if use_gpu:
		return create_gpu_particles(parent, config)
	else:
		return create_cpu_particles(parent, config)


## Set a particle property at runtime on either CPUParticles2D or GPUParticles2D.
## Handles routing material-level properties (velocity, damping, emission radius,
## etc.) to ParticleProcessMaterial when the node is a GPUParticles2D.
## Properties that exist on both node types directly (amount, lifetime, emitting)
## are set on the node itself.
static var _gpu_material_props: Array[String] = [
	"initial_velocity_min", "initial_velocity_max",
	"angular_velocity_min", "angular_velocity_max",
	"damping_min", "damping_max",
	"emission_sphere_radius", "emission_ring_radius", "emission_ring_inner_radius",
	"spread",
	"scale_min", "scale_max",
	"hue_variation_min", "hue_variation_max",
]

## CPU→GPU property name remap for runtime sets
static var _cpu_to_gpu_prop: Dictionary = {
	"scale_amount_min": "scale_min",
	"scale_amount_max": "scale_max",
}

static func set_particle_prop(node: Node2D, prop: String, value: Variant) -> void:
	if node is GPUParticles2D:
		var gpu: GPUParticles2D = node as GPUParticles2D
		var mat: ParticleProcessMaterial = gpu.process_material as ParticleProcessMaterial
		# Properties that live on the material and need Vector2→Vector3 conversion
		if mat and prop in ["direction", "gravity"]:
			if value is Vector2:
				var v2: Vector2 = value as Vector2
				mat.set(prop, Vector3(v2.x, v2.y, 0.0))
			else:
				mat.set(prop, value)
			return
		# Remap CPU property names to GPU equivalents
		var gpu_prop: String = String(_cpu_to_gpu_prop.get(prop, prop))
		if mat and gpu_prop in _gpu_material_props:
			mat.set(gpu_prop, value)
		else:
			gpu.set(prop, value)
	else:
		node.set(prop, value)


## Create a cached radial-gradient ImageTexture with configurable falloff.
## Used for soft glow blobs and point-light textures.
static var _radial_tex_cache: Dictionary = {}

static func make_radial_texture(size: int, falloff_power: float = 2.0) -> ImageTexture:
	var cache_key: String = "%d_%.1f" % [size, falloff_power]
	if _radial_tex_cache.has(cache_key):
		return _radial_tex_cache[cache_key]
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half: float = float(size - 1) / 2.0
	for y in range(size):
		for x in range(size):
			var dx: float = (float(x) - half) / half
			var dy: float = (float(y) - half) / half
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = pow(clampf(1.0 - d, 0.0, 1.0), falloff_power)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_radial_tex_cache[cache_key] = tex
	return tex


## Return a spawn position on the source collision boundary along [param direction].
## Falls back to [param fallback_origin] when source or shape data is unavailable.
static func source_edge_origin(source: Node2D, direction: Vector2, fallback_origin: Vector2) -> Vector2:
	if not is_instance_valid(source):
		return fallback_origin

	var dir: Vector2 = direction.normalized()
	if dir.is_zero_approx():
		dir = Vector2.RIGHT

	var collision: CollisionShape2D = source.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return source.global_position + dir * GameConfig.DEFAULT_COLLISION_RADIUS

	var base_radius: float = GameConfig.DEFAULT_COLLISION_RADIUS
	if collision.shape is CircleShape2D:
		var circle: CircleShape2D = collision.shape as CircleShape2D
		base_radius = circle.radius
	elif collision.shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = collision.shape as CapsuleShape2D
		base_radius = capsule.radius + capsule.height * 0.5
	elif collision.shape is RectangleShape2D:
		var rect: RectangleShape2D = collision.shape as RectangleShape2D
		base_radius = rect.size.length() * 0.5

	var scale_factor: float = maxf(absf(source.global_scale.x), absf(source.global_scale.y))
	var world_radius: float = maxf(1.0, base_radius * scale_factor)
	return source.global_position + dir * world_radius
