class_name WeaponBulletData
extends Resource

## Metadata attached to BB2D bullet batches via bullets_custom_data.
## Shared across all bullets in a single spawn call.

@export var weapon_id: String = ""
@export var base_damage: float = 0.0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 0.0
@export var bounces_remaining: int = 0
@export var bounce_range: float = 0.0
@export var size_mult: float = 1.0
@export var spawn_origin: Vector2 = Vector2.ZERO
@export var extra: Dictionary = {}

## Stats component instance ID — safe across frames, null-checks on retrieval.
var _stats_instance_id: int = 0


## Store a reference to the player's StatsComponent via instance ID.
func set_stats_component(stats: Node) -> void:
	_stats_instance_id = stats.get_instance_id() if stats else 0


## Retrieve the StatsComponent if still valid, or null.
func get_stats_component() -> Node:
	if _stats_instance_id == 0:
		return null
	var obj: Object = instance_from_id(_stats_instance_id)
	if obj is Node:
		return obj as Node
	return null
