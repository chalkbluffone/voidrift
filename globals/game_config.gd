extends Node

## GameConfig - Central location for all game tuning values.
## Change values here to adjust game balance without hunting through scripts.

# =============================================================================
# PLAYER
# =============================================================================
const PLAYER_BASE_SPEED := 150.0  # Base movement speed (modified by character multiplier)
const PLAYER_TURN_RATE := 6.0     # Radians/sec. How fast the ship turns (higher = snappier)

# =============================================================================
# ENEMIES
# =============================================================================
const ENEMY_BASE_SPEED := 100.0  # % of player base speed
const ENEMY_SPEED_PER_LEVEL := 3.5  # Speed increase per player level
const ENEMY_HP_SCALE_PER_MINUTE := 0.4  # +40% HP per minute
const ENEMY_DAMAGE_SCALE_PER_MINUTE := 0.2  # +20% damage per minute
const ENEMY_XP_SCALE_PER_MINUTE := 0.1  # +10% XP value per minute

# =============================================================================
# SPAWNING
# =============================================================================
const SPAWN_RADIUS_MIN := 400.0
const SPAWN_RADIUS_MAX := 600.0
const BASE_SPAWN_RATE := 0.5  # Enemies per second at start
const SPAWN_RATE_GROWTH := 0.4  # Additional enemies per second per minute

# =============================================================================
# PICKUPS
# =============================================================================
const PICKUP_MAGNET_RADIUS := 40.0  # How close player needs to be to attract pickups
const PICKUP_MAGNET_SPEED := 400.0  # Max speed pickups move toward player
const PICKUP_MAGNET_ACCELERATION := 800.0  # How fast pickups accelerate

# =============================================================================
# CREDITS
# =============================================================================
const CREDIT_DROP_CHANCE := 0.30  # 30% chance enemies drop credits
const CREDIT_SCALE_PER_MINUTE := 0.1  # +10% credit value per minute

# =============================================================================
# LEVEL UP
# =============================================================================
const LEVEL_UP_REFRESH_COST := 25  # Credits to refresh upgrade cards

# How many cards appear per level-up.
const LEVEL_UP_OPTION_COUNT := 3

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
const RARITY_LUCK_MAX := 200.0
const RARITY_LUCK_FACTOR_DIVISOR := 100.0
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
]

# Weapons: number of rolled weapon-only effects per weapon level-up.
const WEAPON_EFFECT_COUNT_BY_RARITY: Dictionary = {
	"common": 1,
	"uncommon": 1,
	"rare": 2,
	"epic": 2,
	"legendary": 3,
}

# Weapons: base per-level amounts (before rarity tier multiplier).
# NOTE: weapon upgrades are weapon-local (do not affect other weapons).
const WEAPON_UPGRADE_BASE_AMOUNTS: Dictionary = {
	"damage": 0.08,            # +8% weapon base damage
	"attack_speed": 0.08,      # +8% shots/sec for this weapon
	"projectile_speed": 0.10,  # +10% projectile speed
	"size": 0.06,              # +6% projectile size (multiplies player size stat)
	"projectile_count": 1.0,   # +1 projectile (flat)
	"crit_chance": 2.0,        # +2 percentage points weapon-only crit chance
	"crit_damage": 0.15,       # +0.15 crit damage multiplier (additive)
}

# Weapons: default weights for picking stats from a weapon's upgrade_stats pool.
const WEAPON_UPGRADE_STAT_WEIGHTS: Dictionary = {
	"damage": 1.0,
	"attack_speed": 1.0,
	"projectile_speed": 0.8,
	"size": 0.6,
	"projectile_count": 0.25,
	"crit_chance": 0.4,
	"crit_damage": 0.35,
}

# Weapons: rarity-dependent multipliers for stat selection weights (rarity affects *which* stats are more likely).
const WEAPON_UPGRADE_WEIGHT_MULT_BY_RARITY: Dictionary = {
	"common": {
		"projectile_count": 0.5,
		"crit_damage": 0.8,
	},
	"uncommon": {
		"projectile_count": 0.8,
		"crit_damage": 1.0,
	},
	"rare": {
		"projectile_count": 1.2,
		"crit_damage": 1.2,
	},
	"epic": {
		"projectile_count": 1.5,
		"crit_damage": 1.35,
	},
	"legendary": {
		"projectile_count": 2.0,
		"crit_damage": 1.5,
	},
}

# Weapons: explicit kind overrides for weapon-local stats.
const WEAPON_UPGRADE_STAT_KIND: Dictionary = {
	"projectile_count": "flat",
	"crit_chance": "flat",
	"crit_damage": "flat",
}
