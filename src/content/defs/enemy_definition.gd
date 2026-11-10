class_name EnemyDefinition
extends ContentDef
## An enemy (CONTENT_SCHEMA §3): numbers, a behaviour (src/sim/ai/) with its params, and its attacks.

## v0.7.0 audit A-13: the attack shape params that must be > 0 when an attack has them (sizes, speeds, ranges and
## counts the compiler divides by or turns into ticks). spread_degrees and gap_seconds may be 0.
const POSITIVE_SHAPE_PARAMS: Array[String] = [
	"count", "half_width_m", "length_m", "radius_m", "range_m", "reach_m", "speed_mps"
]

@export var name_key: StringName
## The Codex's line about this enemy (a locale key; empty shows no line).
@export var desc_key: StringName
@export var behaviour_id: StringName
@export var behaviour_params := {}
@export var hp := 10
@export var radius_m := 0.4
@export var move_speed_mps := 3.0
@export var attacks: Array[AttackDefinition] = []
@export var stress_tags := PackedStringArray()
## Economy: shards a kill grants. By default × (1 + 0.25 × danger tier) (RewardsDefinition);
## with shards_by_floor (bosses) × the floor number instead. 0 = drops none.
@export var shards := 0
@export var shards_by_floor := false
## The form or element this kind is weak to
## and the one it resists: a form card's modifier id (gun_laser) or an element id (ModifierOpDefinition.ELEMENTS);
## empty: none. A matching hit or damage-over-time tick of the player's takes the multiplier (per mille; Matchups).
@export var weak_to := &""
@export var resists := &""
@export var weak_permille := 1250
@export var resist_permille := 750


func category() -> StringName:
	return &"enemies"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "name_key is required"))
	if hp <= 0:
		issues.append(ValidationIssue.new(&"not_positive", resource_path, "hp must be > 0"))
	check_positive(issues, "radius_m", radius_m)
	check_positive(issues, "move_speed_mps", move_speed_mps)
	if shards < 0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "shards is negative"))
	_check_matchup(issues)
	var schema: Dictionary = BehaviourSchemas.SCHEMAS.get(behaviour_id, {})
	if schema.is_empty():
		issues.append(
			ValidationIssue.new(
				&"unknown_behaviour", resource_path, "unknown behaviour %s" % behaviour_id
			)
		)
		return issues
	_check_keys(issues, "behaviour_params", behaviour_params, schema["params"])
	if BehaviourSchemas.base_of(behaviour_id) == &"warden":  # The Rubble Warden too
		_check_armour(issues)
	_check_horde(issues)
	var specs: Array = schema.get("attacks", [{"shape": schema.get("shape"), "shape_params": []}])
	if attacks.size() != specs.size():
		issues.append(
			ValidationIssue.new(
				&"attacks",
				resource_path,
				"this behaviour takes exactly %d attack(s)" % specs.size()
			)
		)
		return issues
	for k in specs.size():
		var atk := attacks[k]
		if atk == null:
			issues.append(ValidationIssue.new(&"missing", resource_path, "attack is missing"))
			continue
		var spec: Dictionary = specs[k]
		if spec.has("id") and atk.id != spec["id"]:
			issues.append(
				ValidationIssue.new(
					&"attacks", resource_path, "attack %d must be %s" % [k, spec["id"]]
				)
			)
		_check_attack(issues, atk, spec["shape"], schema.get("shape_params", spec["shape_params"]))
		# An enemy's attacks share one damage number (RunState scales it per floor).
		if atk.damage != attacks[0].damage:
			issues.append(
				ValidationIssue.new(&"damage", resource_path, "every attack takes the same damage")
			)
	return issues


func _check_attack(
	issues: Array[ValidationIssue], atk: AttackDefinition, shape: int, params: Array
) -> void:
	if atk.shape != shape:
		issues.append(
			ValidationIssue.new(
				&"shape", resource_path, "%s needs a different shape" % behaviour_id
			)
		)
	_check_keys(issues, "shape_params", atk.shape_params, params)
	for k in POSITIVE_SHAPE_PARAMS:  # v0.7.0 audit A-13: a 0 speed or range compiles to an undefined tick count
		if atk.shape_params.has(k) and float(atk.shape_params[k]) <= 0.0:
			issues.append(
				ValidationIssue.new(
					&"not_positive", resource_path, "%s shape_params.%s must be > 0" % [atk.id, k]
				)
			)
	if int(round(atk.telegraph_seconds * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
		issues.append(
			ValidationIssue.new(
				&"telegraph_short",
				resource_path,
				(
					"%s telegraph %.2f s is under the %d-tick minimum"
					% [atk.id, atk.telegraph_seconds, BehaviourSchemas.MIN_TELEGRAPH_TICKS]
				)
			)
		)
	if atk.telegraph_max_seconds != 0.0 and atk.telegraph_max_seconds < atk.telegraph_seconds:
		issues.append(
			ValidationIssue.new(
				&"telegraph_range",
				resource_path,
				"%s telegraph_max_seconds is under telegraph_seconds" % atk.id
			)
		)
	check_duration(issues, "active_seconds", atk.active_seconds)
	check_duration(issues, "recovery_seconds", atk.recovery_seconds)
	if atk.damage <= 0 and behaviour_id != &"frost_spitter":  # Its blob hurts nobody
		issues.append(ValidationIssue.new(&"not_positive", resource_path, "damage must be > 0"))


## The Warden's armour (owner, 2026-10-07): arcs within 0..360 that don't overlap, a front multiplier that softens
## without blocking (1..1000 per mille) and a rear one that doesn't soften (1000..3000).
func _check_armour(issues: Array[ValidationIssue]) -> void:
	var bp := behaviour_params
	var keys := [
		"front_arc_degrees", "rear_arc_degrees", "front_mult_permille", "rear_mult_permille"
	]
	for k in keys:
		if not bp.has(k):
			return
	var front := float(bp["front_arc_degrees"])
	var rear := float(bp["rear_arc_degrees"])
	for pair in [["front_arc_degrees", front], ["rear_arc_degrees", rear]]:
		if pair[1] < 0.0 or pair[1] > 360.0:
			issues.append(
				ValidationIssue.new(&"armour", resource_path, "%s must be within 0..360" % pair[0])
			)
	if front + rear > 360.0:
		issues.append(
			ValidationIssue.new(
				&"armour", resource_path, "front_arc_degrees + rear_arc_degrees must be <= 360"
			)
		)
	var fm := int(bp["front_mult_permille"])
	if fm < 1 or fm > 1000:
		issues.append(
			ValidationIssue.new(
				&"armour", resource_path, "front_mult_permille must be within 1..1000 (no block)"
			)
		)
	var rm := int(bp["rear_mult_permille"])
	if rm < 1000 or rm > 3000:
		issues.append(
			ValidationIssue.new(
				&"armour", resource_path, "rear_mult_permille must be within 1000..3000"
			)
		)


## A weakness raises (1001..2000 per mille), a resistance softens without blocking (1..999), and the
## two name different ids. Whether each id exists is cross_check's.
func _check_matchup(issues: Array[ValidationIssue]) -> void:
	if weak_permille <= 1000 or weak_permille > 2000:
		issues.append(
			ValidationIssue.new(
				&"matchup", resource_path, "weak_permille must be within 1001..2000"
			)
		)
	if resist_permille < 1 or resist_permille >= 1000:
		issues.append(
			ValidationIssue.new(
				&"matchup", resource_path, "resist_permille must be within 1..999 (no block)"
			)
		)
	if weak_to != &"" and weak_to == resists:
		issues.append(
			ValidationIssue.new(&"matchup", resource_path, "weak_to and resists are the same id")
		)


## Every enemy's weak_to and resists name an element (ModifierOpDefinition.ELEMENTS) or a modifier.
static func cross_check(defs: Array[ContentDef]) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	var ids := {}
	for e: StringName in ModifierOpDefinition.ELEMENTS:
		ids[e] = true
	for d in defs:
		if d is ModifierDefinition:
			ids[d.id] = true
	for d in defs:
		if not d is EnemyDefinition:
			continue
		var e := d as EnemyDefinition
		for id: StringName in [e.weak_to, e.resists]:
			if id != &"" and not ids.has(id):
				issues.append(
					ValidationIssue.new(
						&"unknown_matchup", e.resource_path, "no form or element %s" % id
					)
				)
	return issues


## The horde kinds: counts, heals and times that must be positive, and a shield arc within 0..360.
func _check_horde(issues: Array[ValidationIssue]) -> void:
	var bp := behaviour_params
	for k in [
		"split_count",
		"max_mines",
		"heal_amount",
		"heal_period_seconds",
		"heal_range_m",
		"mine_life_seconds",
		"drop_seconds",
		"contact_damage",  # The horde critters
		"contact_cd_seconds",
		"crust_hp",  # The biome variants
		"patch_radius_m",
		"patch_seconds",
		"dark_beyond_m",
		"trail_radius_m",
		"trail_seconds",
		"trail_step_seconds",
		"burn_damage",
		"burn_period_seconds",
		"slick_ease_seconds",
		"split_degrees",
		"max_cables",  # The Ruins and Night Rocks signatures
		"post_hp",
		"post_radius_m",
		"cable_period_seconds",
		"circle_m",
		"rear_arc_degrees",
		"stagger_seconds",
		"wake_m",
		"rumble_m",
		"flight_seconds",
		"rock_seconds",
		"rock_half_m",
		"max_rocks",
		"burst_delay_seconds",  # R5-R8
		"burst_radius_m",
		"burst_damage",
		"burst_enemy_damage",
		"vent_reach_m",
		"vent_period_seconds",
		"vent_warn_seconds",
		"vent_radius_m",
		"vent_damage",
		"vent_linger_seconds",
		"slick_seconds",
		"shell_hp",
		"chunk_count",
		"chunk_speed_mps",
		"chunk_seconds",
		"chunk_damage",
		"mark_offset_m",  # The Starfall signatures
		"mark_radius_m",
		"stun_seconds",
		"pull_radius_m",
		"pull_mps2",
	]:
		if bp.has(k) and float(bp[k]) <= 0.0:
			issues.append(
				ValidationIssue.new(
					&"not_positive", resource_path, "behaviour_params.%s must be > 0" % k
				)
			)
	if bp.has("flies") and typeof(bp["flies"]) != TYPE_BOOL:  # v0.11.0 O9
		issues.append(
			ValidationIssue.new(
				&"flies", resource_path, "behaviour_params.flies must be true or false"
			)
		)
	if bp.has("shield_arc_degrees"):
		var arc := float(bp["shield_arc_degrees"])
		if arc <= 0.0 or arc >= 360.0:
			issues.append(
				ValidationIssue.new(
					&"armour", resource_path, "shield_arc_degrees must be within 0..360"
				)
			)
	_check_variant(issues)
	_check_canyon_shore(issues)
	_check_starfall(issues)  # v0.11.0 O13d


## An Ember Charger's fire burns only once it has shown for the telegraph minimum, and a Split Sniper's
## shot splits inside its range.
func _check_variant(issues: Array[ValidationIssue]) -> void:
	var bp := behaviour_params
	if (
		bp.has("trail_arm_seconds")
		and int(round(float(bp["trail_arm_seconds"]) * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS
	):
		issues.append(
			ValidationIssue.new(
				&"telegraph_short",
				resource_path,
				"trail_arm_seconds is under the telegraph minimum"
			)
		)
	if (
		bp.has("patch_slow_permille")
		and (int(bp["patch_slow_permille"]) < 1 or int(bp["patch_slow_permille"]) > 1000)
	):
		issues.append(
			ValidationIssue.new(
				&"slow", resource_path, "patch_slow_permille must be within 1..1000"
			)
		)
	if (
		bp.has("split_at_permille")
		and (int(bp["split_at_permille"]) < 1 or int(bp["split_at_permille"]) > 999)
	):
		issues.append(
			ValidationIssue.new(&"split", resource_path, "split_at_permille must be within 1..999")
		)


## ENEMIES.md R9: a Star Warper's star lies off the hero (standing still is no cancel: mark_radius_m
## under mark_offset_m) and its strike reaches where the hero stood (radius_m over mark_offset_m): move to answer.
func _check_starfall(issues: Array[ValidationIssue]) -> void:
	var bp := behaviour_params
	if behaviour_id != &"star_warper" or attacks.is_empty() or attacks[0] == null:
		return
	var off := float(bp.get("mark_offset_m", 0.0))
	if float(bp.get("mark_radius_m", 0.0)) >= off:
		issues.append(
			ValidationIssue.new(&"star", resource_path, "mark_radius_m must be under mark_offset_m")
		)
	if float(attacks[0].shape_params.get("radius_m", 0.0)) <= off:
		issues.append(
			ValidationIssue.new(
				&"star", resource_path, "the strike radius_m must be over mark_offset_m"
			)
		)


func _check_keys(
	issues: Array[ValidationIssue], field: String, got: Dictionary, need: Array
) -> void:
	for k in need:
		if not got.has(k):
			issues.append(
				ValidationIssue.new(
					&"param_missing", resource_path, "%s.%s is missing" % [field, k]
				)
			)
	for k in got:
		if not need.has(k):
			issues.append(
				ValidationIssue.new(
					&"param_unknown", resource_path, "%s.%s is unknown" % [field, k]
				)
			)


## ENEMIES.md R5-R8: every warning shows for at least the telegraph minimum before it hurts: the Kiln
## Beetle's burst delay and the Cinder Priest's vent pulse (inside its period).
func _check_canyon_shore(issues: Array[ValidationIssue]) -> void:
	var bp := behaviour_params
	for k in ["burst_delay_seconds", "vent_warn_seconds"]:
		if bp.has(k) and int(round(float(bp[k]) * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
			issues.append(
				ValidationIssue.new(
					&"telegraph_short", resource_path, "%s is under the telegraph minimum" % k
				)
			)
	if (
		bp.has("vent_warn_seconds")
		and float(bp["vent_warn_seconds"]) >= float(bp.get("vent_period_seconds", 0.0))
	):
		issues.append(
			ValidationIssue.new(
				&"vent", resource_path, "vent_warn_seconds must be under vent_period_seconds"
			)
		)
