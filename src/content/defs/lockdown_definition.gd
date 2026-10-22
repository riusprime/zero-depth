class_name LockdownDefinition
extends ContentDef
## v0.9.0 LK (owner Q21: "A new room type"; "1-2 a floor, short"; W20-W26; CONTENT_SCHEMA): the Lockdown rooms'
## numbers (data/lockdowns/lockdown.tres, category `lockdown`, id `lockdown`), read by FloorPlan when it builds a
## floor (RunContentCompiler.compile_lockdown -> LockdownTable). A Lockdown seals its doorways with bars when you walk
## in, fights one short encounter in set formations (target 20-40 s), and opens with a free altar. Every number is a
## starting value the owner tunes after playing.

## The kinds (LockdownTable.Kind: Normal, Hazard, Elite) and the telegraph minimum (SimTick.MIN_TELEGRAPH_TICKS, 24
## ticks), named here: content sits below the sim.
const KIND_COUNT := 3
const MIN_WARN_SECONDS := 0.4

## Lockdowns a floor (drawn per floor; fewer when the floor has fewer rooms that fit).
@export var rooms_min := 1
@export var rooms_max := 2
## Each kind's weight, in LockdownTable.Kind order (Normal, Hazard, Elite), and the first floor each may appear on.
## Elite is step EL's hook (owner Q21: floors 4-5 only, under the elite rules): weight 0 until ELITES.md's G1.
@export var kind_weights := PackedInt32Array([750, 250, 0])
@export var kind_floor_min := PackedInt32Array([1, 2, 4])
## Formations per Lockdown, and each formation's size on floors 1-5 (the last repeats).
@export var waves := 3
@export var wave_sizes := PackedInt32Array([5, 5, 5, 6, 6])
## Seconds from the seal (the bars dropping) to the first formation, and from a formation's last kill to the next.
@export var first_wave_seconds := 1.0
@export var wave_gap_seconds := 0.75
## The stuck-enemy safety (W26): an enemy unreachable this long is pulled back into the room; the exits open this long
## after the seal whatever is left.
@export var stuck_seconds := 3.0
@export var cap_seconds := 90.0
## Hazard Lockdowns: a strike every hazard_every_seconds, its ground warning hazard_warn_seconds before it lands (at
## least the 0.4 s telegraph minimum), its radius (m) and its damage to the hero.
@export var hazard_every_seconds := 2.0
@export var hazard_warn_seconds := 1.0
@export var hazard_radius := 1.3
@export var hazard_damage := 12


func category() -> StringName:
	return &"lockdown"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	var p := resource_path
	if rooms_min < 0 or rooms_max < rooms_min:
		issues.append(ValidationIssue.new(&"range", p, "0 <= rooms_min <= rooms_max"))
	if kind_weights.size() != KIND_COUNT:
		issues.append(ValidationIssue.new(&"range", p, "kind_weights needs one weight per kind"))
	if kind_floor_min.size() != KIND_COUNT:
		issues.append(ValidationIssue.new(&"range", p, "kind_floor_min needs one floor per kind"))
	for v in kind_weights:
		if v < 0:
			issues.append(ValidationIssue.new(&"range", p, "kind weights are >= 0"))
			break
	check_positive(issues, "waves", waves)
	issues.append_array(ArenaDefinition.wave_size_issues(p, wave_sizes))
	for f in [
		"stuck_seconds", "cap_seconds", "hazard_every_seconds", "hazard_radius", "hazard_damage"
	]:
		check_positive(issues, f, float(get(f)))
	if first_wave_seconds < 0.0 or wave_gap_seconds < 0.0:
		issues.append(ValidationIssue.new(&"range", p, "times are >= 0"))
	if hazard_warn_seconds < MIN_WARN_SECONDS:
		issues.append(
			ValidationIssue.new(&"range", p, "hazard_warn_seconds >= the telegraph minimum")
		)
	if hazard_warn_seconds >= hazard_every_seconds:
		issues.append(
			ValidationIssue.new(&"range", p, "hazard_warn_seconds < hazard_every_seconds")
		)
	if cap_seconds <= stuck_seconds:
		issues.append(ValidationIssue.new(&"range", p, "cap_seconds > stuck_seconds"))
	return issues
