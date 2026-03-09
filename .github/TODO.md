# Super Cool Space Game — TODO & Issues

---

## TODO (Future Features)

1. GodotSteam GDExtension installation (Steam overlay/achievements)
2. Camera orbit (right stick/mouse)
3. More enemy variety
4. Miniboss spawning at intervals
5. Final boss beacon mechanic
6. Sound effects
7. Visual polish (screen shake, particles)

---

## Codebase Audit Findings (March 9, 2026)

Prioritized by impact. Items marked ✅ when resolved.

### P0 — Instruction Accuracy (fix immediately to prevent future mistakes)

- [x] **architecture.instructions.md autoload table is wrong** — ✅ Fixed: removed phantom `GameManager` entry, corrected count to 12 autoloads.
- [x] **logic.instructions.md FrameCache table is incomplete** — ✅ Fixed: table now documents all 8 properties (enemies, damage_numbers, enemy_grid, pickups, powerups, stations, asteroids, player).
- [x] **gameconfig.instructions.md missing ~15 constants** — ✅ Fixed: added `ENEMY_BASE_SPEED`, `SPAWN_RADIUS_MIN/MAX`, `SPAWN_BATCH_*`, `LEVEL_UP_REFRESH_COST`, `LEVEL_UP_QUEUE_FLASH_DELAY`, `ENEMY_GRID_CELL_SIZE`, `STATION_COLLISION_RADIUS`, `STATION_MIN_SEPARATION`, `STATION_BUFF_OPTION_COUNT`, `STATION_FLAT_STATS`, `STATION_STAT_DISPLAY_NAMES`, `STATION_RARITY_COLORS`, `GRAVITY_WELL_BEACON_MIN_SEPARATION`.
- [x] **logic.instructions.md GameManager example** — ✅ Fixed: replaced with `RunManager` reference.

### P1 — FrameCache Bypass (performance + consistency)

- [x] **area_effect_ability.gd** — ✅ Fixed: screen-wide path uses `FrameCache.enemies`, radius path uses `FrameCache.enemy_grid.query_radius()`.
- [x] **world.gd** — ✅ Fixed: uses `FrameCache.stations` instead of group query.

### P2 — Dead Code Removal

- [x] **persistence_manager.gd — 10 unused methods** — ✅ Marked with `## TODO: implement` doc comments indicating future wiring points.
- [x] **persistence_manager.gd — `add_time_played()`** — ✅ Marked with `## TODO: implement` noting it needs a save trigger.
- [x] **data_loader.gd — unused getters** — ✅ Marked with `## TODO: implement` doc comments for future UI integration.
- [x] **file_logger.gd — unused members** — ✅ Implemented `MAX_LOG_SIZE` truncation logic; `log_custom()` and `get_log_path()` already functional.
- [x] **level_up.gd — 4 deprecated stubs** — ✅ Removed `_style_button()`, `_on_button_mouse_entered()`, `_on_button_mouse_exited()`, `_set_button_hover_state()`.

### P3 — Performance Improvements

- [ ] **fog_of_war.gdshader** — 5×5 Gaussian blur kernel = 25 texture lookups per pixel. Consider pre-blurring the fog texture at load time or using a separable two-pass blur.
- [ ] **nope_bubble.gd** — Calls `FrameCache.enemy_grid.query_radius()` every frame even when shield layers are depleted (`_current_layers <= 0`). Add early-return guard.
- [ ] **spin_cycle.gd** — Creates a new `PackedVector2Array` in `_draw()` every frame for the wedge polygon. Cache the array and rebuild only when `slice_fraction` changes.

### P4 — Hardcoded Values → GameConfig

- [ ] **Weapon spread angles** — `timmy_gun.gd` hardcodes ±4° spread, `space_lasers.gd` hardcodes ±3° spread. These should be weapon-data or GameConfig values.
- [ ] **space_nukes_spawner.gd** — `LAUNCH_ARC_MIN_DEG=18.0`, `LAUNCH_ARC_MAX_DEG=52.0` hardcoded as local constants.
- [ ] **space_nukes_effect.gd** — `_missile_speed = projectile_speed * 0.45` hardcoded multiplier.
- [ ] **Minimap / full_map_overlay color duplication** — Similar color constants duplicated across minimap.gd and full_map_overlay.gd.
- [ ] **gravity_well_beacon.gd** — Visual constants (`CIRCLE_RADIUS=50.0`, colors) hardcoded locally.

### P5 — Refactoring Opportunities

- [ ] **Neon projectile visuals** — `personal_space_violator.gd`, `timmy_gun.gd`, `space_lasers.gd`, `straight_line_negotiator.gd` each define similar inner `_Neon*` visual classes. Could extract a shared `NeonProjectileVisual` base.
- [ ] **persistence_manager.gd `_ensure_default_unlocks()`** — Called in both `_ready()` and `load_game()`, resulting in redundant double-check on every startup. Consolidate to one call path.
- [ ] **station_service.gd GameConfig access pattern** — Uses `GameConfig` via autoload name resolution (no `@onready` declaration). Works but inconsistent with the pattern used in other globals. Add explicit declaration for clarity.

---

## Known Issues

- Godot shows "invalid UID" warnings on load (cosmetic)
- `personal_space_violator.gd` declares `GameManager` reference but autoload doesn't exist (cosmetic, unused reference)

_Last updated: March 9, 2026_
