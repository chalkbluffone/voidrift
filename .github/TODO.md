# Super Cool Space Game — TODO & Issues

## TODO (Priority)

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

_Last updated: March 8, 2026_
