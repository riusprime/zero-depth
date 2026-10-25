class_name EliteDefinition
extends ContentDef
## v0.9.0 EL (owner Q26: "Your three (Recommended)"; G1 docs/roadmap/v0.9.0/ELITES.md rows E1-E3, "ok go for those"):
## an elite archetype (data/elites/<id>.tres, category `elites`): a miniboss-like enemy with its own model, one special
## ability (telegraph, strike, a punish window) and a plain attack between abilities. `archetype` picks the behaviour
## the sim runs (EliteAi): breaker, rift_hunter or conduit. Every number is a starting value (F10), scaled with the
## floor and its danger tier like every enemy (RunState.scale_enemies, SpawnDirector.scale_arrival).
## - The ability: every ability_every_seconds (start to start), a windup of ability_windup_seconds (at least
##   MIN_ABILITY_TELEGRAPH_SECONDS: ELITES.md E0, "always shows at least 0.8 s before the hit"), of which the first
##   ability_track_seconds follow the player (0: none), then the hit (ability_damage) in its shape: the Breaker's disc
##   of ability_radius_m round it, the Rift Hunter's disc round its mark, the Conduit's beam ability_half_width_m
##   wide and up to ability_range_m long (cut by the room's walls). Then ability_recover_seconds of recovery: the
##   punish window, taking ability_vulnerable_permille of every hit (1000: no bonus). The Rift Hunter vanishes for the
##   windup's last ability_vanish_seconds and starts its ability only within ability_range_m of the player.
## - The plain attack: basic_damage (0: none) every basic_every_seconds, a windup of basic_windup_seconds (the same
##   minimum); the Breaker's punch reaches basic_range_m past its body, the Conduit's fan is basic_pattern_id (a slow
##   fireball pattern, data/bullet_patterns).
## - Contact: touching its body while it walks hurts for contact_damage (0: never), at most every
##   contact_cooldown_seconds (never in its windup, strike or punish window).
## - Walking: toward the player (keep_min_m 0) or keeping keep_min_m..keep_max_m away, circling.

const ARCHETYPES: Array[StringName] = [&"breaker", &"rift_hunter", &"conduit"]
const MIN_ABILITY_TELEGRAPH_SECONDS := 0.8

@export var name_key: StringName
@export var desc_key: StringName
@export var archetype: StringName = &"breaker"
@export var hp := 600
@export var radius_m := 0.8
@export var move_speed_mps := 1.3
## Shards a kill grants (ELITES.md E0: 3 x a normal enemy's), by the danger tier as every enemy's.
@export var shards := 18
@export var contact_damage := 0
@export var contact_cooldown_seconds := 1.0
@export var ability_every_seconds := 6.0
@export var ability_windup_seconds := 1.0
@export var ability_track_seconds := 0.0
@export var ability_vanish_seconds := 0.0
@export var ability_damage := 32
@export var ability_radius_m := 3.0
@export var ability_half_width_m := 0.0
@export var ability_range_m := 0.0
@export var ability_recover_seconds := 1.5
@export var ability_vulnerable_permille := 1000
@export var basic_damage := 0
@export var basic_every_seconds := 1.5
@export var basic_windup_seconds := 0.8
@export var basic_recover_seconds := 0.5
@export var basic_range_m := 0.0
@export var basic_pattern_id: StringName = &""
@export var keep_min_m := 0.0
@export var keep_max_m := 0.0


func category() -> StringName:
	return &"elites"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	var p := resource_path
	if String(name_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", p, "name_key is required"))
	if not ARCHETYPES.has(archetype):
		issues.append(
			ValidationIssue.new(&"unknown_behaviour", p, "unknown archetype %s" % archetype)
		)
	for f in ["hp", "radius_m", "move_speed_mps", "ability_every_seconds", "ability_damage"]:
		check_positive(issues, f, float(get(f)))
	for f in ["shards", "contact_damage", "basic_damage"]:
		if int(get(f)) < 0:
			issues.append(ValidationIssue.new(&"negative", p, "%s is negative" % f))
	for f in [
		"contact_cooldown_seconds",
		"ability_track_seconds",
		"ability_vanish_seconds",
		"ability_recover_seconds",
		"basic_every_seconds",
		"basic_recover_seconds",
	]:
		check_duration(issues, f, float(get(f)))
	if ability_windup_seconds < MIN_ABILITY_TELEGRAPH_SECONDS:
		issues.append(
			ValidationIssue.new(&"telegraph_short", p, "ability_windup_seconds is under 0.8 s")
		)
	if basic_damage > 0 and basic_windup_seconds < MIN_ABILITY_TELEGRAPH_SECONDS:
		issues.append(
			ValidationIssue.new(&"telegraph_short", p, "basic_windup_seconds is under 0.8 s")
		)
	if ability_track_seconds + ability_vanish_seconds > ability_windup_seconds:
		issues.append(
			ValidationIssue.new(&"range", p, "tracking and vanishing fit inside the windup")
		)
	if ability_vulnerable_permille < 1000 or ability_vulnerable_permille > 3000:
		issues.append(ValidationIssue.new(&"range", p, "ability_vulnerable_permille in 1000..3000"))
	if keep_max_m < keep_min_m:
		issues.append(ValidationIssue.new(&"range", p, "keep_max_m >= keep_min_m"))
	match archetype:
		&"breaker":
			check_positive(issues, "ability_radius_m", ability_radius_m)
			if basic_damage > 0:
				check_positive(issues, "basic_range_m", basic_range_m)
		&"rift_hunter":
			check_positive(issues, "ability_radius_m", ability_radius_m)
			check_positive(issues, "ability_range_m", ability_range_m)
		&"conduit":
			check_positive(issues, "ability_half_width_m", ability_half_width_m)
			check_positive(issues, "ability_range_m", ability_range_m)
			if basic_damage > 0 and String(basic_pattern_id).is_empty():
				issues.append(ValidationIssue.new(&"missing", p, "basic_pattern_id is required"))
	return issues
