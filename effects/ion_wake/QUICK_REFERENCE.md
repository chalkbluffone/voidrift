# Ion Wake - Quick Reference

## Spawn Example

```gdscript
var spawner = IonWakeSpawner.new(scene_root)
var wake = spawner.spawn(position, params, follow_source)
```

## Key Parameters

| Parameter         | Default | Description            |
| ----------------- | ------- | ---------------------- |
| `inner_radius`    | 20      | Starting radius        |
| `outer_radius`    | 200     | Max expansion radius   |
| `ring_thickness`  | 30      | Ring band width        |
| `expansion_speed` | 300     | Expansion speed (px/s) |
| `duration`        | 1.0     | Effect lifetime        |
| `damage`          | 15      | Damage on hit          |

## Color Scheme

- `color_edge` - White leading edge glow
- `color_inner` - Bright cyan middle
- `color_outer` - Deep blue trailing

## Visual Effects (0 = off, 1 = max)

- `chromatic_aberration` - RGB split
- `pulse_strength` - Flicker
- `electric_strength` - Arcs
- `glow_strength` - Overall glow

## JSON Config (weapons.json)

```json
{
  "ion_wake": {
    "type": "melee",
    "stats": { "damage": 15, "duration": 0.8, "cooldown": 2.5 },
    "shape": {
      "inner_radius": 25,
      "outer_radius": 250,
      "ring_thickness": 35,
      "expansion_speed": 350
    },
    "visual": {
      "color_inner": "#66ccff",
      "color_outer": "#1a4d99",
      "color_edge": "#ccf0ff"
    }
  }
}
```
