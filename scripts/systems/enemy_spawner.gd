extends Node2D

## EnemySpawner - Spawns enemies around the player in waves.

const BaseEnemyScene: PackedScene = preload("res://scenes/enemies/base_enemy.tscn")
const XPPickupScene: PackedScene = preload("res://scenes/pickups/xp_pickup.tscn")
const CreditPickupScene: PackedScene = preload("res://scenes/pickups/credit_pickup.tscn")

var _player: Node2D = null
var _spawn_timer: float = 0.0

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var GameConfig: Node = get_node("/root/GameConfig")
@onready var DataLoader: Node = get_node("/root/DataLoader")
@onready var FileLogger: Node = get_node("/root/FileLogger")


func _ready() -> void:
	_find_player()


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
	
	var enemy: CharacterBody2D = BaseEnemyScene.instantiate()
	
	# Position at random angle around player
	var angle: float = randf() * TAU
	var distance: float = randf_range(GameConfig.SPAWN_RADIUS_MIN, GameConfig.SPAWN_RADIUS_MAX)
	var spawn_pos: Vector2 = _player.global_position + Vector2.from_angle(angle) * distance
	
	enemy.global_position = spawn_pos
	
	# Apply base stats from enemy data (JSON) before time-based scaling
	var enemy_data: Dictionary = DataLoader.get_enemy("drone")
	var base_stats: Dictionary = enemy_data.get("base_stats", {})
	enemy.max_hp = float(base_stats.get("hp", enemy.max_hp))
	enemy.contact_damage = float(base_stats.get("damage", enemy.contact_damage))
	enemy.move_speed = float(base_stats.get("speed", enemy.move_speed))
	enemy.xp_value = float(base_stats.get("xp_value", enemy.xp_value))
	enemy.credit_value = int(base_stats.get("credits_value", enemy.credit_value))
	
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
	
	# Scale enemy speed: use JSON base + time-based scaling per player level
	var player_level: int = RunManager.run_data.level
	enemy.move_speed += GameConfig.ENEMY_SPEED_PER_LEVEL * player_level
	
	# Connect death signal for XP drop
	enemy.died.connect(_on_enemy_died)
	
	get_tree().current_scene.add_child(enemy)


func _on_enemy_died(enemy: Node, death_position: Vector2) -> void:
	_spawn_xp(death_position, enemy.get_xp_value())
	
	# Random chance to drop credits
	var roll: float = randf()
	if roll < GameConfig.CREDIT_DROP_CHANCE:
		var credit_amount: int = enemy.get_credit_value()
		# Scale credits slightly with time
		var time_minutes: float = RunManager.run_data.time_elapsed / 60.0
		credit_amount = int(credit_amount * (1.0 + time_minutes * GameConfig.CREDIT_SCALE_PER_MINUTE))
		_spawn_credits(death_position, credit_amount)


func _spawn_xp(pos: Vector2, amount: float) -> void:
	var xp: Area2D = XPPickupScene.instantiate()
	xp.global_position = pos
	xp.initialize(amount)
	
	# Slight random offset
	xp.position += Vector2(randf_range(-10, 10), randf_range(-10, 10))
	
	# Use call_deferred to avoid physics query flushing error
	get_tree().current_scene.call_deferred("add_child", xp)


func _spawn_credits(pos: Vector2, amount: int) -> void:
	var credit: Area2D = CreditPickupScene.instantiate()
	credit.global_position = pos
	credit.initialize(amount)
	
	# Slight random offset (different from XP so they don't overlap)
	credit.position += Vector2(randf_range(-15, 15), randf_range(-15, 15))
	
	# Use call_deferred to avoid physics query flushing error
	get_tree().current_scene.call_deferred("add_child", credit)
