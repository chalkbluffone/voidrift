# Super Cool Space Game — TODO & Issues

## Current Issues (Organized by Development Phase)

### Phase 1: Foundation & Verification 🔴 HIGH PRIORITY

- [x] Make sure all randomness is based off the run seed
- [x] Verify XP gain is working correctly (document how it works)
- [x] Verify the armor stat works (currently suspected broken)
- [x] Verify the credit_gain stat increases credits gained (currently suspected broken)

### Phase 2: Data & Configuration 🟡 HIGH PRIORITY

- [x] Update the arena_radius to 5000 (currently 4000)
- [x] Clean up instruction files — if a value exists in game_config.gd, don't document it in instruction files
- [x] Review existing todo.md file — keep as active planning + execution tracker

### Phase 3: Blocking UI Bugs 🔴 HIGH PRIORITY

- [x] Weapons showing on screen as weapon ID instead of display name
- [x] Ship modules showing as IDs instead of display names

### Phase 4: Weapon System & Stat Bugs 🔴 HIGH PRIORITY

- [x] Attack speed stat does not speed up Radiant Arc
- [x] Straight Line Negotiator causing two damage numbers on each hit — check if weapon or damage number system issue, verify all weapons
- [x] PSP-9000 does not collide with freighters
- [x] When Timmy Gun and Space Lasers are both selected, Space Lasers never fires — weapon dispatch priority issue (also happens with Nikola's Coil)

### Phase 5: Survivability 🟡 MEDIUM PRIORITY

- [x] Radiation belt damage should affect health regardless of shield

### Phase 6: UX Feedback & Polish 🟡 MEDIUM PRIORITY

- [x] When damage numbers get large, display as "16.5k" instead of "16500"
- [x] When player evades (phase shift), text should pop up near player saying "Evaded!"
- [x] Gravity well vacuum needs to pull XP in faster (2x current speed)

### Phase 7: Level-Up System 🟡 MEDIUM PRIORITY

- [ ] On player leveling up, offer next-level upgrades for existing weapons + new weapons until all 4 slots locked (currently only shows new weapons until all 4 selected)

### Phase 8: Map & Minimap 🟡 MEDIUM PRIORITY

- [ ] Powerups should show on map and minimap with icon and color indicator
- [ ] Minimap rendering asteroids as circles until close — revert to proper rendering (performance optimization removed)

### Phase 9: Spawning & Balance 🟡 MEDIUM PRIORITY

- [ ] Gravity well beacons should randomly spawn with no more than 5 and no less than 2
- [ ] Difficulty scales way too fast — needs to be much more subtle
- [ ] When freighters evade, they can get stuck on asteroids; same with enemies tracking player — modify pathfinding to prevent stuck state without rewriting tracking code

### Phase 10: Controller Support 🟠 LOW PRIORITY

- [ ] Fix space station reward so it works with controller
- [ ] Gravity well shrine should dynamically show input prompt based on keyboard/mouse vs controller

### Phase 11: Performance & Polish 🟠 LOW PRIORITY

- [ ] Instead of credit drops, just update credits earned without visible drop animation (performance optimization)
- [ ] When player gets extra phase shift charges, HUD doesn't update visually with additional sections

---

## TODO (Future Features)

1. GodotSteam GDExtension installation (Steam overlay/achievements)
2. Camera orbit (right stick/mouse)
3. More enemy variety
4. Miniboss spawning at intervals
5. Final boss beacon mechanic
6. Sound effects
7. Visual polish (screen shake, particles)

## Known Issues

- Godot shows "invalid UID" warnings on load (cosmetic)

_Last updated: March 8, 2026_
