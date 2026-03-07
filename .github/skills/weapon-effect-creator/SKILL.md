---
name: weapon-effect-creator
description: Step-by-step procedure for creating a complete new weapon effect in Super Cool Space Game — spawner, effect script, scene, shader, JSON entries, and dispatch wiring.
---

# Weapon Effect Creator Skill

Use this skill when asked to create a new weapon or weapon effect. This is the most complex multi-file workflow in the project (5+ files per weapon). Follow each step in order.

## When to Activate

- Creating a new weapon type or weapon effect
- Adding a new weapon to the game
- Scaffolding a weapon effect directory

## Prerequisites

Before starting, determine:

1. **Weapon name** — snake_case identifier (e.g., `plasma_lance`)
2. **Weapon type** — One of: `projectile`, `beam`, `area`, `orbit`, `melee`
3. **Base class** — Which existing effect base to extend (see Base Classes below)
4. **Targeting mode** — One of: `nearest`, `all`, `none`, `random`

## Base Classes

| Weapon Type  | Base Class       | Example Weapon              | Key Behavior                                  |
| ------------ | ---------------- | --------------------------- | --------------------------------------------- |
| `melee`      | `ArcEffectBase`  | Radiant Arc                 | Sweeping arc from player, follows rotation    |
| `projectile` | `ProjectileBase` | Space Napalm, Nikola's Coil | Travels forward, hits on contact              |
| `beam`       | `BeamBase`       | Broken Tractor Beam         | Locks onto target, ticks damage over duration |
| `area`       | `AoEBase`        | Ion Wake, Nope Bubble       | Placed at position, damages in radius         |
| `orbit`      | `OrbitBase`      | Spin Cycle                  | Orbits around player, damages on contact      |

## Step-by-Step Procedure

### Step 1: Create Effect Directory

```
effects/{weapon_name}/
├── {weapon_name}.gd              # Effect script (extends base class)
├── {WeaponName}.tscn             # Effect scene
├── {weapon_name}_spawner.gd      # Spawner (RefCounted or plain class)
├── {weapon_name}.gdshader         # Optional: custom shader
```

Use `snake_case` for files, `PascalCase` for the `.tscn` scene name.

### Step 2: Create Spawner Script

The spawner is a lightweight class responsible for instantiating effect scenes. It's loaded and cached by `WeaponSpawnerCache`.

**Spawner argument signatures** (must match one of these):

| Args | Signature                                            | Used By                                        |
| ---- | ---------------------------------------------------- | ---------------------------------------------- |
| 4    | `spawn(spawn_pos, direction, params, follow_source)` | Directional weapons (melee, projectile)        |
| 3    | `spawn(spawn_pos, params, follow_source)`            | Auto-targeting weapons (beam, chain lightning) |

**Template (4-arg directional):**

```gdscript
class_name {WeaponName}Spawner

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


## Spawn a {WeaponName} effect.
func spawn(
	spawn_pos: Vector2,
	direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> {WeaponName}:
	var effect: Node = load("res://effects/{weapon_name}/{WeaponName}.tscn").instantiate()
	effect.z_index = -1
	_parent_node.add_child(effect)

	if params:
		effect.setup(params)

	effect.spawn_from(spawn_pos, direction.normalized())

	if follow_source:
		effect.set_follow_source(follow_source)

	return effect
```

**Template (3-arg auto-targeting):**

```gdscript
class_name {WeaponName}Spawner

var _parent_node: Node


func _init(parent: Node) -> void:
	_parent_node = parent


## Spawn a {WeaponName} effect.
func spawn(
	spawn_pos: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	var effect: Node = load("res://effects/{weapon_name}/{WeaponName}.tscn").instantiate()
	effect.z_index = -1
	_parent_node.add_child(effect)

	if params:
		effect.setup(params)

	if follow_source:
		effect.set_follow_source(follow_source)

	effect.fire_from(spawn_pos)
	return effect
```

**Key rules:**

- Constructor always takes `parent: Node` (the effects container)
- `z_index = -1` so effects render below the ship
- Use `load()` not `preload()` — spawners are loaded dynamically by `WeaponSpawnerCache`
- Return type matches the effect class or `Node2D`

### Step 3: Create Effect Script

The effect script extends a base class and adds weapon-specific behavior.

**Required methods:**

```gdscript
extends {BaseClass}
class_name {WeaponName}

## {Description of weapon behavior}

# ── Weapon-specific exports ───────────────────────────────────────────

@export var speed: float = 0.0


# ── Internal state ────────────────────────────────────────────────────

var _follow_source: Node2D = null


# ══════════════════════════════════════════════════════════════════════
#  OVERRIDES
# ══════════════════════════════════════════════════════════════════════

func _get_shader_path() -> String:
	return "res://effects/{weapon_name}/{weapon_name}.gdshader"


func _on_ready_hook() -> void:
	pass


func _process(delta: float) -> void:
	if not _is_active:
		return
	_elapsed += delta
	if _elapsed >= duration:
		_is_active = false
		queue_free()
		return

	# Weapon-specific movement/behavior here

	_update_shader_uniforms()


# ══════════════════════════════════════════════════════════════════════
#  NESTED-JSON LOADER  (weapons.json structure)
# ══════════════════════════════════════════════════════════════════════

func load_from_data(data: Dictionary) -> void:
	var stats: Dictionary = data.get("stats", {})
	damage = float(stats.get("damage", damage))
	duration = float(stats.get("duration", duration))

	var shape: Dictionary = data.get("shape", {})
	# Read shape params with casting: float(shape.get("key", default))

	var motion: Dictionary = data.get("motion", {})
	# Read motion params with casting: float(motion.get("key", default))

	var visual: Dictionary = data.get("visual", {})
	# Read visual params — use EffectUtils.parse_color() for hex strings
```

**JSON casting rule (mandatory):** Always cast values from JSON dictionaries:

```gdscript
damage = float(stats.get("damage", 10.0))
count = int(stats.get("count", 1))
enabled = bool(data.get("enabled", true))
```

### Step 4: Create Effect Scene (.tscn)

Scene structure varies by weapon type:

**Melee/AoE:**

```
Node2D ({WeaponName}.gd)
└── Polygon2D          # Procedural mesh generated in code
```

**Projectile:**

```
Area2D ({WeaponName}.gd)
├── CollisionShape2D   # CircleShape2D for hit detection
└── Sprite2D           # Visual (or Polygon2D for procedural)
```

**Collision rules for projectiles:**

- **Layer**: 4 (Projectiles)
- **Mask**: 8 (Enemies)
- Connect `body_entered` or `area_entered` for hit detection

**Beam:**

```
Node2D ({WeaponName}.gd)
└── Line2D             # Or Polygon2D for shaped beams
```

### Step 5: Create Shader (Optional)

Only create a shader if the weapon needs custom visual FX beyond what the base class provides.

Follow `shaders.instructions.md` conventions:

- File: `effects/{weapon_name}/{weapon_name}.gdshader`
- Header: `shader_type canvas_item;`
- Uniform prefix: `uniform`
- Use synthwave palette colors from `UiColors`
- **No `return` statements in `fragment()`** — assign to `COLOR` directly

### Step 6: Add JSON Entry to weapons.json

Add the weapon definition to `data/weapons.json`:

```json
"{weapon_name}": {
	"description": "Description of weapon behavior",
	"display_name": "Display Name",
	"enabled": true,
	"motion": {
		// Movement parameters (speed, sweep_speed, fade_in, fade_out, etc.)
	},
	"scene": "res://effects/{weapon_name}/{WeaponName}.tscn",
	"shape": {
		// Size/geometry parameters (size, radius, arc_angle_deg, etc.)
	},
	"spawner": "res://effects/{weapon_name}/{weapon_name}_spawner.gd",
	"stats": {
		"cooldown": 2.0,
		"damage": 10.0,
		"duration": 1.0,
		"projectile_count": 1.0
	},
	"targeting": "nearest",
	"type": "projectile",
	"unlock_condition": "default",
	"visual": {
		// Color and glow parameters (color_core, color_glow, glow_strength, etc.)
		// Hex color strings: "#ff00ff"
	}
}
```

**Required keys:** `description`, `display_name`, `enabled`, `scene`, `spawner`, `stats`, `type`, `unlock_condition`

**Optional sections:** `motion`, `shape`, `visual`, `particles`, `spawn`

### Step 7: Add Tier Entry to weapon_upgrades.json

Add weapon tier scaling to `data/weapon_upgrades.json`:

```json
"{weapon_name}": {
	"display_name": "Display Name",
	"base_behavior": "Description of base weapon behavior",
	"type": "projectile",
	"element": "none",
	"special": "none",
	"tags": ["tag1", "tag2"],
	"strategy_synergies": "Short note on what stats to prioritize",
	"tier_stats": {
		"damage": { "common": 2.0, "uncommon": 2.4, "rare": 2.8, "epic": 3.2, "legendary": 4.0 },
		"projectile_count": { "common": 1.0, "uncommon": 1.2, "rare": 1.4, "epic": 1.6, "legendary": 2.0 },
		"size": { "common": 0.20, "uncommon": 0.24, "rare": 0.28, "epic": 0.32, "legendary": 0.40 }
	}
}
```

**Tier scaling pattern:**

- Each stat has 5 rarity tiers: `common`, `uncommon`, `rare`, `epic`, `legendary`
- Values are **multipliers** applied to the base stat, not absolute values
- Typical scaling: Common = 1x base, Legendary = 2x base
- Include 3-4 stats that are meaningful for this weapon type

### Step 8: Wire into WeaponComponent Dispatch

Check if the weapon type already has a fire handler in `scripts/combat/weapon_component.gd`:

```gdscript
func _fire_weapon(weapon_id: String, weapon_state: Dictionary) -> void:
	var weapon_type: String = data.get("type", "projectile")
	match weapon_type:
		"projectile": _fire_projectile_weapon(weapon_id, data, weapon_state.level)
		"orbit":      _fire_orbit_weapon(weapon_id, data, weapon_state.level)
		"area":       _fire_area_weapon(weapon_id, data, weapon_state.level)
		"beam":       _fire_beam_weapon(weapon_id, data, weapon_state.level)
		"melee":      _fire_melee_weapon(weapon_id, data, weapon_state.level)
```

- If the weapon uses an existing type (`projectile`, `beam`, `area`, `orbit`, `melee`), **no changes needed**
- If it's a new weapon type, add a new `match` branch and `_fire_{type}_weapon()` method

### Step 9: Test in Weapon Test Lab

Use the weapon test lab at `tools/weapon_test_lab/` to verify:

1. Effect spawns correctly
2. Visual appearance matches intent
3. Damage ticks register on test targets
4. Lifetime/cleanup works (no orphaned nodes)
5. Parameters respond to JSON changes

## Key Patterns to Follow

### WeaponSpawnerCache

Spawners are lazy-loaded and cached by `scripts/combat/weapon_spawner_cache.gd`:

- The spawner script path comes from `weapons.json` → `"spawner"` field
- The cache detects the spawner's `spawn()` arg count to choose 3-arg vs 4-arg calling convention
- **Do not** preload spawner scripts — the cache handles this

### WeaponDataFlattener

`scripts/combat/weapon_data_flattener.gd` walks all editable sub-dictionaries (`stats`, `shape`, `motion`, `visual`, `particles`, `base_stats`) and flattens them for the test lab UI. New weapons work automatically as long as they follow the nested JSON structure.

### Editable Sections

The following JSON sections are auto-detected as editable parameters:

```
stats, base_stats, shape, spawn, motion, visual, particles
```

Metadata keys that are NOT flattened: `description`, `display_name`, `enabled`, `scene`, `spawner`, `type`, `unlock_condition`

## Checklist

- [ ] Effect directory created: `effects/{weapon_name}/`
- [ ] Spawner script: `{weapon_name}_spawner.gd` with correct arg signature
- [ ] Effect script: `{weapon_name}.gd` extending correct base class
- [ ] Effect scene: `{WeaponName}.tscn` with correct node hierarchy
- [ ] Shader (if needed): `{weapon_name}.gdshader`
- [ ] JSON entry in `data/weapons.json` with all required keys
- [ ] Tier entry in `data/weapon_upgrades.json` with 5 rarity levels
- [ ] `load_from_data()` reads all JSON sections with proper casting
- [ ] Collision layers correct: Layer 4, Mask 8 (for projectile types)
- [ ] Tested in weapon test lab
- [ ] Headless sanity check passes
