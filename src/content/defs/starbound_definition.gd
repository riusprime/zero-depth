class_name StarboundDefinition
extends ContentDef
## A Starbound card,
## the loop-only card kind. It is offered from loop 2 in a regular altar's pick (RewardsDefinition.starbound_permille),
## works with both weapons, has no level cap (each pick adds a stack) and is never in the shop. The id names the card
## and its rule (Starbound, one per id in CARDS order); the numbers are per stack:
## - starbound_arc_jump: `amount` jumps a stack, to the nearest enemy within `reach_m` this chain hasn't hit, each at
##   `share` percent of the hit before;
## - starbound_rising_edge: + `amount` percent crit damage a crit, at most `cap` percent, until the room is cleared;
## - starbound_echo_cast: + `amount` percent repeat chance (past 100 %: sure, and the rest a chance of one more), at
##   most `cap` repeats (a count, not percent);
## - starbound_fervour: + `amount` percent haste a kill, at most `cap` percent, until the room is cleared;
## - starbound_detonation: a kill bursts for `amount` percent of the enemy's max HP within `reach_m`; bosses and
##   elites take `share` percent of it.

## The cards in the sim's order (Starbound's indices). Appended, never renumbered.
const CARDS: Array[StringName] = [
	&"starbound_arc_jump",
	&"starbound_rising_edge",
	&"starbound_echo_cast",
	&"starbound_fervour",
	&"starbound_detonation",
]
## The cards with a cap, a reach and a share.
const CAPPED: Array[StringName] = [
	&"starbound_rising_edge", &"starbound_echo_cast", &"starbound_fervour"
]
const REACHED: Array[StringName] = [&"starbound_arc_jump", &"starbound_detonation"]

@export var name_key: StringName
@export var desc_key: StringName
## Draw weight against the other Starbound cards (when an offer gets one).
@export var weight := 10
## Per stack: Arc Jump's jumps; the others percent.
@export var amount := 0.0
## Per stack, percent (Rising Edge, Fervour); Echo Cast: the most repeats. 0 for the others.
@export var cap := 0.0
## Arc Jump's jump reach, Detonation's burst radius (m). 0 for the others.
@export var reach_m := 0.0
## Percent: Arc Jump's share of the hit before, Detonation's share on bosses and elites. 0 for the others.
@export var share := 0.0


func category() -> StringName:
	return &"starbound"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if not CARDS.has(id):
		issues.append(
			ValidationIssue.new(&"unknown", resource_path, "unknown Starbound card %s" % id)
		)
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	if weight < 0:
		issues.append(ValidationIssue.new(&"negative", resource_path, "weight is negative"))
	check_positive(issues, "amount", amount)
	if CAPPED.has(id):
		check_positive(issues, "cap", cap)
	elif cap != 0.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "cap is only for %s" % [CAPPED]))
	if REACHED.has(id):
		check_positive(issues, "reach_m", reach_m)
		if share <= 0.0 or share > 100.0:
			issues.append(ValidationIssue.new(&"range", resource_path, "share is 0..100 percent"))
	elif reach_m != 0.0 or share != 0.0:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "reach_m and share are only for %s" % [REACHED]
			)
		)
	return issues
