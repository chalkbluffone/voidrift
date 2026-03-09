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

### Overtime Difficulty Multiplier

After the run countdown reaches zero (overtime), enemies spawn with an escalating multiplier that affects HP, contact damage, and move speed:

```gdscript
# Computed at spawn time for each enemy
var overtime_mult: float = RunManager.get_overtime_multiplier()
if overtime_mult > 1.0:
    enemy.max_hp *= overtime_mult
    enemy.contact_damage *= overtime_mult
    enemy.move_speed *= overtime_mult
```

**Multiplier progression**:

- Starts at `OVERTIME_MULTIPLIER_START` (1.0x) when overtime begins
- Increases by `OVERTIME_MULTIPLIER_INCREMENT` (0.5) every `OVERTIME_MULTIPLIER_INTERVAL` (30 seconds)
- Caps at `OVERTIME_MULTIPLIER_CAP` (10.0) after 9 minutes of overtime
- Example: 1.0x → 1.5x → 2.0x → … → 10.0x

**HUD feedback**: New `OvertimeLabel` below the player level displays the current multiplier ("1.0x", "2.5x", etc.) with color-coded feedback (cyan → orange → red as multiplier increases).

**Note**: Enemy move speed is still capped at `PLAYER_BASE_SPEED` to prevent enemies from outrunning the player.

## Elite Enemies

Rolled per spawn with the player's `elite_spawn_rate` modifier:

```gdscript
func _roll_for_elite() -> bool:
    var base_chance: float = GameConfig.ELITE_BASE_CHANCE
    var elite_mult: float = _get_player_elite_spawn_rate()
    return randf() < (base_chance * elite_mult)
```

Elites get:

- `ELITE_HP_MULT`, `ELITE_DAMAGE_MULT`
- Visual: `ELITE_COLOR`, `ELITE_SIZE_SCALE`
- `enemy_type = "elite"` for tracking
- Drop 3 XP (vs 1 XP for normal enemies)

**Exception**: `LootFreighter` enemies are **never** rolled as elites — the elite check is skipped entirely for freighter spawns.

## Swarm Events

Temporary spawn rate boost at fixed times during a run:

```gdscript
const SWARM_TIMES: Array[float] = GameConfig.SWARM_TIMES
const SWARM_DURATION_MIN: float = GameConfig.SWARM_DURATION_MIN
const SWARM_DURATION_MAX: float = GameConfig.SWARM_DURATION_MAX
const SWARM_SPAWN_MULTIPLIER: float = GameConfig.SWARM_SPAWN_MULTIPLIER
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

## Enemy Movement & Asteroid Phasing

Enemies use simple direct chase movement — they move straight toward the player at `move_speed`. Enemies do **not** collide with asteroids (collision mask excludes layer 2). Instead, they phase through asteroids at reduced speed:

- `ENEMY_ASTEROID_SLOW_MULTIPLIER` (0.5) — speed multiplier when overlapping an asteroid
- Visual feedback: enemy sprite dims to 40% alpha while inside an asteroid
- Asteroids act as soft tactical cover — players can kite through asteroid fields for breathing room
- The slow check uses `FrameCache.asteroids` (static cache) with `distance_squared` vs `effective_radius²`

Enemies do **not** collide with each other (collision mask excludes layer 8) — standard for the survivors genre.

### Loot Freighter Movement

`LootFreighter` overrides `_process_movement()` with a chase→flee state machine. Both states call `_get_asteroid_adjusted_speed()` from BaseEnemy for consistent asteroid slow behavior.

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

## Loot Freighter Spawn Control

Freighter spawns are rate-limited to keep them feeling special:

- **Max active**: Only `FREIGHTER_MAX_ACTIVE` (1) freighter can be alive at a time
- **Cooldown**: After a freighter spawns, a random cooldown of `FREIGHTER_SPAWN_COOLDOWN_MIN`–`FREIGHTER_SPAWN_COOLDOWN_MAX` (60–90s) must elapse before another can spawn
- **Implementation**: `_pick_weighted_enemy()` filters out pool entries with the `"freighter"` tag when at cap or on cooldown
- **Never elite**: Elite roll is skipped entirely for `LootFreighter` instances

## take_damage() Signature

All enemy `take_damage()` methods accept an optional `damage_info` dictionary:

```gdscript
func take_damage(amount: float, _source: Node = null, damage_info: Dictionary = {}) -> void:
```

Projectiles pass `{"damage": float, "is_crit": bool, "is_overcrit": bool}`. Non-projectile sources pass `{}` (default). The `damage_info` is forwarded to `_spawn_damage_number()` for visual styling.

When overriding `take_damage()` in an enemy subclass (e.g., `LootFreighter`), call `_spawn_damage_number(amount, damage_info)` in the override body — it's defined in `BaseEnemy` and handles setting checks + soft cap.

## Resolved Issues

- **Raycast obstacle avoidance** caused spinning/clustering (surface normals inconsistent between frames/enemies). Potential field repulsion also caused jitter. BFS flow field was tried but made movement feel unnatural. All replaced with simple direct chase + asteroid phasing (enemies pass through asteroids at 50% speed with visual dim).
- **SpatialHashGrid freed-object crash**: `entity as Node2D` cast on a freed object crashes before `is_instance_valid()` can protect. Fixed by checking validity before the cast in `query_radius()`.
