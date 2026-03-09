class_name SpatialHashGrid
extends RefCounted

## SpatialHashGrid — fixed-cell spatial hash for fast neighbor queries.
## Used to replace O(n²) brute-force enemy separation checks.
## O(1) insert, O(k) radius query where k = nearby entities.

var _cell_size: float = 100.0
var _inv_cell_size: float = 0.01
var _cells: Dictionary = {}  # Vector2i -> Array[Node2D]


func _init(cell_size: float = 100.0) -> void:
	_cell_size = maxf(cell_size, 1.0)
	_inv_cell_size = 1.0 / _cell_size


## Remove all entities from the grid (reuses bucket arrays to avoid GC churn).
func clear() -> void:
	for key: Vector2i in _cells:
		(_cells[key] as Array).clear()


## Insert an entity into the grid based on its global_position.
func insert(entity: Node2D) -> void:
	var key: Vector2i = _pos_to_cell(entity.global_position)
	if not _cells.has(key):
		_cells[key] = []
	_cells[key].append(entity)


## Query all entities within radius of pos. Returns Array[Node2D].
func query_radius(pos: Vector2, radius: float) -> Array[Node2D]:
	var results: Array[Node2D] = []
	var radius_sq: float = radius * radius
	var cell_radius: int = ceili(radius * _inv_cell_size)
	var center_cell: Vector2i = _pos_to_cell(pos)

	for dy: int in range(-cell_radius, cell_radius + 1):
		for dx: int in range(-cell_radius, cell_radius + 1):
			var key: Vector2i = Vector2i(center_cell.x + dx, center_cell.y + dy)
			if not _cells.has(key):
				continue
			var bucket: Array = _cells[key]
			for entity: Variant in bucket:
				if not is_instance_valid(entity):
					continue
				var node: Node2D = entity as Node2D
				if node:
					var dist_sq: float = pos.distance_squared_to(node.global_position)
					if dist_sq <= radius_sq:
						results.append(node)

	return results


func _pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floorf(pos.x * _inv_cell_size)), int(floorf(pos.y * _inv_cell_size)))
