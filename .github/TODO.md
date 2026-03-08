# Super Cool Space Game — TODO & Issues

## TODO (Priority)

1. GodotSteam GDExtension installation (Steam overlay/achievements)
2. Camera orbit (right stick/mouse)
3. More enemy variety
4. Miniboss spawning at intervals
5. Final boss beacon mechanic
6. Sound effects
7. Visual polish (screen shake, particles)

## Known Issues

- Godot shows "invalid UID" warnings on load (cosmetic)

## Resolved Issues (Historical)

- **Codename rename**: Renamed all "Voidrift" references to "Super Cool Space Game" across project.godot, scenes, data schemas, docs, and tools.
- **SteamManager parse errors**: Directly referencing `Steam` class fails when GodotSteam addon isn't installed. Fixed by using `Engine.has_singleton("Steam")` + `Engine.get_singleton("Steam")` + `.call()` for all API methods.
- **PowerShell 5.1 deploy script**: Embedded double quotes in `-replace` operations and em-dash characters caused parse errors. Fixed by using `[char]34` for quotes and ASCII-only text with UTF-8 BOM encoding.
- **macOS export failure**: Missing ETC2 ASTC texture compression for ARM64/universal builds. Fixed by adding `textures/vram_compression/import_etc2_astc=true` to project.godot.
- **SteamCMD depot VDF not found**: Deploy script copied only app_build.vdf to temp dir but depot VDFs referenced relatively. Fixed by copying and patching all VDFs with absolute paths into a temp deploy directory.
- **steam_appid.txt in depots**: SteamCMD warned about inclusion. Fixed by adding `FileExclusion` to all depot VDFs.
- **Ship select hover**: First card appeared hovered on load because `grab_focus()` triggers `focus_entered` → hover tween. Fixed by calling `reset_hover()` immediately after `grab_focus()`.
- **Shader `return` statements**: Godot 4.6 does NOT allow `return` in `fragment()`. Use else blocks or set `COLOR` directly.
- **Array.filter() lambda typing**: Don't use typed parameters like `func(inst: Node)` in filter lambdas — causes "Cannot convert argument" errors. Use untyped `func(inst)`.
- **Station buff flat stats**: Used percentage-scale amounts (0.02–0.15) applied raw as flat bonuses, making +9 Shield actually +0.09. Fixed by scaling flat amounts ×100 at generation in `StationService._generate_single_buff`.
- **HUD shield bar invisible**: `get_stat("max_shield")` doesn't exist — the stat is `"shield"`. Fixed to `get_stat("shield")`.
- **Enemy obstacle avoidance**: Raycast approach caused spinning/clustering. Potential field repulsion caused jitter. Replaced with BFS flow field — globally consistent, deterministic, no per-enemy physics queries.
- **Phase shift into asteroids**: Trapped player. Fixed by keeping `collision_mask=2` (obstacles) during phase shift so `move_and_slide()` slides along asteroid surfaces.
- **Swarm FPS drop (~3 FPS)**: O(n²) enemy separation force + per-frame fog texture rebuild + AOE group-scan fallbacks. Fixed with: spatial hash grid for O(k) separation, enemy leash teleport system, fog texture caching with dirty flag, AOE fallback removal, asteroid position caching for spawn checks.
- **SpatialHashGrid freed-object crash**: Casting a freed entity with `as Node2D` crashes before `is_instance_valid()` can protect. Fixed by checking `is_instance_valid(entity)` before the `as Node2D` cast in `query_radius()`.
- **Minimap polygon triangulation spam (60K errors)**: Clamping asteroid polygon vertices to the circular minimap boundary creates degenerate shapes that fail `draw_colored_polygon()`. Fixed by tracking `any_clamped` flag — if any vertex was clamped, draws a simple `draw_circle()` dot instead.
- **Space napalm monitoring in physics callback**: Setting `monitoring` directly inside `body_entered` signal causes "Can't change state while flushing queries". Fixed with `set_deferred("monitoring", ...)` in `_begin_impact()`.
- **Gravity Well beacon redesign**: Replaced placeholder ColorRect with drawn circle visual (50px radius, pulsing purple glow, border ring, centered "GRAVITY WELL" text), manual activation via `interact` input action with proximity prompt.
- **Title screen overhaul**: Replaced plain dark background with gameplay starfield (reusing existing shader materials), title text with animated PNG image (scanlines, chromatic aberration, glow pulse, GPU vertex bob), random nebula per load, entrance animation, buttons repositioned below title.
- **Weapons Lab button hidden in exports**: Added `OS.has_feature("editor")` guard in `main_menu.gd` to hide the Weapons Lab button in all exported builds. The `tools/*` directory was already excluded from exports, this prevents the orphaned button from appearing.
- **Deploy task fixed**: Added `-Username chalkbluffmedia` and `-SteamCmdExe` parameters to the VS Code deploy task so it works without manual input.
- **Damage numbers implemented**: Floating `DamageNumber` (`RichTextLabel`) spawns at enemy position on every `take_damage()` call. Normal=white, Crit=gold+bounce, Overcrit=hot pink+shake+bounce. Soft cap of 30 labels. Controlled by `show_damage_numbers` persistence setting.
- **Performance diagnostics removed**: Removed `PERF_LOG_INTERVAL` constant from GameConfig and periodic `_log_diagnostics()` polling from `EnemySpawner`. Event-based swarm logging retained.
- **Power-up system implemented**: New `BasePowerUp` class extending `BasePickup` with magnet/vacuum immunity (collision_mask=1, attract_to no-op, "powerups" group). Four power-ups: Health (red heart, 25% max HP), Speed (blue lightning, +300% for 10s), Stopwatch (gold, freeze all enemies 10s), Gravity Well (purple, vacuum drops). 1.5% shared pool per kill. Shared glow shader. Credits changed to guaranteed 1 per kill. Removed `CREDIT_DROP_CHANCE`, `CREDIT_SCALE_PER_MINUTE`, `GRAVITY_WELL_DROP_CHANCE`, `GRAVITY_WELL_MIN_PICKUPS_FOR_DROP` from GameConfig.
- **Stopwatch global freeze**: `BaseEnemy.is_frozen` flag stops movement. SceneTree meta `stopwatch_freeze_active` ensures newly spawned enemies (including freighters) spawn frozen. `LootFreighter._process_movement()` has its own freeze guard since it overrides without calling super.

- **Freighter spawn limiting**: Freighters were spawning too frequently and could appear as elites. Fixed by adding `FREIGHTER_MAX_ACTIVE` (1), cooldown of 60–90s between spawns, and skipping elite roll for `LootFreighter` instances.

_Last updated: March 8, 2026_
