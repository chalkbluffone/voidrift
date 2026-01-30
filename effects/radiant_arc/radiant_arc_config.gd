extends Resource
class_name RadiantArcConfig

# Arc geometry
@export var arc_angle_deg: float = 120.0
@export var radius: float = 50.0
@export var thickness: float = 15.0
@export var taper: float = 0.8  # Thickness falloff along arc
@export var length_scale: float = 1.0
@export var distance: float = 0.0  # Offset from origin

# Movement
@export var speed: float = 0.0  # Travel speed forward
@export var duration: float = 0.2  # Lifetime
@export var fade_in: float = 0.05
@export var fade_out: float = 0.1

# Colors and effects
@export var color_a: Color = Color(0.0, 1.0, 1.0, 1.0)  # Cyan
@export var color_b: Color = Color(1.0, 0.2, 0.8, 1.0)  # Magenta
@export var color_c: Color = Color(1.0, 0.4, 0.8, 1.0)  # Pink
@export var glow_strength: float = 2.0
@export var core_strength: float = 0.6
@export var noise_strength: float = 0.3
@export var uv_scroll_speed: float = 2.0

# Orientation
@export var rotation_offset_deg: float = 0.0
@export var follow_mode: int = 0  # 0=fixed, 1=aim_dir, 2=movement_vec
@export var seed_offset: float = 0.0


func to_dict() -> Dictionary:
	"""Convert config to dictionary for passing to RadiantArc.setup()"""
	return {
		"arc_angle_deg": arc_angle_deg,
		"radius": radius,
		"thickness": thickness,
		"taper": taper,
		"length_scale": length_scale,
		"distance": distance,
		"speed": speed,
		"duration": duration,
		"fade_in": fade_in,
		"fade_out": fade_out,
		"color_a": color_a,
		"color_b": color_b,
		"color_c": color_c,
		"glow_strength": glow_strength,
		"core_strength": core_strength,
		"noise_strength": noise_strength,
		"uv_scroll_speed": uv_scroll_speed,
		"rotation_offset_deg": rotation_offset_deg,
		"follow_mode": follow_mode,
		"seed_offset": seed_offset,
	}


func apply_to(arc: RadiantArc) -> RadiantArc:
	"""Apply this config to a RadiantArc instance."""
	return arc.setup(to_dict())
