---
applyTo: "scripts/ui/**,scenes/ui/**"
---

# UI & HUD — Super Cool Space Game Domain

## HUD Layout

The HUD uses Orbitron-Bold font throughout with synthwave neon styling.

### Health & Shield Bars

- **Shield bar**: Neon blue `ProgressBar` above HP bar, **20px tall** (same as HP bar). Auto-shows when `max_shield > 0` (uses `get_stat("shield")` — the stat name is `"shield"`, not `"max_shield"`). Repositions HP bar dynamically via `_reposition_bars()`.
- **HP bar**: Hot pink `ProgressBar` below shield bar, **20px tall**. When overhealed, the bar's `max_value` expands to `max_hp + overheal_cap` and the fill switches to synthwave yellow (`COLOR_OVERHEAL = Color(1.0, 0.95, 0.2, 1.0)`). Reverts to hot pink when overheal drains back to normal HP.
- `StatsComponent._recalculate_all()` emits `hp_changed`/`shield_changed` signals to keep HUD in sync.
- Bar positions (`_reposition_bars()`): Shield 8→28, HP 32→52 when both visible; HP 10→30 when no shield.

### Overtime Multiplier Label

- **Position**: Top-center, below the timer label
- **Display**: Shows during overtime only (hidden during countdown). Format: "1.0x", "2.5x", etc.
- **Color coding**: Synthwave cyan (1.0x–2.0x) → orange (2.5x–5.0x) → red (5.5x–10.0x)
- **Source**: `RunManager.get_overtime_multiplier()` called every frame
- **Scene node**: `TopCenter/OvertimeLabel` in `hud.tscn`
- **Font**: Orbitron-Bold, 18px, with outline
- See `enemies.instructions.md` for overtime multiplier escalation mechanics

### Top-Center Layout

The `TopCenter` Control (200px wide, centered) holds three labels stacked vertically:

1. **LevelLabel** — "LV X", neon yellow, 24px. Has `pivot_offset = Vector2(100, 0)` for centered scale tween on level-up.
2. **TimerLabel** — "MM:SS" countdown, 22px, centered. Synthwave cyan with teal outline.
3. **OvertimeLabel** — Multiplier display, hidden until overtime.

### Top-Left Info Labels

Below the HP/Shield bars in TopLeft, a VBoxContainer holds:

- **CreditsLabel** — Gold text, ◈ prefix
- **StardustLabel** — Light blue text, ✦ prefix

### Lifesteal Heal Numbers

- When lifesteal procs, HUD spawns a green `DamageNumber` at the player's world position showing `+N`.
- Color: `COLOR_LIFESTEAL = Color(0.2, 1.0, 0.4, 1.0)` via `self_modulate`.
- Uses `is_heal: true` flag in `damage_info` dict passed to `DamageNumber.setup()`.
- Scene: same `HEAL_NUMBER_SCENE` as combat damage numbers.
- Connected via `StatsComponent.lifesteal_healed(amount, position)` signal.
- Respects `show_damage_numbers` persistence setting.
- Soft cap: same `DAMAGE_NUMBER_MAX_COUNT` group limit as combat numbers (shared `"damage_numbers"` group).

### HUD Weapon & Module Icon Grids

Two 1×4 icon grids flank the ability ring at bottom-center:

- **BottomLeftWeapons** — `HBoxContainer` left of the ability ring, showing equipped weapons (L→R fill)
- **BottomRightModules** — `HBoxContainer` right of the ability ring, `layout_direction = 1` (RTL) so modules fill R→L toward the ring

Each slot is a `Panel` (not `PanelContainer` — PanelContainer forces child layout and breaks anchor-based positioning) containing:

1. **TextureRect** — weapon/module icon loaded from `data.get("image")`
2. **Badge background** — small `PanelContainer` anchored bottom-right with dark semi-transparent `StyleBoxFlat`
3. **Badge label** — rarity-colored level number (e.g. "2"), Orbitron-Bold 10px

Slots use `Panel.set_meta("item_name", ...)` to store display names for the tooltip system. Weapons use `display_name` from JSON; modules use `name`.

- Rarity colors from `UiColors.get_rarity_color(rarity)` (defined in `scripts/ui/ui_colors.gd`)
- Empty slots show 50% transparent placeholder with no badge
- Key variables: `_weapon_slots: Array[Dictionary]`, `_module_slots: Array[Dictionary]`
- Grid built by `_build_slot_row()`, refreshed on `weapons_changed`/`modules_changed` signals

### HUD Icon Tooltips

Custom tooltip system (Godot's built-in `tooltip_text` doesn't work reliably on CanvasLayer children):

- Shared `PanelContainer` (`_icon_tooltip`) with `TipLabel` child, `z_index = 200`
- Styled with dark semi-transparent `StyleBoxFlat`, Orbitron-Bold 14px, neon cyan text
- Positioned above the hovered slot via `mouse_entered`/`mouse_exited` signals connected per slot
- Item names stored as `panel.set_meta("item_name", ...)` on each slot Panel
- `BottomXP` Control has `mouse_filter = MOUSE_FILTER_IGNORE` to avoid intercepting hover events over the icon area

### Ship Avatar

- Captain portrait is displayed inside the ability ring circle (bottom-center), not in the top-right.
- `HUD_AVATAR_SIZE` and `HUD_AVATAR_CROP_FRACTION` control portrait display size.

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
- Card minimum width: 625px

### Card Visual Layers (draw order, bottom to top)

1. **Panel background** — `StyleBoxFlat` with `COLOR_PANEL_BG`, 2px border, 8px corner radius
2. **Gradient overlay** — `ColorRect` at child index 0 (behind content). Shader fades left-to-right AND top-to-bottom (120px band height via `rect_height` uniform synced to card size on `resized` signal). Color matches rarity border at 35% alpha.
3. **Content** — `MarginContainer` → `HBoxContainer` with icon + info
4. **Hover overlay** — Shader-driven edge glow, scanlines, click flash (`ui_upgrade_card_hover.gdshader`)
5. **NEW badge** — Top-right corner label for brand-new items

### Card Image

- Each card has an `IconArea` (96×96, `clip_contents = true`) containing a `TextureRect`
- Images loaded from `data.get("image")` field in JSON (`weapons.json`, `ship_upgrades.json`)
- Path format: `"assets/weapons/[id].png"` or `"assets/ship_upgrades/[id].png"`
- Fallback: `icon.svg` if image not found
- **Icon area uses `SIZE_SHRINK_BEGIN`** to prevent vertical stretching in HBox
- **Drop shadow**: `PanelContainer` with `StyleBoxFlat` (shadow_color 0.35 alpha, size 12, offset 5,5, corner radius 4) inserted at index 0 inside `IconArea`

### Card Content Layout

Each upgrade card shows (top to bottom):

1. **Weapon/module name** — header font, rarity-colored
2. **Rarity subtitle** — rarity name in rarity color, 14px
3. **Short description** — uses `description_short` field from JSON with fallback to `description`; gray text (`Color(0.8, 0.8, 0.8)`)
4. **Level line** (if upgrading existing item) — cyan (`UiColors.CYAN`), format: `"Level X → Y"`; hidden for brand-new items (NEW tag handles that)
5. **Bonus line** (weapons only) — white bold (`FONT_HEADER`), 13px, shows stat effects like `"+8% Damage / +1 Projectile"`

Both level and bonus lines are separate `Label` nodes (`"LevelLine"`, `"BonusLine"`) dynamically created and cleaned up on card refresh.

### NEW Badge

- Shown for brand-new weapons/modules (not upgrades of existing items)
- Positioned top-right corner of card via a `Control` overlay named `"NewTag"` with `PRESET_FULL_RECT` anchors
- Neon yellow text (`UiColors.NEON_YELLOW`), `FONT_HEADER`, 18px
- `mouse_filter = MOUSE_FILTER_IGNORE` on both overlay and label
- **Cleanup gotcha**: Since the overlay is dynamically created (`Control.new()` + `add_child()`), it has no `owner`. Cleanup in `_update_card` must use `find_child("NewTag", true, false)` — the third parameter `owned` defaults to `true`, which skips unowned nodes. Without `owned=false`, stale NewTag overlays accumulate across level-ups.

### Module Level Display

`UpgradeService._build_module_candidates()` includes `"current_level"` in the module option dict (matching weapon behavior). The UI uses a unified `int(option.get("current_level", 0))` lookup for all upgrade types.

## Ability Ring Indicator

Combined HUD element at bottom-center, 50% overlapping the XP bar. Shows captain ability cooldown (center circle) surrounded by a 360° ring of phase shift charge segments. Two keybind badges: below center (ability key), bottom-left (phase shift key).

### Captain Portrait (inside ability circle)

The captain's portrait is rendered as a child `ColorRect` with a circle-mask + vignette shader, inserted below `_draw()` content via `show_behind_parent = true`. Three vignette states based on ability phase:

- **Charging**: `vignette_strength = 0.0` (clear portrait, no dark overlay circle)
- **Ready**: `vignette_strength = 0.6` (subtle edge dimming), dark overlay circle at alpha 0.675, "READY" text overlay
- **Active**: `vignette_strength = 1.0` (medium dimming), dark overlay circle, countdown text

Z-order (bottom to top): ReadyGlow → Portrait → `_draw()` (dark circle, arcs, text) → ChargeParticles.

### Charge-Up System

The captain ability starts **uncharged** at run start (full cooldown duration, typically 75s). Three visual states:

1. **Charging**: Dark desaturated circle with a thin progress arc (blue → purple → pink color ramp). Spiraling `GPUParticles2D` (with `ParticleProcessMaterial`) emit from the ring inward, intensifying as charge progresses (4 → 24 particles, increasing tangential + radial acceleration). No text shown.
2. **Ready**: Ability name displayed in center. Pulsing synthwave glow shader (`shaders/ability_ready_glow.gdshader`) with magenta/cyan/purple color cycling and shimmer. On first charge completion, a flash burst (glow intensity 5.0 → 1.5) and scale pop (1.0 → 1.2 → 1.0) plays.
3. **Active**: Magenta glow pulse around circle with duration countdown number.

Key files:

- `scripts/ui/ability_ring_indicator.gd` — all rendering via `_draw()` + GPUParticles2D + shader ColorRect
- `scenes/ui/ability_ring_indicator.tscn` — Control wrapper
- `shaders/ability_ready_glow.gdshader` — ready-state glow (layered smoothstep: halo + ring + dual shimmer + color cycle)

Constants: `INNER_RADIUS=50`, `RING_INNER=60`, `RING_OUTER=72`, `RING_WIDTH=12`. Ring center at `size.y - 40.0` (XP bar top edge). `pivot_offset` set to ring center for correct scale pop direction.

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

## XP Popup

Persistent accumulated XP counter that appears near the player ship. Shows `+N` in bold Orbitron, punches on increment, fades after idle timeout.

- **Rendering**: Screen space — child of the HUD `CanvasLayer`, NOT world space or ship child
- **Positioning**: Fixed offset from viewport center using `GameConfig.XP_POPUP_RADIUS` and `XP_POPUP_ANGLE_DEG` (polar→cartesian), snapped to integer pixels via `.round()`
- **Key files**: `scripts/ui/xp_popup.gd` (`XpPopup` class), `scenes/ui/xp_popup.tscn`
- **Lazy-init**: Created on first XP gain event, added as child of HUD (`self.add_child()`)
- **Gotcha**: Do NOT place the XP popup in world space or as a ship child — sub-pixel camera offsets and ship rotation cause visible text vibration. Screen-space with viewport-center offset eliminates jitter entirely.

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
- **XP popup text vibration**: World-space or ship-child positioning caused sub-pixel jitter from camera transform and ship rotation. Fixed by moving the popup to screen space (HUD CanvasLayer child) with a fixed offset from viewport center.
