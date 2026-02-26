# Voidrift — TODO & Issues

## TODO (Priority)

1. Camera orbit (right stick/mouse)
2. More enemy variety
3. Miniboss spawning at intervals
4. Final boss beacon mechanic
5. Sound effects
6. Visual polish (screen shake, particles, damage numbers)

## Known Issues

- Godot shows "invalid UID" warnings on load (cosmetic)

## Resolved Issues (Historical)

- **Ship select hover**: First card appeared hovered on load because `grab_focus()` triggers `focus_entered` → hover tween. Fixed by calling `reset_hover()` immediately after `grab_focus()`.
- **Shader `return` statements**: Godot 4.6 does NOT allow `return` in `fragment()`. Use else blocks or set `COLOR` directly.
- **Array.filter() lambda typing**: Don't use typed parameters like `func(inst: Node)` in filter lambdas — causes "Cannot convert argument" errors. Use untyped `func(inst)`.
- **Station buff flat stats**: Used percentage-scale amounts (0.02–0.15) applied raw as flat bonuses, making +9 Shield actually +0.09. Fixed by scaling flat amounts ×100 at generation in `StationService._generate_single_buff`.
- **HUD shield bar invisible**: `get_stat("max_shield")` doesn't exist — the stat is `"shield"`. Fixed to `get_stat("shield")`.
- **Enemy obstacle avoidance**: Raycast approach caused spinning/clustering. Potential field repulsion caused jitter. Replaced with BFS flow field — globally consistent, deterministic, no per-enemy physics queries.
- **Phase shift into asteroids**: Trapped player. Fixed by keeping `collision_mask=2` (obstacles) during phase shift so `move_and_slide()` slides along asteroid surfaces.

_Last updated: February 25, 2026_
