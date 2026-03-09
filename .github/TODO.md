# Super Cool Space Game — TODO & Issues

## Current Issues (Organized by Development Phase)

### Phase 1: Foundation & Verification 🔴 HIGH PRIORITY

- [ ] Make sure all randomness is based off the run seed
- [ ] Verify XP gain is working correctly (document how it works)
- [ ] Verify the armor stat works (currently suspected broken)
- [ ] Verify the credit_gain stat increases credits gained (currently suspected broken)

### Phase 2: Data & Configuration 🟡 HIGH PRIORITY

- [ ] Update the arena_radius to 5000 (currently 4000)
- [ ] Clean up instruction files — if a value exists in game_config.gd, don't document it in instruction files
- [ ] Review existing todo.md file — determine if still needed

### Phase 3: Blocking UI Bugs 🔴 HIGH PRIORITY

- [ ] Weapons showing on screen as weapon ID instead of display name
- [ ] Ship modules showing as IDs instead of display names

### Phase 4: Weapon System & Stat Bugs 🔴 HIGH PRIORITY

- [ ] Attack speed stat does not speed up Radiant Arc
- [ ] Straight Line Negotiator causing two damage numbers on each hit — check if weapon or damage number system issue, verify all weapons
- [ ] PSP-9000 does not collide with freighters
- [ ] When Timmy Gun and Space Lasers are both selected, Space Lasers never fires — weapon dispatch priority issue (also happens with Nikola's Coil)

### Phase 5: Survivability 🟡 MEDIUM PRIORITY

- [ ] Radiation belt damage should affect health regardless of shield

### Phase 6: UX Feedback & Polish 🟡 MEDIUM PRIORITY

- [ ] When damage numbers get large, display as "16.5k" instead of "16500"
- [ ] When player evades (phase shift), text should pop up near player saying "Evaded!"
- [ ] Gravity well vacuum needs to pull XP in faster (2x current speed)

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

## Completed

- Ability ring indicator HUD (phase shift charges + captain ability cooldown)
- Captain ability charge-up system (starts uncharged, GPUParticles2D spiral, ready glow shader, flash burst)
- Controller rebinding (RT for captain ability, LT for full map)
- GPU particle migration Phase 1+2 (Ion Wake, Space Napalm, Nikola's Coil, Nope Bubble, Level-up reject)
- EffectUtils.create_particles() dispatcher + set_particle_prop() runtime routing
- SettingsManager.use_gpu_particles toggle with persistence
- Fixed Ion Wake and Radiant Arc never appearing in level-up offers (unlock_condition was "none")
- Overtime difficulty multiplier system (1.0x → 10.0x over 9 min overtime, scales enemy HP/damage/speed, HUD label with color feedback)
- Overheal HP bar color changed to synthwave yellow (opaque, matching level label)

_Last updated: March 8, 2026_
