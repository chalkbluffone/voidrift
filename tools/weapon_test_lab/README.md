# Weapon Test Lab

A development-only tool for testing and tuning weapons in Voidrift.

## Overview

The Weapon Test Lab provides a sandbox environment where you can:

- Test any weapon in isolation
- Adjust weapon parameters in real-time
- See visual feedback immediately
- Spawn test targets to observe damage
- Save and load weapon configurations

## How to Use

### Opening the Test Lab

1. Open the scene: `res://tools/weapon_test_lab/weapon_test_lab.tscn`
2. Press F5 (or run the scene directly)

### Controls

| Key/Action     | Description                |
| -------------- | -------------------------- |
| **Mouse**      | Aim the test ship          |
| **SPACE**      | Fire weapon manually       |
| **TAB**        | Toggle UI panel visibility |
| **Left Panel** | All weapon controls        |

### UI Panel Sections

#### 1. Weapon Selection

Click on any weapon in the list to select it. The configuration panel will update with that weapon's parameters.

#### 2. Fire Controls

- **Fire Button**: Manually fire the weapon once
- **Auto-Fire**: Toggle automatic firing
- **Fire Rate**: Adjust how often auto-fire triggers

#### 3. Test Targets

- **Spawn 5**: Create 5 test targets at random positions
- **Clear All**: Remove all targets from the scene

#### 4. Weapon Parameters

Sliders and color pickers for every configurable weapon parameter. Changes apply immediately so you can see the effect in real-time.

#### 5. Save/Load

- **Save**: Saves current configuration to `user://weapon_configs/{weapon_id}.cfg`
- **Load**: Loads saved configuration for the current weapon

## Available Weapons

| Weapon        | Type       | Description                                      |
| ------------- | ---------- | ------------------------------------------------ |
| Radiant Arc   | Melee      | Neon slash effect with full visual customization |
| Plasma Cannon | Projectile | Basic projectile weapon                          |
| Laser Array   | Projectile | Rapid-fire spread weapon                         |
| Ion Orbit     | Orbit      | Orbital damage spheres                           |
| Missile Pod   | Projectile | Homing missiles                                  |

## Radiant Arc Parameters

The Radiant Arc has the most extensive parameter set:

### Geometry

- **Arc Angle Deg**: Sweep angle of the arc (10-360°)
- **Radius**: Inner radius of the arc
- **Thickness**: Width of the arc
- **Taper**: How the thickness falls off along the arc
- **Length Scale**: Overall scale multiplier
- **Distance**: Offset from the spawn point

### Timing

- **Speed**: Forward travel speed (0 = stationary)
- **Duration**: How long the effect lasts
- **Fade In/Out**: Transition times

### Visuals

- **Color A/B/C**: Three-color gradient
- **Glow Strength**: Intensity of the glow effect
- **Core Strength**: Brightness of the central core
- **Noise Strength**: Distortion amount
- **UV Scroll Speed**: Animation speed

## Saved Configurations

Configurations are saved to:

```
user://weapon_configs/{weapon_id}.cfg
```

On Windows, this is typically:

```
C:\Users\{username}\AppData\Roaming\Godot\app_userdata\Voidrift\weapon_configs\
```

### Using Saved Configs in Game

To use a saved configuration in your weapon code:

```gdscript
# Load saved config
var config = ConfigFile.new()
if config.load("user://weapon_configs/radiant_arc.cfg") == OK:
    var arc_angle = config.get_value("config", "arc_angle_deg", 90.0)
    # ... apply to weapon
```

Or create a `RadiantArcConfig` resource with the saved values.

## Adding New Weapons

1. Add weapon definition to `data/weapons.json`
2. Add entry to `_available_weapons` array in `weapon_test_lab.gd`
3. Add default config in `_get_default_config()`
4. Add slider ranges in `weapon_test_ui.gd` `_get_slider_ranges()`

## Notes

- This tool uses autoloads (DataLoader, GameConfig) - ensure they're registered in Project Settings
- Test targets use collision layer 8 (enemies) and mask layer 4 (projectiles)
- The scene doesn't require a full game state - it works standalone
