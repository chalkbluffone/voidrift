---
applyTo: "scripts/systems/**,scenes/gameplay/**"
---

# World & Environment — Super Cool Space Game Domain

## Arena Boundary

The play area is a circular arena with a radiation danger zone at the edge:

- `ARENA_RADIUS` — circular play area radius
- `RADIATION_BELT_WIDTH` — radiation zone width at the arena edge
- `RADIATION_DAMAGE_PER_SEC` — DOT applied while in radiation belt (bypasses shields; damages HP directly)
- `RADIATION_PUSH_FORCE` — Pushes player back toward center

Key files:

- `scripts/core/arena_utils.gd` — Static helper (`ArenaUtils`) for boundary calculations
- `scripts/systems/arena_boundary.gd` — Visual radiation belt + damage/push mechanics
- `shaders/radiation_belt.gdshader` — Synthwave grid with pink/cyan neon colors, animated pulse

## Asteroids

Static, indestructible obstacles placed via seeded RNG:

- `StaticBody2D` on collision layer 2, mask 0 (blocks movement but detects nothing)
- Procedural polygon shapes with configurable vertex/radius bounds
- `Polygon2D` + `CollisionPolygon2D` for visual and physics shape
- `effective_radius` property on each asteroid for spawn avoidance calculations
- `AsteroidSpawner` (RefCounted) uses rejection sampling with minimum separation distance
- Seeded deterministic placement via `GameSeed.rng("asteroids")`
- Player, enemies, and stations all use asteroid positions for spawn avoidance

## Space Stations

Stations spawn randomly around the arena at run start:

- Player stands in station zone (`STATION_ZONE_RADIUS`) to charge (`STATION_CHARGE_TIME`)
- Charge decays slowly when leaving zone (`STATION_DECAY_TIME`)
- On completion, choose 1 of 3 stat buffs (Uncommon–Legendary rarity, luck-influenced)
- One-time use per station
- `StationService` autoload handles buff generation, rarity rolls with luck influence, and buff application
- Station charge shader: radial progress ring with cyan→pink synthwave gradient
- Station spawner avoids asteroid positions

### Station Buff Scaling

Flat stats (shield, max_hp) use amounts scaled ×100 at generation time in `StationService._generate_single_buff`, so the stored buff amount matches the applied flat value. Percentage-scale stats (damage, speed) use raw decimal values (0.02–0.15).

## Flow Field Pathfinding

BFS-based grid covering the arena for enemy movement:

- `FLOW_FIELD_CELL_SIZE` — flow-field grid cell size
- `FLOW_FIELD_UPDATE_INTERVAL` — recompute cadence from player position
- `FLOW_FIELD_OBSTACLE_BUFFER` — Buffer around asteroids for blocked cells
- 8-directional BFS routing around blocked cells (asteroids + buffer)
- Enemies sample O(1) direction lookups with bilinear interpolation for smooth paths
- Direction changes are lerped via `ENEMY_TURN_SPEED` to prevent jerky turns

Key file: `scripts/systems/flow_field.gd` (`FlowField` node)

## Fog of War

Gradient-based fog with smooth dissipating edges around explored areas:

- `FOG_GRID_SIZE` — resolution of the fog grid
- `FOG_REVEAL_RADIUS` — reveal radius around player
- `FOG_GLOW_INTENSITY` — Neon glow brightness
- `FOG_OPACITY` — Overall fog transparency

Key files:

- `scripts/systems/fog_of_war.gd` — `FogOfWar` RefCounted class managing exploration grid with gradient reveal
- `shaders/fog_of_war.gdshader` — Neon purple gas effect with FBM noise animation

### Performance: Fog Texture Caching

Fog texture is rebuilt only when a dirty flag is set (player moves into a new grid cell), not every frame. This avoids per-frame `ImageTexture` rebuilds which were a major performance bottleneck at high enemy counts.

## Gravity Well Beacons

One-time-use world interactables that vacuum all drops (not power-ups) to the player:

- `GRAVITY_WELL_BEACON_COUNT` beacons per run, spawned by `GravityWellBeaconSpawner`
- Spawn positions avoid asteroids and stations using rejection sampling
- Vacuum skips nodes in `"powerups"` group — power-ups require physical touch
- Vacuum speed uses `GameConfig.GRAVITY_WELL_VACUUM_SPEED` directly (no half-speed multiplier)

### Beacon Visual

Custom `_draw()` on Node2D (no sprite/texture):

- 50px radius circle with pulsing purple glow (`Color(0.5, 0.15, 0.9, 0.7)`)
- Border ring outline
- Centered "GRAVITY\nWELL" text (Orbitron-Bold, 14px)
- Pulse animation via `sin()` modulating alpha

### Beacon Interaction

Manual activation — player must be in range AND press the `interact` input:

- `Area2D` with `GRAVITY_WELL_BEACON_ACTIVATION_RADIUS` for proximity detection
- `body_entered`/`body_exited` signals track `_player_in_range` flag
- `_process()` polls `Input.is_action_just_pressed("interact")` when player is in range
- Proximity prompt shown: `"[E] Activate"` (keyboard) or `"[X] Activate"` (controller)
- Controller detection: `Input.get_connected_joypads().size() > 0`

### Input Action: `interact`

Defined in `project.godot`:

- Keyboard: `E` key (physical keycode 69)
- Gamepad: button index 2 (Square on PS / X on Xbox)

Key files:

- `scripts/systems/gravity_well_beacon.gd` — Beacon node with visual, prompt, and activation logic
- `scripts/systems/gravity_well_beacon_spawner.gd` — Spawner (RefCounted) for placement

## Resolved Issues

- **Enemy obstacle avoidance**: Raycast approach caused spinning/clustering. Potential field repulsion caused jitter. Replaced with BFS flow field — globally consistent, deterministic, no per-enemy physics queries.
- **Station buff flat stats** used percentage-scale amounts (0.02–0.15) applied raw as flat bonuses, making +9 Shield actually +0.09. Fixed by scaling flat amounts ×100 at generation in `StationService._generate_single_buff`.
- **Gravity Well placeholder visual**: Replaced ColorRect with custom `_draw()` circle (pulsing glow, border ring, centered text) and manual activation via `interact` input with proximity prompt.
- **Gravity Well vacuum exemption**: Beacons and Gravity Well power-ups now skip nodes in the `"powerups"` group when vacuuming, so power-ups always require physical touch.
- **Gravity Well refactored to power-up**: `GravityWellPickup` now extends `BasePowerUp` (was `BasePickup`). Dropped from shared power-up pool instead of independent RNG. Scene updated to 48×48 with shader glow.
- **Gravity Well vacuum felt too weak**: Removed legacy `* 0.5` speed multiplier and preserved boosted pickup speed in `BasePickup` so gravity-well pull is meaningfully faster.
- **Radiation survivability mismatch**: Radiation belt damage now bypasses shields and applies directly to HP via `take_damage(..., bypass_shield=true)` to keep boundary pressure meaningful.
