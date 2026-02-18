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

## Default button color (neon purple).
const BUTTON_PRIMARY: Color = Color(0.67, 0.2, 0.95, 1.0)

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
