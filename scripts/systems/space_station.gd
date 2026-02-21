class_name SpaceStation
extends Node2D

## SpaceStation - A zone that charges when the player stays inside, providing a stat buff on completion.
## Charge progress increases while player is in zone, decays slowly when they leave.
## One-time use: station becomes depleted after buff is claimed (or ignored).

signal charging_started
signal charging_stopped
signal charge_completed

@export var zone_radius: float = GameConfig.STATION_ZONE_RADIUS

var _charge: float = 0.0
var _is_player_inside: bool = false
var _is_depleted: bool = false
var _awaiting_selection: bool = false  ## Prevents re-triggering while popup is open
var _player_ref: Node2D = null

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var StationService: Node = get_node("/root/StationService")
@onready var FileLogger: Node = get_node("/root/FileLogger")
@onready var _buff_zone: Area2D = $BuffZone
@onready var _progress_ring: ColorRect = $ProgressRing
@onready var _sprite: CanvasItem = $Sprite2D


func _ready() -> void:
	add_to_group("stations")
	add_to_group("minimap_objects")
	
	_buff_zone.body_entered.connect(_on_body_entered)
	_buff_zone.body_exited.connect(_on_body_exited)
	
	# Connect to station service to know when buff selection is complete
	StationService.station_buff_completed.connect(_on_buff_completed)
	
	# Initialize visual state
	_update_progress_visual()


func _process(delta: float) -> void:
	if _is_depleted:
		return
	
	# Only process charge when game is playing
	if RunManager.current_state != RunManager.GameState.PLAYING:
		return
	
	if _is_player_inside:
		# Charge up while player is inside
		var charge_rate: float = 1.0 / GameConfig.STATION_CHARGE_TIME
		_charge = minf(_charge + charge_rate * delta, 1.0)
		
		if _charge >= 1.0:
			_on_charge_complete()
	else:
		# Decay charge while player is outside
		if _charge > 0.0:
			var decay_rate: float = 1.0 / GameConfig.STATION_DECAY_TIME
			_charge = maxf(_charge - decay_rate * delta, 0.0)
	
	_update_progress_visual()


func _on_body_entered(body: Node2D) -> void:
	if _is_depleted:
		return
	
	if body.is_in_group("player"):
		_is_player_inside = true
		_player_ref = body
		charging_started.emit()
		FileLogger.log_info("SpaceStation", "Player entered zone, charge = %.1f%%" % [_charge * 100.0])


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_is_player_inside = false
		charging_stopped.emit()
		FileLogger.log_info("SpaceStation", "Player exited zone, charge = %.1f%%" % [_charge * 100.0])


func _on_charge_complete() -> void:
	if _is_depleted or _awaiting_selection:
		return
	
	_awaiting_selection = true
	FileLogger.log_info("SpaceStation", "Charge complete! Triggering buff selection.")
	charge_completed.emit()
	
	# Get player's luck stat for rarity rolls
	var player_luck: float = 0.0
	if _player_ref and _player_ref.has_method("get_stats"):
		var stats: Node = _player_ref.get_stats()
		if stats and stats.has_method("get_stat"):
			player_luck = stats.get_stat("luck")
	
	# Trigger buff selection UI
	StationService.trigger_buff_selection(player_luck)


func _on_buff_completed(buff: Dictionary) -> void:
	# Only deplete if we were the station that triggered the popup
	if not _awaiting_selection or _is_depleted:
		return
	
	_awaiting_selection = false
	_is_depleted = true
	_charge = 0.0
	
	# Apply the buff to the player
	if not buff.is_empty() and _player_ref and _player_ref.has_method("get_stats"):
		var stats: Node = _player_ref.get_stats()
		if stats:
			StationService.apply_buff(buff, stats)
	
	# Visual feedback - dim the station
	_update_depleted_visual()
	FileLogger.log_info("SpaceStation", "Depleted")


func _update_progress_visual() -> void:
	# Update shader or visual indicator with charge progress
	if _progress_ring and _progress_ring.material:
		var mat: ShaderMaterial = _progress_ring.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("charge", _charge)


func _update_depleted_visual() -> void:
	# Dim sprite when depleted
	if _sprite:
		_sprite.modulate = Color(0.4, 0.4, 0.4, 0.6)
	if _progress_ring:
		_progress_ring.visible = false


## Get the current charge progress (0.0 to 1.0).
func get_charge() -> float:
	return _charge


## Check if this station has been used.
func is_depleted() -> bool:
	return _is_depleted


## Get whether the player is currently inside the zone.
func is_player_inside() -> bool:
	return _is_player_inside
