---
applyTo: "scripts/combat/**,effects/**"
---

# Combat & Weapons — Voidrift Domain

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
