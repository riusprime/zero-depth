class_name ShrineDefinition
extends ContentDef
## v0.9.0 SH, HF (owner Q29b: "Today's gamble shrine becomes the Fortune Shrine; Blood and Chaos shrines are added (at
## most one shrine a floor, costs shown first; the Chaos challenge may bring an elite, a designed exception). Healing
## fountains (rare, one use)"; W36; CONTENT_SCHEMA): the shrines' and the healing fountain's numbers
## (data/shrines/shrines.tres, category `shrines`, id `shrines`), read by FloorPlan when it builds a floor
## (RunContentCompiler.compile_shrines -> ShrineTable). The Fortune shrine's own numbers stay the gamble shrine's
## (data/gamble/shrine.tres). Every number is a starting value the owner tunes after playing.

## The kinds (ShrineTable.Kind: Fortune, Blood, Chaos), named here: content sits below the sim.
const KIND_COUNT := 3

## Each kind's weight for the floor's one shrine, in ShrineTable.Kind order (Fortune, Blood, Chaos), and the first
## floor each may stand on. The shrine's own chance and room stay the gamble shrine's (floor_chance_permille).
@export var kind_weights := PackedInt32Array([400, 300, 300])
@export var kind_floor_min := PackedInt32Array([1, 1, 1])
## Blood: its price, per mille of the hero's current HP (rounded up; it never leaves less than 1 HP), the least HP it
## takes a price from (per mille of max HP; below it the shrine refuses), and the free altars it raises.
@export var blood_cost_permille := 300
@export var blood_min_permille := 250
@export var blood_altars := 1
## Chaos: the challenge's enemies on floors 1-5 (the last repeats), the chance (per mille) it also brings an elite
## archetype (v0.9.0 EL, owner Q29b: "a designed exception"; a starting value, on any floor) and the free altars
## clearing it raises.
@export var chaos_sizes := PackedInt32Array([5, 6, 6, 7, 7])
@export var chaos_elite_permille := 250
@export var chaos_altars := 1
## The healing fountain: the chance a floor has one (per mille), the first floor it may appear on, and its one heal
## (per mille of max HP).
@export var fountain_permille := 250
@export var fountain_floor_min := 2
@export var fountain_heal_permille := 400
## How near the hero stands to use a shrine or the fountain (m).
@export var reach := 1.8


func category() -> StringName:
	return &"shrines"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	var p := resource_path
	if kind_weights.size() != KIND_COUNT:
		issues.append(ValidationIssue.new(&"range", p, "kind_weights needs one weight per kind"))
	if kind_floor_min.size() != KIND_COUNT:
		issues.append(ValidationIssue.new(&"range", p, "kind_floor_min needs one floor per kind"))
	for v in kind_weights:
		if v < 0:
			issues.append(ValidationIssue.new(&"range", p, "kind weights are >= 0"))
			break
	for f in ["blood_cost_permille", "fountain_heal_permille", "reach"]:
		check_positive(issues, f, float(get(f)))
	for f in [
		"blood_cost_permille", "blood_min_permille", "fountain_permille", "fountain_heal_permille"
	]:
		if int(get(f)) < 0 or int(get(f)) > 1000:
			issues.append(ValidationIssue.new(&"range", p, "%s is per mille (0..1000)" % f))
	if blood_altars < 1 or chaos_altars < 1:
		issues.append(ValidationIssue.new(&"range", p, "a shrine raises at least one altar"))
	if chaos_elite_permille < 0 or chaos_elite_permille > 1000:
		issues.append(
			ValidationIssue.new(&"range", p, "chaos_elite_permille is per mille (0..1000)")
		)
	if fountain_floor_min < 1:
		issues.append(ValidationIssue.new(&"range", p, "fountain_floor_min >= 1"))
	issues.append_array(ArenaDefinition.wave_size_issues(p, chaos_sizes))
	return issues
