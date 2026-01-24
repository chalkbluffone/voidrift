extends Area2D

## Minable asteroid - interactive object that can be destroyed for loot.
## Press interact button near asteroid to mine it for Credits/XP/Stardust.

var drift_velocity: Vector2 = Vector2.ZERO
var spin_speed: float = 0.0

func _physics_process(delta: float) -> void:
	global_position += drift_velocity * delta
	rotation += spin_speed * delta
