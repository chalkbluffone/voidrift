class_name TothianMineSpawner

## Spawner for Tothian Mines.
## 3-arg spawn signature: (pos, params, follow_source).
## Drops one mine at the ship position and enforces an active mine cap.

var _parent_node: Node
var _active_mines: Array = []


func _init(parent: Node) -> void:
	_parent_node = parent


func spawn(spawn_pos: Vector2, params: Dictionary = {}, _follow_source: Node2D = null) -> Node2D:
	if _parent_node == null:
		return null

	_active_mines = _active_mines.filter(
		func(inst: Node) -> bool: return is_instance_valid(inst) and inst.is_inside_tree()
	)

	var max_active_mines: int = int(params.get("max_active_mines", 12))
	if max_active_mines < 1:
		max_active_mines = 1
	if _active_mines.size() >= max_active_mines:
		return null

	var scene: PackedScene = load("res://effects/tothian_mines/TothianMine.tscn")
	if scene == null:
		return null

	var mine: Node2D = scene.instantiate()
	_parent_node.add_child(mine)

	if params and mine.has_method("setup"):
		mine.setup(params)

	if mine.has_method("spawn_at"):
		mine.spawn_at(spawn_pos)
	else:
		mine.global_position = spawn_pos

	_active_mines.append(mine)
	if mine.has_signal("tree_exited"):
		mine.tree_exited.connect(func() -> void:
			_active_mines.erase(mine)
		)

	return mine


func cleanup() -> void:
	for mine in _active_mines:
		if is_instance_valid(mine):
			mine.queue_free()
	_active_mines.clear()
