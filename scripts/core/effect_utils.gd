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
