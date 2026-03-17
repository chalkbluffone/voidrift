---
applyTo: "scripts/combat/**,effects/**"
---

# Combat & Weapons — Super Cool Space Game Domain

## Auto-Attack System

All weapons fire automatically — no manual aiming. The `WeaponComponent` handles targeting and spawn timing. Weapons select the nearest enemy within `GameConfig.WEAPON_TARGETING_RANGE` and fire at the configured rate.

### Cooldown + Attack Speed Rule

- Weapon cooldown calculation must apply both:
- Per-weapon `attack_speed` bonuses from weapon level-ups (`WeaponInventory.apply_weapon_stat_mod`)
- Global `attack_speed` from `StatsComponent`
- Apply per-weapon attack speed even when the weapon has an explicit `stats.cooldown` value.

This prevents melee/projectile weapons (including Radiant Arc) from ignoring attack-speed upgrades.

### Multi-Weapon Dispatch Fairness

- Do not iterate weapons in a fixed dictionary order each frame.
- Rotate the starting index each tick (round-robin) when processing ready weapons.

This avoids persistent priority bias where one burst weapon can repeatedly starve another (observed with Timmy Gun vs Space Lasers/Nikola's Coil combinations).

## Weapon Architecture

- 17 weapon effect directories under `effects/`, each containing `.gd` + `.tscn` + optional `.gdshader`
- Weapon definitions live in `data/weapons.json` (base stats, visual config, effect scene path)
- Per-weapon rarity tier stat tables in `data/weapon_upgrades.json`
- `WeaponComponent` (`scripts/combat/weapon_component.gd`) manages auto-fire and projectile spawning

### BlastBullets2D (BB2D) Integration

Six projectile weapons use the [BlastBullets2D](https://github.com/nikoladevelops/godot-blast-bullets-2d) GDExtension for optimized MultiMesh bullet spawning. Plugin lives in `blastbullets2d/`, docs in `documentation/blast_bullets_2d_documentation.md`.

**Key classes (GDExtension — use `ClassDB.instantiate()` since editor locks DLL):**

- `BulletFactory2D` — scene node that spawns/manages bullets. Exposed via `BulletFactoryRef` autoload (`globals/bullet_factory_ref.gd`).
- `DirectionalBulletsData2D` — data class for per-bullet direction/speed. Key properties: `transforms`, `all_bullet_speed_data`, `textures`, `texture_size`, `collision_shape_size`, `max_life_time`, `bullet_max_collision_count`, `monitorable`, `bullets_custom_data`.
- `BulletSpeedData2D` — per-bullet speed data. Properties: `speed`, `max_speed`, `acceleration`. **Not** `speed_acceleration` (that name is invalid and silently ignored).
- `DirectionalBullets2D` — runtime multimesh instance returned by `spawn_controllable_directional_bullets()`. Has homing, orbiting, curves, attachments, movement pattern features.

**Spawn functions:**

- `spawn_directional_bullets(data)` — fire-and-forget, no reference returned. Use for simple projectiles.
- `spawn_controllable_directional_bullets(data)` — returns `DirectionalBullets2D` instance for homing, orbiting, etc.

**Collision routing:** `BulletFactoryRef._on_body_entered` / `_on_area_entered` → `_handle_enemy_hit()`. Weapon-specific logic (PSV falloff, Space Nukes AoE, Space Lasers bounce) via `weapon_id` dispatch.

**BB2D weapons:** Personal Space Violator, Space Lasers, Straight-Line Negotiator, Timmy Gun, Space Nukes. Space Napalm is shader-driven (not BB2D).

**BB2D weapon texture sizes (tuned values, not raw PNG):**

| Weapon                   | `texture_size`         | Scales with `size_mult`?                 |
| ------------------------ | ---------------------- | ---------------------------------------- |
| Personal Space Violator  | `Vector2(76.5, 59.85)` | Yes                                      |
| Space Lasers             | `Vector2(114.0, 16.7)` | No — size only increases targeting range |
| Timmy Gun                | `Vector2(33.75, 34.5)` | Yes                                      |
| Straight-Line Negotiator | `Vector2(40.0, 8.0)`   | Yes                                      |
| Space Nukes              | `Vector2(36.0, 19.5)`  | Yes                                      |

**Bounce bullet edge spawning:** Bounce bullets (Space Lasers, Timmy Gun) spawn from the edge of the hit enemy facing the next target, not from the enemy center. Uses the enemy's `CollisionShape2D` `CircleShape2D` radius + 4px padding. Code in `BulletFactoryRef._spawn_bounce_bullet()`.

**Gotchas:**

- **`max_speed` MUST be set** on every `BulletSpeedData2D`. It defaults to `0.0` and BB2D clamps speed to `max_speed`, so bullets with unset `max_speed` will never move. For constant-speed bullets: `spd.max_speed = spd.speed`. For accelerating bullets (e.g., Space Nukes): set `max_speed` higher than `speed` to allow acceleration room (e.g., `spd.max_speed = projectile_speed * 2.0`).
- `texture_size` controls rendered size, NOT the raw PNG pixel dimensions. Scale appropriately for the weapon's visual intent (e.g., sniper needle ≈ 40×8, not 237×136).
- Collision layers use array indices (1-based): `set_collision_layer_from_array([3])` = layer 3 = Projectiles (bitmask 4). Mask `[4]` = layer 4 = Enemies (bitmask 8).
- `bullet_max_collision_count` exists on both data class and runtime instance. Set on data class for `spawn_directional_bullets`; set on runtime instance for `spawn_controllable_directional_bullets`.
- BB2D has automatic object pooling. No manual pool management needed.

### Space Lasers Visual Contract

- Space Lasers uses `assets/lasers/laser_bullet.png` for projectile visuals.
- The bullet's **top of PNG is the nose** and must face travel direction via a forward-rotation offset (default `90.0` degrees).
- Bolts spawn from the ship collision boundary (not ship center): source origin = ship center + normalized shot direction \* ship collision radius.
- Space Lasers does not use a particle trail; keep the projectile read as a clean additive bullet sprite.
- Optional glow should be texture-based (secondary additive Sprite2D overlay) instead of procedural draw primitives.
- Preserve JSON-driven visual controls in `data/weapons.json` under `space_lasers.visual` (texture-driven color toggle, sprite scaling, and glow overlay tuning).
- Avoid procedural `draw_circle`/`draw_rect` capsule overlays in Space Lasers on macOS Metal; this can trigger `timeout waiting for fence` under high projectile counts.

### Personal Space Violator Visual/Size Contract

- Personal Space Violator projectiles use `assets/lasers/laser_bullet_green.png` via a sprite-based additive visual helper.
- Keep PSP sprite scale fixed from `data/weapons.json` (`personal_space_violator.visual.sprite_scale`); weapon `size` upgrades must not inflate the visual sprite.
- PSP weapon `size` upgrades must increase projectile collision reach (hit radius) by flowing runtime `size_mult` into projectile initialization.

### Projectile Spawn Origin Rule

- Projectile-style weapons should spawn from the firing ship collision edge, not center.
- Use `EffectUtils.source_edge_origin(source, direction, fallback_origin)` when a follow/source node is available.
- Apply the edge-origin rule for initial shots and any burst re-aim/retarget shots.

## Weapon Tier Upgrade System

Weapons level up through rarity tiers: Common → Uncommon → Rare → Epic → Legendary. Each tier applies stat multipliers defined in `weapon_upgrades.json`. Key constants in GameConfig:

- `MAX_WEAPON_LEVEL` — Maximum weapon upgrade tier
- `WEAPON_RARITY_FACTORS` — Per-tier stat multipliers
- `MAX_WEAPON_SLOTS` — Loadout weapon slot limit

## Common Gotcha: Weapon Stats Not Loading

Weapons use nested `base_stats` dict in JSON. Access the nested dictionary:

```gdscript
# WRONG
var damage: float = weapon_data.get("damage", 10)

# RIGHT
var base_stats: Dictionary = weapon_data.get("base_stats", {})
var damage: float = base_stats.get("damage", 10)
```

## Weapon Implementation Verification Checklist

When adding or changing any weapon, verify ALL of:

- [ ] Weapon is `enabled` in `data/weapons.json`
- [ ] Unlock path is valid (default unlocks or migration in `PersistenceManager`)
- [ ] Weapon appears in run selection/equip flow
- [ ] Effect node actually spawns (verify via FileLogger in `debug_log.txt`)
- [ ] Effect is visibly rendered (z-index/layer/alpha/scale validated)
- [ ] Core behavior works in-game (damage, collision, movement/orbit)
- [ ] Stat scaling works (damage, projectile_count, size, speed, knockback, etc.)
- [ ] Persistent effects clean up correctly on unequip/remove
- [ ] `get_errors` shows no new script/JSON errors

## Enemy Queries in Effects (FrameCache)

**All weapon effects and combat scripts must use `FrameCache` for enemy queries** instead of calling `get_nodes_in_group("enemies")` directly. With 17+ weapon effects potentially active, each querying the enemy list every frame, this avoids redundant group scans.

```gdscript
# In effect scripts:
@onready var FrameCache: Node = get_node("/root/FrameCache")

# Use FrameCache.enemies for targeting, AOE checks, etc.
var enemies: Array[Node] = FrameCache.enemies

# Use FrameCache.enemy_grid for spatial neighbor queries (separation, range checks)
var nearby: Array = FrameCache.enemy_grid.query_radius(position, radius)
```

The static utility class `EffectUtils` (`scripts/core/effect_utils.gd`) routes all its helpers (`find_nearest_enemy()`, `has_enemy_in_range()`, `find_enemies_in_range()`) through FrameCache automatically.

## Weapon Test Lab Maintenance

When making changes to a weapon or its parameters:

1. Update the weapon's default config in `weapon_test_lab.gd` (`_get_default_config()`)
2. Add slider ranges for new parameters in `weapon_test_ui.gd` (`_get_slider_range()`)
3. Ensure parameter names match exactly between the weapon script's `@export` variables and test lab config keys
4. Test all new parameters in the weapon test lab before considering the feature complete

## Common Gotcha: `set_deferred` for Monitoring in Physics Callbacks

When toggling `Area2D.monitoring` inside a physics signal callback (e.g., `body_entered`, `body_exited`), use `set_deferred`:

```gdscript
# WRONG — crashes with "Can't change state while flushing queries"
func _on_body_entered(body: Node2D) -> void:
    _proj_hitbox.monitoring = false
    _aoe_hitbox.monitoring = true

# RIGHT — deferred to avoid physics state conflict
func _on_body_entered(body: Node2D) -> void:
    _proj_hitbox.set_deferred("monitoring", false)
    _aoe_hitbox.set_deferred("monitoring", true)
```

This applies to any weapon effect that transitions between phases (e.g., Space Napalm: projectile → AOE impact).

## GPU Particle Migration (EffectUtils)

Weapon effects use `EffectUtils.create_particles()` to spawn particle systems. This dispatcher reads `SettingsManager.use_gpu_particles` and delegates to either `create_cpu_particles()` or `create_gpu_particles()`, allowing a global CPU/GPU toggle.

### Migrated Effects

| Effect               | Systems Migrated                          | Notes                        |
| -------------------- | ----------------------------------------- | ---------------------------- |
| Ion Wake             | 1 (explosion burst)                       | One-shot                     |
| Space Napalm         | 5 (trail, burst, flame, ember, smoke)     | Mix of continuous + one-shot |
| Nikola's Coil        | 4 (impact layers)                         | One-shot bursts              |
| Nope Bubble          | 5 (ambient, swirl, hit, break, + visuals) | Continuous + one-shot        |
| Level-up card reject | 1 (reject particles)                      | UI particle                  |

### Not Yet Migrated (DIRECTED_POINTS)

- **Broken Tractor Beam** — uses `EMISSION_SHAPE_DIRECTED_POINTS`, no GPU equivalent
- **Arc Effect Base** (Radiant Arc, Snarky Comeback) — same issue

### Runtime Property Routing

When setting particle properties at runtime on nodes typed as `Node2D` (which may be either CPUParticles2D or GPUParticles2D), use `EffectUtils.set_particle_prop()` instead of direct assignment:

```gdscript
# WRONG — fails on GPUParticles2D (direction is on ParticleProcessMaterial)
particles.direction = Vector2(1, 0)
particles.emission_ring_radius = 50.0

# RIGHT — routes to correct target with type conversion
EffectUtils.set_particle_prop(particles, "direction", Vector2(1, 0))
EffectUtils.set_particle_prop(particles, "emission_ring_radius", 50.0)
```

`set_particle_prop()` handles:

- **Vector2→Vector3 conversion** for `direction` and `gravity` (material properties)
- **CPU→GPU property name remapping** (e.g., `scale_amount_min` → `scale_min`)
- **Material vs node routing** — properties like `spread`, `initial_velocity_min/max`, `damping_min/max` live on `ParticleProcessMaterial` for GPU particles

### Key Files

- `scripts/core/effect_utils.gd` — `create_particles()`, `create_gpu_particles()`, `set_particle_prop()`
- `globals/settings_manager.gd` — `use_gpu_particles` toggle (persisted in config)

## Damage Numbers

Floating damage numbers appear at the enemy's position whenever `take_damage()` is called. The system is driven from `BaseEnemy`, not individual weapon effects, so all damage sources are automatically covered.

### Flow

```
Projectile._hit_enemy() → stats.calculate_damage() → enemy.take_damage(amount, source, damage_info)
                                                          ↓
                                                  _spawn_damage_number(amount, damage_info)
                                                          ↓
                                                  DamageNumber.setup() → tween → queue_free()
```

### damage_info Dictionary

Projectiles pass a full `damage_info` dict with crit status:

```gdscript
{"damage": float, "is_crit": bool, "is_overcrit": bool}
```

Heal numbers (lifesteal) pass:

```gdscript
{"is_heal": true}
```

Non-projectile sources (AoE, beams, mines) pass `{}` (default parameter) → displayed as normal white hits.

Non-projectile sources (AoE, beams, orbit, melee, mines) also pass a full `damage_info` dict with crit status. **All weapon effects use `StatsComponent.calculate_damage()` and pass `damage_info` to `take_damage()`**, so every weapon can crit.

### Styling

- **Normal**: White text, `DAMAGE_NUMBER_FONT_SIZE_NORMAL` (16), z_index=100
- **Crit**: Gold (`UiColors.GOLD`) via `self_modulate`, `[b]` BBCode, bounce scale (`DAMAGE_NUMBER_CRIT_SCALE`), z_index=101
- **Overcrit**: Hot pink (`UiColors.HOT_PINK`) via `self_modulate`, `[b]` + `[shake]` BBCode, larger bounce (`DAMAGE_NUMBER_OVERCRIT_SCALE`), z_index=102
- **Heal**: Green (`COLOR_LIFESTEAL`) via `self_modulate`, `[b]` BBCode, `+N` prefix, z_index=99

No exclamation mark suffixes on any tier. Z-index layering ensures crits render above normal hits and overcrits render above crits.

### Key Files

- `scripts/ui/damage_number.gd` — `DamageNumber` class (RichTextLabel)
- `scenes/ui/damage_number.tscn` — Scene with z_index=100, bbcode_enabled, fit_content
- `scripts/enemies/base_enemy.gd` — `_spawn_damage_number()` method

### Gotcha: Color via self_modulate

Do **not** use `add_theme_color_override("default_color", color)` or BBCode `[color]` tags — the global Exo2 theme overrides them. Use `self_modulate` on the RichTextLabel node to tint reliably.

### Gotcha: Duplicate Hit Events from Shared Projectile Signals

Projectiles listen to both `body_entered` and `area_entered` to support enemy body collisions and `HitboxArea` collisions. The same enemy can trigger both during one contact.

Guard `_hit_enemy()` by enemy instance ID so each projectile can only apply damage to a given enemy once. Without this, single hits can produce duplicate damage numbers and duplicate damage application (seen with Straight Line Negotiator).

### Gotcha: Orbit Contact Radius vs Large Enemies

Orbit weapons should not use a fixed extra radius for all enemies. Use enemy hitbox shape dimensions (`HitboxArea/HitboxShape`) when computing contact threshold.

This keeps PSP-9000 collisions reliable against large freighters and other non-circular enemies.

### Nikola's Coil Size Scaling

Nikola's Coil (`effects/nikolas_coil/`) scales its targeting reach (`search_radius`) with the combined player `size` × weapon `size` stat multiplier via a `size_mult` property on the coil script. Both the spawner's initial target pre-sort and the coil's chain hop targeting use the scaled radius. Visual bolt width (`arc_width`) and fork length are NOT scaled — only targeting range. The `setup()` method automatically picks up `size_mult` from the weapon component's params dict.
