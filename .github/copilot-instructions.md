# Voidrift — Global Constitution

> **Top-down 2D sci-fi roguelike survival game** | Godot 4.6 | Steam (Windows primary)
> Players pilot a ship through space, auto-attacking waves of enemies while collecting XP, leveling up, and choosing upgrades during timed survival runs. Inspired by Megabonk.

---

## Modular Workspace Structure

This project uses a modular agentic workspace. Detailed instructions are distributed across specialized files:

### Instruction Files

| File                                                | Scope                                   | Contains                                                                   |
| --------------------------------------------------- | --------------------------------------- | -------------------------------------------------------------------------- |
| `.github/instructions/logic.instructions.md`        | `**/*.gd`                               | GDScript style rules, typing, naming, gotchas, FileLogger, testing         |
| `.github/instructions/shaders.instructions.md`      | `**/*.gdshader`                         | Shader conventions, uniform naming, synthwave palette, inventory           |
| `.github/instructions/architecture.instructions.md` | `**`                                    | Directory layout, autoloads, data files, collision layers, GameConfig rule |
| `.github/instructions/gameconfig.instructions.md`   | `**`                                    | Full GameConfig constant inventory by section                              |
| `.github/instructions/combat.instructions.md`       | `scripts/combat/**,effects/**`          | Weapons, auto-attack, weapon tiers, test lab, verification                 |
| `.github/instructions/enemies.instructions.md`      | `scripts/enemies/**,scenes/enemies/**`  | Enemy scaling, elites, swarms, flow field movement, spawning               |
| `.github/instructions/player.instructions.md`       | `scripts/player/**`                     | Phase shift, ship+captain, synergies, stats, survivability                 |
| `.github/instructions/world.instructions.md`        | `scripts/systems/**,scenes/gameplay/**` | Arena boundary, asteroids, stations, flow field, fog of war                |
| `.github/instructions/ui.instructions.md`           | `scripts/ui/**,scenes/ui/**`            | HUD, minimap, full map, level-up UI, station buff popup                    |
| `.github/instructions/progression.instructions.md`  | `globals/**`                            | XP curve, rarity, level-up, station buffs, credits, run structure          |

### Agent & Skill Files

| File                                              | Scope         | Contains                                                    |
| ------------------------------------------------- | ------------- | ----------------------------------------------------------- |
| `.github/agents/architect.agent.md`               | Agent persona | Scene composition, signal flow, collision layers, autoloads |
| `.github/agents/shader-expert.agent.md`           | Agent persona | Shader language, CanvasItem pipeline, visual FX patterns    |
| `.github/agents/api-specialist.agent.md`          | Agent persona | Godot 4.6 API changes, new nodes, migration patterns        |
| `.github/agents/qa-researcher.agent.md`           | Agent persona | Playwright-based doc verification, QA workflows             |
| `.github/skills/docs-researcher/SKILL.md`         | Skill         | Playwright MCP crawling for Godot and Copilot docs          |
| `.github/skills/state-machine-generator/SKILL.md` | Skill         | Modular GDScript state machine generation                   |

### Other Files

| File              | Purpose                                  |
| ----------------- | ---------------------------------------- |
| `.github/TODO.md` | TODO list, known/resolved issues tracker |

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

## Core Mechanics (Quick Reference)

Detailed mechanics live in the domain instruction files. This is the high-level summary:

- **Auto-attack**: All weapons fire automatically. No manual aiming. → `combat.instructions.md`
- **Phase Shift**: Dash with i-frames, 3–4 charges, slides along asteroids. → `player.instructions.md`
- **XP → Level Up**: Static XP drops (1 normal, 3 elite) → polynomial curve → choose 1 of 3 upgrades. → `progression.instructions.md`
- **Enemy Scaling**: Polynomial HP + linear damage over time, difficulty stat multiplier, elites, swarms. → `enemies.instructions.md`
- **Rarity System**: Common → Uncommon → Rare → Epic → Legendary. → `progression.instructions.md`
- **Ship + Captain**: Independent selection per run, hidden synergy combos. → `player.instructions.md`
- **Arena**: Circular 4000px radius, radiation belt, 50 asteroids, 15 stations, flow field pathing. → `world.instructions.md`
- **HUD**: Shield/HP bars, minimap, full map overlay, swarm warnings, level-up UI. → `ui.instructions.md`
- **Run structure**: Timed survival (default 10 min), swarms at intervals, final boss via beacon. → `progression.instructions.md`

---

## "Lock It In" Protocol

When the user says **"lock it in"**, distribute the new knowledge from the current session into the appropriate `.github/instructions/*.instructions.md` domain files:

1. **Identify affected domains** — determine which instruction files cover the newly implemented features.
2. **Update existing instruction files** — add the new mechanics, constants, resolved issues, or gotchas to the relevant domain file(s).
3. **Create new instruction files** — if the work covers a domain that doesn't have an instruction file yet, create one following the established pattern (YAML frontmatter with `applyTo` glob, domain heading, structured sections).
4. **Update `.github/TODO.md`** — move completed TODO items, add new known issues, add new resolved issues.
5. **Update this file's workspace structure table** — if new instruction files were created, add them to the table above.

Do **not** append dated session logs. The instruction files should always reflect the **current state** of the project, not a changelog.

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

## Resources

- [Megabonk Wiki](https://megabonk.wiki/wiki/Main_Page)
- [Godot 4 Docs](https://docs.godotengine.org/en/stable/)
- [GDQuest](https://www.gdquest.com/)

_Last updated: February 25, 2026_
