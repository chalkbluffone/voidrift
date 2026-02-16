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
const ENEMY_BASE_SPEED: float = 100.0  # % of player base speed
const ENEMY_SPEED_PER_LEVEL: float = 3.5  # Speed increase per player level
const ENEMY_HP_SCALE_PER_MINUTE: float = 0.4  # +40% HP per minute
const ENEMY_DAMAGE_SCALE_PER_MINUTE: float = 0.2  # +20% damage per minute
const ENEMY_XP_SCALE_PER_MINUTE: float = 0.1  # +10% XP value per minute

# =============================================================================
# SPAWNING
# =============================================================================
const SPAWN_RADIUS_MIN: float = 400.0
const SPAWN_RADIUS_MAX: float = 600.0
const BASE_SPAWN_RATE: float = 0.5  # Enemies per second at start
const SPAWN_RATE_GROWTH: float = 0.4  # Additional enemies per second per minute

# =============================================================================
# PICKUPS
# =============================================================================
const PICKUP_MAGNET_RADIUS: float = 40.0  # How close player needs to be to attract pickups
const PICKUP_MAGNET_SPEED: float = 400.0  # Max speed pickups move toward player
const PICKUP_MAGNET_ACCELERATION: float = 800.0  # How fast pickups accelerate

# =============================================================================
# CREDITS
# =============================================================================
const CREDIT_DROP_CHANCE: float = 0.30  # 30% chance enemies drop credits
const CREDIT_SCALE_PER_MINUTE: float = 0.1  # +10% credit value per minute

# =============================================================================
# LEVEL UP
# =============================================================================
const LEVEL_UP_REFRESH_COST: int = 25  # Credits to refresh upgrade cards

# How many cards appear per level-up.
const LEVEL_UP_OPTION_COUNT: int = 3

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

# Rarity factors applied to CSV-derived tier baseline deltas.
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
