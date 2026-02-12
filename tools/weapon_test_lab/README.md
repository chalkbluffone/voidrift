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

- **Save to JSON**: Saves current configuration directly to `data/weapons.json`
- **Reload JSON**: Reloads from `data/weapons.json` (discards unsaved changes)

## Dynamic Weapon Loading

The weapon test lab is **fully data-driven**. All weapons are loaded from `data/weapons.json` at runtime via `DataLoader`. No hardcoded weapon lists or type-specific parameter handling exists in the lab code.

### How It Works

1. **Weapon list**: Built dynamically from `DataLoader.get_weapon_ids()` on startup
2. **Parameter discovery**: When a weapon is selected, `WeaponDataFlattener.flatten()` walks ALL sub-dictionaries (`stats`, `shape`, `motion`, `visual`, `particles`, `base_stats`) and extracts every key/value pair
3. **UI generation**: Sliders, color pickers, and checkboxes are created automatically for each parameter. Slider ranges are inferred from key naming conventions (e.g., keys containing "radius" get [0, 500], keys ending in "\_deg" get [0, 360])
4. **Save roundtrip**: `WeaponDataFlattener.unflatten()` uses a key map to write values back to their original JSON sections — no weapon-type detection needed
5. **Live updates**: Persistent effects (like Nope Bubble) receive real-time config pushes via group-based discovery

## Adding New Weapons

1. Add weapon definition to `data/weapons.json` with the standard structure (stats, shape, motion, visual, particles sections as needed)
2. Create the spawner script and effect scene in `effects/your_weapon/`
3. **That's it.** The test lab will automatically:
   - Show the weapon in the selection list
   - Generate parameter controls for every key in every sub-dictionary
   - Fire the weapon using the real `WeaponComponent` code path
   - Save/reload configuration to `weapons.json`

No test lab code changes are required when adding new weapons.

### Naming Conventions for Good Slider Ranges

When adding parameters to a new weapon, use these naming patterns for automatic slider range inference:

| Pattern in key name          | Range              | Example keys                           |
| ---------------------------- | ------------------ | -------------------------------------- |
| `_deg`, `angle`              | 0-360, step 5      | `arc_angle_deg`, `shockwave_angle_deg` |
| `radius`, `range`            | 0-500, step 5      | `search_radius`, `shockwave_range`     |
| `strength`, `intensity`      | 0-10, step 0.1     | `glow_strength`, `branch_intensity`    |
| `speed`                      | 0-100, step 1      | `sweep_speed`, `flicker_speed`         |
| `count`, `amount`            | 1-200, step 1      | `projectile_count`, `particles_amount` |
| `size`, `thickness`, `width` | 1-300, step 1      | `proj_size`, `arc_width`               |
| `duration`, `lifetime`       | 0.05-10, step 0.05 | `burn_duration`, `particles_lifetime`  |
| `fade_*`                     | 0-1, step 0.01     | `fade_in`, `fade_out`                  |
| `offset`                     | -1 to 1, step 0.05 | `gradient_offset`, `seed_offset`       |

## Notes

- This tool uses autoloads (DataLoader, GameConfig) - ensure they're registered in Project Settings
- Test targets use collision layer 8 (enemies) and mask layer 4 (projectiles)
- The scene doesn't require a full game state - it works standalone
