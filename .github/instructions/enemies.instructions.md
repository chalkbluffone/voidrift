---
applyTo: "scripts/enemies/**,scenes/enemies/**"
---

# Enemies & Spawning — Super Cool Space Game Domain

## Enemy Scaling (Over Time)

Enemies scale with run time using polynomial HP and linear damage:

```gdscript
# HP: polynomial scaling
var time_hp_mult: float = 1.0 + pow(time_minutes, GameConfig.ENEMY_HP_EXPONENT)

# Damage: linear scaling
var time_damage_mult: float = 1.0 + (time_minutes * GameConfig.ENEMY_DAMAGE_SCALE_PER_MINUTE)
```

The **difficulty stat** (a player stat, 0.0–1.0+) further multiplies these scaling factors. See `progression.instructions.md` for difficulty stat formulas.

## Elite Enemies

Rolled per spawn with the player's `elite_spawn_rate` modifier:

```gdscript
func _roll_for_elite() -> bool:
    var base_chance: float = GameConfig.ELITE_BASE_CHANCE  # 0.05 = 5%
    var elite_mult: float = _get_player_elite_spawn_rate()
    return randf() < (base_chance * elite_mult)
```

Elites get:

- `ELITE_HP_MULT` (3×), `ELITE_DAMAGE_MULT` (2×)
- Visual: `ELITE_COLOR` (orange tint), `ELITE_SIZE_SCALE` (1.3×)
- `enemy_type = "elite"` for tracking
- Drop 3 XP (vs 1 XP for normal enemies)

## Swarm Events

Temporary spawn rate boost at fixed times during a run:

```gdscript
const SWARM_TIMES: Array[float] = [240.0, 420.0]  # 4 min, 7 min
const SWARM_DURATION_MIN: float = 45.0
const SWARM_DURATION_MAX: float = 60.0
const SWARM_SPAWN_MULTIPLIER: float = 3.0
```

Signals: `swarm_warning_started`, `swarm_started`, `swarm_ended`

HUD displays "A MASSIVE FLEET IS INBOUND" during the warning phase (`SWARM_WARNING_DURATION` seconds before swarm starts).

## Stopwatch Freeze (`is_frozen`)

The Stopwatch power-up freezes all enemies in place:

- `BaseEnemy.is_frozen: bool = false` — when true, `_process_movement()` skips chase/flee logic
- Frozen enemies still process knockback, contact damage, and `move_and_slide()`
- `LootFreighter` overrides `_process_movement()` without calling `super` — has its own `is_frozen` guard
- Global freeze flag: `SceneTree.set_meta("stopwatch_freeze_active", true)` set by `StopwatchPowerUp`
- **New enemy spawns** check `get_tree().has_meta("stopwatch_freeze_active")` in `_ready()` and spawn frozen
- Unfreeze timer uses generation-counter pattern — collecting another stopwatch refreshes the duration

## Enemy Movement & Flow Field

Enemies use the `FlowField` system for pathfinding (see `world.instructions.md` for flow field details). Key behavior:

- Direction from flow field is sampled via O(1) bilinear interpolation lookup
- Direction changes are lerped via `ENEMY_TURN_SPEED` (default 6.0) to prevent jerky turns
- Soft `_get_separation_force()` provides gentle visual spread without hard blocking
- Enemies do **not** collide with each other (collision mask excludes layer 8) — standard for the survivors genre

### Separation via SpatialHashGrid

Separation force uses `SpatialHashGrid` for O(k) neighbor queries instead of O(n²) brute force:

- `SpatialHashGrid` (`scripts/core/spatial_hash_grid.gd`) uses fixed-size cells for fast radius queries
- Entities register/unregister on spawn/despawn
- `query_radius()` returns nearby entities within a given radius
- **Critical**: `is_instance_valid(entity)` must be checked BEFORE `entity as Node2D` cast — casting a freed object crashes immediately

### Enemy Leash System

Enemies too far from the player are teleported back to prevent unbounded world spread:

- `ENEMY_LEASH_RADIUS` — max distance from player before teleport-respawn (normal enemies)
- `BOSS_LEASH_RADIUS` — larger leash for bosses
- Teleported enemies are repositioned to a valid spawn point near the player
- Prevents enemy count from growing unboundedly at arena edges

## Enemy Spawn Avoidance

Enemy spawn positions use rejection sampling to avoid asteroids:

- Each asteroid has an `effective_radius` property used for clearance checks
- If no valid position found in normal range, an extended range fallback is attempted
- Spawn positions are also constrained to the arena boundary

## take_damage() Signature

All enemy `take_damage()` methods accept an optional `damage_info` dictionary:

```gdscript
func take_damage(amount: float, _source: Node = null, damage_info: Dictionary = {}) -> void:
```

Projectiles pass `{"damage": float, "is_crit": bool, "is_overcrit": bool}`. Non-projectile sources pass `{}` (default). The `damage_info` is forwarded to `_spawn_damage_number()` for visual styling.

When overriding `take_damage()` in an enemy subclass (e.g., `LootFreighter`), call `_spawn_damage_number(amount, damage_info)` in the override body — it's defined in `BaseEnemy` and handles setting checks + soft cap.

## Resolved Issues

- **Raycast obstacle avoidance** caused spinning/clustering (surface normals inconsistent between frames/enemies). Potential field repulsion also caused jitter. Both replaced with BFS flow field — globally consistent, deterministic, no per-enemy physics queries.
- **SpatialHashGrid freed-object crash**: `entity as Node2D` cast on a freed object crashes before `is_instance_valid()` can protect. Fixed by checking validity before the cast in `query_radius()`.
