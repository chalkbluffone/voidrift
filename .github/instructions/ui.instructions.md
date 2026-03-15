---
applyTo: "scripts/ui/**,scenes/ui/**"
---

# UI & HUD — Super Cool Space Game Domain

## HUD Layout

The HUD uses Orbitron-Bold font throughout with synthwave neon styling.

### Health & Shield Bars

- **Shield bar**: Neon blue `ProgressBar` above HP bar. Auto-shows when `max_shield > 0` (uses `get_stat("shield")` — the stat name is `"shield"`, not `"max_shield"`). Repositions HP bar dynamically.
- **HP bar**: Hot pink `ProgressBar` below shield bar. When overhealed, the bar's `max_value` expands to `max_hp + overheal_cap` and the fill switches to synthwave yellow (`COLOR_OVERHEAL = Color(1.0, 0.95, 0.2, 1.0)`). Reverts to hot pink when overheal drains back to normal HP.
- `StatsComponent._recalculate_all()` emits `hp_changed`/`shield_changed` signals to keep HUD in sync.

### Overtime Multiplier Label

- **Position**: Top-center, below the player level label ("LV X")
- **Display**: Shows during overtime only (hidden during countdown). Format: "1.0x", "2.5x", etc.
- **Color coding**: Synthwave cyan (1.0x–2.0x) → orange (2.5x–5.0x) → red (5.5x–10.0x)
- **Source**: `RunManager.get_overtime_multiplier()` called every frame
- **Scene node**: `TopCenter/OvertimeLabel` in `hud.tscn`
- **Font**: Orbitron-Bold, 18px, with outline
- See `enemies.instructions.md` for overtime multiplier escalation mechanics

### Lifesteal Heal Numbers

- When lifesteal procs, HUD spawns a green `DamageNumber` at the player's world position showing `+N`.
- Color: `COLOR_LIFESTEAL = Color(0.2, 1.0, 0.4, 1.0)` via `self_modulate`.
- Uses `is_heal: true` flag in `damage_info` dict passed to `DamageNumber.setup()`.
- Scene: same `HEAL_NUMBER_SCENE` as combat damage numbers.
- Connected via `StatsComponent.lifesteal_healed(amount, position)` signal.
- Respects `show_damage_numbers` persistence setting.
- Soft cap: same `DAMAGE_NUMBER_MAX_COUNT` group limit as combat numbers (shared `"damage_numbers"` group).

### Ship Avatar

- `HUD_AVATAR_SIZE` and `HUD_AVATAR_CROP_FRACTION` control avatar display size.

## Minimap

180px circular minimap in bottom-right corner:

- Shows player (center), enemies, pickups, arena boundary ring
- Station markers: gold (active), gray (depleted) — always visible (not fog-restricted)
- Asteroid polygons: actual shapes scaled to minimap coordinates, fog-restricted, clamped to circular boundary
- **Polygon clamping rule**: If ANY vertex is clamped to the circular boundary, draw a simple `draw_circle()` dot instead of `draw_colored_polygon()`. Only fully-inside asteroids get polygon treatment (avoids degenerate triangulation).
- World radius visible controlled by `MINIMAP_WORLD_RADIUS_COVERAGE` (fraction of `ARENA_RADIUS`, zoom level)
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

## Ability Ring Indicator

Combined HUD element at bottom-center, 50% overlapping the XP bar. Shows captain ability cooldown (center circle) surrounded by a 360° ring of phase shift charge segments. Two keybind badges: below center (ability key), bottom-left (phase shift key).

### Charge-Up System

The captain ability starts **uncharged** at run start (full cooldown duration, typically 75s). Three visual states:

1. **Charging**: Dark desaturated circle with a thin progress arc (blue → purple → pink color ramp). Spiraling `GPUParticles2D` (with `ParticleProcessMaterial`) emit from the ring inward, intensifying as charge progresses (4 → 24 particles, increasing tangential + radial acceleration). No text shown.
2. **Ready**: Ability name displayed in center. Pulsing synthwave glow shader (`shaders/ability_ready_glow.gdshader`) with magenta/cyan/purple color cycling and shimmer. On first charge completion, a flash burst (glow intensity 5.0 → 1.5) and scale pop (1.0 → 1.2 → 1.0) plays.
3. **Active**: Magenta glow pulse around circle with duration countdown number.

Key files:

- `scripts/ui/ability_ring_indicator.gd` — all rendering via `_draw()` + GPUParticles2D + shader ColorRect
- `scenes/ui/ability_ring_indicator.tscn` — Control wrapper
- `shaders/ability_ready_glow.gdshader` — ready-state glow (layered smoothstep: halo + ring + dual shimmer + color cycle)

Constants: `INNER_RADIUS=50`, `RING_INNER=60`, `RING_OUTER=72`, `RING_WIDTH=12`. Ring center at `size.y - 40.0` (XP bar top edge).

### Keybind Badges

Auto-detect keyboard vs controller via `InputMap` and `input_device_changed` signal. Keyboard shows key names (Q, Space), controller shows button/axis names (RT, A). Font dynamically sizes ability name to fit circle.

### Phase Charge Segment Sync

- When `extra_phase_shifts` changes (level-up or station buff), ship phase capacity is recalculated immediately.
- `phase_energy_changed(current, max)` is emitted with the updated max so `AbilityRingIndicator` redraws segment count right away.
- On capacity increases, newly gained charge slots are filled immediately (current charges increase by the delta).

## Station Buff Popup

3-choice buff selection matching the level-up UI pattern. Triggered when station charge completes. Uses `GameState.STATION_BUFF` to pause gameplay during selection.

Controller support details:

- Explicit focus-neighbor wiring for station cards and Ignore button ensures reliable D-pad/left-stick navigation.
- `ui_accept` now works on both focused station cards and focused Ignore button.
- If focus is lost, popup recovers by focusing the first visible card.

## Swarm Warning

"A MASSIVE FLEET IS INBOUND" displayed centered at top of screen during swarm warning phase.

## Game Over Screen

- `GAME_OVER_DELAY` controls delay before showing screen
- Displays run stats summary
- Shows **Run ID** (UUID) at the bottom of the stats list in subtle gray (font size 14)

## Pause Menu

- Shows **Run ID** below the "PAUSED" title in subtle gray (font size 12)
- Run ID is populated from `RunManager.run_data.run_id` each time the pause menu opens

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
- **Weapons Lab button is editor-only**: Hidden via `OS.has_feature("editor")` check in `_ready()`. In exported builds (debug or release), the button is invisible, unstyled, unconnected, and excluded from the entrance animation. The `VBoxContainer` layout collapses the gap automatically. The `tools/*` directory is excluded from exports via `exclude_filter`, so the weapon test lab scene doesn't exist in builds.

### Gotcha: Control Node Float Animation

- Do **NOT** animate Control node `position` in `_process()` for smooth float effects — the layout system recalculates and causes jerkiness.
- Use vertex shader `VERTEX` offset instead for buttery-smooth GPU-driven motion.

## Debug XP Graph

Visual XP graph overlay in HUD for debugging progression curve during play.

## Damage Numbers

Floating `RichTextLabel` nodes spawned in world space at enemy hit positions or player position (heals). See `combat.instructions.md` for full details.

- Scene: `scenes/ui/damage_number.tscn` (bbcode_enabled, fit_content, mouse_filter=IGNORE)
- Script: `scripts/ui/damage_number.gd` (`DamageNumber` class)
- Font: Orbitron-Bold with 3px black outline for readability
- Animation: rise upward (`DAMAGE_NUMBER_RISE_DISTANCE`) + fade out over `DAMAGE_NUMBER_DURATION`
- Crit/overcrit: bounce scale via `create_tween()`, BBCode bold/shake. No exclamation mark suffixes.
- **Compact formatting**: values >= 1000 render as `k` shorthand with one decimal (`16500` -> `16.5k`, `12000` -> `12k`)
- **Heal numbers**: Green `+N` text for lifesteal procs via `is_heal` flag in `damage_info`
- **Evade popup**: During phase shift, blocked hits spawn cyan `Evaded!` popup text near the ship via `is_evade` flag in `DamageNumber.setup()`
- **Z-index layering**: heal=99, normal=100, crit=101, overcrit=102 — ensures crits render above normal hits
- Soft cap: 30 simultaneous labels (`"damage_numbers"` group), oldest removed when exceeded
- Setting: `PersistenceManager.persistent_data.settings.show_damage_numbers` (default `true`)
- Added to `get_tree().current_scene` (not enemy child) so labels survive enemy death

## Resolved Issues

- **Ship select hover on load**: First card appeared hovered because `grab_focus()` triggers `focus_entered` → hover tween. Fixed by calling `reset_hover()` immediately after `grab_focus()`.
- **HUD shield bar invisible**: `get_stat("max_shield")` doesn't exist — the stat is `"shield"`. Fixed to `get_stat("shield")`.
- **Minimap polygon triangulation spam (60K errors)**: Clamping asteroid vertices to circle edge creates degenerate shapes. Fixed by drawing `draw_circle()` dot when any vertex is clamped instead of attempting `draw_colored_polygon()`.
- **Missing phase-shift feedback**: Added `Evaded!` popup text when incoming hits are ignored during active phase shift, with cooldown via `GameConfig.EVADE_POPUP_COOLDOWN` to prevent spam.
