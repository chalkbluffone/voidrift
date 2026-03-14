extends "res://scripts/pickups/xp_pickup.gd"

## MergedXPPickup — same as XPPickup but excluded from further merge passes.
## Supports animated entrance (scale pop + flash) when spawned by merge system.


func _on_pickup_ready() -> void:
	pass


## Plays bouncy scale-pop + white flash entrance animation.
## Called by enemy_spawner after the fly-in tween completes.
func animate_entrance() -> void:
	scale = Vector2.ZERO
	modulate = Color(3.0, 3.0, 3.0, 1.0)  # Bright white flash

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, GameConfig.XP_MERGE_POP_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, GameConfig.XP_MERGE_FLASH_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
