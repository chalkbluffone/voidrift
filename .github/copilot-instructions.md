# Voidrift — Global Constitution

> **Top-down 2D sci-fi roguelike survival game** | Godot 4.6 | Steam (Windows primary)
> Players pilot a ship through space, auto-attacking waves of enemies while collecting XP, leveling up, and choosing upgrades during timed survival runs. Inspired by Megabonk.

---

## Modular Workspace Structure

This project uses a modular agentic workspace. Detailed instructions are distributed across specialized files:

| File                                              | Scope           | Contains                                                                                        |
| ------------------------------------------------- | --------------- | ----------------------------------------------------------------------------------------------- |
| `.github/instructions/logic.instructions.md`      | `**/*.gd`       | GDScript style rules, typing, naming, gotchas, collision layers, FileLogger, testing checklists |
| `.github/instructions/shaders.instructions.md`    | `**/*.gdshader` | Shader conventions, uniform naming, synthwave palette, shader inventory                         |
| `.github/agents/architect.agent.md`               | Agent persona   | Scene composition, signal flow, collision layers, autoloads, data-driven design                 |
| `.github/agents/shader-expert.agent.md`           | Agent persona   | Shader language, CanvasItem pipeline, visual FX patterns                                        |
| `.github/agents/api-specialist.agent.md`          | Agent persona   | Godot 4.6 API changes, new nodes, migration patterns                                            |
| `.github/agents/qa-researcher.agent.md`           | Agent persona   | Playwright-based doc verification, QA workflows                                                 |
| `.github/skills/docs-researcher/SKILL.md`         | Skill           | Playwright MCP crawling for Godot and Copilot docs                                              |
| `.github/skills/state-machine-generator/SKILL.md` | Skill           | Modular GDScript state machine generation                                                       |

### Persona Routing

| Task Type                                                    | Use                               |
| ------------------------------------------------------------ | --------------------------------- |
| Scene tree design, signals, node hierarchy, collision layers | **architect** agent               |
| `.gdshader` files, visual FX, rendering pipeline             | **shader-expert** agent           |
| Godot 4.6 API questions, deprecations, new nodes             | **api-specialist** agent          |
| Verify code against live docs, QA validation                 | **qa-researcher** agent           |
| Unknown 4.6 API or Copilot feature                           | **docs-researcher** skill         |
| State machine for enemies, bosses, UI flows                  | **state-machine-generator** skill |

---

## Research Protocol (Mandatory)

If a Godot 4.6 API, node, method, or a Copilot feature (skills, hooks, agents) is unknown or uncertain, the agent **MUST** use the Playwright MCP to visit official documentation before responding. Do NOT guess.

**Reference URLs:**

- Godot Docs: `https://docs.godotengine.org/en/stable/`
- Godot Class Reference: `https://docs.godotengine.org/en/stable/classes/`
- Copilot Custom Instructions: `https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions`
- Copilot Custom Agents: `https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-custom-agents`
- Copilot Agent Skills: `https://docs.github.com/en/copilot/concepts/agents/about-agent-skills`
- Copilot Hooks: `https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/use-hooks`

---

## GDScript Style (Summary)

Full rules in `.github/instructions/logic.instructions.md`. Key mandates:

- **Explicit typing always** — `: Type =` on every variable, parameter, return. Never use `:=`.
- **`##` doc comments** — Never use `"""` triple-quote strings for docs.
- **JSON casting** — Always cast: `float(data.get("key", 0.0))`, `int(...)`, `bool(...)`.
- **Naming** — `snake_case` functions/variables, `PascalCase` classes/nodes, `SCREAMING_SNAKE` constants.
- **Signals** — Use for cross-system communication. Document with `##`.

---

## Architecture Overview

### Directory Layout

```
data/           9 JSON files — all game content (weapons, ships, captains, enemies, etc.)
globals/        10 autoloads (GameConfig → SettingsManager)
scripts/        GDScript organized by domain (core/, combat/, player/, systems/, ui/, pickups/, enemies/)
scenes/         .tscn files (gameplay/, ui/, pickups/, enemies/)
effects/        17 weapon effect directories, each with .gd + .tscn + .gdshader
shaders/        Global shaders (starfield)
tools/          headless_sanity_check.ps1, weapon_test_lab/, build_megabonk_csv.py
```

### Autoloads (load order)

1. `GameConfig` — Centralized tuning constants (balance, progression, combat, camera, UI)
2. `GameSeed` — Deterministic randomness
3. `DataLoader` — JSON loading + mod merge
4. `PersistenceManager` — Save/load
5. `RunManager` — Run lifecycle
6. `ProgressionManager` — XP + level-up
7. `UpgradeService` — Level-up options
8. `GameManager` — Legacy facade
9. `FileLogger` — Debug logging to `debug_log.txt`
10. `SettingsManager` — Audio/display/monitor selection

### Data Files (`data/`)

| File                     | Content                                      |
| ------------------------ | -------------------------------------------- |
| `base_player_stats.json` | Universal default stats                      |
| `weapons.json`           | Weapon definitions + visual config           |
| `weapon_upgrades.json`   | Per-weapon rarity tier stat tables           |
| `ships.json`             | Ship definitions (speed, stats, phase shift) |
| `captains.json`          | Captain passive + active ability             |
| `synergies.json`         | Ship+Captain combo bonuses                   |
| `ship_upgrades.json`     | Passive upgrade definitions (tomes)          |
| `items.json`             | Pickup items + effects                       |
| `enemies.json`           | Enemy types, stats, behaviors                |

Mods load from `user://mods/` and merge with base data.

### GameConfig Sections (`globals/game_config.gd`)

All game-balance tuning constants live in the `GameConfig` autoload. **Never hardcode balance values in scripts** — add them to GameConfig and reference `GameConfig.CONSTANT_NAME`.

| Section                    | Key Constants                                                                                                                                            |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Player                     | `PLAYER_BASE_SPEED`, `PLAYER_TURN_RATE`                                                                                                                  |
| Enemies (Scaling)          | `ENEMY_HP_EXPONENT`, `ENEMY_DAMAGE_SCALE_PER_MINUTE`, `ENEMY_XP_NORMAL`, `ENEMY_XP_ELITE`                                                                |
| Enemies (Elites)           | `ELITE_BASE_CHANCE`, `ELITE_HP_MULT`, `ELITE_DAMAGE_MULT`, `ELITE_SIZE_SCALE`, `ELITE_COLOR`                                                             |
| Difficulty Stat            | `DIFFICULTY_HP_WEIGHT`, `DIFFICULTY_DAMAGE_WEIGHT`, `DIFFICULTY_SPAWN_WEIGHT`                                                                            |
| Spawning                   | `BASE_SPAWN_RATE`, `SPAWN_RATE_GROWTH`, batch/overtime tuning                                                                                            |
| Swarm Events               | `SWARM_TIMES`, `SWARM_DURATION_MIN`, `SWARM_DURATION_MAX`, `SWARM_SPAWN_MULTIPLIER`, `SWARM_WARNING_DURATION`                                            |
| Pickups                    | `PICKUP_MAGNET_RADIUS`, `PICKUP_MAGNET_SPEED`, `PICKUP_MAGNET_ACCELERATION`                                                                              |
| Credits                    | `CREDIT_DROP_CHANCE`, `CREDIT_SCALE_PER_MINUTE`                                                                                                          |
| Run                        | `DEFAULT_RUN_DURATION`                                                                                                                                   |
| Level Up / Progression     | `XP_BASE`, `XP_EXPONENT`, `MAX_WEAPON_SLOTS`, `MAX_MODULE_SLOTS`, `LEVEL_UP_OPTION_COUNT`                                                                |
| Phase Shift                | `PHASE_SHIFT_DURATION`, `PHASE_SHIFT_COOLDOWN`, `PHASE_RECHARGE_TIME`, `POST_PHASE_IFRAMES`                                                              |
| Survivability / I-Frames   | `DAMAGE_IFRAMES`, `PLAYER_KNOCKBACK_FORCE`, knockback friction, contact damage interval                                                                  |
| Combat / Stats             | `SHIELD_RECHARGE_DELAY`, `SHIELD_RECHARGE_RATE`, `DIMINISHING_RETURNS_DENOMINATOR`, `STAT_CAPS`, `WEAPON_TARGETING_RANGE`, `PROJECTILE_DEFAULT_LIFETIME` |
| Camera                     | `CAMERA_BASE_ZOOM`, `CAMERA_SPEED_ZOOM_FACTOR`, `CAMERA_MIN_ZOOM`, `CAMERA_ZOOM_LERP`                                                                    |
| Upgrade Offer Weights      | `OFFER_WEIGHT_*` — controls weapon vs module frequency at level-up                                                                                       |
| Loot Freighter             | `FREIGHTER_FLEE_DRIFT_INTERVAL`, `FREIGHTER_FLEE_DRIFT_ANGLE`                                                                                            |
| Pickup Scatter (cosmetic)  | `PICKUP_SCATTER_XP`, `PICKUP_SCATTER_CREDIT`, `PICKUP_SCATTER_BURST`, `PICKUP_SCATTER_STARDUST`                                                          |
| UI Cosmetic                | `GAME_OVER_DELAY`, `HUD_AVATAR_SIZE`, `HUD_AVATAR_CROP_FRACTION`                                                                                         |
| Ability Defaults           | `ABILITY_DEFAULT_COOLDOWN`, `ABILITY_DEFAULT_DURATION`                                                                                                   |
| Ship Visual Defaults       | `DEFAULT_VISUAL_WIDTH`, `DEFAULT_VISUAL_HEIGHT`, `DEFAULT_COLLISION_RADIUS`                                                                              |
| Rarity / Upgrade Rolls     | `RARITY_ORDER`, `RARITY_DEFAULT_WEIGHTS`, luck model, tier multipliers                                                                                   |
| Weapon Tier Upgrade System | `MAX_WEAPON_LEVEL`, `WEAPON_RARITY_FACTORS`, stat pick counts, stat weights                                                                              |
| Arena / Boundary           | `ARENA_RADIUS`, `RADIATION_BELT_WIDTH`, `RADIATION_DAMAGE_PER_SEC`, `RADIATION_PUSH_FORCE`, spawn/despawn margins                                        |
| Minimap / Fog of War       | `MINIMAP_SIZE`, `MINIMAP_WORLD_RADIUS`, `FULLMAP_SIZE`, `FOG_GRID_SIZE`, `FOG_REVEAL_RADIUS`, `FOG_GLOW_INTENSITY`, `FOG_OPACITY`                        |

---

## Core Mechanics Summary

- **Auto-attack**: All weapons fire automatically. No manual aiming.
- **Phase Shift**: Dash with i-frames, 3–4 charges, passes through enemies/obstacles.
- **XP → Level Up**: Enemies drop static XP (1 normal, 3 elite) → collect → choose 1 of 3 upgrades.
- **XP Curve**: Polynomial formula: `threshold(level) = ∑ XP_BASE * n^XP_EXPONENT` for n=1 to level-1.
- **Enemy Scaling**: Polynomial HP scaling over time: `hp_mult = 1 + time_minutes^ENEMY_HP_EXPONENT`. Damage scales linearly.
- **Difficulty Stat**: Player stat (0-100%+) that multiplicatively scales enemy HP, damage, and spawn rate.
- **Elite Enemies**: 5% base spawn chance (scaled by `elite_spawn_rate` stat), 3× HP, 2× damage, orange tint, 1.3× size, drop 3 XP.
- **Swarm Events**: Two per run (4 min, 7 min). Warning "A MASSIVE FLEET IS INBOUND" → 3× spawn rate for 45-60 seconds.
- **Rarity System**: Common → Uncommon → Rare → Epic → Legendary.
- **Ship + Captain**: Selected independently per run. Ships own frame/weapon/phase; Captains own passive + active ability.
- **Synergies**: Hidden ship+captain combos (5–8% stat nudges), tracked in PersistenceManager.
- **Run structure**: Timed survival (default 10 min via `GameConfig.DEFAULT_RUN_DURATION`), swarms at intervals, final boss via beacon.
- **Arena Boundary**: Circular 4000px radius play area with 800px radiation belt at edge. Radiation deals DOT and pushes player back toward center.
- **Minimap**: 180px circular minimap in bottom-right showing player, enemies, pickups, arena boundary with fog of war overlay.
- **Full Map Overlay**: 800px map overlay on left side when holding Tab/RT, shows full arena with fog of war.

---

## Validation Requirements

### Headless Sanity Check

After any non-trivial code or data change, run:

```powershell
& "C:\git\godot\Godot_v4.6-stable_win64\Godot_v4.6-stable_win64.exe" --headless --path "C:\git\voidrift" --import --quit
```

Or VS Code task: `godot: headless sanity check`. Pass = exit code 0.

### FileLogger Debugging

Use `FileLogger` autoload for all debug output. Writes to `c:\git\voidrift\debug_log.txt` (cleared each startup).

---

## Development Progress

**Update this section when the user says "lock it in".**

### Completed

Core systems, player ship + Phase Shift, 17 weapon effects, enemy spawner with polynomial scaling, XP/credit pickups, level-up UI with synthwave styling, ship+captain+synergy system, weapon test lab, options menu (audio/display/graphics/debug tabs + primary display picker), ability system, run/progression/upgrade/persistence/settings managers, game over screen, HUD with synthwave theme, centralized GameConfig tuning.

**Session 2026-02-20:**

- Polynomial XP curve system (`XP_BASE`, `XP_EXPONENT`) replacing exponential
- Polynomial enemy HP scaling (`ENEMY_HP_EXPONENT`) replacing exponential
- Static XP drops (1 normal, 3 elite) — no time/difficulty scaling
- Elite enemy system (5% base chance, 3× HP, 2× damage, orange tint + 1.3× size)
- Difficulty stat integration (scales enemy HP, damage, spawn rate)
- Swarm event system (triggers at 4min/7min, 3× spawn rate, 45-60s duration)
- Swarm warning UI ("A MASSIVE FLEET IS INBOUND" centered at top)
- Run tracking for `swarms_completed`
- Debug XP graph visualization in HUD
- Circular arena boundary system (4000px radius with 800px radiation belt)
- Radiation belt shader (synthwave grid with pink/cyan neon colors, animated pulse)
- Arena boundary damage/push mechanics (DOT + force toward center)
- Minimap system (180px circular, bottom-right, shows player/enemies/pickups/boundary)
- Fog of war system (gradient-based with smooth dissipating edges)
- Fog of war shader (neon purple gas effect with FBM noise animation)
- Full map overlay (800px, left side, visible when holding Tab/RT)
- ArenaUtils helper class for boundary calculations
- FogOfWar RefCounted class with gradient reveal system

### TODO (Priority)

1. Camera orbit (right stick/mouse)
2. More enemy variety
3. Miniboss spawning at intervals
4. Final boss beacon mechanic
5. Sound effects
6. Visual polish (screen shake, particles, damage numbers)

### Known Issues

- Godot shows "invalid UID" warnings on load (cosmetic)

### Resolved Issues

- Ship select screen: first card appeared hovered on load because `grab_focus()` triggers `focus_entered` → hover tween. Fixed by calling `reset_hover()` immediately after `grab_focus()`.
- Shader `return` statements: Godot 4.6 does NOT allow `return` in fragment() function. Use else blocks or set COLOR directly.
- Array.filter() lambda typing: Don't use typed parameters like `func(inst: Node)` in filter lambdas — causes "Cannot convert argument" errors. Use untyped `func(inst)`.

---

## Resources

- [Megabonk Wiki](https://megabonk.wiki/wiki/Main_Page)
- [Godot 4 Docs](https://docs.godotengine.org/en/stable/)
- [GDQuest](https://www.gdquest.com/)

_Last updated: February 20, 2026_
