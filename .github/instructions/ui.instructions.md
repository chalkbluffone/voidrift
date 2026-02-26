---
applyTo: "scripts/ui/**,scenes/ui/**"
---

# UI & HUD — Voidrift Domain

## HUD Layout

The HUD uses Orbitron-Bold font throughout with synthwave neon styling.

### Health & Shield Bars

- **Shield bar**: Neon blue `ProgressBar` above HP bar. Auto-shows when `max_shield > 0` (uses `get_stat("shield")` — the stat name is `"shield"`, not `"max_shield"`). Repositions HP bar dynamically.
- **HP bar**: Hot pink `ProgressBar` below shield bar.
- `StatsComponent._recalculate_all()` emits `hp_changed`/`shield_changed` signals to keep HUD in sync.

### Ship Avatar

- `HUD_AVATAR_SIZE` and `HUD_AVATAR_CROP_FRACTION` control avatar display size.

## Minimap

180px circular minimap in bottom-right corner:

- Shows player (center), enemies, pickups, arena boundary ring
- Station markers: gold (active), gray (depleted) — always visible (not fog-restricted)
- Asteroid polygons: actual shapes scaled to minimap coordinates, fog-restricted, clamped to circular boundary
- World radius visible controlled by `MINIMAP_WORLD_RADIUS` (zoom level)
- Key file: `scripts/ui/minimap.gd`

## Full Map Overlay

800px map overlay on left side, visible when holding Tab/RT:

- Shows full arena with fog of war overlay
- Station markers: fog-restricted visibility
- Asteroid polygons: same as minimap but at full map scale
- Key file: `scripts/ui/full_map_overlay.gd`

## Level-Up UI

- Synthwave-styled card selection (choose 1 of 3 upgrades)
- `LEVEL_UP_OPTION_COUNT` controls number of options shown
- Upgrade card hover shader: `shaders/ui_upgrade_card_hover.gdshader`

## Station Buff Popup

3-choice buff selection matching the level-up UI pattern. Triggered when station charge completes. Uses `GameState.STATION_BUFF` to pause gameplay during selection.

## Swarm Warning

"A MASSIVE FLEET IS INBOUND" displayed centered at top of screen during swarm warning phase.

## Game Over Screen

- `GAME_OVER_DELAY` controls delay before showing screen
- Displays run stats summary

## Debug XP Graph

Visual XP graph overlay in HUD for debugging progression curve during play.

## Resolved Issues

- **Ship select hover on load**: First card appeared hovered because `grab_focus()` triggers `focus_entered` → hover tween. Fixed by calling `reset_hover()` immediately after `grab_focus()`.
- **HUD shield bar invisible**: `get_stat("max_shield")` doesn't exist — the stat is `"shield"`. Fixed to `get_stat("shield")`.
