class_name DifficultyCurveDefinition
extends ContentDef
## A floor's difficulty curve (v0.4.0 TU, owner 2026-10-08 D1–D4 and "distribute presenting them through the first
## 3 floors"): floor time → phase. The first phase is the calm minute (no tier growth, few enemies, the basic kinds,
## small packs); the next phases bring the floor's kinds in order and ramp the danger tier, the alive cap and the
## spawn rate up to the last phase, the peak (SC's tier-max level), which holds to the floor's end. SC's spawn
## director (SpawnDirectorDefinition) stays the source of the per-tier tables and the mix's weights; the curve says
## when. One definition per floor (floor_index); compiled into CurveTable by ContentCompiler.compile_curve.

## The floor this curve runs on (1-based).
@export var floor_index := 1
@export var phases: Array[DifficultyPhase] = []


func category() -> StringName:
	return &"curve"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if floor_index < 1:
		issues.append(_issue(&"floor_index", "floor_index must be >= 1"))
	if phases.is_empty():
		issues.append(_issue(&"missing", "the curve has no phases"))
		return issues
	var seen := {}
	for k in phases.size():
		var p := phases[k]
		if p == null:
			issues.append(_issue(&"phase", "phases[%d] is empty" % k))
			continue
		check_duration(issues, "phases[%d].start_seconds" % k, p.start_seconds)
		if String(p.name_key).is_empty():
			issues.append(_issue(&"phase_name", "phases[%d] has no name" % k))
		if p.tier_permille < 0 or p.cap_permille < 1 or p.cap_permille > 1000:
			issues.append(_issue(&"phase_range", "phases[%d]: tier or cap out of range" % k))
		for v in [p.hp_permille, p.damage_permille]:
			if v < 1 or v > 1000:
				issues.append(_issue(&"phase_range", "phases[%d]: HP or damage out of 1..1000" % k))
		if p.interval_permille < 1 or p.pack_cap < 0:
			issues.append(_issue(&"phase_range", "phases[%d]: interval or pack out of range" % k))
		for id in p.kinds:
			if String(id).is_empty() or seen.has(id):
				issues.append(
					_issue(&"phase_kind", "phases[%d]: kind '%s' empty or repeated" % [k, id])
				)
			seen[id] = true
		if k > 0 and phases[k - 1] != null:
			_check_step(issues, k, phases[k - 1], p)
	var calm := phases[0]
	if calm != null:
		if calm.start_seconds != 0.0:
			issues.append(_issue(&"calm", "the first phase must start at 0"))
		if calm.tier_permille != 0 or not calm.hold:
			issues.append(_issue(&"calm", "the first phase must hold tier 0 (the calm minute)"))
		if calm.kinds.is_empty():
			issues.append(_issue(&"calm", "the first phase opens no kind"))
	return issues


## Every enemy id the curve names, in phase order.
func enemy_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p in phases:
		if p != null:
			out.append_array(p.kinds)
	return out


## Phase k after phase q: later, and never easier (tier, cap, HP and damage don't fall, the interval doesn't grow).
func _check_step(
	issues: Array[ValidationIssue], k: int, q: DifficultyPhase, p: DifficultyPhase
) -> void:
	if p.start_seconds <= q.start_seconds:
		issues.append(_issue(&"phase_order", "phases[%d] starts no later than the one before" % k))
	if (
		p.tier_permille < q.tier_permille
		or p.cap_permille < q.cap_permille
		or p.hp_permille < q.hp_permille
		or p.damage_permille < q.damage_permille
		or p.interval_permille > q.interval_permille
	):
		issues.append(_issue(&"phase_ramp", "phases[%d] is easier than the one before" % k))


func _issue(code: StringName, message: String) -> ValidationIssue:
	return ValidationIssue.new(code, resource_path, message)
