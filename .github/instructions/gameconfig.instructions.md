---
applyTo: "**"
---

# GameConfig Sections (`globals/game_config.gd`)

All game-balance tuning constants live in the `GameConfig` autoload. See `architecture.instructions.md` for the mandatory reference rule and how to access constants. The full constant inventory by section:

| Section                    | Key Constants                                                                                                                                                                            |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Player                     | `PLAYER_BASE_SPEED`, `PLAYER_TURN_RATE`                                                                                                                                                  |
| Enemies (Scaling)          | `ENEMY_HP_EXPONENT`, `ENEMY_DAMAGE_SCALE_PER_MINUTE`, `ENEMY_XP_NORMAL`, `ENEMY_XP_ELITE`                                                                                                |
| Enemies (Elites)           | `ELITE_BASE_CHANCE`, `ELITE_HP_MULT`, `ELITE_DAMAGE_MULT`, `ELITE_SIZE_SCALE`, `ELITE_COLOR`                                                                                             |
| Difficulty Stat            | `DIFFICULTY_HP_WEIGHT`, `DIFFICULTY_DAMAGE_WEIGHT`, `DIFFICULTY_SPAWN_WEIGHT`                                                                                                            |
| Spawning                   | `BASE_SPAWN_RATE`, `SPAWN_RATE_GROWTH`, batch/overtime tuning                                                                                                                            |
| Swarm Events               | `SWARM_TIMES`, `SWARM_DURATION_MIN`, `SWARM_DURATION_MAX`, `SWARM_SPAWN_MULTIPLIER`, `SWARM_WARNING_DURATION`                                                                            |
| Pickups                    | `PICKUP_MAGNET_RADIUS`, `PICKUP_MAGNET_SPEED`, `PICKUP_MAGNET_ACCELERATION`                                                                                                              |
| Credits                    | `CREDIT_DROP_CHANCE`, `CREDIT_SCALE_PER_MINUTE`                                                                                                                                          |
| Run                        | `DEFAULT_RUN_DURATION`                                                                                                                                                                   |
| Level Up / Progression     | `XP_BASE`, `XP_EXPONENT`, `MAX_WEAPON_SLOTS`, `MAX_MODULE_SLOTS`, `LEVEL_UP_OPTION_COUNT`                                                                                                |
| Phase Shift                | `PHASE_SHIFT_DURATION`, `PHASE_SHIFT_COOLDOWN`, `PHASE_RECHARGE_TIME`, `POST_PHASE_IFRAMES`                                                                                              |
| Survivability / I-Frames   | `DAMAGE_IFRAMES`, `PLAYER_KNOCKBACK_FORCE`, knockback friction, contact damage interval                                                                                                  |
| Combat / Stats             | `SHIELD_RECHARGE_DELAY`, `SHIELD_RECHARGE_RATE`, `DIMINISHING_RETURNS_DENOMINATOR`, `STAT_CAPS`, `WEAPON_TARGETING_RANGE`, `PROJECTILE_DEFAULT_LIFETIME`                                 |
| Camera                     | `CAMERA_BASE_ZOOM`, `CAMERA_SPEED_ZOOM_FACTOR`, `CAMERA_MIN_ZOOM`, `CAMERA_ZOOM_LERP`                                                                                                    |
| Upgrade Offer Weights      | `OFFER_WEIGHT_*` — controls weapon vs module frequency at level-up                                                                                                                       |
| Loot Freighter             | `FREIGHTER_FLEE_DRIFT_INTERVAL`, `FREIGHTER_FLEE_DRIFT_ANGLE`                                                                                                                            |
| Pickup Scatter (cosmetic)  | `PICKUP_SCATTER_XP`, `PICKUP_SCATTER_CREDIT`, `PICKUP_SCATTER_BURST`, `PICKUP_SCATTER_STARDUST`                                                                                          |
| UI Cosmetic                | `GAME_OVER_DELAY`, `HUD_AVATAR_SIZE`, `HUD_AVATAR_CROP_FRACTION`                                                                                                                         |
| Ability Defaults           | `ABILITY_DEFAULT_COOLDOWN`, `ABILITY_DEFAULT_DURATION`                                                                                                                                   |
| Ship Visual Defaults       | `DEFAULT_VISUAL_WIDTH`, `DEFAULT_VISUAL_HEIGHT`, `DEFAULT_COLLISION_RADIUS`                                                                                                              |
| Rarity / Upgrade Rolls     | `RARITY_ORDER`, `RARITY_DEFAULT_WEIGHTS`, luck model, tier multipliers                                                                                                                   |
| Weapon Tier Upgrade System | `MAX_WEAPON_LEVEL`, `WEAPON_RARITY_FACTORS`, stat pick counts, stat weights                                                                                                              |
| Arena / Boundary           | `ARENA_RADIUS`, `RADIATION_BELT_WIDTH`, `RADIATION_DAMAGE_PER_SEC`, `RADIATION_PUSH_FORCE`, spawn/despawn margins                                                                        |
| Minimap / Fog of War       | `MINIMAP_SIZE`, `MINIMAP_WORLD_RADIUS`, `FULLMAP_SIZE`, `FOG_GRID_SIZE`, `FOG_REVEAL_RADIUS`, `FOG_GLOW_INTENSITY`, `FOG_OPACITY`                                                        |
| Space Stations             | `STATION_COUNT`, `STATION_ZONE_RADIUS`, `STATION_CHARGE_TIME`, `STATION_DECAY_TIME`, `STATION_SPAWN_RADIUS_*`, `STATION_RARITY_WEIGHTS`, `STATION_BUFF_RANGES`, `STATION_BUFFABLE_STATS` |
| Asteroids                  | `ASTEROID_COUNT`, `ASTEROID_SIZE_MIN`, `ASTEROID_SIZE_MAX`, `ASTEROID_VERTEX_COUNT_MIN/MAX`, `ASTEROID_MIN_SEPARATION`, `ASTEROID_SPAWN_MIN/MAX_RADIUS`, `ASTEROID_RADIUS_JITTER`        |
| Flow Field (Enemy Pathing) | `FLOW_FIELD_CELL_SIZE`, `FLOW_FIELD_UPDATE_INTERVAL`, `FLOW_FIELD_OBSTACLE_BUFFER`, `ENEMY_TURN_SPEED`, `ENEMY_SEPARATION_RADIUS`, `ENEMY_SEPARATION_STRENGTH`                           |
