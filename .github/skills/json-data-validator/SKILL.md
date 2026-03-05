---
name: json-data-validator
description: Validates data/*.json files against expected schemas, catches structural errors, and verifies cross-references (scene paths, stat names, rarity tiers).
---

# JSON Data Validator Skill

Use this skill when creating or modifying JSON data files, or when debugging data-related bugs. It defines the expected schema for every `data/*.json` file and common pitfalls.

## When to Activate

- After adding or modifying entries in any `data/*.json` file
- When debugging data loading errors or missing properties
- When the headless sanity check fails with JSON-related errors
- When reviewing data files for correctness

## Validation Process

For each data file, check three things:

1. **Schema compliance** — Required keys present, correct types
2. **Cross-references** — Scene/spawner paths exist as files, stat names are valid
3. **Common pitfalls** — Trailing commas, type mismatches, missing rarity tiers

## File Schemas

### weapons.json

Each weapon entry (keyed by weapon_id):

```
Required keys:
  "description"      : String
  "display_name"     : String
  "enabled"          : bool
  "scene"            : String (res:// path to .tscn)
  "spawner"          : String (res:// path to .gd)
  "stats"            : Dictionary
    "cooldown"       : float (> 0)
    "damage"         : float
  "type"             : String — one of: "projectile", "beam", "area", "orbit", "melee"
  "unlock_condition" : String — one of: "default", "challenge", "none"

Optional sections:
  "targeting"        : String — one of: "nearest", "all", "none", "random"
  "motion"           : Dictionary (speed, sweep_speed, fade_in, fade_out, etc.)
  "shape"            : Dictionary (size, radius, arc_angle_deg, etc.)
  "visual"           : Dictionary (colors as hex strings, glow_strength, etc.)
  "particles"        : Dictionary (count, lifetime, speed_min, speed_max, etc.)
  "spawn"            : Dictionary (spawn_distance, spawn_angle_degrees, etc.)

Cross-references:
  ✓ "scene" path must exist as a file: effects/{weapon_name}/{WeaponName}.tscn
  ✓ "spawner" path must exist as a file: effects/{weapon_name}/{weapon_name}_spawner.gd
  ✓ weapon_id should have a matching entry in weapon_upgrades.json
```

### weapon_upgrades.json

Each weapon entry (keyed by weapon_id):

```
Required keys:
  "display_name"     : String
  "base_behavior"    : String
  "type"             : String (matches weapons.json type)
  "element"          : String
  "special"          : String
  "tags"             : Array[String]
  "strategy_synergies" : String
  "tier_stats"       : Dictionary
    Each stat key maps to a rarity dictionary:
      "common"       : float
      "uncommon"     : float
      "rare"         : float
      "epic"         : float
      "legendary"    : float

Validation rules:
  ✓ Every stat in tier_stats must have ALL 5 rarity tiers
  ✓ Rarity names must be exactly: "common", "uncommon", "rare", "epic", "legendary"
  ✓ Values should generally increase from common → legendary
  ✓ weapon_id must have a matching entry in weapons.json
```

### enemies.json

Each enemy entry (keyed by enemy_id):

```
Required keys:
  "id"               : String (matches key)
  "name"             : String
  "description"      : String
  "scene"            : String (res:// path to .tscn)
  "base_stats"       : Dictionary
    "hp"             : float (> 0)
    "damage"         : float
    "speed"          : float
    "xp_value"       : float
    "credits_value"  : float
    "stardust_value" : float
  "behavior"         : String — one of: "chase", "chase_then_flee", "orbit", "stationary"
  "spawn_weight"     : float (> 0 for spawnable enemies)
  "tags"             : Array[String]

Optional keys:
  "min_difficulty"   : float (0.0 to 1.0)
  "base_stats.flee_speed"       : float (for chase_then_flee enemies)
  "base_stats.drop_burst_count" : float (for loot enemies)

Cross-references:
  ✓ "scene" path must exist: scenes/enemies/{name}.tscn
  ✓ "id" value must match the dictionary key
```

### ships.json

Each ship entry (keyed by ship_id):

```
Required keys:
  "id"               : String (matches key)
  "name"             : String
  "description"      : String
  "sprite"           : String (res:// path to .png)
  "visual"           : Dictionary
    "width"          : float
    "height"         : float
  "collision"        : Dictionary
    "type"           : String ("circle")
    "width"          : float
    "height"         : float
  "base_speed"       : float
  "base_stats"       : Dictionary (stat overrides — keys must exist in base_player_stats.json)
  "starting_weapon"  : String (must exist as key in weapons.json)
  "phase_shift"      : Dictionary
    "id"             : String
    "name"           : String
    "duration"       : float
    "charges"        : float
    "recharge_time"  : float
  "unlock_condition" : String

Cross-references:
  ✓ "starting_weapon" must exist in weapons.json
  ✓ All keys in "base_stats" must exist in base_player_stats.json
  ✓ "sprite" path should exist as a file
```

### captains.json

Each captain entry (keyed by captain_id):

```
Required keys:
  "id"               : String (matches key)
  "name"             : String
  "description"      : String
  "sprite"           : String (res:// path to .png)
  "passive"          : Dictionary
    "id"             : String
    "name"           : String
    "description"    : String
    "effects"        : Dictionary (stat_name: amount — stat names must exist in base_player_stats.json)
  "active_ability"   : Dictionary
    "id"             : String
    "name"           : String
    "description"    : String
    "template"       : String — one of: "buff_self", "area_effect"
    "cooldown"       : float
    "duration"       : float
    "effects"        : Dictionary
  "unlock_condition" : String

Cross-references:
  ✓ All stat names in "passive.effects" must exist in base_player_stats.json
  ✓ "sprite" path should exist as a file
```

### synergies.json

Each synergy entry (keyed by "{ship_id}+{captain_id}"):

```
Required keys:
  "ship_id"          : String (must exist in ships.json)
  "captain_id"       : String (must exist in captains.json)
  "name"             : String
  "description"      : String
  "discovered_text"  : String
  "effects"          : Dictionary (stat_name: amount)

Cross-references:
  ✓ "ship_id" must exist as key in ships.json
  ✓ "captain_id" must exist as key in captains.json
  ✓ Dictionary key must be "{ship_id}+{captain_id}"
  ✓ All stat names in "effects" must exist in base_player_stats.json
```

### ship_upgrades.json

Each module entry (keyed by module_id):

```
Required keys:
  "id"               : String (matches key)
  "name"             : String
  "description"      : String
  "icon"             : String (res:// path)
  "stat"             : String (must exist in base_player_stats.json)
  "per_level"        : float
  "max_level"        : float
  "unlock_condition" : String
  "rarity_weights"   : Dictionary
    "common"         : float
    "uncommon"       : float
    "rare"           : float
    "epic"           : float
    "legendary"      : float

Cross-references:
  ✓ "stat" must exist as key in base_player_stats.json
  ✓ "rarity_weights" must have all 5 tiers
```

### items.json

Each item entry (keyed by item_id):

```
Required keys:
  "id"               : String (matches key)
  "name"             : String
  "description"      : String
  "icon"             : String (res:// path)
  "rarity"           : String — one of: "common", "uncommon", "rare", "epic", "legendary"
  "effects"          : Dictionary (stat_name: amount)
  "unlock_condition" : String
  "stacks"           : bool
  "max_stacks"       : int (-1 for unlimited)

Cross-references:
  ✓ All stat names in "effects" must exist in base_player_stats.json
  ✓ "rarity" must be a valid rarity name
```

### base_player_stats.json

Flat dictionary of stat_name → default_value. This is the master list of all valid stat names.

```
Current valid stats:
  Defensive: max_hp, hp_regen, overheal, shield, armor, evasion, lifesteal, hull_shock
  Offensive: damage, crit_chance, crit_damage, attack_speed, projectile_count, projectile_bounces
  Scaling:   size, projectile_speed, duration, damage_to_elites, knockback, movement_speed
  Phase:     extra_phase_shifts, phase_shift_distance
  Meta:      luck, difficulty
  Economy:   pickup_range, xp_gain, credits_gain, stardust_gain, elite_spawn_rate,
             powerup_multiplier, powerup_drop_chance

Keys starting with "_section_" or "$" are metadata — skip during validation.
```

## Common Pitfalls

| Pitfall                      | Symptom                     | Fix                                                                   |
| ---------------------------- | --------------------------- | --------------------------------------------------------------------- |
| Trailing comma in JSON       | Parse error on load         | Remove comma after last element in array/dict                         |
| String instead of float      | Stats don't apply correctly | Ensure numeric values have no quotes: `25.0` not `"25.0"`             |
| Missing rarity tier          | Tier lookup returns null    | All 5 tiers required: common, uncommon, rare, epic, legendary         |
| Typo in stat name            | Stat silently ignored       | Check against `base_player_stats.json` master list                    |
| Scene path doesn't exist     | Enemy/weapon never spawns   | Verify path matches actual file: `res://scenes/enemies/filename.tscn` |
| `"id"` doesn't match key     | Data lookup fails           | Key and `"id"` field must be identical strings                        |
| Missing `"enabled": true`    | Weapon never available      | Weapons need explicit `"enabled": true`                               |
| Rarity name capitalization   | Lookup fails                | Must be lowercase: `"common"` not `"Common"`                          |
| `$schema`/`_comment` in data | Processed as game entity    | DataLoader skips keys starting with `$` or `_` — this is safe         |

## Quick Validation Checklist

After editing any data file:

- [ ] JSON parses without errors (no trailing commas, matching brackets)
- [ ] All required keys present for the entry type
- [ ] `"id"` matches the dictionary key
- [ ] All `res://` paths point to existing files
- [ ] Stat names exist in `base_player_stats.json`
- [ ] Rarity names are lowercase: common, uncommon, rare, epic, legendary
- [ ] Numeric values are numbers, not strings
- [ ] All 5 rarity tiers present where required
- [ ] Run headless sanity check: exit code 0
