class_name UiColors
extends RefCounted

## Centralized synthwave color palette for all UI screens.
## Use UiColors.CONSTANT_NAME to reference colors instead of inline Color(...) literals.

# --- Core Synthwave Palette ---

## Hot pink — selected items, HP bars, accents.
const HOT_PINK: Color = Color(1.0, 0.08, 0.4, 1.0)

## Neon purple — buttons, XP bars, epic rarity.
const NEON_PURPLE: Color = Color(0.67, 0.2, 0.95, 1.0)

## Cyan — titles, stats, rare-ish accents.
const CYAN: Color = Color(0.0, 1.0, 0.9, 1.0)

## Neon yellow — level text, headers, highlights.
const NEON_YELLOW: Color = Color(1.0, 0.95, 0.2, 1.0)

## Gold — credits, legendary rarity.
const GOLD: Color = Color(1.0, 0.84, 0.0, 1.0)

# --- Panel / Card Colors ---

## Dark translucent background for cards and panels.
const PANEL_BG: Color = Color(0.08, 0.05, 0.15, 0.95)

## Dim purple border for unselected cards.
const PANEL_BORDER: Color = Color(0.4, 0.2, 0.5, 1.0)

## Hot pink border for selected cards (alias of HOT_PINK).
const PANEL_SELECTED: Color = Color(1.0, 0.08, 0.4, 1.0)

# --- Background ---

## Deep dark blue used for full-screen backgrounds.
const BG_DARK: Color = Color(0.05, 0.05, 0.12, 1.0)

## Dark-red tinted background for game-over overlay.
const BG_GAME_OVER: Color = Color(0.1, 0.0, 0.0, 0.8)

## Dark overlay for level-up and pause dimmer.
const BG_OVERLAY: Color = Color(0.0, 0.0, 0.0, 0.85)

# --- Button Colors ---

## Default button color (magenta-purple).
const BUTTON_PRIMARY: Color = Color("#920075")

## Back / secondary button color.
const BUTTON_BACK: Color = Color(0.4, 0.3, 0.5, 1.0)

## Disabled button color.
const BUTTON_DISABLED: Color = Color(0.3, 0.15, 0.4, 0.6)

## Neutral / skip button color.
const BUTTON_NEUTRAL: Color = Color(0.5, 0.5, 0.5, 1.0)

# --- Text Colors ---

## White for primary text (names, button labels).
const TEXT_PRIMARY: Color = Color(1.0, 1.0, 1.0, 1.0)

## Light lavender for descriptions.
const TEXT_DESC: Color = Color(0.75, 0.7, 0.85, 1.0)

## Dim gray for stat labels.
const TEXT_STAT_LABEL: Color = Color(0.5, 0.5, 0.6, 1.0)

## Cyan for stat values (alias of CYAN).
const TEXT_STAT_VALUE: Color = Color(0.0, 1.0, 0.9, 1.0)

## Dim gray for locked / unavailable items.
const TEXT_LOCKED: Color = Color(0.4, 0.4, 0.4, 0.6)

## Disabled font color for buttons.
const TEXT_DISABLED: Color = Color(0.5, 0.5, 0.5, 0.8)

# --- Rarity Colors ---

const RARITY_COMMON: Color = Color(0.7, 0.7, 0.7, 1.0)
const RARITY_UNCOMMON: Color = Color(0.2, 0.8, 0.2, 1.0)
const RARITY_RARE: Color = Color(0.2, 0.5, 1.0, 1.0)
const RARITY_EPIC: Color = Color(0.67, 0.2, 0.95, 1.0)
const RARITY_LEGENDARY: Color = Color(1.0, 0.8, 0.0, 1.0)


## Map a rarity string to its display color.
static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return RARITY_LEGENDARY
		"epic":
			return RARITY_EPIC
		"rare":
			return RARITY_RARE
		"uncommon":
			return RARITY_UNCOMMON
		_:
			return RARITY_COMMON

# --- Type Colors ---

## Red-ish for weapon-type upgrade cards.
const TYPE_WEAPON: Color = Color(1.0, 0.3, 0.3, 1.0)

## Cyan for passive upgrade cards.
const TYPE_UPGRADE: Color = Color(0.0, 0.9, 0.8, 1.0)

# --- Hover / FX Colors ---

## Click flash color (bright yellow).
const CLICK_FLASH: Color = Color(1.0, 0.95, 0.25, 1.0)

## Game-over title color on defeat.
const DEFEAT_TITLE: Color = Color(1.0, 0.15, 0.3, 1.0)

## Game-over title outline.
const DEFEAT_OUTLINE: Color = Color(0.4, 0.0, 0.1, 1.0)

# --- Particle / FX Colors ---

const PARTICLE_PINK: Color = Color(1.0, 0.08, 0.58, 1.0)
const PARTICLE_PURPLE: Color = Color(0.58, 0.0, 1.0, 1.0)
const PARTICLE_CYAN: Color = Color(0.0, 1.0, 1.0, 1.0)

# --- Map Element Colors (minimap + full map) ---

const MAP_PLAYER: Color = Color(0.0, 1.0, 0.9, 1.0)        # Cyan
const MAP_ENEMY: Color = Color(1.0, 0.2, 0.2, 1.0)         # Red
const MAP_PICKUP: Color = Color(0.5, 1.0, 0.3, 1.0)        # Green
const MAP_STATION: Color = Color(1.0, 0.8, 0.2, 1.0)       # Yellow/Gold
const MAP_ASTEROID: Color = Color(0.45, 0.45, 0.5, 0.7)    # Gray
const MAP_POWERUP_HEALTH: Color = Color(1.0, 0.25, 0.25, 1.0)
const MAP_POWERUP_SPEED: Color = Color(0.3, 0.7, 1.0, 1.0)
const MAP_POWERUP_STOPWATCH: Color = Color(1.0, 0.85, 0.25, 1.0)
const MAP_POWERUP_GRAVITY: Color = Color(0.75, 0.45, 1.0, 1.0)
const MAP_BEACON: Color = Color(0.75, 0.45, 1.0, 1.0)       # Purple (gravity well beacons)
const MAP_BOUNDARY: Color = Color(1.0, 0.0, 1.0, 0.8)      # Pink
