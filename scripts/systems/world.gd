extends Node2D

@export var stars_far_rect_path: NodePath
@export var stars_near_rect_path: NodePath

const ArenaBoundaryScene: PackedScene = preload("res://scenes/gameplay/arena_boundary.tscn")

@onready var _settings: Node = get_node("/root/SettingsManager")
var _stars_near_layer: Node = null
var _arena_boundary: Node2D = null
var _asteroid_spawner: AsteroidSpawner = null
var _station_spawner: StationSpawner = null
var _flow_field: FlowField = null

func _enter_tree() -> void:
	randomize()
	GameSeed.set_seed_from_int(randi())

func _ready() -> void:
	_set_star_seed(stars_far_rect_path, "stars_far")
	_set_star_seed(stars_near_rect_path, "stars_near")

	# Cache the StarsNear Parallax2D parent for quality toggling
	var near_rect: ColorRect = get_node_or_null(stars_near_rect_path) as ColorRect
	if near_rect:
		_stars_near_layer = near_rect.get_parent()

	_apply_background_quality()
	_settings.settings_changed.connect(_on_settings_changed)
	
	# Setup arena boundary
	_setup_arena_boundary()
	
	# Spawn asteroids (terrain placed first)
	var asteroid_positions: Array[Vector2] = _setup_asteroids()
	
	# Build flow field for enemy pathfinding around asteroids
	_setup_flow_field()
	
	# Spawn space stations (avoids asteroid positions)
	_setup_stations(asteroid_positions)
	
	# Spawn player at random safe position (avoids asteroids)
	_setup_player_spawn(asteroid_positions)

	# Start the run if no main menu launched it
	if RunManager.current_state != RunManager.GameState.PLAYING:
		RunManager.current_state = RunManager.GameState.PLAYING
		RunManager.run_data.time_elapsed = 0.0
		RunManager.run_data.time_remaining = RunManager.run_duration


## Setup the arena boundary (radiation belt).
func _setup_arena_boundary() -> void:
	_arena_boundary = ArenaBoundaryScene.instantiate()
	_arena_boundary.position = Vector2.ZERO
	# Insert before Ship so it renders behind gameplay elements
	add_child(_arena_boundary)
	move_child(_arena_boundary, 1)  # After Starfield


## Move the player ship to a random safe spawn position, avoiding asteroids.
func _setup_player_spawn(obstacle_positions: Array[Vector2]) -> void:
	var ship: Node2D = get_node_or_null("Ship") as Node2D
	if not ship:
		return

	var clearance: float = GameConfig.ASTEROID_SIZE_MAX + 40.0
	var max_attempts: int = 50

	for attempt: int in range(max_attempts):
		var candidate: Vector2 = ArenaUtils.get_random_spawn_position()
		var is_clear: bool = true
		for obs_pos: Vector2 in obstacle_positions:
			if candidate.distance_to(obs_pos) < clearance:
				is_clear = false
				break
		if is_clear:
			ship.global_position = candidate
			return

	# Final fallback: spawn at arena center (always clear)
	ship.global_position = Vector2.ZERO


## Spawn asteroids across the arena.
## Returns the placed positions so stations can avoid them.
func _setup_asteroids() -> Array[Vector2]:
	var asteroids_container: Node2D = Node2D.new()
	asteroids_container.name = "Asteroids"
	asteroids_container.z_index = -1
	add_child(asteroids_container)
	# Insert after ArenaBoundary so asteroids render above belt but below Ship
	move_child(asteroids_container, 2)

	_asteroid_spawner = AsteroidSpawner.new()
	return _asteroid_spawner.spawn_asteroids(asteroids_container)


## Build the flow field navigation grid for enemy pathfinding.
func _setup_flow_field() -> void:
	_flow_field = FlowField.new()
	_flow_field.name = "FlowField"
	add_child(_flow_field)

	var asteroids: Array[Node] = get_tree().get_nodes_in_group("asteroids")
	_flow_field.setup(
		GameConfig.ARENA_RADIUS,
		GameConfig.FLOW_FIELD_CELL_SIZE,
		asteroids,
		GameConfig.FLOW_FIELD_OBSTACLE_BUFFER,
	)

	# First update so enemies spawned immediately have a valid field
	var ship: Node2D = get_node_or_null("Ship") as Node2D
	if ship:
		_flow_field.update_field(ship.global_position)


## Spawn space stations around the arena, avoiding asteroid positions.
func _setup_stations(obstacle_positions: Array[Vector2]) -> void:
	var stations_container: Node2D = get_node_or_null("Stations") as Node2D
	if not stations_container:
		stations_container = Node2D.new()
		stations_container.name = "Stations"
		add_child(stations_container)
	
	_station_spawner = StationSpawner.new()
	_station_spawner.spawn_stations(stations_container, obstacle_positions)


func _on_settings_changed() -> void:
	_apply_background_quality()


## Show/hide near-star layer and disable twinkle based on background_quality.
func _apply_background_quality() -> void:
	var quality: int = _settings.background_quality  # 0=Low, 1=High
	if _stars_near_layer and _stars_near_layer is CanvasItem:
		(_stars_near_layer as CanvasItem).visible = (quality >= 1)

	# Disable twinkle on far stars when Low
	var far_rect: ColorRect = get_node_or_null(stars_far_rect_path) as ColorRect
	if far_rect:
		var mat: ShaderMaterial = far_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("twinkle", 0.1 if quality >= 1 else 0.0)


func _set_star_seed(rect_path: NodePath, ns: String) -> void:
	var rect: ColorRect = get_node(rect_path) as ColorRect
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("seed", GameSeed.derive_seed(ns))
