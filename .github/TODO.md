# Super Cool Space Game — TODO & Issues

## TODO (Priority)

1. GodotSteam GDExtension installation (Steam overlay/achievements)
2. Camera orbit (right stick/mouse)
3. More enemy variety
4. Miniboss spawning at intervals
5. Final boss beacon mechanic
6. Sound effects
7. Visual polish (screen shake, particles, damage numbers)

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

_Last updated: March 7, 2026_
