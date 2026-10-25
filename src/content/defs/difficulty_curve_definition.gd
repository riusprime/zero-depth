class_name DifficultyCurveDefinition
extends ContentDef
## A floor's difficulty curve (v0.4.0 TU, owner 2026-10-08 D1–D4 and "distribute presenting them through the first
## 3 floors"): floor time → phase. The first phase starts at tier 0 and opens the first kinds; on floor 1 it is the
## calm phase (it holds: no tier growth, few enemies, the basic kinds, small packs; v0.5.5 D1: 30 s), and floors 2–3
## start straight at their warm-up level (no calm phase, v0.5.5 D1); the next phases bring the floor's kinds in
## order and ramp the danger tier, the alive cap and the spawn rate up to the last phase, the peak (SC's tier-max
## level), which holds to the floor's end. SC's spawn
## director (SpawnDirectorDefinition) stays the source of the per-tier tables and the mix's weights; the curve says
## when. One definition per floor (floor_index); compiled into CurveTable by ContentCompiler.compile_curve.

## The floor this curve runs on (1-based).
@export var floor_index := 1
@export var phases: Array[DifficultyPhase] = []
## v0.9.5 DC (owner: "aim to a 10 minutes max per floor"): after the peak the danger tier keeps rising on a schedule of
## floor time. overtime_seconds[i] is when tier 4 + i starts (ascending); past the last, +1 tier every
## overtime_step_seconds up to overtime_max_tier. Each tier above 3 adds cap_per_tier_permille to the peak's cap and
## takes interval_per_tier_permille off its interval (not below interval_min_seconds); pack_cap_bumps are the tiers
## that add one to the largest pack. Empty overtime_seconds = none.
@export var overtime_seconds := PackedInt32Array()
@export var overtime_step_seconds := 30
@export var overtime_max_tier := 20
@export var cap_per_tier_permille := 0
## v0.9.5 (lead, owner line 21: 10–20 enemies already lag): the cap's overtime growth stops here; past it the danger
## comes from the tier tables (enemy HP and damage), not more enemies at once. 0 = no ceiling.
@export var cap_bonus_max_permille := 0
@export var interval_per_tier_permille := 0
@export var interval_min_seconds := 0.8
@export var pack_cap_bumps := PackedInt32Array()


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
		if k > 0 and p.hold:
			issues.append(_issue(&"calm", "only the first phase may hold (the calm phase)"))
		if k > 0 and phases[k - 1] != null:
			_check_step(issues, k, phases[k - 1], p)
	_check_overtime(issues)
	var calm := phases[0]
	if calm != null:
		if calm.start_seconds != 0.0:
			issues.append(_issue(&"calm", "the first phase must start at 0"))
		if calm.tier_permille != 0:
			issues.append(_issue(&"calm", "the first phase must start at tier 0"))
		if calm.kinds.is_empty():
			issues.append(_issue(&"calm", "the first phase opens no kind"))
	return issues


func _check_overtime(issues: Array[ValidationIssue]) -> void:
	if overtime_seconds.is_empty():
		return
	var peak := phases[phases.size() - 1]
	for k in overtime_seconds.size():
		if overtime_seconds[k] <= 0 or (k > 0 and overtime_seconds[k] <= overtime_seconds[k - 1]):
			issues.append(_issue(&"overtime", "overtime_seconds must be positive and ascending"))
			break
	if peak != null and overtime_seconds[0] < peak.start_seconds:
		issues.append(_issue(&"overtime", "the overtime starts before the peak phase"))
	if overtime_step_seconds < 1 or interval_min_seconds <= 0.0:
		issues.append(_issue(&"overtime", "step and interval floor must be positive"))
	if overtime_max_tier < 3 + overtime_seconds.size():
		issues.append(_issue(&"overtime", "overtime_max_tier is below the last scheduled tier"))
	if (
		cap_per_tier_permille < 0
		or (cap_bonus_max_permille != 0 and cap_bonus_max_permille < 1000)
		or interval_per_tier_permille < 0
		or interval_per_tier_permille > 100
	):
		issues.append(_issue(&"overtime", "the per-tier cap or interval share is out of range"))
	for k in pack_cap_bumps.size():
		if pack_cap_bumps[k] < 4 or (k > 0 and pack_cap_bumps[k] <= pack_cap_bumps[k - 1]):
			issues.append(_issue(&"overtime", "pack_cap_bumps must be tiers above 3, ascending"))
			break


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
