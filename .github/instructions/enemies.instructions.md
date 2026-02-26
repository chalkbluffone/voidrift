---
applyTo: "scripts/enemies/**,scenes/enemies/**"
---

# Enemies & Spawning — Voidrift Domain

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

## Enemy Movement & Flow Field

Enemies use the `FlowField` system for pathfinding (see `world.instructions.md` for flow field details). Key behavior:

- Direction from flow field is sampled via O(1) bilinear interpolation lookup
- Direction changes are lerped via `ENEMY_TURN_SPEED` (default 6.0) to prevent jerky turns
- Soft `_get_separation_force()` provides gentle visual spread without hard blocking
- Enemies do **not** collide with each other (collision mask excludes layer 8) — standard for the survivors genre

## Enemy Spawn Avoidance

Enemy spawn positions use rejection sampling to avoid asteroids:

- Each asteroid has an `effective_radius` property used for clearance checks
- If no valid position found in normal range, an extended range fallback is attempted
- Spawn positions are also constrained to the arena boundary

## Resolved Issues

- **Raycast obstacle avoidance** caused spinning/clustering (surface normals inconsistent between frames/enemies). Potential field repulsion also caused jitter. Both replaced with BFS flow field — globally consistent, deterministic, no per-enemy physics queries.
