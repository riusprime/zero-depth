class_name BossDefinition
extends ContentDef
## A boss (PLAN v0.3.0 C; CONTENT_SCHEMA §4; BLUEPRINT §F): body numbers, armour by hit direction (like the
## Warden's), a stagger meter (hits fill it; full -> staggered for stagger_seconds, then it resets), phases at HP
## thresholds, its attacks, and its arena (the boss room's size in cells and its interior template, which the
## floor generator reads). Every number is a starting value the owner tunes after playing.

@export var name_key: StringName
@export var hp := 1000
@export var radius_m := 1.2
@export var move_speed_mps := 1.5
## Degrees per second it turns while pursuing (0 = always faces the player).
@export var turn_rate_dps := 0.0
## Pursuit stops this far from the player (0 = walks into melee).
@export var keep_distance_m := 0.0
## Armour by the direction a hit comes from (0 arcs = none): as the Warden (CONTENT_SCHEMA §3).
@export var front_arc_degrees := 0.0
@export var front_mult_permille := 1000
@export var rear_arc_degrees := 0.0
@export var rear_mult_permille := 1000
## Stagger: meter size in damage points, its decay per second, and how long a full meter staggers.
@export var stagger_size := 200
@export var stagger_decay_per_second := 10.0
@export var stagger_seconds := 2.5
@export var attacks: Array[BossAttackDefinition] = []
@export var phases: Array[BossPhaseDefinition] = []
## The boss room: its size in cells and its interior template (BossSchemas.ARENA_TEMPLATES index).
@export var arena_cells := Vector2i(2, 2)
@export_enum("open", "scatter", "pillars", "centre", "cross", "lines", "bunkers")
var arena_template := 0


func category() -> StringName:
	return &"bosses"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	var p := resource_path
	if not BossSchemas.KINDS.has(id):
		issues.append(ValidationIssue.new(&"unknown_boss", p, "no boss kind for id %s" % id))
	if String(name_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", p, "name_key is required"))
	if hp <= 0:
		issues.append(ValidationIssue.new(&"not_positive", p, "hp must be > 0"))
	check_positive(issues, "radius_m", radius_m)
	check_positive(issues, "move_speed_mps", move_speed_mps)
	if turn_rate_dps < 0.0 or keep_distance_m < 0.0:
		issues.append(ValidationIssue.new(&"negative", p, "turn rate and keep distance are >= 0"))
	_check_armour(issues)
	if stagger_size <= 0:
		issues.append(ValidationIssue.new(&"not_positive", p, "stagger_size must be > 0"))
	if stagger_decay_per_second < 0.0:
		issues.append(ValidationIssue.new(&"negative", p, "stagger_decay_per_second < 0"))
	if int(round(stagger_seconds * 60.0)) <= 0:
		issues.append(ValidationIssue.new(&"duration", p, "stagger_seconds must be > 0"))
	_check_attacks(issues)
	_check_phases(issues)
	if (
		arena_cells.x < 1
		or arena_cells.y < 1
		or arena_cells.x > BossSchemas.ARENA_MAX_CELLS
		or arena_cells.y > BossSchemas.ARENA_MAX_CELLS
	):
		issues.append(
			ValidationIssue.new(
				&"arena", p, "arena_cells must be 1..%d per side" % BossSchemas.ARENA_MAX_CELLS
			)
		)
	if arena_template < 0 or arena_template >= BossSchemas.ARENA_TEMPLATES.size():
		issues.append(
			ValidationIssue.new(&"arena", p, "unknown arena_template %d" % arena_template)
		)
	return issues


## The attack with this id, or null.
func attack(attack_id: StringName) -> BossAttackDefinition:
	for a in attacks:
		if a != null and a.id == attack_id:
			return a
	return null


func _check_attacks(issues: Array[ValidationIssue]) -> void:
	if attacks.is_empty():
		issues.append(ValidationIssue.new(&"attacks", resource_path, "a boss needs attacks"))
	var seen := {}
	for a in attacks:
		if a == null:
			issues.append(ValidationIssue.new(&"missing", resource_path, "an attack is missing"))
			continue
		if seen.has(a.id):
			issues.append(
				ValidationIssue.new(&"duplicate_id", resource_path, "attack %s twice" % a.id)
			)
		seen[a.id] = true
		a.validate_into(issues, resource_path)


func _check_phases(issues: Array[ValidationIssue]) -> void:
	var p := resource_path
	if phases.is_empty():
		issues.append(ValidationIssue.new(&"phases", p, "a boss needs at least one phase"))
		return
	var last := 1001
	for k in phases.size():
		var ph := phases[k]
		if ph == null:
			issues.append(ValidationIssue.new(&"missing", p, "phase %d is missing" % k))
			continue
		var th := ph.hp_threshold_permille
		if k == 0 and th != 1000:
			issues.append(ValidationIssue.new(&"phases", p, "the first phase starts at 1000"))
		if th < 1 or th >= last:
			issues.append(
				ValidationIssue.new(
					&"phases", p, "phase thresholds must fall strictly, within 1..1000"
				)
			)
		last = th
		if ph.attack_ids.is_empty():
			issues.append(ValidationIssue.new(&"phases", p, "phase %d has no attacks" % k))
		for aid in ph.attack_ids:
			if attack(StringName(aid)) == null:
				issues.append(
					ValidationIssue.new(&"unknown_attack", p, "phase %d: no attack %s" % [k, aid])
				)
		if not String(ph.entry_attack).is_empty() and attack(ph.entry_attack) == null:
			issues.append(
				ValidationIssue.new(
					&"unknown_attack", p, "phase %d: no entry attack %s" % [k, ph.entry_attack]
				)
			)
		if ph.speed_permille < 0 or ph.cooldown_permille < 0:
			issues.append(ValidationIssue.new(&"negative", p, "phase %d: negative per mille" % k))


## As the Warden's (CONTENT_SCHEMA §3): arcs 0..360 that don't overlap, a front multiplier that softens without
## blocking (1..1000) and a rear one that doesn't soften (1000..3000).
func _check_armour(issues: Array[ValidationIssue]) -> void:
	var p := resource_path
	for pair in [["front_arc_degrees", front_arc_degrees], ["rear_arc_degrees", rear_arc_degrees]]:
		if pair[1] < 0.0 or pair[1] > 360.0:
			issues.append(ValidationIssue.new(&"armour", p, "%s must be within 0..360" % pair[0]))
	if front_arc_degrees + rear_arc_degrees > 360.0:
		issues.append(ValidationIssue.new(&"armour", p, "the armour arcs overlap"))
	if front_mult_permille < 1 or front_mult_permille > 1000:
		issues.append(ValidationIssue.new(&"armour", p, "front_mult_permille must be 1..1000"))
	if rear_mult_permille < 1000 or rear_mult_permille > 3000:
		issues.append(ValidationIssue.new(&"armour", p, "rear_mult_permille must be 1000..3000"))
