# Quick Reference: Radiant Arc Effect

## Files Created

```
res://effects/radiant_arc/
├── RadiantArc.tscn                  # Scene (Node2D + Polygon2D + Shader)
├── radiant_arc.gd                   # Main script (procedural generation)
├── radiant_arc.gdshader             # Neon shader
├── radiant_arc_config.gd            # Config resource class
├── radiant_arc_spawner.gd           # Spawner utility
├── default_radiant_arc_config.tres  # Default config resource
├── README.md                        # Full documentation
└── IMPLEMENTATION.md                # Implementation summary
```

## Test in Editor

Press these keys when running the game:

- **T** - Standard arc
- **Y** - Large arc
- **U** - Quick arc

## Usage Examples

### Simplest (Copy-Paste Ready)

```gdscript
var spawner = RadiantArcSpawner.new(self)
spawner.spawn(
    global_position,
    Vector2.RIGHT.rotated(rotation),
    {"arc_angle_deg": 120.0, "radius": 50.0, "duration": 0.2}
)
```

### With Config Resource

```gdscript
var config = preload("res://effects/radiant_arc/default_radiant_arc_config.tres")
var spawner = RadiantArcSpawner.new(self)
spawner.spawn_from_config(global_position, direction, config)
```

### Advanced Setup

```gdscript
var arc = load("res://effects/radiant_arc/RadiantArc.tscn").instantiate()
add_child(arc)
arc.setup({
    "arc_angle_deg": 120.0,
    "radius": 50.0,
    "thickness": 15.0,
    "taper": 0.8,
    "duration": 0.2,
    "color_a": Color(0, 1, 1, 1),
    "glow_strength": 2.0,
})
arc.spawn_from(global_position, direction)
```

## Key Parameters at a Glance

| Parameter         | Type  | Default | Notes                           |
| ----------------- | ----- | ------- | ------------------------------- |
| `arc_angle_deg`   | float | 120.0   | Sweep angle (60–180 looks good) |
| `radius`          | float | 50.0    | Inner radius                    |
| `thickness`       | float | 15.0    | Arc width                       |
| `taper`           | float | 0.8     | Falloff (0=sharp, 1=uniform)    |
| `duration`        | float | 0.2     | Lifetime (0.12–0.3 recommended) |
| `glow_strength`   | float | 2.0     | Brightness                      |
| `core_strength`   | float | 0.6     | Bright center band              |
| `color_a`         | Color | Cyan    | Main color                      |
| `color_b`         | Color | Magenta | Mid color                       |
| `color_c`         | Color | Pink    | Accent color                    |
| `uv_scroll_speed` | float | 2.0     | Animation flow speed            |

## Tweaking Tips

**Brighter**: ↑ `glow_strength`, ↑ `core_strength`  
**Thinner**: ↓ `thickness`, ↑ `taper`  
**Wider**: ↑ `arc_angle_deg`  
**Faster fade**: ↓ `duration`  
**More shimmer**: ↑ `uv_scroll_speed`  
**Different colors**: Edit `color_a`, `color_b`, `color_c`

## Integration Checklist

- [x] Effect works in editor
- [x] Test keys (T, Y, U) spawn effects
- [x] Shader renders neon glow correctly
- [x] Alpha transparency working (no black sheets)
- [x] Spawner utility working
- [x] Config resource system ready
- [ ] Integrate into weapon code
- [ ] Create weapon-specific configs
- [ ] Remove test keys before production

## Scene Node Hierarchy

```
RadiantArc (Node2D)
│   [radiant_arc.gd script]
│   [All @export parameters]
└── ArcPoly (Polygon2D)
    [ShaderMaterial → radiant_arc.gdshader]
    [Polygon generated procedurally]
```

## Shader Uniforms (Auto-updated by Script)

- `color_a`, `color_b`, `color_c` - Gradient colors
- `glow_strength`, `core_strength` - Glow control
- `noise_strength` - Distortion intensity
- `uv_scroll_speed` - Animation speed
- `progress` - Animation timeline (0–1)
- `alpha` - Master opacity
- `sweep_progress` - Arc growth (0–1)
- `seed_offset` - Noise variation

## Performance

✅ Single Polygon2D (efficient)  
✅ Single draw call per effect  
✅ Shader handles all effects  
✅ Safe to spawn frequently  
⚠️ Avoid > 20 effects simultaneously (GPU limit)

---

**Ready to integrate!** Pick your integration method and go.
