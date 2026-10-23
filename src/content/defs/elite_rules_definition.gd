class_name EliteRulesDefinition
extends ContentDef
## v0.9.0 EL (owner Q24: "15 % / 25 %", floors 4-5 only, at most 1 alive, at least 2 rooms apart; Q25: "you have a 30%
## chance of dropping the core"; ELITES.md E0): where elites appear and what a kill gives (data/elites/rules.tres,
## category `elite_rules`, id `rules`). Starting values (F10).
## - room_permille: the share of a floor's combat rooms that hold an elite, per floor of a loop (1-based; the last
##   repeats; 0 = none). The elite arrives the first time the hero walks in (while fewer than max_alive are alive).
## - min_gap_rooms: at least this many rooms between two elite rooms (an Elite Lockdown counts as one).
## - core_drop_permille: a killed elite drops the card its core holds with this chance.
## - kind_weights: Breaker, Rift Hunter, Conduit (EliteDefinition.ARCHETYPES order), for each elite drawn.
## - lockdown_escort: the normal enemies standing with an Elite Lockdown's elite (owner Q21: "an elite plus a small
##   escort").

@export var room_permille := PackedInt32Array([0, 0, 0, 150, 250])
@export var min_gap_rooms := 2
@export var max_alive := 1
@export var core_drop_permille := 300
@export var kind_weights := PackedInt32Array([1, 1, 1])
@export var lockdown_escort := 3


func category() -> StringName:
	return &"elite_rules"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	var p := resource_path
	if room_permille.is_empty():
		issues.append(ValidationIssue.new(&"range", p, "room_permille needs one entry a floor"))
	for v in room_permille:
		if v < 0 or v > 1000:
			issues.append(ValidationIssue.new(&"range", p, "room_permille is per mille (0..1000)"))
			break
	if min_gap_rooms < 0:
		issues.append(ValidationIssue.new(&"range", p, "min_gap_rooms >= 0"))
	if max_alive < 1:
		issues.append(ValidationIssue.new(&"range", p, "max_alive >= 1"))
	if core_drop_permille < 0 or core_drop_permille > 1000:
		issues.append(ValidationIssue.new(&"range", p, "core_drop_permille is per mille"))
	if kind_weights.size() != EliteDefinition.ARCHETYPES.size():
		issues.append(ValidationIssue.new(&"range", p, "kind_weights needs one weight per elite"))
	var any := false
	for v in kind_weights:
		if v < 0:
			issues.append(ValidationIssue.new(&"range", p, "kind weights are >= 0"))
		any = any or v > 0
	if not any:
		issues.append(ValidationIssue.new(&"range", p, "some elite needs a weight"))
	if lockdown_escort < 0:
		issues.append(ValidationIssue.new(&"range", p, "lockdown_escort >= 0"))
	return issues
