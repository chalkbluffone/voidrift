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


## Return the nearest Node2D in the "enemies" group to [param origin],
## or null if the group is empty / all members are invalid.
static func find_nearest_enemy(tree: SceneTree, origin: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy in tree.get_nodes_in_group("enemies"):
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
	for enemy in tree.get_nodes_in_group("enemies"):
		if enemy is Node2D and is_instance_valid(enemy):
			if origin.distance_to((enemy as Node2D).global_position) < radius:
				return true
	return false


## Return all valid enemies within [param radius] of [param center], sorted
## nearest-first.  Used by multi-target weapons like Space Nukes.
static func find_enemies_in_range(tree: SceneTree, center: Vector2, radius: float) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for enemy_any in tree.get_nodes_in_group("enemies"):
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
