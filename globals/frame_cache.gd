extends Node

## FrameCache — Per-frame cache for expensive group queries and spatial structures.
## Rebuilt once at the start of each _process frame.  All systems read from here
## instead of calling get_nodes_in_group() individually.
##
## Access from ANY script via the autoload name:
##   FrameCache.enemies
##   FrameCache.damage_numbers
##   FrameCache.enemy_grid
##   FrameCache.pickups
##   FrameCache.powerups
##   FrameCache.stations
##   FrameCache.asteroids
##   FrameCache.player  (Node2D or null)

## Cached enemy list (rebuilt once per frame).
var enemies: Array[Node] = []

## Cached damage number list (rebuilt once per frame).
var damage_numbers: Array[Node] = []

## Cached pickup list (rebuilt once per frame).
var pickups: Array[Node] = []

## Cached power-up list (rebuilt once per frame).
var powerups: Array[Node] = []

## Cached station list (rebuilt once at run start, then on change).
var stations: Array[Node] = []

## Cached asteroid list (rebuilt once at run start).
var asteroids: Array[Node] = []

## Cached player reference (rebuilt once per frame).
var player: Node2D = null

## Spatial hash grid for fast enemy neighbor queries (separation, targeting).
var enemy_grid: SpatialHashGrid = null

## The physics frame counter used to detect stale data.
var _last_frame: int = -1

## Whether static groups (asteroids, stations) have been cached.
var _statics_cached: bool = false


func _ready() -> void:
	# Ensure this runs before other _process calls
	process_priority = -100
	enemy_grid = SpatialHashGrid.new(GameConfig.ENEMY_GRID_CELL_SIZE)


func _process(_delta: float) -> void:
	_rebuild()


## Call once after world setup to cache static groups (asteroids, stations).
func cache_statics() -> void:
	asteroids = get_tree().get_nodes_in_group("asteroids")
	stations = get_tree().get_nodes_in_group("stations")
	_statics_cached = true


## Call when a station is removed/depleted so the cache stays accurate.
func invalidate_stations() -> void:
	stations = get_tree().get_nodes_in_group("stations")


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

	# --- Pickups + power-ups (dynamic, change every frame) ---
	pickups = get_tree().get_nodes_in_group("pickups")
	powerups = get_tree().get_nodes_in_group("powerups")

	# --- Player reference ---
	if player == null or not is_instance_valid(player):
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		player = players[0] as Node2D if players.size() > 0 else null

	# --- Static groups (lazy init if not explicitly called) ---
	if not _statics_cached:
		cache_statics()
