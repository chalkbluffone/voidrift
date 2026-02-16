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

1. `GameConfig` — Tuning constants
2. `GameSeed` — Deterministic randomness
3. `DataLoader` — JSON loading + mod merge
4. `PersistenceManager` — Save/load
5. `RunManager` — Run lifecycle
6. `ProgressionManager` — XP + level-up
7. `UpgradeService` — Level-up options
8. `GameManager` — Legacy facade
9. `FileLogger` — Debug logging to `debug_log.txt`
10. `SettingsManager` — Audio/display

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

---

## Core Mechanics Summary

- **Auto-attack**: All weapons fire automatically. No manual aiming.
- **Phase Shift**: Dash with i-frames, 3–4 charges, passes through enemies/obstacles.
- **XP → Level Up**: Enemies drop XP → collect → choose 1 of 3 upgrades (weapons or ship modules).
- **Rarity System**: Common → Uncommon → Rare → Epic → Legendary.
- **Ship + Captain**: Selected independently per run. Ships own frame/weapon/phase; Captains own passive + active ability.
- **Synergies**: Hidden ship+captain combos (5–8% stat nudges), tracked in PersistenceManager.
- **Run structure**: Timed survival (default 12 min), minibosses at intervals, final boss via beacon.

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

Core systems, player ship + Phase Shift, 17 weapon effects, enemy spawner, XP/credit pickups, level-up UI with synthwave styling, ship+captain+synergy system, weapon test lab, options menu, ability system, run/progression/upgrade/persistence/settings managers, game over screen, HUD with synthwave theme.

### TODO (Priority)

1. Camera orbit (right stick/mouse)
2. More enemy variety
3. Miniboss spawning at intervals
4. Final boss beacon mechanic
5. Sound effects
6. Visual polish (screen shake, particles, damage numbers)

### Known Issues

- Godot shows "invalid UID" warnings on load (cosmetic)

---

## Resources

- [Megabonk Wiki](https://megabonk.wiki/wiki/Main_Page)
- [Godot 4 Docs](https://docs.godotengine.org/en/stable/)
- [GDQuest](https://www.gdquest.com/)

_Last updated: February 16, 2026_
