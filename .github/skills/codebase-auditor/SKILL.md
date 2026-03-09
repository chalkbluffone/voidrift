# Codebase Auditor Skill

Performs a comprehensive audit of the Super Cool Space Game codebase to find unused code, duplicated patterns, performance issues, instruction drift, and refactoring opportunities. Outputs a prioritized list of findings to `.github/TODO.md`.

---

## When to Use

- Periodic codebase health check (every major feature milestone)
- After large refactors to catch orphaned code
- When instruction files may have drifted from reality
- When performance profiling suggests systemic issues

## Prerequisites

- All instruction files under `.github/instructions/` are accessible
- `project.godot` autoload section is the source of truth for registered autoloads
- `data/*.json` files define all game content
- `.github/TODO.md` is the output target

---

## Procedure

### Phase 1: Context Gathering

1. **Read all instruction files** — Load every `.github/instructions/*.instructions.md` file to understand documented conventions, rules, and systems.
2. **Read `project.godot` autoload section** — Extract the actual registered autoloads (names, paths, order).
3. **Read `.github/TODO.md`** — Understand existing known issues to avoid duplicates.
4. **Read `data/weapons.json`** — Cross-reference weapon entries against `effects/` directories.

### Phase 2: Instruction Accuracy Audit

Check each instruction file against the actual codebase:

5. **Autoload table** (`architecture.instructions.md`) — Compare the documented autoload table against `project.godot [autoload]`. Flag any mismatches in count, order, names, or purposes.
6. **FrameCache property table** (`logic.instructions.md`) — Read `globals/frame_cache.gd` and compare its actual properties against the documented table. Flag missing or outdated entries.
7. **GameConfig constant inventory** (`gameconfig.instructions.md`) — Read `globals/game_config.gd` and compare every constant against the documented sections. Flag undocumented constants and constants documented but missing from the file.
8. **Collision layers** (`architecture.instructions.md`) — Spot-check a few scene files or scripts to verify layer/mask assignments match the documented table.
9. **Code examples** — Check that example code in instruction files references autoloads, functions, and patterns that actually exist.

### Phase 3: Globals Audit

Read every `globals/*.gd` file completely:

10. **Unused functions** — For each public function, search the codebase for callers. Flag functions with zero external callers.
11. **Unused signals** — For each signal definition, search for `.connect()` or `.emit()` calls. Flag signals that are emitted but never connected, or connected but never emitted.
12. **Unused variables/constants** — Flag constants that are defined but never referenced outside the declaring file.
13. **Style violations** — Check for `:=` usage, triple-quote docstrings, missing explicit types, hardcoded balance values that should be in GameConfig.
14. **Stale references** — Check for references to nodes, groups, scenes, or autoloads that don't exist.

### Phase 4: Scripts Audit

Read every file in `scripts/` subdirectories:

15. **FrameCache bypass** — Search for `get_tree().get_nodes_in_group("enemies")`, `get_nodes_in_group("damage_numbers")`, and similar direct group queries that should use FrameCache. Also check for `get_nodes_in_group("player")` that could use `FrameCache.player`.
16. **Dead code** — Functions never called, variables set but never read, unreachable code after early returns.
17. **Duplicated logic** — Similar patterns across files that could be extracted into shared utilities (e.g., duplicate targeting code, duplicate stat lookups, duplicate spawn avoidance).
18. **Per-frame allocations** — Array/object creation in `_process()` or `_draw()` that could be cached.
19. **Hardcoded magic numbers** — Numeric literals that affect gameplay feel or balance and should be in GameConfig or data files.

### Phase 5: Effects & Shaders Audit

20. **Effects cross-reference** — Verify every `effect_scene` path in `data/weapons.json` points to an existing `.tscn`. Flag orphan effect directories with no weapon reference (distinguish intentional bases/cosmetics from truly orphaned).
21. **Shader performance** — Review each `.gdshader` for expensive per-pixel operations (excessive texture lookups, complex blur kernels).
22. **Shader duplication** — Check for similar code across shaders that could be shared.
23. **Effect cleanup** — Verify effects call `queue_free()` properly and don't leak nodes.

### Phase 6: Output

24. **Prioritize findings** into categories:
    - **P0 — Instruction Accuracy**: Outdated instruction files that will cause AI agents to generate wrong code
    - **P1 — FrameCache Bypass**: Direct group queries that violate the mandatory FrameCache rule
    - **P2 — Dead Code**: Unused functions, variables, signals that add noise
    - **P3 — Performance**: Per-frame allocation, expensive shaders, missing caches
    - **P4 — Hardcoded Values**: Magic numbers that belong in GameConfig
    - **P5 — Refactoring**: Duplication and structural improvements

25. **Update `.github/TODO.md`** — Write findings under a dated "Codebase Audit Findings" section. Preserve existing TODO items and Known Issues. Use checkboxes (`- [ ]`) for each item.

26. **Fix instruction files** — For P0 items (instruction accuracy), apply the fixes directly rather than just logging them. Update autoload tables, constant inventories, property tables, and stale code examples.

---

## Verification

After the audit:

- [ ] All instruction file tables match their source-of-truth files
- [ ] No new autoloads or GameConfig constants are undocumented
- [ ] `.github/TODO.md` contains the full prioritized findings list
- [ ] Headless sanity check still passes (if instruction files were edited)

---

## Notes

- **Do NOT fix code issues** during the audit — only log them. The audit output is a TODO list, not a patch set.
- **DO fix instruction files** when they contain outdated information (P0 items). Stale instructions cause cascading errors in AI-generated code.
- Use subagents (Explore agent) for parallelized file reading across large directories.
- For each "unused function" claim, verify with a codebase-wide grep before flagging — some functions are called dynamically or from `.tscn` signal connections.
