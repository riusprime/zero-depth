class_name BossAttackDefinition
extends AttackDefinition
## One boss attack (PLAN v0.3.0 C): an AttackDefinition plus the move that performs it (BossSchemas.MOVES), when
## the boss may pick it (distance band, weight), its cooldown, and the death recap line it leaves (cause_key).

@export var move: StringName
## The boss starts it only with the player this far away (metres, inclusive).
@export var min_range_m := 0.0
@export var max_range_m := 99.0
## Relative pick weight among the phase's attacks in range.
@export var weight := 1
## Pause after the recovery before the next attack (scaled by the phase's cooldown_permille).
@export var cooldown_seconds := 1.0
## Locale key of the death recap line ("The Gatekeeper's fist slam crushed you.").
@export var cause_key: StringName
## Boss challenge (v0.3.0 BX): its recovery opens the boss's weak point; and a follow-up attack (an id of the same
## boss, empty = none) that starts at once instead of the recovery, follow_up_permille of the time (when the player
## is in the follow-up's range band; a follow-up never chains again).
@export var opens_weak_point := false
@export var follow_up: StringName
@export var follow_up_permille := 0
## v0.7.5 BF1 (owner N15, "Track, then lock 0.8 s"): > 0 makes the attack's marker follow the player's exact
## position for the windup's first (telegraph_seconds - lock_seconds), then lock in place and flash for its last
## lock_seconds before it strikes (a dodge window: at least the telegraph minimum). 0 = as before (the boss's
## track_commit rule).
@export var lock_seconds := 0.0
## v0.7.5 BF1 (owner N15, "Shielded during big patterns"): the boss is shielded while it winds up and performs this
## attack (its signature pattern): hits spark off and deal nothing; it opens between patterns.
@export var shielded := false
## v0.8.0 BS1 (owner O5; BOSS_SIGNATURES.md S2, S3): the death recap line for the attack's late part: the javelins
## coming back (a pattern with recall_seconds), an egg bursting (marks with egg_seconds and a pattern). Required
## with them; empty otherwise.
@export var late_cause_key: StringName


func validate_into(issues: Array[ValidationIssue], path: String) -> void:
	var where := "attack %s: " % id
	if String(id).is_empty():
		issues.append(ValidationIssue.new(&"missing", path, "attack id is required"))
	var schema: Dictionary = BossSchemas.MOVES.get(move, {})
	if schema.is_empty():
		issues.append(ValidationIssue.new(&"unknown_move", path, where + "unknown move %s" % move))
		return
	if shape != schema["shape"]:
		issues.append(
			ValidationIssue.new(&"shape", path, where + "%s needs a different shape" % move)
		)
	for k: String in schema["params"]:
		if not shape_params.has(k):
			issues.append(ValidationIssue.new(&"param_missing", path, where + "%s is missing" % k))
	var optional: Array = schema.get("optional", [])  # v0.7.5 BF2: params a move may take
	for k in shape_params:
		if not (schema["params"] as Array).has(k) and not optional.has(k):
			issues.append(ValidationIssue.new(&"param_unknown", path, where + "%s is unknown" % k))
	if int(round(telegraph_seconds * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
		issues.append(
			ValidationIssue.new(
				&"telegraph_short",
				path,
				(
					where
					+ (
						"telegraph %.2f s is under the %d-tick minimum"
						% [telegraph_seconds, BehaviourSchemas.MIN_TELEGRAPH_TICKS]
					)
				)
			)
		)
	if (
		shape_params.has("erupt_seconds")
		and (
			int(round(float(shape_params["erupt_seconds"]) * 60.0))
			< BehaviourSchemas.MIN_TELEGRAPH_TICKS
		)
	):
		issues.append(
			ValidationIssue.new(
				&"telegraph_short", path, where + "erupt_seconds is under the telegraph minimum"
			)
		)
	for pair in [["active_seconds", active_seconds], ["recovery_seconds", recovery_seconds]]:
		if pair[1] < 0.0 or (pair[1] > 0.0 and int(round(pair[1] * 60.0)) == 0):
			issues.append(ValidationIssue.new(&"duration", path, where + "%s is invalid" % pair[0]))
	if damage <= 0:
		issues.append(ValidationIssue.new(&"not_positive", path, where + "damage must be > 0"))
	if weight <= 0:
		issues.append(ValidationIssue.new(&"not_positive", path, where + "weight must be > 0"))
	if min_range_m < 0.0 or max_range_m < min_range_m:
		issues.append(ValidationIssue.new(&"range", path, where + "needs 0 <= min_range_m <= max"))
	if cooldown_seconds < 0.0:
		issues.append(ValidationIssue.new(&"duration", path, where + "cooldown_seconds < 0"))
	if String(cause_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", path, where + "cause_key is required"))
	if follow_up_permille < 0 or follow_up_permille > 1000:
		issues.append(ValidationIssue.new(&"range", path, where + "follow_up_permille: 0..1000"))
	for k in ["count", "chain", "volleys", "max_alive"]:
		if shape_params.has(k) and int(shape_params[k]) < 1:
			issues.append(ValidationIssue.new(&"not_positive", path, where + "%s must be >= 1" % k))
	if shape_params.has("count") and int(shape_params["count"]) > 8:
		issues.append(ValidationIssue.new(&"too_many", path, where + "count must be <= 8"))
	# v0.4.0 BO: a flood's lanes need room between them and a burn period of at least a tick.
	if shape_params.has("gap_m") and float(shape_params["gap_m"]) <= 0.0:
		issues.append(ValidationIssue.new(&"not_positive", path, where + "gap_m must be > 0"))
	if (
		shape_params.has("burn_seconds")
		and int(round(float(shape_params["burn_seconds"]) * 60.0)) < 1
	):
		issues.append(
			ValidationIssue.new(&"duration", path, where + "burn_seconds is under a tick")
		)
	for k: String in BossSchemas.ENEMY_PARAMS + BossSchemas.PATTERN_PARAMS:
		if shape_params.has(k) and String(shape_params[k]).is_empty():
			issues.append(ValidationIssue.new(&"missing", path, where + "%s is empty" % k))
	_validate_lock(issues, path, where)
	_validate_signature(issues, path, where)
	_validate_signature_2(issues, path, where)
	_validate_colossus(issues, path, where)
	_validate_cross(issues, path, where)


## v0.8.0 FB2 (FINAL_BOSS.md F5, F7): a Cross has 2..8 arms, real lengths and times, speeds up (its fast quarter no
## slower than its quarter), spins and opens a window of at least the telegraph minimum each, fits both in its active
## time, is shielded (its window is the only opening), names its orbs' death line with a pattern, and fires its orbs
## and bolts no faster than a tick.
func _validate_cross(issues: Array[ValidationIssue], path: String, where: String) -> void:
	if move != &"cross":
		return
	var sp := shape_params
	if int(sp.get("count", 0)) < 2:
		issues.append(ValidationIssue.new(&"range", path, where + "a cross has 2..8 arms"))
	for k in [
		"length_m",
		"width_m",
		"quarter_seconds",
		"fast_quarter_seconds",
		"reverse_seconds",
		"orb_every_seconds",
		"bolt_every_seconds",
	]:
		if sp.has(k) and float(sp[k]) <= 0.0:
			issues.append(ValidationIssue.new(&"not_positive", path, where + "%s must be > 0" % k))
	if float(sp.get("fast_quarter_seconds", 0.0)) > float(sp.get("quarter_seconds", 0.0)):
		issues.append(
			ValidationIssue.new(
				&"range", path, where + "fast_quarter_seconds must be <= quarter_seconds"
			)
		)
	var spin := int(round(float(sp.get("spin_seconds", 0.0)) * 60.0))
	var window := int(round(float(sp.get("window_seconds", 0.0)) * 60.0))
	for pair in [["spin_seconds", spin], ["window_seconds", window]]:
		if pair[1] < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
			issues.append(
				ValidationIssue.new(
					&"telegraph_short", path, where + "%s is under the telegraph minimum" % pair[0]
				)
			)
	if int(round(active_seconds * 60.0)) < spin + window:
		issues.append(
			ValidationIssue.new(
				&"duration", path, where + "active_seconds must cover spin_seconds + window_seconds"
			)
		)
	if not shielded:
		issues.append(
			ValidationIssue.new(
				&"missing", path, where + "a cross is shielded (its window opens it)"
			)
		)
	if sp.has("pattern_id") != sp.has("orb_every_seconds"):
		issues.append(
			ValidationIssue.new(
				&"missing", path, where + "pattern_id and orb_every_seconds go together"
			)
		)
	if sp.has("bolt_attack") != sp.has("bolt_every_seconds"):
		issues.append(
			ValidationIssue.new(
				&"missing", path, where + "bolt_attack and bolt_every_seconds go together"
			)
		)
	if sp.has("bolt_attack") and String(sp["bolt_attack"]).is_empty():
		issues.append(ValidationIssue.new(&"missing", path, where + "bolt_attack is empty"))


## v0.8.0 FB1 (FINAL_BOSS.md F4): the Colossus's moves. A combo's strikes stand apart more than the lock (each follows
## the player a little before it locks); spikes come in 1..MAX_STEPS steps a real distance apart; a chase has at most
## two lines and each line's spike erupts before its point is laid again (BossColossus keeps MAX_PTS / count a line).
func _validate_colossus(issues: Array[ValidationIssue], path: String, where: String) -> void:
	var sp := shape_params
	var lock := int(round(lock_seconds * 60.0))
	var gap := int(round(float(sp.get("stagger_seconds", 0.0)) * 60.0))
	if move == &"combo" and gap <= lock:
		issues.append(
			ValidationIssue.new(
				&"duration", path, where + "a combo's stagger_seconds must be over its lock"
			)
		)
	if move != &"spike_chase" and move != &"spike_burst":
		return
	var steps := int(sp.get("steps", 0))
	if steps < 1 or steps > BossSchemas.MAX_STEPS:
		issues.append(
			ValidationIssue.new(&"range", path, where + "steps: 1..%d" % BossSchemas.MAX_STEPS)
		)
	if float(sp.get("step_m", 0.0)) <= 0.0 or float(sp.get("radius_m", 0.0)) <= 0.0:
		issues.append(ValidationIssue.new(&"not_positive", path, where + "step_m and radius_m > 0"))
	if gap < 1:
		issues.append(ValidationIssue.new(&"duration", path, where + "stagger_seconds < a tick"))
	if move == &"spike_chase":
		var lines := int(sp.get("count", 1))
		if lines > 2:
			issues.append(ValidationIssue.new(&"too_many", path, where + "a chase has 1-2 lines"))
		elif gap * (8 / maxi(1, lines)) <= lock:
			issues.append(
				ValidationIssue.new(
					&"duration", path, where + "a chase's spikes are laid too fast for its lock"
				)
			)


## v0.8.0 BS1 (owner O5): the signature params. Pillars need a size and a step that leaves a gap between them; a
## recall and an egg give at least the telegraph minimum before the javelins come back or the egg hatches or bursts;
## an egg names its enemy and HP; the late part of a recall or a bursting egg names its death line.
func _validate_signature(issues: Array[ValidationIssue], path: String, where: String) -> void:
	var sp := shape_params
	if sp.has("pillar_seconds") or sp.has("pillar_m") or sp.has("pillar_step_m"):
		for k in ["pillar_seconds", "pillar_m", "pillar_step_m"]:
			if float(sp.get(k, 0.0)) <= 0.0:
				issues.append(
					ValidationIssue.new(&"not_positive", path, where + "%s must be > 0" % k)
				)
		if float(sp.get("pillar_step_m", 0.0)) <= float(sp.get("pillar_m", 0.0)):
			issues.append(
				ValidationIssue.new(
					&"no_gap", path, where + "pillars need pillar_step_m > pillar_m"
				)
			)
	for k in ["recall_seconds", "egg_seconds"]:
		if sp.has(k) and int(round(float(sp[k]) * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
			issues.append(
				ValidationIssue.new(
					&"telegraph_short", path, where + "%s is under the telegraph minimum" % k
				)
			)
	if sp.has("egg_seconds"):
		if not sp.has("enemy_id") or int(sp.get("egg_hp", 0)) < 1:
			issues.append(
				ValidationIssue.new(
					&"missing", path, where + "an egg needs enemy_id and egg_hp >= 1"
				)
			)
		if sp.has("burst_phase") and int(sp["burst_phase"]) < 1:
			issues.append(ValidationIssue.new(&"range", path, where + "burst_phase is 1-based"))
	var late := (
		sp.has("recall_seconds")
		or (sp.has("egg_seconds") and sp.has("pattern_id"))
		or sp.has("bounces")  # v0.8.0 BS2 (S5): a ricochet's death line
		or sp.has("bounce_phase")
		or sp.has("lava_seconds")  # v0.8.0 BS2 (S6): the lava's
		or (move == &"gaze" and sp.has("pattern_id"))  # v0.8.0 BS2 (S4): the gaze's orbs
		or (move == &"cross" and sp.has("pattern_id"))
	)  # v0.8.0 FB2: the Cross's orbs
	if late and String(late_cause_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", path, where + "late_cause_key is required"))


## v0.8.0 BS2 (owner O5; BOSS_SIGNATURES.md S4-S6): the gaze turns (a quarter turn and a reversal of at least a
## tick each, a beam with a length and a width), a ricochet bounces once and from a real phase, lava lasts at least
## the telegraph minimum with damage and a ford wider than the hero, and a melt shrinks from its radius to a smaller
## minimum in real steps, each warned for at least the telegraph minimum and shorter than the step.
func _validate_signature_2(issues: Array[ValidationIssue], path: String, where: String) -> void:
	var sp := shape_params
	var pos := ["quarter_seconds", "reverse_seconds", "length_m", "width_m", "orb_every_seconds"]
	if move == &"gaze":
		for k: String in pos:
			if sp.has(k) and float(sp[k]) <= 0.0:
				issues.append(
					ValidationIssue.new(&"not_positive", path, where + "%s must be > 0" % k)
				)
	if sp.has("bounces") and (int(sp["bounces"]) < 1 or int(sp["bounces"]) > 1):
		issues.append(ValidationIssue.new(&"range", path, where + "bounces must be 1 (once)"))
	if sp.has("bounce_phase") and int(sp["bounce_phase"]) < 1:
		issues.append(ValidationIssue.new(&"range", path, where + "bounce_phase is 1-based"))
	if sp.has("lava_seconds"):
		if int(round(float(sp["lava_seconds"]) * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
			issues.append(
				ValidationIssue.new(
					&"telegraph_short", path, where + "lava_seconds is under the telegraph minimum"
				)
			)
		if int(sp.get("lava_damage", 0)) < 1:
			issues.append(ValidationIssue.new(&"not_positive", path, where + "lava_damage >= 1"))
		if int(round(float(sp.get("lava_burn_seconds", 0.0)) * 60.0)) < 1:
			issues.append(
				ValidationIssue.new(&"duration", path, where + "lava_burn_seconds is under a tick")
			)
	if sp.has("lava_seconds") or move == &"melt":
		if float(sp.get("ford_m", 0.0)) < 1.2:
			issues.append(
				ValidationIssue.new(&"range", path, where + "ford_m must be >= 1.2 (the hero fits)")
			)
	if move == &"melt":
		if float(sp.get("ring_m", 0.0)) <= 0.0 or float(sp.get("min_radius_m", 0.0)) <= 0.0:
			issues.append(
				ValidationIssue.new(&"not_positive", path, where + "ring_m and min_radius_m > 0")
			)
		var step := int(round(float(sp.get("step_seconds", 0.0)) * 60.0))
		var warn := int(round(float(sp.get("warn_seconds", 0.0)) * 60.0))
		if float(sp.get("step_m", 0.0)) <= 0.0 or step < 1:
			issues.append(
				ValidationIssue.new(&"not_positive", path, where + "step_m and step_seconds > 0")
			)
		if warn < BehaviourSchemas.MIN_TELEGRAPH_TICKS or warn >= step:
			issues.append(
				ValidationIssue.new(
					&"telegraph_short",
					path,
					where + "warn_seconds: at least the telegraph minimum, under step_seconds"
				)
			)


## v0.7.5 BF1: a lock leaves tracking time before it and a dodge window of at least the telegraph minimum; marks and
## row lanes must lock; their markers' spacing is at least a tick when there are several.
func _validate_lock(issues: Array[ValidationIssue], path: String, where: String) -> void:
	var lock := int(round(lock_seconds * 60.0))
	if lock_seconds < 0.0:
		issues.append(ValidationIssue.new(&"duration", path, where + "lock_seconds < 0"))
	elif lock_seconds > 0.0:
		if lock < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
			issues.append(
				ValidationIssue.new(
					&"telegraph_short", path, where + "lock_seconds is under the telegraph minimum"
				)
			)
		if lock >= int(round(telegraph_seconds * 60.0)):
			issues.append(
				ValidationIssue.new(&"duration", path, where + "lock_seconds must be < telegraph")
			)
	if BossSchemas.LOCKED_MOVES.has(move) and lock_seconds <= 0.0:
		issues.append(ValidationIssue.new(&"missing", path, where + "%s needs lock_seconds" % move))
	if move == &"grid" and int(shape_params.get("count", 1)) % 2 == 0:
		issues.append(ValidationIssue.new(&"range", path, where + "a grid's count must be odd"))
	if (
		move == &"grid"
		and float(shape_params.get("cell_m", 0.0)) < 2.0 * float(shape_params.get("radius_m", 0.0))
	):
		issues.append(ValidationIssue.new(&"no_gap", path, where + "a grid's circles overlap"))
	if (
		shape_params.has("stagger_seconds")
		and int(shape_params.get("count", 1)) > 1
		and int(round(float(shape_params["stagger_seconds"]) * 60.0)) < 1
	):
		issues.append(
			ValidationIssue.new(&"duration", path, where + "stagger_seconds is under a tick")
		)
