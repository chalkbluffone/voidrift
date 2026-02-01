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

# Visual Effects
@export var chromatic_aberration: float = 0.0  # 0 = off, 0.5 = subtle, 1.0+ = intense
@export var pulse_strength: float = 0.0  # 0 = off, 0.5 = subtle, 1.0 = intense
@export var pulse_speed: float = 8.0  # Pulses per second
@export var electric_strength: float = 0.0  # 0 = off, 0.5 = subtle, 1.0 = intense
@export var electric_frequency: float = 20.0  # Higher = finer detail
@export var electric_speed: float = 15.0  # Animation speed

# Orientation
@export var rotation_offset_deg: float = 0.0
@export var seed_offset: float = 0.0

# Combat
@export var damage: float = 25.0

# Particles
@export var particles_enabled: bool = true
@export var particles_amount: int = 20
@export var particles_size: float = 3.0  # Pixel size
@export var particles_speed: float = 30.0
@export var particles_lifetime: float = 0.4
@export var particles_spread: float = 0.3  # Angle spread of sparks (0-1)
@export var particles_drag: float = 1.0  # How quickly sparks slow down (0-2)
@export var particles_outward: float = 0.7  # How much sparks shoot outward vs backward (0-1)
@export var particles_radius: float = 1.0  # Where sparks spawn: 0 = inner, 1 = outer edge
@export var particles_color: Color = Color(1.0, 1.0, 1.0, 0.8)  # Tint (uses arc colors if white)


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
		"chromatic_aberration": chromatic_aberration,
		"pulse_strength": pulse_strength,
		"pulse_speed": pulse_speed,
		"electric_strength": electric_strength,
		"electric_frequency": electric_frequency,
		"electric_speed": electric_speed,
		"rotation_offset_deg": rotation_offset_deg,
		"seed_offset": seed_offset,
		"damage": damage,
		"particles_enabled": particles_enabled,
		"particles_amount": particles_amount,
		"particles_size": particles_size,
		"particles_speed": particles_speed,
		"particles_lifetime": particles_lifetime,
		"particles_spread": particles_spread,
		"particles_drag": particles_drag,
		"particles_outward": particles_outward,
		"particles_radius": particles_radius,
		"particles_color": particles_color,
	}


func apply_to(arc: RadiantArc) -> RadiantArc:
	"""Apply this config to a RadiantArc instance."""
	return arc.setup(to_dict())
