---
applyTo: "scripts/systems/**,scenes/gameplay/**"
---

# World & Environment — Voidrift Domain

## Arena Boundary

The play area is a circular arena with a radiation danger zone at the edge:

- `ARENA_RADIUS` — 4000px circular play area radius
- `RADIATION_BELT_WIDTH` — 800px radiation zone at edge
- `RADIATION_DAMAGE_PER_SEC` — DOT applied while in radiation belt
- `RADIATION_PUSH_FORCE` — Pushes player back toward center

Key files:

- `scripts/core/arena_utils.gd` — Static helper (`ArenaUtils`) for boundary calculations
- `scripts/systems/arena_boundary.gd` — Visual radiation belt + damage/push mechanics
- `shaders/radiation_belt.gdshader` — Synthwave grid with pink/cyan neon colors, animated pulse

## Asteroids

50 static, indestructible obstacles placed via seeded RNG:

- `StaticBody2D` on collision layer 2, mask 0 (blocks movement but detects nothing)
- Procedural polygon shapes (6–16 vertices, 30–256px radius, dark gray/brown)
- `Polygon2D` + `CollisionPolygon2D` for visual and physics shape
- `effective_radius` property on each asteroid for spawn avoidance calculations
- `AsteroidSpawner` (RefCounted) uses rejection sampling with minimum separation distance
- Seeded deterministic placement via `GameSeed.rng("asteroids")`
- Player, enemies, and stations all use asteroid positions for spawn avoidance

## Space Stations

15 stations spawn randomly around the arena at run start:

- Player stands in 200px zone (`STATION_ZONE_RADIUS`) to charge for 5s (`STATION_CHARGE_TIME`)
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

- `FLOW_FIELD_CELL_SIZE` — 64px grid cells
- `FLOW_FIELD_UPDATE_INTERVAL` — Recomputes every 0.15s from player position
- `FLOW_FIELD_OBSTACLE_BUFFER` — Buffer around asteroids for blocked cells
- 8-directional BFS routing around blocked cells (asteroids + buffer)
- Enemies sample O(1) direction lookups with bilinear interpolation for smooth paths
- Direction changes are lerped via `ENEMY_TURN_SPEED` to prevent jerky turns

Key file: `scripts/systems/flow_field.gd` (`FlowField` node)

## Fog of War

Gradient-based fog with smooth dissipating edges around explored areas:

- `FOG_GRID_SIZE` — Resolution of fog grid (128)
- `FOG_REVEAL_RADIUS` — Radius revealed around player (800px)
- `FOG_GLOW_INTENSITY` — Neon glow brightness
- `FOG_OPACITY` — Overall fog transparency

Key files:

- `scripts/systems/fog_of_war.gd` — `FogOfWar` RefCounted class managing exploration grid with gradient reveal
- `shaders/fog_of_war.gdshader` — Neon purple gas effect with FBM noise animation

## Resolved Issues

- **Enemy obstacle avoidance**: Raycast approach caused spinning/clustering. Potential field repulsion caused jitter. Replaced with BFS flow field — globally consistent, deterministic, no per-enemy physics queries.
- **Station buff flat stats** used percentage-scale amounts (0.02–0.15) applied raw as flat bonuses, making +9 Shield actually +0.09. Fixed by scaling flat amounts ×100 at generation in `StationService._generate_single_buff`.
