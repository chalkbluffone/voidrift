# Radiant Arc Effect

A dynamic, procedurally-generated synthwave slash effect for Voidrift, built with Polygon2D and custom shaders.

## Overview

The **Radiant Arc** is a neon-glowing crescent arc effect suitable for spawning as a weapon VFX from the player ship. It features:

- **Procedural generation**: Polygon2D-based crescent mesh built at runtime
- **Full parameter control**: Every aspect is configurable (angle, radius, thickness, colors, glow, etc.)
- **Synthwave aesthetic**: Cyan/magenta/pink neon palette with bright core and soft glow
- **Animation**: Fade in/out, UV scrolling, subtle distortion, sweep growth
- **Performance**: Geometry + shader approach, no heavy particle systems
- **Transparency**: Alpha-correct rendering (no opaque black)

## Files

- **RadiantArc.tscn** - Scene file with Node2D root and Polygon2D child
- **radiant_arc.gd** - Main script with procedural arc generation and animation
- **radiant_arc.gdshader** - Shader for neon gradient, glow, and effects
- **radiant_arc_config.gd** - Resource class for reusable parameter configurations
- **radiant_arc_spawner.gd** - Utility class for spawning effects

## Quick Start

### Method 1: Using the Spawner (Recommended)

```gdscript
# In your player/weapon script:
var arc_spawner = RadiantArcSpawner.new(self)

arc_spawner.spawn(
    global_position,           # Where to spawn
    Vector2.RIGHT.rotated(rotation),  # Direction to face
    {
        "arc_angle_deg": 120.0,
        "radius": 50.0,
        "thickness": 15.0,
        "duration": 0.2,
        "glow_strength": 2.0,
    }
)
```

### Method 2: Using Config Resource

Create a `.tres` resource file with `RadiantArcConfig` class and populate parameters in the editor, then:

```gdscript
var config = preload("res://path/to/my_radiant_arc_config.tres")
var arc_spawner = RadiantArcSpawner.new(self)
arc_spawner.spawn_from_config(global_position, direction, config)
```

### Method 3: Direct Instance (Advanced)

```gdscript
var arc = load("res://effects/radiant_arc/RadiantArc.tscn").instantiate()
add_child(arc)
arc.setup({
    "arc_angle_deg": 120.0,
    "radius": 50.0,
    # ... more params
})
arc.spawn_from(global_position, direction)
```

## Parameters

All parameters are fully exposed and configurable:

### Geometry

- **arc_angle_deg** (float): Sweep angle in degrees. Default: `120.0`
  - Range: 10–360 (practical: 60–180)
- **radius** (float): Inner radius of the arc. Default: `50.0`
  - The outer radius is `radius + thickness`
- **thickness** (float): Base width of the arc. Default: `15.0`
- **taper** (float): Thickness falloff along the arc (0–1). Default: `0.8`
  - `1.0` = no taper (uniform width)
  - `0.5` = rapid falloff toward the arc end
- **length_scale** (float): Scale the entire polygon. Default: `1.0`
- **distance** (float): Offset from spawn origin along local +X. Default: `0.0`

### Movement & Lifetime

- **speed** (float): Forward travel speed. Default: `0.0`
  - If `> 0`, the effect moves forward along its rotation
- **duration** (float): Total lifetime in seconds. Default: `0.2`
- **fade_in** (float): Time to fade in. Default: `0.05`
- **fade_out** (float): Time to fade out. Default: `0.1`

### Colors & Glow

- **color_a** (Color): Base gradient color. Default: `(0, 1, 1, 1)` (cyan)
- **color_b** (Color): Mid gradient color. Default: `(1, 0.2, 0.8, 1)` (magenta)
- **color_c** (Color): Accent color. Default: `(1, 0.4, 0.8, 1)` (pink)
- **glow_strength** (float): Multiplier for glow falloff. Default: `2.0`
- **core_strength** (float): Size of bright core band (0–1). Default: `0.6`
- **noise_strength** (float): Distortion/wave intensity. Default: `0.3`
- **uv_scroll_speed** (float): Speed of UV animation. Default: `2.0`

### Orientation & Variation

- **rotation_offset_deg** (float): Add to the aimed rotation. Default: `0.0`
- **follow_mode** (int): How to orient the effect. Default: `0`
  - `0` = fixed rotation
  - `1` = follow aim direction (not yet used in shader)
  - `2` = follow movement vector (not yet used in shader)
- **seed_offset** (float): Randomize noise pattern per effect. Default: `0.0`

## Test Keys

Added test inputs to **ship.gd** for immediate visual feedback:

- **T**: Spawn standard radiant arc
- **Y**: Spawn large arc (wider angle, bigger radius)
- **U**: Spawn quick arc (small, snappy effect)

(Remove these test methods before shipping!)

## How It Works

### Polygon Generation

The script builds a crescent polygon by:

1. Sampling `N` points along the outer arc
2. Sampling the same points on the inner arc (reversed)
3. Merging into a single closed polygon
4. Applying **taper**: thickness decreases toward the arc end

### Animation

- **Progress** parameter (0–1) drives shader effects over lifetime
- **Alpha** blends fade-in/fade-out curves
- **Sweep progress** makes the arc "grow" from thin to full during fade-in
- **UV scroll** and **distortion** create flowing neon energy

### Shader Effects

- **Radial gradient**: Bright core transitioning to soft edges
- **Neon colors**: Smooth blends between color_a, color_b, color_c
- **Wave patterns**: Sine-based modulation along UV
- **Glow multiplier**: Brightens and emphasizes the arc
- **Time-based**: Uses `TIME` for continuous animation

## Performance Notes

- **Single Polygon2D**: Minimal draw calls
- **No particles**: Shader does all visual complexity
- **Alpha blending**: Correct transparency (respects existing layers)
- **Suitable for**: Frequent spawning (e.g., every sword swing)

## Visual Tuning Tips

| Goal             | Adjustment                                |
| ---------------- | ----------------------------------------- |
| Brighter         | Increase `glow_strength`, `core_strength` |
| Thinner slash    | Decrease `thickness`, increase `taper`    |
| Wider sweep      | Increase `arc_angle_deg`                  |
| Faster fade      | Decrease `duration`                       |
| More distortion  | Increase `noise_strength`                 |
| Different colors | Adjust `color_a`, `color_b`, `color_c`    |
| More shimmer     | Increase `uv_scroll_speed`                |

## Integration Example (Weapon Class)

```gdscript
extends Node2D

var arc_spawner: RadiantArcSpawner
var radiant_arc_config: RadiantArcConfig

func _ready() -> void:
    arc_spawner = RadiantArcSpawner.new(self)
    radiant_arc_config = preload("res://weapons/configs/radiant_slash_config.tres")

func fire(direction: Vector2) -> void:
    # Spawn radiant arc at muzzle position
    var muzzle_pos = global_position + direction * 30.0
    arc_spawner.spawn_from_config(muzzle_pos, direction, radiant_arc_config)
    # Fire projectile, damage, etc.
```

## Customization

### Create a New Config

1. Open Godot file browser
2. Right-click → New Resource → RadiantArcConfig
3. Edit all parameters in the Inspector
4. Save as `.tres` file
5. Use with `spawner.spawn_from_config(pos, dir, config)`

### Modify the Shader

Edit **radiant_arc.gdshader** directly. Key uniforms:

- All color and glow parameters are exposed
- `progress` and `alpha` drive animation
- `seed_offset` allows deterministic variation
- Add custom effects by modifying the fragment shader

## Known Limitations & Future Work

- **follow_mode** not fully implemented (currently always fixed rotation)
- No particle accents yet (sparks, etc.) — can add via Sparks node in scene
- Shader uses simple hash noise (could upgrade to Perlin for smoother distortion)
- Only 2D currently (Voidrift scope)

## Credits

Designed as a dynamic synthwave slash effect for **Voidrift**, using procedural geometry and custom Godot 4.5.1 shaders.
