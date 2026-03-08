extends Node

## FrameCache — Per-frame cache for expensive group queries and spatial structures.
## Rebuilt once at the start of each _process frame.  All systems read from here
## instead of calling get_nodes_in_group() individually.
##
## Access from ANY script via the autoload name:
##   FrameCache.enemies
##   FrameCache.damage_numbers
##   FrameCache.enemy_grid

## Cached enemy list (rebuilt once per frame).
var enemies: Array[Node] = []

## Cached damage number list (rebuilt once per frame).
var damage_numbers: Array[Node] = []

## Spatial hash grid for fast enemy neighbor queries (separation, targeting).
var enemy_grid: SpatialHashGrid = null

## The physics frame counter used to detect stale data.
var _last_frame: int = -1


func _ready() -> void:
	# Ensure this runs before other _process calls
	process_priority = -100
	enemy_grid = SpatialHashGrid.new(GameConfig.ENEMY_SEPARATION_RADIUS * 2.0)


func _process(_delta: float) -> void:
	_rebuild()


func _rebuild() -> void:
	var frame: int = Engine.get_process_frames()
	if frame == _last_frame:
		return
	_last_frame = frame

	# --- Enemy list + spatial grid ---
	enemies = get_tree().get_nodes_in_group("enemies")
	enemy_grid.clear()
	for enemy: Node in enemies:
		if enemy is Node2D:
			enemy_grid.insert(enemy as Node2D)

	# --- Damage numbers ---
	damage_numbers = get_tree().get_nodes_in_group("damage_numbers")
