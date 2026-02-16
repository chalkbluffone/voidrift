---
applyTo: "**/*.gdshader"
---

# Shader Conventions — Voidrift

## Godot 4.6 Shader Language

All shaders use `.gdshader` files with Godot's GLSL-like shading language. Voidrift uses **CanvasItem** shaders exclusively (2D game).

## Shader Header Convention

Every shader file must declare its type on the first line:

```glsl
shader_type canvas_item;
```

## Uniform Naming

- Use `snake_case` for all uniform names
- Prefix with `hint_` annotations where appropriate
- Group related uniforms with comments

```glsl
// Color parameters
uniform vec4 color_a : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 1.0, 0.0, 1.0);

// Shape parameters
uniform float radius : hint_range(0.0, 500.0) = 100.0;
uniform float thickness : hint_range(0.0, 200.0) = 10.0;
```

## Visual Theme: Synthwave Palette

Voidrift uses a neon synthwave aesthetic. Common colors:

- **Hot Pink**: `vec4(1.0, 0.08, 0.58, 1.0)` — HP bars, damage
- **Neon Purple**: `vec4(0.58, 0.0, 1.0, 1.0)` — XP, upgrades
- **Cyan**: `vec4(0.0, 1.0, 1.0, 1.0)` — timers, ship upgrades
- **Yellow**: `vec4(1.0, 1.0, 0.0, 1.0)` — level text
- **Gold**: `vec4(1.0, 0.84, 0.0, 1.0)` — credits

Use glow/bloom-friendly values (components > 1.0 for HDR glow).

## Existing Shader Inventory

| File                                                    | Purpose                                        |
| ------------------------------------------------------- | ---------------------------------------------- |
| `shaders/starfield.gdshader`                            | Parallax star background with dust layers      |
| `effects/radiant_arc/radiant_arc.gdshader`              | Arc-shaped melee slash visual (photonic sweep) |
| `effects/space_napalm/space_napalm_projectile.gdshader` | Napalm projectile trail effect                 |
| `effects/space_napalm/space_napalm_fire.gdshader`       | Napalm ground fire burn area                   |
| `effects/ion_wake/ion_wake.gdshader`                    | Ion trail behind ship movement                 |
| `effects/nikolas_coil/nikolas_coil.gdshader`            | Tesla coil lightning arc effect                |
| `effects/nope_bubble/nope_bubble.gdshader`              | Defensive bubble force field                   |
| `effects/snarky_comeback/snarky_comeback.gdshader`      | Snarky comeback projectile visual              |
| `effects/aoe_base/proximity_tax_aura.gdshader`          | Area-of-effect proximity damage aura           |

## Performance Guidelines

- Avoid branching (`if/else`) in fragment shaders where possible — use `step()`, `smoothstep()`, `mix()`
- Keep texture lookups minimal per fragment
- Use `TIME` built-in for animation rather than passing elapsed time as uniform
- For effects that fade in/out, pass progress as uniform from GDScript

## Research Protocol

For complex visual FX work or unfamiliar shader built-ins, use the **shader-expert** agent persona. For Godot 4.6 shader API specifics, the agent should use the Playwright MCP to verify at `https://docs.godotengine.org/en/stable/tutorials/shaders/`.
