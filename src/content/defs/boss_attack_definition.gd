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
	for k in shape_params:
		if not (schema["params"] as Array).has(k):
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
	for k in ["count", "chain", "volleys", "max_alive"]:
		if shape_params.has(k) and int(shape_params[k]) < 1:
			issues.append(ValidationIssue.new(&"not_positive", path, where + "%s must be >= 1" % k))
	if shape_params.has("count") and int(shape_params["count"]) > 8:
		issues.append(ValidationIssue.new(&"too_many", path, where + "count must be <= 8"))
	for k: String in BossSchemas.ENEMY_PARAMS:
		if shape_params.has(k) and String(shape_params[k]).is_empty():
			issues.append(ValidationIssue.new(&"missing", path, where + "%s is empty" % k))
