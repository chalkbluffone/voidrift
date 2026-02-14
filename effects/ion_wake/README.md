# Ion Wake

A planar fire shockwave weapon that emits an expanding ring of fire outward from the player's ship.

## Visual Concept

The Ion Wake creates a turbulent ring of fire that rapidly expands outward. It features:

- **Full-quad radial rendering** - A single Sprite2D covers the entire area; the shader computes polar coordinates per-pixel
- **Single color control** - Set `base_color` and the palette (dark embers -> base -> hot -> white-hot) is derived
- **Noise-texture fire** - A seamless `NoiseTexture2D` is sampled at 3 scrolling layers for animated flame patterns
- **Volumetric density** - Noise carves dark holes through the fire so you see space behind it
- **Soft glow halo** - Red/orange glow bleeds past the ring edges
- **Ragged edges** - Noise distorts the ring boundaries for organic, torn shapes

## Files

| File                  | Purpose                                |
| --------------------- | -------------------------------------- |
| `ion_wake.gd`         | Main script (Sprite2D quad + shader)   |
| `ion_wake.gdshader`   | Radial fire ring shader                |
| `fire_noise.tres`     | Seamless noise texture (FastNoiseLite) |
| `ion_wake_spawner.gd` | Helper class to spawn instances        |
| `IonWake.tscn`        | Scene file for instantiation           |

## Parameters

### Shape

- `start_radius` - Ring radius at spawn in pixels (default: 30)
- `max_radius` - Ring radius at full expansion in pixels (default: 350)
- `ring_width_ratio` - Ring thickness as fraction of radius, 0.1-0.6 (default: 0.35)
- `expansion_speed` - How fast the ring expands in pixels/sec (default: 300)

### Timing

- `duration` - Total lifetime of the effect (default: 1.0)
- `fade_in` - Fade-in time at start (default: 0.05)
- `fade_out` - Fade-out time at end (default: 0.3)

### Color

- `base_color` - Single color that drives the entire fire palette (default: `#ff4400`)

### Fire Appearance

- `intensity` - Overall brightness (default: 2.0, range 0.5-5.0)
- `fire_speed` - Flame animation speed (default: 1.0, range 0-5.0)
- `distortion` - How much noise warps the ring edges (default: 0.06, range 0-0.2)
- `fire_detail` - Noise tiling scale (default: 3.5, range 1-8)
- `glow_spread` - Soft glow past ring edges (default: 0.1, range 0-0.25)
- `density_contrast` - How visible the dark holes in the fire are (default: 0.5, range 0-1)

### Tweaking the Noise Texture

Open `fire_noise.tres` in the Godot Inspector to tweak the noise pattern in real-time:

- **`noise_type`**: 3 (Cellular) for craggy fire, 0 (Simplex) for smoother plasma
- **`frequency`**: Lower = bigger blobs, higher = finer detail
- **`fractal_octaves`**: More = more detail layers (4-8)
- **`fractal_gain`**: How much each octave contributes (0.3-0.7)
- **`seed`**: Change for a different pattern

## Usage

### Via Weapon System

Registered as a melee weapon in `weapons.json`. Equip it to the player and it auto-fires based on cooldown.

### Manual Spawning

```gdscript
var spawner = IonWakeSpawner.new(parent_node)
var wake = spawner.spawn(
    ship.global_position,
    {
        "start_radius": 30,
        "max_radius": 400,
        "expansion_speed": 300,
        "base_color": Color(1.0, 0.3, 0.05),
    },
    ship  # Follow source
)
```

## How It Works

Unlike a traditional ring mesh approach, the Ion Wake uses a **full-quad radial shader**:

1. A `Sprite2D` is scaled to cover the entire effect diameter (+ glow margin)
2. The shader converts each pixel's UV to **polar coordinates** (distance from center, angle)
3. The ring shape is computed per-pixel by comparing distance to `ring_radius`
4. A noise texture is sampled at 3 different scales/speeds using the polar coords
5. Noise **distorts the ring edges** for ragged, torn shapes
6. Noise **carves dark holes** in the fire density for a volumetric look
7. A color ramp maps heat (distance from ring center + noise) to dark -> base -> hot -> white
8. Soft exponential glow bleeds past the ring edges

This approach allows unlimited glow bleed, noise distortion, and thick fire that would be impossible with a fixed-width ring mesh.
