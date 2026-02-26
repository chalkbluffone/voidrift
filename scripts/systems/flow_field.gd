class_name FlowField
extends Node

## FlowField - Precomputed BFS navigation grid for enemy pathfinding.
## Covers the circular arena with a square grid of direction vectors.
## Each cell stores a normalized direction toward the player, routed around
## blocked cells (asteroids). Enemies sample `get_direction()` for smooth,
## consistent, O(1) pathing that avoids obstacle-induced jitter.

## Emitted after each BFS recompute finishes.
signal field_updated

# -------------------------------------------------------------------------
# Grid state
# -------------------------------------------------------------------------

## World-space position of grid cell (0, 0) top-left corner.
var _origin: Vector2 = Vector2.ZERO

## Grid dimensions (cells).
var _grid_w: int = 0
var _grid_h: int = 0
var _total_cells: int = 0
var _cell_size: float = 64.0

## Direction toward player for each grid cell (flat row-major index).
var _directions: PackedVector2Array = PackedVector2Array()

## 1 = blocked (obstacle / out-of-arena), 0 = passable.
var _blocked: PackedByteArray = PackedByteArray()

# -------------------------------------------------------------------------
# BFS work buffers — pre-allocated, reused every update
# -------------------------------------------------------------------------

var _bfs_queue: PackedInt32Array = PackedInt32Array()
var _bfs_visited: PackedByteArray = PackedByteArray()

# -------------------------------------------------------------------------
# 8-directional neighbour table
# -------------------------------------------------------------------------

## Horizontal offsets for 8 compass neighbours.
var _ndx: PackedInt32Array = PackedInt32Array([1, -1, 0, 0, 1, -1, 1, -1])
## Vertical offsets for 8 compass neighbours.
var _ndy: PackedInt32Array = PackedInt32Array([0, 0, 1, -1, 1, 1, -1, -1])
## Precomputed direction vectors (from neighbour toward its BFS parent = toward player).
var _ndir: PackedVector2Array = PackedVector2Array()

# -------------------------------------------------------------------------
# Timing
# -------------------------------------------------------------------------

var _update_timer: float = 0.0
var _is_setup: bool = false


func _ready() -> void:
	add_to_group("flow_field")

	# Precompute normalised direction vectors for each neighbour offset.
	_ndir.resize(8)
	for i: int in range(8):
		_ndir[i] = Vector2(float(-_ndx[i]), float(-_ndy[i])).normalized()


# =========================================================================
# Public API
# =========================================================================

## Initialise the grid and mark obstacles. Call once after asteroids are spawned.
## @param arena_radius: World-space radius of the circular play area.
## @param cell_size: Width/height of each grid cell in pixels.
## @param asteroids: Array of asteroid Node2D instances (must have effective_radius).
## @param obstacle_buffer: Extra clearance around each asteroid (pixels).
func setup(arena_radius: float, cell_size: float, asteroids: Array[Node], obstacle_buffer: float) -> void:
	_cell_size = cell_size
	var diameter: float = arena_radius * 2.0
	_grid_w = int(ceil(diameter / cell_size)) + 2  # +2 for margin
	_grid_h = _grid_w
	_total_cells = _grid_w * _grid_h
	_origin = Vector2(-arena_radius - cell_size, -arena_radius - cell_size)

	# Allocate arrays
	_directions.resize(_total_cells)
	_blocked.resize(_total_cells)
	_bfs_queue.resize(_total_cells)
	_bfs_visited.resize(_total_cells)

	_blocked.fill(0)

	# --- Mark cells outside the arena as blocked ---
	var arena_r_sq: float = arena_radius * arena_radius
	for cy: int in range(_grid_h):
		for cx: int in range(_grid_w):
			var world_pos: Vector2 = _cell_to_world(cx, cy)
			if world_pos.length_squared() > arena_r_sq:
				_blocked[cy * _grid_w + cx] = 1

	# --- Mark asteroid cells as blocked ---
	for node: Node in asteroids:
		if not node is Node2D:
			continue
		var asteroid: Node2D = node as Node2D
		var pos: Vector2 = asteroid.global_position
		var radius: float = 64.0
		if "effective_radius" in asteroid:
			radius = float(asteroid.get("effective_radius"))
		radius += obstacle_buffer

		var min_cx: int = maxi(0, int((pos.x - radius - _origin.x) / _cell_size))
		var max_cx: int = mini(_grid_w - 1, int((pos.x + radius - _origin.x) / _cell_size))
		var min_cy: int = maxi(0, int((pos.y - radius - _origin.y) / _cell_size))
		var max_cy: int = mini(_grid_h - 1, int((pos.y + radius - _origin.y) / _cell_size))

		for cy: int in range(min_cy, max_cy + 1):
			for cx: int in range(min_cx, max_cx + 1):
				var cell_center: Vector2 = _cell_to_world(cx, cy)
				if cell_center.distance_to(pos) < radius:
					_blocked[cy * _grid_w + cx] = 1

	_is_setup = true


## Run BFS from the player position to recompute the entire direction field.
func update_field(player_position: Vector2) -> void:
	if not _is_setup:
		return

	_bfs_visited.fill(0)

	# Convert player position to grid cell
	var pcx: int = clampi(int((player_position.x - _origin.x) / _cell_size), 0, _grid_w - 1)
	var pcy: int = clampi(int((player_position.y - _origin.y) / _cell_size), 0, _grid_h - 1)
	var start_idx: int = pcy * _grid_w + pcx

	# BFS init
	var head: int = 0
	var tail: int = 0
	_bfs_queue[tail] = start_idx
	tail += 1
	_bfs_visited[start_idx] = 1
	_directions[start_idx] = Vector2.ZERO

	# BFS loop
	while head < tail:
		var cur_idx: int = _bfs_queue[head]
		head += 1

		var cx: int = cur_idx % _grid_w
		var cy: int = cur_idx / _grid_w

		for i: int in range(8):
			var nx: int = cx + _ndx[i]
			var ny: int = cy + _ndy[i]

			if nx < 0 or nx >= _grid_w or ny < 0 or ny >= _grid_h:
				continue

			var n_idx: int = ny * _grid_w + nx

			if _bfs_visited[n_idx] == 1 or _blocked[n_idx] == 1:
				continue

			_bfs_visited[n_idx] = 1
			_directions[n_idx] = _ndir[i]
			_bfs_queue[tail] = n_idx
			tail += 1

	field_updated.emit()


## Sample the flow direction at a world position.
## Returns a normalised direction toward the player, routed around obstacles.
## Uses bilinear interpolation of the 4 nearest cell centres for smooth paths.
func get_direction(world_pos: Vector2) -> Vector2:
	if not _is_setup:
		return Vector2.ZERO

	# Fractional grid coordinates relative to cell centres
	var local_x: float = (world_pos.x - _origin.x) / _cell_size - 0.5
	var local_y: float = (world_pos.y - _origin.y) / _cell_size - 0.5

	var x0: int = int(floor(local_x))
	var y0: int = int(floor(local_y))
	var x1: int = x0 + 1
	var y1: int = y0 + 1
	var fx: float = local_x - float(x0)
	var fy: float = local_y - float(y0)

	var d00: Vector2 = _safe_dir(x0, y0)
	var d10: Vector2 = _safe_dir(x1, y0)
	var d01: Vector2 = _safe_dir(x0, y1)
	var d11: Vector2 = _safe_dir(x1, y1)

	var result: Vector2 = (
		d00 * (1.0 - fx) * (1.0 - fy)
		+ d10 * fx * (1.0 - fy)
		+ d01 * (1.0 - fx) * fy
		+ d11 * fx * fy
	)

	if result.length_squared() > 0.001:
		return result.normalized()
	return Vector2.ZERO


# =========================================================================
# Auto-update
# =========================================================================

func _physics_process(delta: float) -> void:
	if not _is_setup:
		return

	_update_timer += delta
	if _update_timer < GameConfig.FLOW_FIELD_UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return
	var player: Node2D = players[0] as Node2D
	if player == null:
		return

	update_field(player.global_position)


# =========================================================================
# Helpers
# =========================================================================

## Convert grid cell (cx, cy) to its world-space centre point.
func _cell_to_world(cx: int, cy: int) -> Vector2:
	return _origin + Vector2((float(cx) + 0.5) * _cell_size, (float(cy) + 0.5) * _cell_size)


## Safe direction lookup — returns Vector2.ZERO for blocked or out-of-bounds cells
## so bilinear interpolation gracefully blends around obstacles.
func _safe_dir(cx: int, cy: int) -> Vector2:
	cx = clampi(cx, 0, _grid_w - 1)
	cy = clampi(cy, 0, _grid_h - 1)
	var idx: int = cy * _grid_w + cx
	if _blocked[idx] == 1:
		return Vector2.ZERO
	return _directions[idx]
