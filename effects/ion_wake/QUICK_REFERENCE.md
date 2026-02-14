# Ion Wake - Quick Reference

## Spawn Example

```gdscript
var spawner = IonWakeSpawner.new(scene_root)
var wake = spawner.spawn(position, params, follow_source)
```

## Key Parameters

| Parameter          | Default | Description                          |
| ------------------ | ------- | ------------------------------------ |
| `start_radius`     | 30      | Ring radius at spawn (px)            |
| `max_radius`       | 350     | Ring radius at full expansion (px)   |
| `ring_width_ratio` | 0.35    | Ring thickness as fraction of radius |
| `expansion_speed`  | 300     | Expansion speed (px/s)               |
| `duration`         | 1.0     | Effect lifetime                      |
| `damage`           | 15      | Damage on hit                        |

## Color

- `base_color` - Set one color, the full fire palette is derived from it

## Fire Appearance

| Parameter          | Default | Description                        |
| ------------------ | ------- | ---------------------------------- |
| `intensity`        | 2.0     | Overall brightness (0.5-5.0)       |
| `fire_speed`       | 1.0     | Flame animation speed (0-5.0)      |
| `distortion`       | 0.06    | Noise warp on ring edges (0-0.2)   |
| `fire_detail`      | 3.5     | Noise tiling scale (1-8)           |
| `glow_spread`      | 0.1     | Soft glow past ring edges (0-0.25) |
| `density_contrast` | 0.5     | Dark hole visibility in fire (0-1) |

## JSON Config (weapons.json)

```json
{
  "ion_wake": {
    "type": "melee",
    "stats": { "damage": 13, "duration": 1.0, "cooldown": 2.5 },
    "shape": {
      "start_radius": 36,
      "max_radius": 365,
      "ring_width_ratio": 0.35,
      "expansion_speed": 140
    },
    "visual": {
      "base_color": "#ff4400",
      "intensity": 2.0,
      "fire_speed": 1.0,
      "fire_detail": 3.5
    }
  }
}
```
