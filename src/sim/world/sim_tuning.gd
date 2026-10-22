class_name SimTuning
extends RefCounted
## The designer numbers that used to be fixed in the sim's code (docs/tools/DEV_PANEL.md Step 6, owner 2026-10-12:
## "add everything to that panel"), in sim units. A fresh table holds the shipped values (the old constants, which
## stay as the defaults), so a World without content behaves exactly as before; Main fills it from
## data/tuning/sim.tres (SimTuningDefinition) so the dev panel can tune it. Read-only in play, like every table.

## Enemies rise this long after spawning (no acting, no damage).
var spawn_in_ticks := SimTick.SPAWN_IN_TICKS
## A boss rises this long (invulnerable, not acting), and waits this long after a stagger.
var boss_intro_ticks := BossAi.INTRO_TICKS
var boss_after_stagger_cd := BossAi.AFTER_STAGGER_CD
## A boss's phase gate: how long it holds, how many adds it brings (clamped) and how far they stand.
var gate_ticks := BossGates.GATE_TICKS
var gate_adds_min := BossGates.ADDS_MIN
var gate_adds_max := BossGates.ADDS_MAX
var gate_add_ring_m := BossGates.ADD_RING_M
## Enemy AI: aimed windups stop tracking this long before they fire (a Sniper's longer); strafe and flank shares of
## the walk; the crowd spread; a Sniper's relocation speed share and time limit; how often a Mender looks round.
var ai_commit_ticks := EnemyAi.COMMIT_TICKS
var ai_snipe_commit_ticks := EnemyAi.SNIPE_COMMIT_TICKS
var ai_strafe_permille := EnemyAi.STRAFE_PERMILLE
var ai_flank_permille := EnemyAi.FLANK_PERMILLE
var ai_flank_min_m := EnemyAi.FLANK_MIN_M
var ai_flank_range_m := EnemyAi.FLANK_RANGE_M
var ai_spread_radius_m := EnemyAi.SPREAD_RADIUS_M
var ai_spread_weight := EnemyAi.SPREAD_WEIGHT
var ai_relocate_speed_permille := EnemyAi.RELOCATE_SPEED_PERMILLE
var ai_relocate_max_ticks := EnemyAi.RELOCATE_MAX_TICKS
var ai_mend_scan_ticks := EnemyAi.MEND_SCAN_TICKS
## Heal orbs lying on the floor at most; the pickup radius (before the reach stat).
var heal_orbs_max := HealOrbs.MAX_ON_FLOOR
var pickup_radius_m := ItemEffects.PICKUP_RADIUS_M
## Fire patches alive at most; how often a patch without its own rate hits; Flame Trail's spacing along a dash.
var fire_cap := ElementAbilities.FIRE_CAP
var fire_hit_ticks := ElementAbilities.FIRE_HIT_TICKS
var fire_trail_spacing_m := ElementAbilities.TRAIL_SPACING_M
## The shortest throw of a shot's field (Arc Field and the like).
var field_min_m := ModifierAbilities.FIELD_MIN_M
## v0.8.0 PF (owner O9): the player's projectiles alive at once, at most (Attacks._shot_room).
var player_shots_max := Attacks.MAX_PLAYER_SHOTS
## v0.8.0 N11 (owner O69): the hero's arrival on the floor's receiver (BossFlow.arrival_length): floor 1 of a run, a
## later floor, and either with reduced motion. Nothing spawns and nothing acts until it ends.
var arrival_first_ticks := BossFlow.ARRIVE_FIRST_TICKS
var arrival_ticks := BossFlow.ARRIVE_TICKS
var arrival_calm_ticks := BossFlow.ARRIVE_TICKS_CALM
## v0.8.0 SG (owner O91): the attack-speed curve (AttackRate.curve): full up to the knee, then slope, then slope2
## past knee2, per mille.
var attack_speed_knee_permille := AttackRate.KNEE
var attack_speed_knee2_permille := AttackRate.KNEE2
var attack_speed_slope_permille := AttackRate.SLOPE
var attack_speed_slope2_permille := AttackRate.SLOPE2
