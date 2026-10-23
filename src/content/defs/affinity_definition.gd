class_name AffinityDefinition
extends ContentDef
## v0.9.0 RB (owner, PLAN "Owner decisions" RB; docs/roadmap/v0.9.0/AFFINITIES.md A0-A5): one rune affinity, picked at
## the hub's Wardrobe between runs and locked once a run starts (RunState.affinity). A sidegrade, never a stat
## (PD-06): every gain is conditional and comes with its trade-off. Category `affinity`, in data/wardrobe/; compiled
## into AffinityTable (RunContentCompiler.compile_affinity). Every number is a starting value (a tuning default, not a
## measurement). None (id `none`) holds no effect: a run with it builds no affinity state, so it plays as before RB.

## The order the Wardrobe lists it in.
@export var order := 0
@export var name_key: StringName
## One line on its gain and one on its trade-off (the Wardrobe shows both).
@export var desc_key: StringName
@export var cost_key: StringName
## Its colour (the rune on the robe's back and the circle under the feet; ART_DIRECTION §4) and the glyph drawn
## (AffinityRunes.GLYPHS: 0 none, 1 ember, 2 storm, 3 venom, 4 astral, 5 guardian).
@export var color := Color.WHITE
@export var glyph := 0
## A1 Ember: burns the hero applies last this per mille of their duration (1500: 50 % longer).
@export var burn_duration_permille := 1000
## A2 Storm: the dash shocks enemies within this many metres of its path (0: off), this many stacks each, once a
## dash; and the dash's cooldown grows by this many seconds.
@export var dash_shock_radius_m := 0.0
@export var dash_shock_stacks := 0
@export var dash_cooldown_add_seconds := 0.0
## A3 Venom: a poisoned enemy's poison jumps to the nearest enemy within this many metres when it dies (0: off).
@export var poison_jump_m := 0.0
## A4 Astral: secrets within this many metres pulse faintly (0: off), and the minimap marks a room that holds a
## secret once it has been entered. No combat effect.
@export var secret_sense_m := 0.0
@export var map_secrets := false
## A5 Guardian: the wards that block the next damaging hit, refilled at each floor's start; and the run shards picked
## up, per mille (800: 20 % fewer).
@export var ward_charges := 0
@export var shard_permille := 1000
## Card offers: the cards (item ids) offered more often and less often, each weight times its per mille.
@export var favoured_cards: Array[StringName] = []
@export var favoured_permille := 1000
@export var disfavoured_cards: Array[StringName] = []
@export var disfavoured_permille := 1000


func category() -> StringName:
	return &"affinity"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	var p := resource_path
	if String(name_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", p, "an affinity needs a name_key"))
	if glyph < 0 or glyph > 5:
		issues.append(ValidationIssue.new(&"range", p, "glyph is 0..5"))
	for f in [
		"burn_duration_permille", "shard_permille", "favoured_permille", "disfavoured_permille"
	]:
		if int(get(f)) < 1 or int(get(f)) > 5000:
			issues.append(ValidationIssue.new(&"range", p, "%s is per mille (1..5000)" % f))
	for f in [
		"dash_shock_radius_m", "poison_jump_m", "secret_sense_m", "dash_cooldown_add_seconds"
	]:
		if float(get(f)) < 0.0:
			issues.append(ValidationIssue.new(&"range", p, "%s is >= 0" % f))
	check_duration(issues, "dash_cooldown_add_seconds", dash_cooldown_add_seconds)
	if dash_shock_stacks < 0 or ward_charges < 0 or ward_charges > 3:
		issues.append(ValidationIssue.new(&"range", p, "stacks >= 0, wards 0..3"))
	for c in favoured_cards:
		if c in disfavoured_cards:
			issues.append(ValidationIssue.new(&"range", p, "%s is both favoured and not" % c))
	return issues


## True for None: no effect at all (FloorPlan builds no affinity state for it).
func is_none() -> bool:
	return (
		burn_duration_permille == 1000
		and dash_shock_radius_m <= 0.0
		and dash_cooldown_add_seconds <= 0.0
		and poison_jump_m <= 0.0
		and secret_sense_m <= 0.0
		and not map_secrets
		and ward_charges == 0
		and shard_permille == 1000
		and (favoured_cards.is_empty() or favoured_permille == 1000)
		and (disfavoured_cards.is_empty() or disfavoured_permille == 1000)
	)
