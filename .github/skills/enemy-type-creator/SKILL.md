---
name: enemy-type-creator
description: Step-by-step procedure for creating new enemy types in Super Cool Space Game — script, scene, JSON data entry, spawner integration, and difficulty scaling.
---

# Enemy Type Creator Skill

Use this skill when asked to create a new enemy type, variant, or miniboss. All enemies extend `BaseEnemy` and are data-driven via `data/enemies.json`.

## When to Activate

- Creating a new enemy type or variant
- Adding a miniboss or boss enemy
- Creating an enemy with unique behavior (flee, orbit, charge, etc.)

## Prerequisites

Before starting, determine:

1. **Enemy ID** — snake_case identifier (e.g., `void_stalker`)
2. **Behavior type** — `chase`, `chase_then_flee`, `orbit`, `charge`, `stationary`, or custom
3. **Whether it needs a custom script** — Simple chasers can reuse `base_enemy.tscn` directly; unique behaviors need a new script
4. **Drop type** — XP, credits, stardust, or combination

## Existing Enemy Types (Reference)

| Enemy              | Script          | Behavior          | Tags            |
| ------------------ | --------------- | ----------------- | --------------- |
| Drone              | `BaseEnemy`     | `chase`           | basic           |
| Shipping Freighter | `LootFreighter` | `chase_then_flee` | loot, freighter |
| Armored Freighter  | `LootFreighter` | `chase_then_flee` | loot, freighter |

## Step-by-Step Procedure

### Step 1: Determine Script Approach

**Option A — Reuse BaseEnemy (simple chase enemies):**
No new script needed. Just add a JSON entry pointing to `res://scenes/enemies/base_enemy.tscn` with different stats.

**Option B — Extend BaseEnemy (custom behavior):**
Create a new script in `scripts/enemies/` that extends `BaseEnemy` and overrides movement/damage methods.

### Step 2: Create Enemy Script (if needed)

```gdscript
class_name {EnemyName}
extends BaseEnemy

## {EnemyName} - {Description of unique behavior}

# ── Custom state / exports ────────────────────────────────────────────

enum {EnemyName}State {
	CHASE,
	# Add custom states here
}

var _state: {EnemyName}State = {EnemyName}State.CHASE


func _ready() -> void:
	super._ready()
	enemy_type = "normal"  # or "elite", "boss", "loot"


## Override movement to implement custom behavior.
func _process_movement(delta: float) -> void:
	if not _target:
		_find_player()
		return

	match _state:
		{EnemyName}State.CHASE:
			_chase_movement(delta)


func _chase_movement(_delta: float) -> void:
	## Standard chase — direct toward player with asteroid slow.
	var speed: float = _get_asteroid_adjusted_speed(move_speed)
	var desired_dir: Vector2 = (_target.global_position - global_position).normalized()
	velocity = desired_dir * speed + _knockback_velocity

	if velocity.length() > 10:
		rotation = velocity.angle()
```

**Key rules for enemy scripts:**

- Always call `super._ready()` to inherit base setup (group, HP, player finding)
- Override `_process_movement(delta)` for custom movement — BaseEnemy calls this from `_physics_process`
- Override `take_damage()` if the enemy has special damage reactions (like LootFreighter's flee trigger)
- Set `enemy_type` in `_ready()`: `"normal"`, `"elite"`, `"boss"`, or `"loot"`
- Use `_get_asteroid_adjusted_speed(base_speed)` for movement speed (handles asteroid slow + visual dim)
- Include knockback velocity in final velocity calculation

### Step 3: Create Enemy Scene

Scene hierarchy for all enemies:

```
CharacterBody2D ({EnemyName}.gd or BaseEnemy.gd)
├── CollisionShape2D          # Physics collision (CircleShape2D)
├── HitboxArea (Area2D)       # Overlap detection for contact damage
│   └── CollisionShape2D      # Same shape as parent, slightly larger
└── Sprite2D                  # Or AnimatedSprite2D for animated enemies
```

**Collision layer setup (mandatory):**

- **Layer**: 8 (Enemies)
- **Mask**: 5 (1 + 4 = Player + Projectiles)

**HitboxArea collision setup:**

- **Layer**: 8 (Enemies)
- **Mask**: 1 (Player only)
- `monitoring = true`, `monitorable = true`

Save as `scenes/enemies/{enemy_name}.tscn`.

### Step 4: Add JSON Entry to enemies.json

```json
"{enemy_id}": {
	"id": "{enemy_id}",
	"name": "Display Name",
	"description": "Description of enemy behavior",
	"scene": "res://scenes/enemies/{enemy_name}.tscn",
	"base_stats": {
		"hp": 25.0,
		"damage": 4.0,
		"speed": 70.0,
		"xp_value": 1.0,
		"credits_value": 1.0,
		"stardust_value": 0.0
	},
	"behavior": "chase",
	"spawn_weight": 50.0,
	"min_difficulty": 0.0,
	"tags": ["basic"]
}
```

**Required keys:** `id`, `name`, `scene`, `base_stats`, `behavior`, `spawn_weight`, `tags`

**base_stats fields:**
| Stat | Type | Description |
|---|---|---|
| `hp` | float | Base hit points (scaled by difficulty) |
| `damage` | float | Contact damage per tick |
| `speed` | float | Movement speed in px/sec |
| `xp_value` | float | XP dropped on death (1.0 normal, 3.0+ elite) |
| `credits_value` | float | Credits dropped on death |
| `stardust_value` | float | Stardust dropped on death (meta currency) |

**Additional stats for special enemies:**
| Stat | Type | Used By |
|---|---|---|
| `flee_speed` | float | LootFreighter (speed when fleeing) |
| `drop_burst_count` | float | LootFreighter (number of pickup orbs scattered) |

**spawn_weight:** Higher = more frequent. Drone = 100 (very common), Freighter = 5 (rare).

**min_difficulty:** 0.0 = spawns from start. 0.5 = spawns after 50% difficulty ramp. Use to gate harder enemies.

**Tags for filtering:**

- `basic` — Standard enemy
- `loot` — Drops extra resources
- `freighter` — Loot freighter variant
- `elite_only` — Only spawns as elite
- `boss` — Boss enemy (special spawn rules)

### Step 5: Integrate with Enemy Spawner

`scripts/systems/enemy_spawner.gd` reads `data/enemies.json` and selects enemies by `spawn_weight`. New enemies are automatically included in the spawn pool if:

1. They have a valid `scene` path
2. Their `spawn_weight` > 0
3. Current difficulty >= their `min_difficulty`

**No spawner code changes needed** for standard enemies. For special spawn rules (boss, miniboss), check if the spawner needs a new trigger condition.

### Step 6: Configure Difficulty Scaling

BaseEnemy stats are scaled by the enemy spawner at spawn time using GameConfig formulas:

- **HP scaling**: `base_hp * (1 + time_minutes) ^ ENEMY_HP_EXPONENT`
- **Damage scaling**: `base_damage * (1 + time_minutes * ENEMY_DAMAGE_SCALE_PER_MINUTE)`
- **Elite modifiers**: HP × `ELITE_HP_MULT`, Damage × `ELITE_DAMAGE_MULT`, Size × `ELITE_SIZE_SCALE`

Ensure the base_stats in JSON are tuned for **minute 0** values. The spawner handles scaling.

### Step 7: Configure Loot Drops

Enemy death → `died` signal → `EnemySpawner._on_enemy_died()` → spawns pickups.

The spawner reads `xp_value`, `credit_value`, `stardust_value` from the enemy instance and spawns the appropriate pickup scenes. Special burst behavior (like LootFreighter's scatter) is handled in the enemy's `_die()` override or by the spawner checking `drop_burst_count`.

## LootFreighter Pattern (Chase → Flee)

For enemies that change behavior on hit, follow the `LootFreighter` pattern:

```gdscript
# State enum
enum FreighterState { CHASE, FLEE }
var _state: FreighterState = FreighterState.CHASE
var _has_been_hit: bool = false

# Override take_damage to trigger state change
func take_damage(amount: float, _source: Node = null) -> void:
	if _is_dying:
		return
	current_hp -= amount
	_flash_damage()
	if not _has_been_hit:
		_has_been_hit = true
		_enter_flee_state()
	if current_hp <= 0:
		_die()

# Override movement to use state machine
func _process_movement(delta: float) -> void:
	match _state:
		FreighterState.CHASE: _chase_movement(delta)
		FreighterState.FLEE:  _flee_movement(delta)
```

## Checklist

- [ ] Enemy script (if custom behavior): `scripts/enemies/{enemy_name}.gd`
- [ ] Enemy scene: `scenes/enemies/{enemy_name}.tscn`
- [ ] Collision layers: Layer 8, Mask 5 (Player + Projectiles)
- [ ] HitboxArea: Layer 8, Mask 1 (Player), monitoring + monitorable enabled
- [ ] JSON entry in `data/enemies.json` with all required keys
- [ ] `super._ready()` called in custom scripts
- [ ] Asteroid slow used via `_get_asteroid_adjusted_speed()` in movement
- [ ] `enemy_type` set correctly ("normal", "elite", "boss", "loot")
- [ ] Loot values configured (xp_value, credit_value, stardust_value)
- [ ] `died` signal emits correctly (inherited from BaseEnemy)
- [ ] Headless sanity check passes
