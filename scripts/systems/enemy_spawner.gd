extends Node2D

## EnemySpawner - Spawns enemies around the player in waves.
## Supports weighted random enemy selection, elite enemies, swarm events, and loot freighter drops.

signal swarm_warning_started
signal swarm_started
signal swarm_ended

const XPPickupScene: PackedScene = preload("res://scenes/pickups/xp_pickup.tscn")
const CreditPickupScene: PackedScene = preload("res://scenes/pickups/credit_pickup.tscn")
const StardustPickupScene: PackedScene = preload("res://scenes/pickups/stardust_pickup.tscn")

var _player: Node2D = null
var _spawn_timer: float = 0.0

## Cached enemy pool: Array of { data: Dictionary, scene: PackedScene, weight: float }
var _enemy_pool: Array[Dictionary] = []
var _total_weight: float = 0.0

## Swarm state
var _swarm_active: bool = false
var _swarm_timer: float = 0.0
var _swarms_triggered: int = 0  # How many swarms have been triggered this run

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var GameConfig: Node = get_node("/root/GameConfig")
@onready var DataLoader: Node = get_node("/root/DataLoader")


func _ready() -> void:
	add_to_group("enemy_spawner")
	_find_player()
	_build_enemy_pool()


func _process(delta: float) -> void:
	if not _player:
		_find_player()
		return
	
	# Check for swarm triggers
	_check_swarm_triggers()
	
	# Update swarm timer if active
	if _swarm_active:
		_swarm_timer -= delta
		if _swarm_timer <= 0.0:
			_end_swarm()
	
	_spawn_timer -= delta
	if _spawn_timer <= 0:
		var batch_size: int = _get_batch_size()
		for i: int in range(batch_size):
			_spawn_enemy()
		_spawn_timer = _get_spawn_interval()


func _find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _get_spawn_interval() -> float:
	var time_minutes: float = RunManager.run_data.time_elapsed / 60.0
	var current_rate: float = GameConfig.BASE_SPAWN_RATE + (GameConfig.SPAWN_RATE_GROWTH * time_minutes)
	
	# Overtime: extra spawn ramp after countdown hits zero
	var overtime_seconds: float = maxf(0.0, -RunManager.run_data.time_remaining)
	if overtime_seconds > 0.0:
		current_rate += GameConfig.OVERTIME_SPAWN_RATE_GROWTH * (overtime_seconds / 60.0)
	
	# Difficulty stat scales spawn rate
	var difficulty_stat: float = _get_player_difficulty_stat()
	current_rate *= (1.0 + difficulty_stat * GameConfig.DIFFICULTY_SPAWN_WEIGHT)
	
	# Swarm multiplier
	if _swarm_active:
		current_rate *= GameConfig.SWARM_SPAWN_MULTIPLIER
	
	return 1.0 / maxf(current_rate, 0.1)


## How many enemies spawn per tick. Starts at 1, grows after SPAWN_BATCH_MIN_MINUTE.
func _get_batch_size() -> int:
	var time_minutes: float = RunManager.run_data.time_elapsed / 60.0
	if time_minutes < GameConfig.SPAWN_BATCH_MIN_MINUTE:
		return 1
	var extra_minutes: float = time_minutes - GameConfig.SPAWN_BATCH_MIN_MINUTE
	return 1 + int(extra_minutes * GameConfig.SPAWN_BATCH_SIZE_PER_MINUTE)


## Find a spawn position around the player that doesn't overlap with any asteroid.
## Uses each asteroid's actual effective_radius + buffer for accurate collision checks.
func _find_spawn_position() -> Vector2:
	var asteroids: Array[Node] = get_tree().get_nodes_in_group("asteroids")
	var buffer: float = 30.0  # Extra clearance beyond asteroid edge
	var max_attempts: int = 30

	for attempt: int in range(max_attempts):
		var angle: float = randf() * TAU
		var distance: float = randf_range(GameConfig.SPAWN_RADIUS_MIN, GameConfig.SPAWN_RADIUS_MAX)
		var candidate: Vector2 = _player.global_position + Vector2.from_angle(angle) * distance

		var overlaps: bool = false
		for asteroid: Node in asteroids:
			if not asteroid is Node2D:
				continue
			var asteroid_2d: Node2D = asteroid as Node2D
			var radius: float = GameConfig.ASTEROID_SIZE_MAX
			if "effective_radius" in asteroid_2d:
				radius = float(asteroid_2d.get("effective_radius"))
			if candidate.distance_to(asteroid_2d.global_position) < radius + buffer:
				overlaps = true
				break

		if not overlaps:
			return candidate

	# Fallback: try spawning further away from player to find open space
	for attempt: int in range(max_attempts):
		var angle: float = randf() * TAU
		var distance: float = randf_range(GameConfig.SPAWN_RADIUS_MAX, GameConfig.SPAWN_RADIUS_MAX * 1.5)
		var candidate: Vector2 = _player.global_position + Vector2.from_angle(angle) * distance

		var overlaps: bool = false
		for asteroid: Node in asteroids:
			if not asteroid is Node2D:
				continue
			var asteroid_2d: Node2D = asteroid as Node2D
			var radius: float = GameConfig.ASTEROID_SIZE_MAX
			if "effective_radius" in asteroid_2d:
				radius = float(asteroid_2d.get("effective_radius"))
			if candidate.distance_to(asteroid_2d.global_position) < radius + buffer:
				overlaps = true
				break

		if not overlaps:
			return candidate

	# Last resort: spawn directly behind player (opposite to facing direction)
	var behind_dir: Vector2 = -_player.global_position.normalized()
	if behind_dir.length_squared() < 0.01:
		behind_dir = Vector2.RIGHT
	return _player.global_position + behind_dir * GameConfig.SPAWN_RADIUS_MIN


func _spawn_enemy() -> void:
	if not _player:
		return
	if _enemy_pool.is_empty():
		return

	# Weighted random enemy selection
	var entry: Dictionary = _pick_weighted_enemy()
	var enemy_data: Dictionary = entry.get("data", {})
	var enemy_scene: PackedScene = entry.get("scene", null) as PackedScene
	if enemy_scene == null:
		return

	var enemy: CharacterBody2D = enemy_scene.instantiate()

	# Position at random angle around player, avoiding asteroids
	var spawn_pos: Vector2 = _find_spawn_position()

	enemy.global_position = spawn_pos

	# Apply base stats from enemy data (JSON) before scaling
	var base_stats: Dictionary = enemy_data.get("base_stats", {})
	enemy.max_hp = float(base_stats.get("hp", enemy.max_hp))
	enemy.contact_damage = float(base_stats.get("damage", enemy.contact_damage))
	enemy.move_speed = float(base_stats.get("speed", enemy.move_speed))
	enemy.credit_value = int(base_stats.get("credits_value", enemy.credit_value))
	enemy.stardust_value = int(base_stats.get("stardust_value", 0))

	# Apply freighter-specific stats if applicable
	if enemy is LootFreighter and base_stats.has("flee_speed"):
		enemy.flee_speed = float(base_stats.get("flee_speed", 150.0))
	if enemy is LootFreighter and base_stats.has("drop_burst_count"):
		enemy.drop_burst_count = int(base_stats.get("drop_burst_count", 5))

	# --- Determine if this is an elite ---
	var is_elite: bool = _roll_for_elite()
	if is_elite:
		enemy.enemy_type = "elite"
	
	# --- Calculate scaling multipliers ---
	var time_minutes: float = RunManager.run_data.time_elapsed / 60.0
	var difficulty_stat: float = _get_player_difficulty_stat()
	
	# HP scales polynomially with time, then multiplied by difficulty
	# Formula: hp_mult = (1 + time^exponent) * (1 + difficulty * weight)
	var time_hp_mult: float = 1.0 + pow(time_minutes, GameConfig.ENEMY_HP_EXPONENT)
	var diff_hp_mult: float = 1.0 + (difficulty_stat * GameConfig.DIFFICULTY_HP_WEIGHT)
	var hp_mult: float = time_hp_mult * diff_hp_mult
	
	# Damage scales linearly with time, then multiplied by difficulty
	var time_damage_mult: float = 1.0 + (time_minutes * GameConfig.ENEMY_DAMAGE_SCALE_PER_MINUTE)
	var diff_damage_mult: float = 1.0 + (difficulty_stat * GameConfig.DIFFICULTY_DAMAGE_WEIGHT)
	var damage_mult: float = time_damage_mult * diff_damage_mult
	
	# Apply elite multipliers
	if is_elite:
		hp_mult *= GameConfig.ELITE_HP_MULT
		damage_mult *= GameConfig.ELITE_DAMAGE_MULT
	
	# Apply final stats
	enemy.max_hp *= hp_mult
	enemy.current_hp = enemy.max_hp
	enemy.contact_damage *= damage_mult
	
	# XP is static (no scaling) — set based on enemy type
	enemy.xp_value = GameConfig.ENEMY_XP_ELITE if is_elite else GameConfig.ENEMY_XP_NORMAL

	# Speed only increases in overtime (after countdown hits zero)
	var overtime_seconds: float = maxf(0.0, -RunManager.run_data.time_remaining)
	if overtime_seconds > 0.0:
		enemy.move_speed += GameConfig.ENEMY_OVERTIME_SPEED_PER_MINUTE * (overtime_seconds / 60.0)
	# Cap enemy speed at player base speed — never outrun the player
	enemy.move_speed = minf(enemy.move_speed, GameConfig.PLAYER_BASE_SPEED)
	
	# Apply elite visuals (color tint + size)
	if is_elite:
		_apply_elite_visuals(enemy)

	# Connect death signal for drops
	enemy.died.connect(_on_enemy_died)

	get_tree().current_scene.add_child(enemy)


## Build the weighted enemy pool from DataLoader on startup.
func _build_enemy_pool() -> void:
	_enemy_pool.clear()
	_total_weight = 0.0
	var all_enemies: Array[Dictionary] = DataLoader.get_all_enemies()
	for enemy_data: Dictionary in all_enemies:
		var scene_path: String = String(enemy_data.get("scene", ""))
		if scene_path.is_empty():
			continue
		if not ResourceLoader.exists(scene_path):
			continue
		var scene: PackedScene = load(scene_path) as PackedScene
		var weight: float = float(enemy_data.get("spawn_weight", 0.0))
		if weight <= 0.0:
			continue
		_enemy_pool.append({
			"data": enemy_data,
			"scene": scene,
			"weight": weight,
		})
		_total_weight += weight


## Pick a random enemy from the pool using weighted selection.
## Filters out enemies whose min_difficulty hasn't been reached yet.
func _pick_weighted_enemy() -> Dictionary:
	var time_minutes: float = RunManager.run_data.time_elapsed / 60.0
	# Build a filtered pool respecting min_difficulty
	var eligible: Array[Dictionary] = []
	var eligible_weight: float = 0.0
	for entry: Dictionary in _enemy_pool:
		var enemy_data: Dictionary = entry.get("data", {})
		var min_diff: float = float(enemy_data.get("min_difficulty", 0.0))
		if time_minutes >= min_diff:
			eligible.append(entry)
			eligible_weight += float(entry.get("weight", 0.0))
	if eligible.is_empty():
		return _enemy_pool[0]
	var roll: float = randf() * eligible_weight
	var cumulative: float = 0.0
	for entry: Dictionary in eligible:
		cumulative += float(entry.get("weight", 0.0))
		if roll <= cumulative:
			return entry
	# Fallback to last eligible entry
	return eligible[eligible.size() - 1]


func _on_enemy_died(enemy: Node, death_position: Vector2) -> void:
	var is_freighter: bool = enemy is LootFreighter

	if is_freighter:
		# Freighter jackpot drops: burst of primary pickup type + stardust
		var burst_count: int = int(enemy.drop_burst_count)
		var drop_type: String = String(enemy.drop_type)

		if drop_type == "xp" and enemy.get_xp_value() > 0:
			_spawn_burst_xp(death_position, enemy.get_xp_value(), burst_count)
		elif drop_type == "credits" and enemy.get_credit_value() > 0:
			var time_minutes: float = RunManager.run_data.time_elapsed / 60.0
			var scaled_credits: int = int(enemy.get_credit_value() * (1.0 + time_minutes * GameConfig.CREDIT_SCALE_PER_MINUTE))
			_spawn_burst_credits(death_position, scaled_credits, burst_count)
	else:
		# Normal enemy drops
		_spawn_xp(death_position, enemy.get_xp_value())

		# Random chance to drop credits
		var roll: float = randf()
		if roll < GameConfig.CREDIT_DROP_CHANCE:
			var credit_amount: int = enemy.get_credit_value()
			var time_minutes: float = RunManager.run_data.time_elapsed / 60.0
			credit_amount = int(credit_amount * (1.0 + time_minutes * GameConfig.CREDIT_SCALE_PER_MINUTE))
			_spawn_credits(death_position, credit_amount)

	# Stardust drops (any enemy with stardust_value > 0)
	var stardust: int = enemy.get_stardust_value()
	if stardust > 0:
		_spawn_burst_stardust(death_position, stardust)


func _spawn_xp(pos: Vector2, amount: float) -> void:
	var xp: Area2D = XPPickupScene.instantiate()
	xp.global_position = pos
	xp.initialize(amount)
	
	# Slight random offset
	xp.position += Vector2(randf_range(-GameConfig.PICKUP_SCATTER_XP, GameConfig.PICKUP_SCATTER_XP), randf_range(-GameConfig.PICKUP_SCATTER_XP, GameConfig.PICKUP_SCATTER_XP))
	
	# Use call_deferred to avoid physics query flushing error
	get_tree().current_scene.call_deferred("add_child", xp)


func _spawn_credits(pos: Vector2, amount: int) -> void:
	var credit: Area2D = CreditPickupScene.instantiate()
	credit.global_position = pos
	credit.initialize(amount)

	# Slight random offset (different from XP so they don't overlap)
	credit.position += Vector2(randf_range(-GameConfig.PICKUP_SCATTER_CREDIT, GameConfig.PICKUP_SCATTER_CREDIT), randf_range(-GameConfig.PICKUP_SCATTER_CREDIT, GameConfig.PICKUP_SCATTER_CREDIT))

	# Use call_deferred to avoid physics query flushing error
	get_tree().current_scene.call_deferred("add_child", credit)


## Spawn a burst of XP pickups scattered around a position (for freighter jackpot).
func _spawn_burst_xp(pos: Vector2, total_amount: float, count: int) -> void:
	var per_orb: float = total_amount / float(count)
	for i: int in range(count):
		var offset: Vector2 = Vector2(randf_range(-GameConfig.PICKUP_SCATTER_BURST, GameConfig.PICKUP_SCATTER_BURST), randf_range(-GameConfig.PICKUP_SCATTER_BURST, GameConfig.PICKUP_SCATTER_BURST))
		_spawn_xp(pos + offset, per_orb)


## Spawn a burst of credit pickups scattered around a position (for freighter jackpot).
func _spawn_burst_credits(pos: Vector2, total_amount: int, count: int) -> void:
	var per_orb: int = maxi(1, int(float(total_amount) / float(count)))
	var remainder: int = total_amount - (per_orb * count)
	for i: int in range(count):
		var extra: int = 1 if i < remainder else 0
		var offset: Vector2 = Vector2(randf_range(-GameConfig.PICKUP_SCATTER_BURST, GameConfig.PICKUP_SCATTER_BURST), randf_range(-GameConfig.PICKUP_SCATTER_BURST, GameConfig.PICKUP_SCATTER_BURST))
		_spawn_credits(pos + offset, per_orb + extra)


## Spawn stardust pickups scattered around a position.
func _spawn_burst_stardust(pos: Vector2, total_amount: int) -> void:
	for i: int in range(total_amount):
		var stardust: Area2D = StardustPickupScene.instantiate()
		var offset: Vector2 = Vector2(randf_range(-GameConfig.PICKUP_SCATTER_STARDUST, GameConfig.PICKUP_SCATTER_STARDUST), randf_range(-GameConfig.PICKUP_SCATTER_STARDUST, GameConfig.PICKUP_SCATTER_STARDUST))
		stardust.global_position = pos + offset
		stardust.initialize(1)
		get_tree().current_scene.call_deferred("add_child", stardust)


# =============================================================================
# SWARM SYSTEM
# =============================================================================

## Check if it's time to trigger a swarm event.
func _check_swarm_triggers() -> void:
	if _swarm_active:
		return  # Already in a swarm
	
	var swarm_times: Array = GameConfig.SWARM_TIMES
	if _swarms_triggered >= swarm_times.size():
		return  # All swarms for this run have been triggered
	
	var next_swarm_time: float = float(swarm_times[_swarms_triggered])
	var current_time: float = RunManager.run_data.time_elapsed
	
	if current_time >= next_swarm_time:
		_start_swarm_warning()


## Show warning message, then start the swarm.
func _start_swarm_warning() -> void:
	_swarms_triggered += 1
	swarm_warning_started.emit()
	
	# After warning duration, start the actual swarm
	var warning_timer: SceneTreeTimer = get_tree().create_timer(GameConfig.SWARM_WARNING_DURATION)
	warning_timer.timeout.connect(_start_swarm)


## Begin the swarm — accelerated spawn rate for a random duration.
func _start_swarm() -> void:
	_swarm_active = true
	_swarm_timer = randf_range(GameConfig.SWARM_DURATION_MIN, GameConfig.SWARM_DURATION_MAX)
	swarm_started.emit()


## End the current swarm event.
func _end_swarm() -> void:
	_swarm_active = false
	RunManager.record_swarm_completed()
	swarm_ended.emit()


# =============================================================================
# ELITE SYSTEM
# =============================================================================

## Roll to determine if the next enemy should be an elite.
func _roll_for_elite() -> bool:
	var base_chance: float = GameConfig.ELITE_BASE_CHANCE
	var elite_mult: float = _get_player_elite_spawn_rate()
	var final_chance: float = base_chance * elite_mult
	return randf() < final_chance


## Apply elite visual effects: color tint and size scale.
func _apply_elite_visuals(enemy: Node) -> void:
	# Apply color modulate
	if enemy.has_method("set_modulate"):
		enemy.modulate = GameConfig.ELITE_COLOR
	elif "modulate" in enemy:
		enemy.modulate = GameConfig.ELITE_COLOR
	
	# Apply size scale
	if "scale" in enemy:
		enemy.scale *= GameConfig.ELITE_SIZE_SCALE


# =============================================================================
# STAT HELPERS
# =============================================================================

## Get the player's difficulty stat (0.0 = 0%, 1.0 = 100%).
func _get_player_difficulty_stat() -> float:
	if _player and _player.has_method("get_stat"):
		return _player.get_stat("difficulty")
	return 0.0


## Get the player's elite_spawn_rate stat (multiplier, default 1.0).
func _get_player_elite_spawn_rate() -> float:
	if _player and _player.has_method("get_stat"):
		return _player.get_stat("elite_spawn_rate")
	return 1.0
