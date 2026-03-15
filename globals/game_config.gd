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

# --- Overtime Difficulty Multiplier ---
# After countdown hits zero, enemies get a stacking multiplier every INTERVAL seconds.
# Affects HP, contact damage, and move speed of newly spawned enemies.
const OVERTIME_MULTIPLIER_START: float = 1.0       # Starting multiplier when overtime begins
const OVERTIME_MULTIPLIER_INCREMENT: float = 0.5   # Added per interval (1.0x → 1.5x → 2.0x …)
const OVERTIME_MULTIPLIER_INTERVAL: float = 30.0   # Seconds between increments
const OVERTIME_MULTIPLIER_CAP: float = 10.0        # Maximum multiplier (reached at 9 min overtime)

# --- Enemy Stat Scaling (polynomial, over time) ---
# HP formula: hp_mult = 1 + pow(time_minutes, ENEMY_HP_EXPONENT)
# Damage formula: damage_mult = 1 + (time_minutes * ENEMY_DAMAGE_SCALE_PER_MINUTE)
const ENEMY_HP_EXPONENT: float = 1.15     # Polynomial exponent for HP scaling (subtler ramp over a 10 min run)
const ENEMY_DAMAGE_SCALE_PER_MINUTE: float = 0.07  # +7% damage per minute

# --- Difficulty Stat Scaling ---
# Player's "difficulty" stat (0.0 = 0%, 1.0 = 100%) multiplies enemy stats and spawn rate.
# Formula: stat_mult *= (1.0 + difficulty * WEIGHT)
const DIFFICULTY_HP_WEIGHT: float = 0.4       # How much difficulty affects HP
const DIFFICULTY_DAMAGE_WEIGHT: float = 0.2   # How much difficulty affects damage
const DIFFICULTY_SPAWN_WEIGHT: float = 0.4    # How much difficulty affects spawn rate

# --- XP Drops (static, no scaling) ---
const ENEMY_XP_NORMAL: float = 1.0   # XP dropped by normal enemies
const ENEMY_XP_ELITE_MIN: float = 2.0 # Min XP dropped by elite enemies
const ENEMY_XP_ELITE_MAX: float = 5.0 # Max XP dropped by elite enemies

# --- Credit Drops ---
const ENEMY_CREDITS_NORMAL: int = 1       # Credits dropped by normal enemies
const ENEMY_CREDITS_ELITE_MIN: int = 2    # Min credits dropped by elite enemies
const ENEMY_CREDITS_ELITE_MAX: int = 5    # Max credits dropped by elite enemies

# --- Elite Enemies ---
const ELITE_BASE_CHANCE: float = 0.05       # 5% base chance to spawn elite
const ELITE_HP_MULT: float = 3.0            # Elite HP multiplier
const ELITE_DAMAGE_MULT: float = 2.0        # Elite damage multiplier
const ELITE_SIZE_SCALE: float = 1.3         # Elite visual scale
const ELITE_COLOR: Color = Color(1.0, 0.4, 0.2, 1.0)  # Orange tint for elites

# =============================================================================
# SPAWNING
# =============================================================================
const SPAWN_RADIUS_MIN: float = 500.0
const SPAWN_RADIUS_MAX: float = 750.0
const BASE_SPAWN_RATE: float = 0.4  # Enemies per second at start (slow burn)
const SPAWN_RATE_GROWTH: float = 0.2  # Additional enemies/sec per minute (during countdown)
const SPAWN_BATCH_MIN_MINUTE: float = 3.0  # Minutes before batch spawns begin
const SPAWN_BATCH_SIZE_PER_MINUTE: float = 0.5  # Extra enemies per batch per minute

# Overtime spawn scaling removed — overtime difficulty multiplier handles escalation via
# OVERTIME_MULTIPLIER_* constants in the Enemies section above.

# --- Swarm Events ---
# Swarms temporarily boost spawn rate. Triggered at specific times during the run.
const SWARM_TIMES: Array[float] = [240.0, 420.0]  # Swarm at 4 min (240s) and 7 min (420s)
const SWARM_DURATION_MIN: float = 45.0            # Minimum swarm duration (seconds)
const SWARM_DURATION_MAX: float = 60.0            # Maximum swarm duration (seconds)
const SWARM_SPAWN_MULTIPLIER: float = 2.0         # Spawn rate multiplier during swarm
const SWARM_WARNING_DURATION: float = 2.0         # How long to show "Fleet inbound" warning

# =============================================================================
# PICKUPS
# =============================================================================
const PICKUP_MAGNET_RADIUS: float = 150.0  # Base pixel radius to attract pickups (multiplied by pickup_range stat)
const PICKUP_MAGNET_SPEED: float = 400.0  # Max speed pickups move toward player
const PICKUP_MAGNET_ACCELERATION: float = 800.0  # How fast pickups accelerate

# XP merge (performance — combines nearby idle XP pickups into larger glowing ones)
const XP_MERGE_RADIUS: float = 100.0       # Pixel radius to cluster nearby XP for merging
const XP_MERGE_COUNT: int = 5              # Minimum XP pickup count in cluster to trigger merge
const XP_MERGE_INTERVAL: float = 2.0       # Seconds between merge scan passes
const XP_MERGE_VISUAL_SIZE: float = 12.0   # Half-size of merged XP glow footprint (pixels)
const XP_MERGE_COLLISION_RADIUS: float = 12.0  # Collision radius for merged XP pickup

# XP merge animation
const XP_MERGE_FLY_DURATION: float = 0.35      # Seconds for originals to fly to centroid
const XP_MERGE_POP_DURATION: float = 0.25      # Seconds for merged pickup scale-pop entrance
const XP_MERGE_POP_OVERSHOOT: float = 1.2      # Scale overshoot factor (TRANS_BACK)
const XP_MERGE_FLASH_DURATION: float = 0.15    # Seconds for white flash fade on merged spawn

# =============================================================================
# CREDITS
# =============================================================================
# Credits now guaranteed 1 per kill (no RNG). credits_gain stat still multiplies via ProgressionManager.

# =============================================================================
# POWER-UPS (dropped by enemies, rare)
# =============================================================================
const POWERUP_BASE_DROP_CHANCE: float = 0.015          # 1.5% chance per kill to drop a power-up
const POWERUP_HEALTH_RESTORE_FRACTION: float = 0.25    # 25% of max HP restored (scaled by powerup_multiplier)
const POWERUP_SPEED_BOOST_AMOUNT: float = 3.0          # +300% movement speed bonus
const POWERUP_SPEED_BOOST_DURATION: float = 10.0       # Duration in seconds (scaled by powerup_multiplier)
const POWERUP_STOPWATCH_DURATION: float = 10.0         # Enemy freeze duration in seconds (scaled by powerup_multiplier)
const POWERUP_SCATTER: float = 20.0                    # Power-up random offset from death position (pixels)
const POWERUP_COLLISION_RADIUS: float = 24.0           # Collision circle radius for 48×48 power-ups
const POWERUP_VISUAL_SIZE: float = 48.0                # Power-up visual size in pixels

# =============================================================================
# RUN
# =============================================================================
const DEFAULT_RUN_DURATION: float = 600.0  # Run timer in seconds (600 = 10 minutes)

# =============================================================================
# LEVEL UP / PROGRESSION
# =============================================================================
const LEVEL_UP_REFRESH_COST: int = 0  # Credits to refresh upgrade cards

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
const PHASE_SHIFT_DURATION: float = 0.5   # How long the dash lasts (seconds)
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
# ENEMY ASTEROID INTERACTION
# =============================================================================
const ENEMY_ASTEROID_SLOW_MULTIPLIER: float = 0.5  # Speed multiplier when enemy overlaps an asteroid
const ENEMY_GRID_CELL_SIZE: float = 100.0           # SpatialHashGrid cell size for enemy proximity queries

# =============================================================================
# COMBAT / STATS
# =============================================================================
const SHIELD_RECHARGE_DELAY: float = 5.0   # Seconds before shield starts recharging
const SHIELD_RECHARGE_RATE: float = 10.0   # Shield HP recovered per second
const DIMINISHING_RETURNS_DENOMINATOR: float = 100.0  # DR formula: raw / (raw + DENOM)
const WEAPON_TARGETING_RANGE: float = 500.0  # Auto-aim max distance (pixels)
const PROJECTILE_DEFAULT_LIFETIME: float = 5.0  # Seconds before projectile self-destructs
const WEAPON_MAX_FIRES_PER_SECOND: float = 20.0  # Hard cap on weapon fire rate (min cooldown = 1/N)

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
const OFFER_WEIGHT_EXISTING_WEAPON: float = 3.0
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
const FREIGHTER_MAX_ACTIVE: int = 1               # Maximum freighters alive at once
const FREIGHTER_SPAWN_COOLDOWN_MIN: float = 60.0   # Minimum seconds between freighter spawns
const FREIGHTER_SPAWN_COOLDOWN_MAX: float = 90.0   # Maximum seconds between freighter spawns

# =============================================================================
# PICKUP SCATTER (cosmetic feel)
# =============================================================================
const PICKUP_SCATTER_XP: float = 10.0       # XP pickup random offset (pixels)
const PICKUP_SCATTER_CREDIT: float = 15.0   # Credit pickup random offset (pixels)
const PICKUP_SCATTER_BURST: float = 30.0    # Burst pickup random offset (pixels)
const PICKUP_SCATTER_STARDUST: float = 25.0 # Stardust random offset (pixels)

# =============================================================================
# STARDUST
# =============================================================================
const STARDUST_BASE_DROP_CHANCE: float = 0.03  # 3% base chance per non-freighter kill to drop stardust

# =============================================================================
# UI COSMETIC
# =============================================================================
const GAME_OVER_DELAY: float = 0.6         # Death animation delay before game over screen (seconds)
const HUD_AVATAR_SIZE: float = 72.0        # Captain portrait diameter (pixels)
const HUD_AVATAR_CROP_FRACTION: float = 0.65  # How much of captain sprite to show (0-1)
const EVADE_POPUP_COOLDOWN: float = 0.2     # Minimum time between "Evaded!" popups while phasing

# =============================================================================
# DAMAGE NUMBERS
# =============================================================================
const DAMAGE_NUMBER_FONT_SIZE_NORMAL: int = 16     # Base font size for normal hits
const DAMAGE_NUMBER_FONT_SIZE_CRIT: int = 22       # Font size for critical hits
const DAMAGE_NUMBER_FONT_SIZE_OVERCRIT: int = 28   # Font size for overcritical hits
const DAMAGE_NUMBER_DURATION: float = 0.7          # Total lifetime of damage number (seconds)
const DAMAGE_NUMBER_RISE_DISTANCE: float = 40.0    # Pixels the number floats upward
const DAMAGE_NUMBER_OFFSET_RANGE: float = 20.0     # Random spawn offset radius (pixels)
const DAMAGE_NUMBER_MAX_COUNT: int = 30             # Soft cap — oldest removed when exceeded
const DAMAGE_NUMBER_CRIT_SCALE: float = 1.4         # Peak bounce scale for crit numbers
const DAMAGE_NUMBER_OVERCRIT_SCALE: float = 1.6     # Peak bounce scale for overcrit numbers
const DAMAGE_NUMBER_OUTLINE_SIZE: int = 3           # Dark outline thickness for readability (pixels)

# =============================================================================
# ABILITY DEFAULTS
# =============================================================================
const ABILITY_DEFAULT_COOLDOWN: float = 75.0  # Fallback cooldown if captain JSON omits it
const ABILITY_DEFAULT_DURATION: float = 5.0   # Fallback duration if captain JSON omits it

# --- Subjugation (Zoltan) ---
const SUBJUGATION_MAX_TARGETS: int = 5          # Max enemies converted per activation
const SUBJUGATION_DAMAGE_MULT: float = 0.6      # Fraction of original damage dealt to former allies
const SUBJUGATION_TINT_COLOR: Color = Color(0.2, 1.0, 0.4, 1.0)  # Green tint for converted enemies

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

# =============================================================================
# ARENA / BOUNDARY
# =============================================================================
const ARENA_RADIUS: float = 5000.0            # Circular play area radius (pixels)
const RADIATION_BELT_WIDTH: float = 800.0      # Width of the radiation danger zone at edge
const RADIATION_DAMAGE_PER_SEC: float = 10.0   # DOT when inside radiation belt
const RADIATION_PUSH_FORCE: float = 150.0      # Force pushing player back toward center
const PLAYER_SPAWN_MAX_RADIUS_COVERAGE: float = 0.6 # Player spawn radius as % of ARENA_RADIUS
const ENEMY_DESPAWN_BUFFER: float = 500.0      # Despawn enemies beyond ARENA_RADIUS + buffer
const ENEMY_LEASH_RADIUS: float = 1200.0       # Max distance from player before teleport-respawn
const BOSS_LEASH_RADIUS: float = 2000.0        # Leash radius for boss enemies (wider)

# =============================================================================
# ASTEROIDS
# =============================================================================
const ASTEROID_DENSITY: float = 0.9                # Asteroids per million sq px of safe area (~50 at R=5000)
const ASTEROID_SIZE_MIN: float = 30.0              # Smallest asteroid radius (pixels)
const ASTEROID_SIZE_MAX: float = 256.0             # Largest asteroid radius (pixels)
const ASTEROID_VERTEX_COUNT_MIN: int = 6           # Minimum polygon vertices
const ASTEROID_VERTEX_COUNT_MAX: int = 16          # Maximum polygon vertices
const ASTEROID_MIN_SEPARATION: float = 150.0       # Minimum distance between asteroids
const ASTEROID_RADIUS_JITTER: float = 0.35         # Per-vertex radius variation (0-1)

# =============================================================================
# MINIMAP / FOG OF WAR / FULL MAP
# =============================================================================
const MINIMAP_SIZE: float = 180.0              # Minimap diameter (pixels)
const MINIMAP_WORLD_RADIUS_COVERAGE: float = 0.12 # World radius visible in minimap as % of ARENA_RADIUS
const FULLMAP_SIZE: float = 800.0              # Full map overlay diameter (pixels)
const FULLMAP_GRID_RING_INTERVAL_COVERAGE: float = 0.8 # Ring spacing as % of ARENA_RADIUS
const FOG_GRID_SIZE: int = 128                 # Fog of war grid resolution
const FOG_REVEAL_RADIUS: float = 800.0         # Radius revealed around player (world units)
const FOG_GLOW_INTENSITY: float = 0.6          # Brightness of fog neon glow (0.5 = dim, 3.0 = bright)
const FOG_OPACITY: float = 0.5                 # Fog transparency (0.0 = invisible, 1.0 = fully opaque)

# =============================================================================
# SPACE STATIONS (Buff Shrines)
# =============================================================================
const STATION_DENSITY: float = 0.27            # Stations per million sq px of safe area (~15 at R=5000)
const STATION_ZONE_RADIUS: float = 200.0       # Activation bubble radius (pixels)
const STATION_COLLISION_RADIUS: float = 50.0   # Solid collision radius for station center
const STATION_CHARGE_TIME: float = 5.0         # Seconds to fully charge when inside zone
const STATION_DECAY_TIME: float = 5.0          # Seconds for charge to drain to 0 when outside
const STATION_MIN_SEPARATION: float = 400.0    # Minimum distance between stations
const STATION_BUFF_OPTION_COUNT: int = 3       # Number of buff choices shown on completion

# Station rarity weights (no Common — Uncommon to Legendary only)
const STATION_RARITY_WEIGHTS: Dictionary = {
	"uncommon": 50.0,
	"rare": 30.0,
	"epic": 15.0,
	"legendary": 5.0,
}

# Stat bonus ranges per rarity (multiplier values, e.g., 0.04 = +4%)
const STATION_BUFF_RANGES: Dictionary = {
	"uncommon": {"min": 0.02, "max": 0.04},
	"rare": {"min": 0.04, "max": 0.06},
	"epic": {"min": 0.06, "max": 0.10},
	"legendary": {"min": 0.10, "max": 0.15},
}

# All stats that can be buffed by stations (from base_player_stats.json)
const STATION_BUFFABLE_STATS: Array[String] = [
	"max_hp", "hp_regen", "overheal", "shield", "armor", "evasion", "lifesteal", "hull_shock",
	"damage", "crit_chance", "crit_damage", "attack_speed", "projectile_count", "projectile_bounces",
	"size", "projectile_speed", "duration", "damage_to_elites", "knockback", "movement_speed",
	"extra_phase_shifts", "phase_shift_distance",
	"luck", "difficulty",
	"pickup_range", "xp_gain", "credits_gain", "stardust_gain", "elite_spawn_rate", "powerup_multiplier", "powerup_drop_chance",
]

# Flat bonus stats (use add_flat_bonus instead of add_multiplier_bonus)
const STATION_FLAT_STATS: Array[String] = [
	"max_hp", "hp_regen", "overheal", "shield", "crit_chance", "crit_damage",
	"projectile_count", "projectile_bounces", "extra_phase_shifts", "phase_shift_distance",
	"luck", "difficulty", "lifesteal",
]

# =============================================================================
# OBJECT POOL
# =============================================================================
const POOL_MAX_DORMANT_PROJECTILES: int = 256    # Max dormant base projectiles in pool
const POOL_MAX_DORMANT_DAMAGE_NUMBERS: int = 64  # Max dormant damage number labels in pool
const POOL_MAX_DORMANT_EFFECTS: int = 32         # Max dormant per-effect pool (mines, nukes)

# =============================================================================
# GRAVITY WELL (pickup vacuum system)
# =============================================================================
const GRAVITY_WELL_VACUUM_SPEED: float = 1200.0            # Speed pickups fly to player during vacuum
const GRAVITY_WELL_BEACON_DENSITY: float = 0.063            # Beacons per million sq px of safe area (~3-4 at R=5000)
const GRAVITY_WELL_BEACON_ACTIVATION_RADIUS: float = 80.0   # Proximity to activate beacon
const GRAVITY_WELL_BEACON_MIN_SEPARATION: float = 500.0     # Minimum distance between beacons

# Display-friendly stat names for UI
const STATION_STAT_DISPLAY_NAMES: Dictionary = {
	"max_hp": "Max HP",
	"hp_regen": "HP Regen",
	"overheal": "Overheal",
	"shield": "Shield",
	"armor": "Armor",
	"evasion": "Evasion",
	"lifesteal": "Lifesteal",
	"hull_shock": "Hull Shock",
	"damage": "Damage",
	"crit_chance": "Crit Chance",
	"crit_damage": "Crit Damage",
	"attack_speed": "Attack Speed",
	"projectile_count": "Projectile Count",
	"projectile_bounces": "Projectile Bounces",
	"size": "Size",
	"projectile_speed": "Projectile Speed",
	"duration": "Duration",
	"damage_to_elites": "Elite Damage",
	"knockback": "Knockback",
	"movement_speed": "Move Speed",
	"extra_phase_shifts": "Phase Charges",
	"phase_shift_distance": "Phase Distance",
	"luck": "Luck",
	"difficulty": "Difficulty",
	"pickup_range": "Pickup Range",
	"xp_gain": "XP Gain",
	"credits_gain": "Credit Gain",
	"stardust_gain": "Stardust Gain",
	"elite_spawn_rate": "Elite Spawn Rate",
	"powerup_multiplier": "Powerup Strength",
	"powerup_drop_chance": "Powerup Drop Rate",
}

# Rarity colors for station buff UI
const STATION_RARITY_COLORS: Dictionary = {
	"uncommon": Color(0.0, 1.0, 0.5, 1.0),    # Green
	"rare": Color(0.3, 0.6, 1.0, 1.0),        # Blue
	"epic": Color(0.8, 0.3, 1.0, 1.0),        # Purple
	"legendary": Color(1.0, 0.8, 0.2, 1.0),   # Gold
}

# =============================================================================
# SPACE NUKES (missile weapon)
# =============================================================================
const NUKE_LAUNCH_ARC_MIN_DEG: float = 18.0     # Minimum launch angle offset from target direction
const NUKE_LAUNCH_ARC_MAX_DEG: float = 52.0     # Maximum launch angle offset from target direction
const NUKE_BASE_TARGETING_RADIUS: float = 500.0  # Base radius for finding nuke targets
const NUKE_MISSILE_SPEED_FACTOR: float = 0.45    # Initial speed as fraction of projectile_speed

# =============================================================================
# GRAVITY WELL BEACON (visual)
# =============================================================================
const BEACON_CIRCLE_RADIUS: float = 50.0
const BEACON_CIRCLE_COLOR: Color = Color(0.5, 0.15, 0.9, 0.7)
const BEACON_CIRCLE_COLOR_DEPLETED: Color = Color(0.2, 0.2, 0.2, 0.3)
const BEACON_TITLE_COLOR: Color = Color(0.85, 0.75, 1.0, 1.0)
const BEACON_PROMPT_COLOR: Color = Color(1.0, 1.0, 0.5, 1.0)
