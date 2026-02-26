---
applyTo: "scripts/player/**"
---

# Player & Ship — Voidrift Domain

## Ship + Captain System

- **Ship** and **Captain** are selected independently per run
- Ships define frame/weapon loadout/phase shift parameters
- Captains define passive bonus + active ability
- Ship definitions in `data/ships.json`, captain definitions in `data/captains.json`

## Synergies

Hidden ship+captain combo bonuses (5–8% stat nudges) defined in `data/synergies.json`. Discovered synergies are tracked in `PersistenceManager`.

## Phase Shift

Dash mechanic with i-frames:

- 3–4 charges (ship-dependent), recharge over time via `PHASE_RECHARGE_TIME`
- Duration: `PHASE_SHIFT_DURATION`, cooldown: `PHASE_SHIFT_COOLDOWN`
- Post-phase i-frames: `POST_PHASE_IFRAMES`
- Passes through enemies but **slides along asteroids** — keeps `collision_mask=2` (obstacles) during phase shift so `move_and_slide()` still handles asteroid surfaces
- Implementation toggles `collision_layer=0, collision_mask=2` instead of disabling collision shape

## Player Stats

- Base stats loaded from `data/base_player_stats.json`
- `StatsComponent` (`scripts/core/stats_component.gd`) manages HP, shield, all stat modifiers
- `_recalculate_all()` emits `hp_changed`/`shield_changed` signals when those stats change, ensuring HUD stays in sync regardless of modification path (flat bonus, multiplier, base stat)

## Survivability

- **I-Frames**: `DAMAGE_IFRAMES` duration after taking damage
- **Knockback**: `PLAYER_KNOCKBACK_FORCE` with friction decay
- **Contact damage**: Interval-based (not per-frame) via `CONTACT_DAMAGE_INTERVAL`
- **Shield**: Recharges after `SHIELD_RECHARGE_DELAY` at `SHIELD_RECHARGE_RATE`

## Player Spawn

Spawn position uses rejection sampling to avoid asteroids:

- 50 attempts to find a clear position
- Fallback to arena center if all attempts fail
- Must be within the safe zone (inside radiation belt inner edge)

## Resolved Issues

- **Phase shift into asteroids** trapped the player. Fixed by keeping `collision_mask=2` during phase shift so `move_and_slide()` slides along asteroid surfaces instead of phasing inside them.
