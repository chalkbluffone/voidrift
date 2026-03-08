---
applyTo: "scripts/combat/**,effects/**"
---

# Combat & Weapons — Super Cool Space Game Domain

## Auto-Attack System

All weapons fire automatically — no manual aiming. The `WeaponComponent` handles targeting and spawn timing. Weapons select the nearest enemy within `GameConfig.WEAPON_TARGETING_RANGE` and fire at the configured rate.

## Weapon Architecture

- 17 weapon effect directories under `effects/`, each containing `.gd` + `.tscn` + optional `.gdshader`
- Weapon definitions live in `data/weapons.json` (base stats, visual config, effect scene path)
- Per-weapon rarity tier stat tables in `data/weapon_upgrades.json`
- `WeaponComponent` (`scripts/combat/weapon_component.gd`) manages auto-fire and projectile spawning

## Weapon Tier Upgrade System

Weapons level up through rarity tiers: Common → Uncommon → Rare → Epic → Legendary. Each tier applies stat multipliers defined in `weapon_upgrades.json`. Key constants in GameConfig:

- `MAX_WEAPON_LEVEL` — Maximum weapon upgrade tier
- `WEAPON_RARITY_FACTORS` — Per-tier stat multipliers
- `MAX_WEAPON_SLOTS` — Loadout weapon slot limit

## Common Gotcha: Weapon Stats Not Loading

Weapons use nested `base_stats` dict in JSON. Access the nested dictionary:

```gdscript
# WRONG
var damage: float = weapon_data.get("damage", 10)

# RIGHT
var base_stats: Dictionary = weapon_data.get("base_stats", {})
var damage: float = base_stats.get("damage", 10)
```

## Weapon Implementation Verification Checklist

When adding or changing any weapon, verify ALL of:

- [ ] Weapon is `enabled` in `data/weapons.json`
- [ ] Unlock path is valid (default unlocks or migration in `PersistenceManager`)
- [ ] Weapon appears in run selection/equip flow
- [ ] Effect node actually spawns (verify via FileLogger in `debug_log.txt`)
- [ ] Effect is visibly rendered (z-index/layer/alpha/scale validated)
- [ ] Core behavior works in-game (damage, collision, movement/orbit)
- [ ] Stat scaling works (damage, projectile_count, size, speed, knockback, etc.)
- [ ] Persistent effects clean up correctly on unequip/remove
- [ ] `get_errors` shows no new script/JSON errors

## Weapon Test Lab Maintenance

When making changes to a weapon or its parameters:

1. Update the weapon's default config in `weapon_test_lab.gd` (`_get_default_config()`)
2. Add slider ranges for new parameters in `weapon_test_ui.gd` (`_get_slider_range()`)
3. Ensure parameter names match exactly between the weapon script's `@export` variables and test lab config keys
4. Test all new parameters in the weapon test lab before considering the feature complete

## Common Gotcha: `set_deferred` for Monitoring in Physics Callbacks

When toggling `Area2D.monitoring` inside a physics signal callback (e.g., `body_entered`, `body_exited`), use `set_deferred`:

```gdscript
# WRONG — crashes with "Can't change state while flushing queries"
func _on_body_entered(body: Node2D) -> void:
    _proj_hitbox.monitoring = false
    _aoe_hitbox.monitoring = true

# RIGHT — deferred to avoid physics state conflict
func _on_body_entered(body: Node2D) -> void:
    _proj_hitbox.set_deferred("monitoring", false)
    _aoe_hitbox.set_deferred("monitoring", true)
```

This applies to any weapon effect that transitions between phases (e.g., Space Napalm: projectile → AOE impact).

## Damage Numbers

Floating damage numbers appear at the enemy's position whenever `take_damage()` is called. The system is driven from `BaseEnemy`, not individual weapon effects, so all damage sources are automatically covered.

### Flow

```
Projectile._hit_enemy() → stats.calculate_damage() → enemy.take_damage(amount, source, damage_info)
                                                          ↓
                                                  _spawn_damage_number(amount, damage_info)
                                                          ↓
                                                  DamageNumber.setup() → tween → queue_free()
```

### damage_info Dictionary

Projectiles pass a full `damage_info` dict with crit status:

```gdscript
{"damage": float, "is_crit": bool, "is_overcrit": bool}
```

Non-projectile sources (AoE, beams, mines) pass `{}` (default parameter) → displayed as normal white hits.

### Styling

- **Normal**: White text, `DAMAGE_NUMBER_FONT_SIZE_NORMAL` (16)
- **Crit**: Gold (`UiColors.GOLD`) via `self_modulate`, `[b]` BBCode, "!" suffix, bounce scale (`DAMAGE_NUMBER_CRIT_SCALE`)
- **Overcrit**: Hot pink (`UiColors.HOT_PINK`) via `self_modulate`, `[b]` + `[shake]` BBCode, "!!" suffix, larger bounce (`DAMAGE_NUMBER_OVERCRIT_SCALE`)

### Key Files

- `scripts/ui/damage_number.gd` — `DamageNumber` class (RichTextLabel)
- `scenes/ui/damage_number.tscn` — Scene with z_index=100, bbcode_enabled, fit_content
- `scripts/enemies/base_enemy.gd` — `_spawn_damage_number()` method

### Gotcha: Color via self_modulate

Do **not** use `add_theme_color_override("default_color", color)` or BBCode `[color]` tags — the global Exo2 theme overrides them. Use `self_modulate` on the RichTextLabel node to tint reliably.
