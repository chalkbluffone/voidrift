# Voidrift Code Cleanup - Decision Points

This document tracks refactoring decisions to be made during the code cleanup process.

---

## Decision Point 4: RadiantArcConfig Sync

**Status:** ⏳ Pending

`RadiantArcConfig` is missing parameters that exist in `radiant_arc.gd`:

- `sweep_speed`
- `gradient_offset`

Also, default values differ between:

- `radiant_arc.gd` (the main script)
- `radiant_arc_config.gd` (the resource class)
- `weapon_test_lab.gd` (the testing tool)

**Options:**

1. **Make `RadiantArcConfig` the single source of truth** - have `radiant_arc.gd` load defaults from a default config resource
2. **Keep them separate but sync** - add missing parameters to config, document that test lab has its own tuned defaults
3. **Remove `RadiantArcConfig` entirely** - if only using the test lab for configuration

**Decision:** _TBD_

---

## Decision Point 5: GameManager "God Object"

**Status:** ⏳ Pending

`GameManager` is 640+ lines handling many responsibilities:

- XP/leveling system
- Upgrade selection & rarity rolling
- Weapon effects generation
- Run state management
- Scene transitions
- Save/load persistence
- Currency management

**Options:**

1. **Leave as-is** (it works, refactoring is risky and time-consuming)
2. **Full split into focused services:**
   - `RunManager` - run state, timing, scene transitions
   - `UpgradeService` - upgrade selection, rarity rolling
   - `ProgressionManager` - XP, leveling, currency
   - `PersistenceManager` - save/load
3. **Gradual refactor** - extract only the most complex/reusable parts first

**Decision:** _TBD_

---

## Decision Point 6: Asset Folder Structure

**Status:** ⏳ Pending

The `Shoot'em Up/` folder contains sprite assets but has a backtick in the name which can cause issues on some systems and with some tools.

**Options:**

1. **Rename to `shootemup/`** or `shoot_em_up/` (snake_case)
2. **Move contents to `assets/sprites/`** (consolidate with other assets)
3. **Leave as-is** (if it's not causing actual problems)

**Decision:** _TBD_

---

## Completed Fixes (No Decision Needed)

These issues were fixed without requiring input:

- [x] **Fixed missing DataLoader reference in `stats_component.gd`** - Added autoload reference and null check
- [x] **Decision Point 1: Deleted obsolete files** - Removed `radiant_arc_debug_ui.gd`, 55 translation files, `minable_asteroid.gd/.tscn`, `obstacle_manager.gd`, and updated `ship.gd` and `world.tscn` to remove references
- [x] **Decision Point 2: SettingsManager autoload** - Extracted duplicate settings code (~160 lines) to new `globals/settings_manager.gd` autoload. Refactored `options_menu.gd` (97→64 lines) and `pause_menu.gd` (223→175 lines) to use it.
- [x] **Decision Point 3: BasePickup class** - Created `scripts/pickups/base_pickup.gd` (78 lines) with shared magnet attraction logic. Refactored `xp_pickup.gd` (53→17 lines) and `credit_pickup.gd` (55→18 lines). Future item drops can override `_get_fixed_magnet_radius()` for smaller pickup range.

---

## Next Steps

After decisions are made:

1. Implement chosen options for each decision point
2. Run full game test to verify no regressions
3. Update `copilot-instructions.md` with any architectural changes
4. Commit changes with clear commit messages per decision

---

_Last updated: February 1, 2026_
