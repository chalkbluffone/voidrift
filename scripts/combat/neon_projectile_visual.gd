class_name NeonProjectileVisual
extends Node2D

## Base for neon projectile visual effects.
## Subclasses override _draw() to render their specific shape (circles, capsules, lines).
## Provides shared glow properties and a helper for computing glow-layer colors.

var color_core: Color = Color.WHITE
var color_glow: Color = Color(0.0, 1.0, 1.0, 1.0)
var glow_strength: float = 2.0


## Build a glow-layer color from the glow palette.
## @param t Fade factor (1.0 = outermost layer, approaches 0.0 = innermost)
## @param base_alpha Per-layer base opacity before strength scaling
func _glow_color(t: float, base_alpha: float = 0.12) -> Color:
	return Color(color_glow.r, color_glow.g, color_glow.b, base_alpha * t * glow_strength)
