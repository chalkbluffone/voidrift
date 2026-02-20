extends Node2D

## EnemySpawner - Spawns enemies around the player in waves.
## Supports weighted random enemy selection and loot freighter drops.

const XPPickupScene: PackedScene = preload("res://scenes/pickups/xp_pickup.tscn")
const CreditPickupScene: PackedScene = preload("res://scenes/pickups/credit_pickup.tscn")
const StardustPickupScene: PackedScene = preload("res://scenes/pickups/stardust_pickup.tscn")

var _player: Node2D = null
var _spawn_timer: float = 0.0

## Cached enemy pool: Array of { data: Dictionary, scene: PackedScene, weight: float }
var _enemy_pool: Array[Dictionary] = []
var _total_weight: float = 0.0

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var GameConfig: Node = get_node("/root/GameConfig")
@onready var DataLoader: Node = get_node("/root/DataLoader")
@onready var FileLogger: Node = get_node("/root/FileLogger")


func _ready() -> void:
	_find_player()
	_build_enemy_pool()


func _process(delta: float) -> void:
	if not _player:
		_find_player()
		return
	
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
	return 1.0 / maxf(current_rate, 0.1)


## How many enemies spawn per tick. Starts at 1, grows after SPAWN_BATCH_MIN_MINUTE.
func _get_batch_size() -> int:
	var time_minutes: float = RunManager.run_data.time_elapsed / 60.0
	if time_minutes < GameConfig.SPAWN_BATCH_MIN_MINUTE:
		return 1
	var extra_minutes: float = time_minutes - GameConfig.SPAWN_BATCH_MIN_MINUTE
	return 1 + int(extra_minutes * GameConfig.SPAWN_BATCH_SIZE_PER_MINUTE)


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

	# Position at random angle around player
	var angle: float = randf() * TAU
	var distance: float = randf_range(GameConfig.SPAWN_RADIUS_MIN, GameConfig.SPAWN_RADIUS_MAX)
	var spawn_pos: Vector2 = _player.global_position + Vector2.from_angle(angle) * distance

	enemy.global_position = spawn_pos

	# Apply base stats from enemy data (JSON) before time-based scaling
	var base_stats: Dictionary = enemy_data.get("base_stats", {})
	enemy.max_hp = float(base_stats.get("hp", enemy.max_hp))
	enemy.contact_damage = float(base_stats.get("damage", enemy.contact_damage))
	enemy.move_speed = float(base_stats.get("speed", enemy.move_speed))
	enemy.xp_value = float(base_stats.get("xp_value", enemy.xp_value))
	enemy.credit_value = int(base_stats.get("credits_value", enemy.credit_value))
	enemy.stardust_value = int(base_stats.get("stardust_value", 0))

	# Apply freighter-specific stats if applicable
	if enemy is LootFreighter and base_stats.has("flee_speed"):
		enemy.flee_speed = float(base_stats.get("flee_speed", 150.0))
	if enemy is LootFreighter and base_stats.has("drop_burst_count"):
		enemy.drop_burst_count = int(base_stats.get("drop_burst_count", 5))

	# Scale enemy stats based on time
	var time_minutes: float = RunManager.run_data.time_elapsed / 60.0

	# HP scales exponentially — requires multiplicative damage stacking to keep up
	var hp_mult: float = GameConfig.ENEMY_HP_BASE_MULT * pow(GameConfig.ENEMY_HP_GROWTH_RATE, time_minutes)
	# Damage scales linearly — manageable with defensive stats
	var damage_mult: float = 1.0 + (time_minutes * GameConfig.ENEMY_DAMAGE_SCALE_PER_MINUTE)

	enemy.max_hp *= hp_mult
	enemy.current_hp = enemy.max_hp
	enemy.contact_damage *= damage_mult
	enemy.xp_value *= (1.0 + time_minutes * GameConfig.ENEMY_XP_SCALE_PER_MINUTE)

	# Speed only increases in overtime (after countdown hits zero)
	var overtime_seconds: float = maxf(0.0, -RunManager.run_data.time_remaining)
	if overtime_seconds > 0.0:
		enemy.move_speed += GameConfig.ENEMY_OVERTIME_SPEED_PER_MINUTE * (overtime_seconds / 60.0)
	# Cap enemy speed at player base speed — never outrun the player
	enemy.move_speed = minf(enemy.move_speed, GameConfig.PLAYER_BASE_SPEED)

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
			FileLogger.log_warn("EnemySpawner", "Scene not found for enemy: %s" % String(enemy_data.get("id", "unknown")))
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
	FileLogger.log_info("EnemySpawner", "Built enemy pool: %d types, total weight %.1f" % [_enemy_pool.size(), _total_weight])


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
