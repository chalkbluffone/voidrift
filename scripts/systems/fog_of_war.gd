class_name FogOfWar
extends RefCounted

## FogOfWar - Manages binary fog of war state for the minimap.
## Tracks which cells of the arena have been explored by the player.

var _grid_size: int = 128
var _cell_size: float = 250.0  # World units per cell
var _explored: PackedByteArray
var _fog_image: Image
var _fog_texture: ImageTexture
var _arena_radius: float = 16000.0


func _init() -> void:
	_grid_size = GameConfig.FOG_GRID_SIZE
	_arena_radius = GameConfig.ARENA_RADIUS
	_cell_size = (_arena_radius * 2.0) / float(_grid_size)
	
	# Initialize explored grid (all unexplored = 0)
	_explored = PackedByteArray()
	_explored.resize(_grid_size * _grid_size)
	_explored.fill(0)
	
	# Create fog image (white = explored, black = unexplored)
	_fog_image = Image.create(_grid_size, _grid_size, false, Image.FORMAT_L8)
	_fog_image.fill(Color.BLACK)
	
	# Create texture from image
	_fog_texture = ImageTexture.create_from_image(_fog_image)


## Returns the full fog texture for shader sampling.
func get_full_texture() -> ImageTexture:
	return _fog_texture


## Returns a fog texture centered on the given world position covering the view range.
## The texture maps UV (0-1) to the view area around center_pos.
func get_texture(center_pos: Vector2, view_radius: float) -> ImageTexture:
	# Create a smaller texture for the viewport
	var view_size: int = 64  # Texture resolution for view
	var view_image: Image = Image.create(view_size, view_size, false, Image.FORMAT_L8)
	
	# Sample the fog grid for the view area
	for y: int in range(view_size):
		for x: int in range(view_size):
			# Map texture pixel to world position
			var uv_x: float = (float(x) + 0.5) / float(view_size)
			var uv_y: float = (float(y) + 0.5) / float(view_size)
			var world_offset: Vector2 = Vector2(
				(uv_x - 0.5) * 2.0 * view_radius,
				(uv_y - 0.5) * 2.0 * view_radius
			)
			var world_pos: Vector2 = center_pos + world_offset
			
			# Check if explored
			var is_exp: bool = is_explored(world_pos)
			view_image.set_pixel(x, y, Color.WHITE if is_exp else Color.BLACK)
	
	return ImageTexture.create_from_image(view_image)


## Reveal area around a world position with given radius.
func reveal_radius(world_pos: Vector2, radius: float) -> void:
	var center_cell: Vector2i = _world_to_cell(world_pos)
	var cell_radius: int = ceili(radius / _cell_size)
	
	var changed: bool = false
	
	for dy: int in range(-cell_radius, cell_radius + 1):
		for dx: int in range(-cell_radius, cell_radius + 1):
			var cell: Vector2i = center_cell + Vector2i(dx, dy)
			
			# Check if within circular radius
			var cell_world: Vector2 = _cell_to_world(cell)
			if cell_world.distance_to(world_pos) <= radius:
				if _reveal_cell(cell):
					changed = true
	
	if changed:
		_update_texture()


## Returns true if the given world position has been explored.
func is_explored(world_pos: Vector2) -> bool:
	var cell: Vector2i = _world_to_cell(world_pos)
	return _get_cell_explored(cell)


## Convert world position to grid cell coordinates.
func _world_to_cell(world_pos: Vector2) -> Vector2i:
	# World goes from -arena_radius to +arena_radius
	# Grid goes from 0 to grid_size-1
	var normalized: Vector2 = (world_pos + Vector2(_arena_radius, _arena_radius)) / (_arena_radius * 2.0)
	var cell_x: int = clampi(int(normalized.x * _grid_size), 0, _grid_size - 1)
	var cell_y: int = clampi(int(normalized.y * _grid_size), 0, _grid_size - 1)
	return Vector2i(cell_x, cell_y)


## Convert grid cell to world position (center of cell).
func _cell_to_world(cell: Vector2i) -> Vector2:
	var x: float = (float(cell.x) + 0.5) / float(_grid_size) * (_arena_radius * 2.0) - _arena_radius
	var y: float = (float(cell.y) + 0.5) / float(_grid_size) * (_arena_radius * 2.0) - _arena_radius
	return Vector2(x, y)


## Get index into flat array from cell coordinates.
func _cell_to_index(cell: Vector2i) -> int:
	return cell.y * _grid_size + cell.x


## Check if cell is within grid bounds.
func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _grid_size and cell.y >= 0 and cell.y < _grid_size


## Get explored state for a cell.
func _get_cell_explored(cell: Vector2i) -> bool:
	if not _is_valid_cell(cell):
		return false
	return _explored[_cell_to_index(cell)] > 0


## Set a cell as explored. Returns true if state changed.
func _reveal_cell(cell: Vector2i) -> bool:
	if not _is_valid_cell(cell):
		return false
	
	var idx: int = _cell_to_index(cell)
	if _explored[idx] > 0:
		return false  # Already explored
	
	_explored[idx] = 255
	_fog_image.set_pixel(cell.x, cell.y, Color.WHITE)
	return true


## Update the texture from the image.
func _update_texture() -> void:
	_fog_texture.update(_fog_image)


## Get exploration percentage (0.0 to 1.0).
func get_exploration_percent() -> float:
	var explored_count: int = 0
	for i: int in range(_explored.size()):
		if _explored[i] > 0:
			explored_count += 1
	return float(explored_count) / float(_explored.size())
