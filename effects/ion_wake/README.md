# Ion Wake

A planar shockwave weapon that emits an expanding ring of energy outward from the player's ship. Inspired by the classic sci-fi "Saturn ring explosion" effect seen in movies like Star Trek.

## Visual Concept

The Ion Wake creates a luminous ring that rapidly expands outward in all directions from the ship's center. It features:

- **Bright leading edge** - The outer expanding front of the ring glows white/cyan
- **Color gradient** - Transitions from bright cyan at the edge to deep blue at the trail
- **Energy effects** - Electric arcs, chromatic aberration, and pulse effects
- **Particle trail** - Sparks and energy motes emit along the ring

## Files

| File                  | Purpose                               |
| --------------------- | ------------------------------------- |
| `ion_wake.gd`         | Main script controlling the effect    |
| `ion_wake.gdshader`   | Shader for ring rendering and effects |
| `ion_wake_spawner.gd` | Helper class to spawn instances       |
| `IonWake.tscn`        | Scene file for instantiation          |

## Parameters

### Shape

- `inner_radius` - Starting radius of the ring (default: 20)
- `outer_radius` - Maximum expansion radius (default: 200)
- `ring_thickness` - Thickness of the ring band (default: 30)
- `expansion_speed` - How fast the ring expands in pixels/sec (default: 300)

### Timing

- `duration` - Total lifetime of the effect (default: 1.0)
- `fade_in` - Fade-in time at start (default: 0.05)
- `fade_out` - Fade-out time at end (default: 0.3)

### Colors

- `color_inner` - Inner ring color (bright cyan)
- `color_outer` - Outer/trailing color (deep blue)
- `color_edge` - Leading edge glow color (white)

### Visual Effects

- `glow_strength` - Intensity of the glow (default: 3.0)
- `core_strength` - Leading edge brightness (default: 1.5)
- `noise_strength` - Edge distortion amount (default: 0.2)
- `edge_thickness` - Thickness of bright leading edge (default: 0.08)
- `chromatic_aberration` - RGB split effect (0-1+)
- `pulse_strength` - Flicker intensity (0-1)
- `pulse_speed` - Flicker speed
- `electric_strength` - Electric arc effect (0-1)
- `electric_frequency` - Arc detail level
- `electric_speed` - Arc animation speed

### Particles

- `particles_enabled` - Enable/disable particles
- `particles_amount` - Number of particles
- `particles_size` - Size of particles
- `particles_speed` - Outward velocity
- `particles_lifetime` - How long particles live
- `particles_color` - Particle color

## Usage

### Via Weapon System

The Ion Wake is registered as a melee weapon in `weapons.json`. Equip it to the player and it will auto-fire based on cooldown.

### Manual Spawning

```gdscript
var spawner = IonWakeSpawner.new(parent_node)
var wake = spawner.spawn(
    ship.global_position,
    {
        "inner_radius": 30,
        "outer_radius": 300,
        "expansion_speed": 400,
        "color_inner": Color(0.4, 0.8, 1.0),
    },
    ship  # Follow source
)
```

## Hitbox Behavior

The Ion Wake uses an expanding circular hitbox that grows with the ring:

- Enemies are hit once when the ring passes through them
- Already-hit targets are tracked to prevent double damage
- The hitbox radius matches the current visual ring position

## Shader Details

The shader uses UV coordinates where:

- **U (x-axis)**: 0 = leading edge (outer), 1 = trailing edge (inner)
- **V (y-axis)**: 0-1 wrapping around the ring circumference

This allows the shader to create:

- Sharp leading edge glow that fades inward
- Noise distortion based on position around the ring
- Proper color gradients from edge to trail
