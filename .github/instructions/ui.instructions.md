---
applyTo: "scripts/ui/**,scenes/ui/**"
---

# UI & HUD — Super Cool Space Game Domain

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
- **Polygon clamping rule**: If ANY vertex is clamped to the circular boundary, draw a simple `draw_circle()` dot instead of `draw_colored_polygon()`. Only fully-inside asteroids get polygon treatment (avoids degenerate triangulation).
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

## Main Menu / Title Screen

The title screen (`scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd`) features:

### Starfield Background

- Reuses the gameplay starfield from `world.tscn` — three Parallax2D layers (Nebula, StarsFar, StarsNear) using the same `materials/stars_far.tres` and `materials/stars_near.tres` shader materials.
- Purely horizontal `autoscroll` creates the illusion of a camera panning through space. Speeds increase with layer depth for correct parallax: Nebula `(5, 0)`, StarsFar `(15, 0)`, StarsNear `(30, 0)`.
- Respects `SettingsManager.background_quality`: Low hides near star layer and disables twinkle on far layer (mirrors `world.gd` logic).

### Random Nebula

- On each menu load, picks a random nebula texture from Blue and Purple nebula pools (no Green — clashes with title aesthetics).
- 15 textures total across `assets/backgrounds/Blue Nebula/` and `Purple Nebula/` folders.

### Title Image

- `assets/backgrounds/super_cool_space_game_main_title.png` displayed via `TextureRect`.
- Sized to 30% of viewport height, fully centered horizontally, offset slightly upward.
- Uses `shaders/title_glow.gdshader` for scanlines, chromatic aberration, glow pulse, and vertex-driven 2D float bob (Lissajous-like drift).
- **Float motion is in the vertex shader** — avoids Control layout jerkiness from per-frame `position` updates in GDScript.

### Entrance Animation

- Title scales from 1.15→1.0 with alpha fade-in over 0.8s (ease-out cubic).
- Buttons fade in staggered (0.1s delay each) after title entrance.
- First button grabs focus for gamepad/keyboard nav after animation completes.

### Button Layout

- Buttons (Play, Options, Weapons Lab, Quit) in a VBoxContainer positioned directly below the title image with a 50px gap.
- Same synthwave styling as all other buttons (via `card_hover_fx.gd`).

### Gotcha: Control Node Float Animation

- Do **NOT** animate Control node `position` in `_process()` for smooth float effects — the layout system recalculates and causes jerkiness.
- Use vertex shader `VERTEX` offset instead for buttery-smooth GPU-driven motion.

## Debug XP Graph

Visual XP graph overlay in HUD for debugging progression curve during play.

## Resolved Issues

- **Ship select hover on load**: First card appeared hovered because `grab_focus()` triggers `focus_entered` → hover tween. Fixed by calling `reset_hover()` immediately after `grab_focus()`.
- **HUD shield bar invisible**: `get_stat("max_shield")` doesn't exist — the stat is `"shield"`. Fixed to `get_stat("shield")`.
- **Minimap polygon triangulation spam (60K errors)**: Clamping asteroid vertices to circle edge creates degenerate shapes. Fixed by drawing `draw_circle()` dot when any vertex is clamped instead of attempting `draw_colored_polygon()`.
