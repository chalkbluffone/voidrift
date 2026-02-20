extends Node

## GameConfig - Central location for all game tuning values.
## Change values here to adjust game balance without hunting through scripts.

# =============================================================================
# PLAYER
# =============================================================================
const PLAYER_BASE_SPEED: float = 150.0  # Base movement speed (modified by character multiplier)
const PLAYER_TURN_RATE: float = 6.0     # Radians/sec. How fast the ship turns (higher = snappier)

# =============================================================================
# ENEMIES
# =============================================================================
const ENEMY_BASE_SPEED: float = 70.0  # Base movement speed (slower than player's 150)

# Overtime speed scaling — only activates after the countdown hits zero
const ENEMY_OVERTIME_SPEED_PER_MINUTE: float = 8.0  # +8 speed per overtime minute

# --- Enemy Stat Scaling (polynomial, over time) ---
# HP formula: hp_mult = 1 + pow(time_minutes, ENEMY_HP_EXPONENT)
# Damage formula: damage_mult = 1 + (time_minutes * ENEMY_DAMAGE_SCALE_PER_MINUTE)
const ENEMY_HP_EXPONENT: float = 1.25     # Polynomial exponent for HP scaling (1.25 ≈ 18× at 10 min)
const ENEMY_DAMAGE_SCALE_PER_MINUTE: float = 0.10  # +10% damage per minute (mild threat)

# --- Difficulty Stat Scaling ---
# Player's "difficulty" stat (0.0 = 0%, 1.0 = 100%) multiplies enemy stats and spawn rate.
# Formula: stat_mult *= (1.0 + difficulty * WEIGHT)
const DIFFICULTY_HP_WEIGHT: float = 1.0       # How much difficulty affects HP
const DIFFICULTY_DAMAGE_WEIGHT: float = 0.5   # How much difficulty affects damage
const DIFFICULTY_SPAWN_WEIGHT: float = 1.0    # How much difficulty affects spawn rate

# --- XP Drops (static, no scaling) ---
const ENEMY_XP_NORMAL: float = 1.0   # XP dropped by normal enemies
const ENEMY_XP_ELITE: float = 3.0    # XP dropped by elite enemies

# --- Elite Enemies ---
const ELITE_BASE_CHANCE: float = 0.05       # 5% base chance to spawn elite
const ELITE_HP_MULT: float = 3.0            # Elite HP multiplier
const ELITE_DAMAGE_MULT: float = 2.0        # Elite damage multiplier
const ELITE_SIZE_SCALE: float = 1.3         # Elite visual scale
const ELITE_COLOR: Color = Color(1.0, 0.4, 0.2, 1.0)  # Orange tint for elites

# =============================================================================
# SPAWNING
# =============================================================================
const SPAWN_RADIUS_MIN: float = 400.0
const SPAWN_RADIUS_MAX: float = 600.0
const BASE_SPAWN_RATE: float = 0.4  # Enemies per second at start (slow burn)
const SPAWN_RATE_GROWTH: float = 0.3  # Additional enemies/sec per minute (during countdown)
const SPAWN_BATCH_MIN_MINUTE: float = 3.0  # Minutes before batch spawns begin
const SPAWN_BATCH_SIZE_PER_MINUTE: float = 0.5  # Extra enemies per batch per minute

# Overtime spawn scaling — additional ramp after the countdown hits zero
const OVERTIME_SPAWN_RATE_GROWTH: float = 0.8  # Extra enemies/sec per overtime minute

# --- Swarm Events ---
# Swarms temporarily boost spawn rate. Triggered at specific times during the run.
const SWARM_TIMES: Array[float] = [240.0, 420.0]  # Swarm at 4 min (240s) and 7 min (420s)
const SWARM_DURATION_MIN: float = 45.0            # Minimum swarm duration (seconds)
const SWARM_DURATION_MAX: float = 60.0            # Maximum swarm duration (seconds)
const SWARM_SPAWN_MULTIPLIER: float = 3.0         # Spawn rate multiplier during swarm
const SWARM_WARNING_DURATION: float = 2.0         # How long to show "Fleet inbound" warning

# =============================================================================
# PICKUPS
# =============================================================================
const PICKUP_MAGNET_RADIUS: float = 150.0  # Base pixel radius to attract pickups (multiplied by pickup_range stat)
const PICKUP_MAGNET_SPEED: float = 400.0  # Max speed pickups move toward player
const PICKUP_MAGNET_ACCELERATION: float = 800.0  # How fast pickups accelerate

# =============================================================================
# CREDITS
# =============================================================================
const CREDIT_DROP_CHANCE: float = 0.40  # 40% chance enemies drop credits
const CREDIT_SCALE_PER_MINUTE: float = 0.1  # +10% credit value per minute

# =============================================================================
# RUN
# =============================================================================
const DEFAULT_RUN_DURATION: float = 600.0  # Run timer in seconds (600 = 10 minutes)

# =============================================================================
# LEVEL UP / PROGRESSION
# =============================================================================
const LEVEL_UP_REFRESH_COST: int = 25  # Credits to refresh upgrade cards

# How many cards appear per level-up.
const LEVEL_UP_OPTION_COUNT: int = 3

# XP curve (polynomial): per-level cost = XP_BASE * n ^ XP_EXPONENT, summed cumulatively.
# XP_BASE     — cost of the first level-up. Scales all levels uniformly.
# XP_EXPONENT — steepness of the curve (1.0 = linear, 1.5 = moderate, 2.0 = quadratic).
const XP_BASE: float = 7.0            # XP cost of the first level-up (~7 kills)
const XP_EXPONENT: float = 1.1        # Polynomial exponent (1.25 ≈ ~15K XP at level 50)

# Loadout capacity
const MAX_WEAPON_SLOTS: int = 4       # Max weapons per run
const MAX_MODULE_SLOTS: int = 4       # Max tomes/modules per run

# Brief gameplay flash between queued level-ups (seconds)
const LEVEL_UP_QUEUE_FLASH_DELAY: float = 0.3

# =============================================================================
# PHASE SHIFT
# =============================================================================
const PHASE_SHIFT_DURATION: float = 0.3   # How long the dash lasts (seconds)
const PHASE_SHIFT_COOLDOWN: float = 0.5   # Min time between phases (seconds)
const PHASE_RECHARGE_TIME: float = 3.0    # Seconds to recharge one phase charge
const POST_PHASE_IFRAMES: float = 0.2     # Brief i-frames after phase ends (seconds)

# =============================================================================
# SURVIVABILITY / I-FRAMES
# =============================================================================
const DAMAGE_IFRAMES: float = 0.5         # I-frame duration after taking damage (seconds)
const PLAYER_KNOCKBACK_FORCE: float = 400.0  # Knockback velocity from damage source
const PLAYER_KNOCKBACK_FRICTION: float = 10.0  # Knockback decay rate (player)
const ENEMY_KNOCKBACK_FRICTION: float = 8.0   # Knockback decay rate (enemies)
const ENEMY_CONTACT_DAMAGE_INTERVAL: float = 0.5  # Contact damage tick rate (seconds)

# =============================================================================
# COMBAT / STATS
# =============================================================================
const SHIELD_RECHARGE_DELAY: float = 5.0   # Seconds before shield starts recharging
const SHIELD_RECHARGE_RATE: float = 10.0   # Shield HP recovered per second
const DIMINISHING_RETURNS_DENOMINATOR: float = 100.0  # DR formula: raw / (raw + DENOM)
const WEAPON_TARGETING_RANGE: float = 500.0  # Auto-aim max distance (pixels)
const PROJECTILE_DEFAULT_LIFETIME: float = 5.0  # Seconds before projectile self-destructs

# Hard caps for stats (stat_name → max value)
const STAT_CAPS: Dictionary = {
	"xp_gain": 10.0,
	"armor": 90.0,
	"evasion": 90.0,
}

# =============================================================================
# CAMERA
# =============================================================================
const CAMERA_BASE_ZOOM: float = 1.2       # Default camera zoom level
const CAMERA_SPEED_ZOOM_FACTOR: float = 0.08  # Zoom reduction per 1.0 speed multiplier above baseline
const CAMERA_MIN_ZOOM: float = 0.7        # Floor so camera never zooms too far out
const CAMERA_ZOOM_LERP: float = 3.0       # Zoom transition smoothing speed

# =============================================================================
# UPGRADE OFFER WEIGHTS
# =============================================================================
# Controls how often weapons vs modules appear at level-up.
# Slots full → only upgrade existing. Slots open → only offer new.

# Base weights when slots are partially filled
const OFFER_WEIGHT_EXISTING_WEAPON: float = 1.0
const OFFER_WEIGHT_NEW_WEAPON: float = 1.5
const OFFER_WEIGHT_EXISTING_MODULE: float = 1.0
const OFFER_WEIGHT_NEW_MODULE: float = 1.2

# When weapon slots are full
const OFFER_WEIGHT_WEAPON_FULL_EXISTING: float = 8.0
# When weapon slots still open
const OFFER_WEIGHT_WEAPON_OPEN_NEW: float = 6.0

# When module slots are full
const OFFER_WEIGHT_MODULE_FULL_EXISTING: float = 8.0
# When module slots partially filled
const OFFER_WEIGHT_MODULE_PARTIAL_EXISTING: float = 4.0
const OFFER_WEIGHT_MODULE_PARTIAL_NEW: float = 1.2
# When module slots empty
const OFFER_WEIGHT_MODULE_EMPTY_EXISTING: float = 1.0
const OFFER_WEIGHT_MODULE_EMPTY_NEW: float = 5.0

# =============================================================================
# LOOT FREIGHTER
# =============================================================================
const FREIGHTER_FLEE_DRIFT_INTERVAL: float = 2.0  # Seconds between random flee direction changes
const FREIGHTER_FLEE_DRIFT_ANGLE: float = 0.3     # Radians of random drift

# =============================================================================
# PICKUP SCATTER (cosmetic feel)
# =============================================================================
const PICKUP_SCATTER_XP: float = 10.0       # XP pickup random offset (pixels)
const PICKUP_SCATTER_CREDIT: float = 15.0   # Credit pickup random offset (pixels)
const PICKUP_SCATTER_BURST: float = 30.0    # Burst pickup random offset (pixels)
const PICKUP_SCATTER_STARDUST: float = 25.0 # Stardust random offset (pixels)

# =============================================================================
# UI COSMETIC
# =============================================================================
const GAME_OVER_DELAY: float = 0.6         # Death animation delay before game over screen (seconds)
const HUD_AVATAR_SIZE: float = 72.0        # Captain portrait diameter (pixels)
const HUD_AVATAR_CROP_FRACTION: float = 0.65  # How much of captain sprite to show (0-1)

# =============================================================================
# ABILITY DEFAULTS
# =============================================================================
const ABILITY_DEFAULT_COOLDOWN: float = 75.0  # Fallback cooldown if captain JSON omits it
const ABILITY_DEFAULT_DURATION: float = 5.0   # Fallback duration if captain JSON omits it

# =============================================================================
# SHIP VISUAL DEFAULTS
# =============================================================================
const DEFAULT_VISUAL_WIDTH: float = 64.0      # Ship sprite fallback width (pixels)
const DEFAULT_VISUAL_HEIGHT: float = 64.0     # Ship sprite fallback height (pixels)
const DEFAULT_COLLISION_RADIUS: float = 24.0  # Ship collision fallback radius (pixels)

# =============================================================================
# RARITY / UPGRADE ROLLS
# =============================================================================

const RARITY_ORDER: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]

# Default weights when a specific upgrade/weapon does not provide its own rarity_weights.
const RARITY_DEFAULT_WEIGHTS: Dictionary = {
	"common": 60.0,
	"uncommon": 25.0,
	"rare": 10.0,
	"epic": 4.0,
	"legendary": 1.0,
}

# Luck model for rarity rolls.
const RARITY_LUCK_MAX: float = 200.0
const RARITY_LUCK_FACTOR_DIVISOR: float = 100.0
const RARITY_LUCK_EXPONENT_BY_RARITY: Dictionary = {
	"uncommon": 1,
	"rare": 2,
	"epic": 3,
	"legendary": 4,
}

# Scales effect magnitude by card rarity.
const RARITY_TIER_MULT: Dictionary = {
	"common": 1.0,
	"uncommon": 1.15,
	"rare": 1.35,
	"epic": 1.6,
	"legendary": 2.0,
}

# Modules: number of total effects shown/applied per card (includes the main effect).
const MODULE_EFFECT_COUNT_BY_RARITY: Dictionary = {
	"common": 1,
	"uncommon": 1,
	"rare": 2,
	"epic": 2,
	"legendary": 3,
}

# Modules: small secondary bonuses added on higher rarities.
const MODULE_EXTRA_EFFECT_POOL: Array[Dictionary] = [
	{"stat": "max_hp", "kind": "flat", "amount": 5.0},
	{"stat": "damage", "kind": "mult", "amount": 0.03},
	{"stat": "attack_speed", "kind": "mult", "amount": 0.03},
	{"stat": "movement_speed", "kind": "mult", "amount": 0.03},
	{"stat": "pickup_range", "kind": "mult", "amount": 0.10},
	{"stat": "crit_chance", "kind": "flat", "amount": 2.0},
	{"stat": "duration", "kind": "mult", "amount": 0.03},
	{"stat": "crit_damage", "kind": "mult", "amount": 0.05},
]

# Weapons: number of rolled weapon-only effects per weapon level-up.
const WEAPON_EFFECT_COUNT_BY_RARITY: Dictionary = {
	"common": 1,
	"uncommon": 1,
	"rare": 2,
	"epic": 2,
	"legendary": 3,
}

# =============================================================================
# WEAPON TIER UPGRADE SYSTEM (Megabonk hybrid model)
# =============================================================================

# Maximum weapon level (each re-pick at level-up increments the weapon's level).
const MAX_WEAPON_LEVEL: int = 40

# Rarity factors applied to json-derived tier baseline deltas.
# In "baseline_plus_factor" mode: final_delta = tier_value * rarity_factor.
# In "direct" mode: final_delta = tier_value (factor ignored).
const WEAPON_RARITY_FACTORS: Dictionary = {
	"common": 1.0,
	"uncommon": 1.2,
	"rare": 1.4,
	"epic": 1.6,
	"legendary": 2.0,
}

# Toggle how tier values from weapon_upgrades.json are applied:
#   "baseline_plus_factor" — multiply tier value by WEAPON_RARITY_FACTORS[rarity] (default)
#   "direct"               — use the tier value as-is from the JSON
const WEAPON_TIER_VALUE_MODE: String = "baseline_plus_factor"

# How many stats are improved per weapon level-up, by rarity.
# Each entry is [min_picks, max_picks]. The actual count is rolled uniformly.
const WEAPON_STAT_PICK_COUNT: Dictionary = {
	"common": [1, 2],
	"uncommon": [2, 2],
	"rare": [2, 2],
	"epic": [2, 2],
	"legendary": [2, 3],
}

# Floor value for any positive stat delta after scaling. Prevents zero-gain upgrades.
const WEAPON_MIN_POSITIVE_DELTA: float = 0.01

# Default weights for stat selection when picking which stats to upgrade.
# Higher weight = more likely to be picked. Only stats present in the weapon's
# tier_stats are eligible; this provides relative weighting among them.
const WEAPON_UPGRADE_STAT_WEIGHTS: Dictionary = {
	"damage": 1.0,
	"attack_speed": 1.0,
	"projectile_speed": 0.8,
	"size": 0.6,
	"projectile_count": 0.25,
	"crit_chance": 0.4,
	"crit_damage": 0.35,
	"duration": 0.7,
	"projectile_bounces": 0.5,
	"knockback": 0.4,
}

# Weapons: explicit kind overrides for weapon-local stats.
# Stats listed here use "flat" additions; all others default to "mult".
const WEAPON_UPGRADE_STAT_KIND: Dictionary = {
	"projectile_count": "flat",
	"projectile_bounces": "flat",
	"crit_chance": "flat",
	"crit_damage": "flat",
	"knockback": "flat",
}
