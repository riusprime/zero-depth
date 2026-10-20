class_name RemnantRule
extends RefCounted
## v0.8.0 RM (owner O91: "Build reusable remnants, connections and events—not hardcoded modifier-pair scripts";
## docs/design/WAND.md rule 12; SIM_CONTRACTS §8l): a REMNANT op's remnant in sim units (ModifierOpDefinition's
## remnant_* fields compiled by ModifierCompiler). Loadout: compiled with the card, grown by its level (at_level), never
## written in play. What a remnant does is its kind and these numbers (Remnants runs them), never its card: the same
## rules serve every card.

## ModifierOpDefinition.RemnantKind, Spawn and Activate, same numbers.
enum Kind { SEGMENT, ANCHOR, MARK, FRAGMENT }
enum Spawn { LINK, CONTACT, HIT, PATH, NONE }
enum Activate { ENEMY_CROSS, ATTACK_CROSS, PULL, TURN, FINISHER, DELAY, CONSUME }

## Every field, in hash order (appended, never reordered).
const FIELDS: Array[StringName] = [
	&"kind",
	&"spawn",
	&"activate",
	&"life_ticks",
	&"life_per_level",
	&"max_alive",
	&"max_per_level",
	&"gap_ticks",
	&"charges",
	&"length_m",
	&"width_m",
	&"link_ticks",
	&"pull_radius_m",
	&"pull_step_m",
	&"bend_radius_m",
	&"bend_step",
	&"turn_units",
	&"delay_ticks",
	&"stack_max",
	&"stack_per_level",
	&"period_ticks",
	&"release_max",
	&"stagger",
]

var kind: int = Kind.SEGMENT
var spawn: int = Spawn.HIT
var activate: int = Activate.ENEMY_CROSS
## Its life (ticks) and the most of this card's alive at once, each + its per-level step a level above 1.
var life_ticks := 60
var life_per_level := 0
var max_alive := 1
var max_per_level := 0
## The least ticks between two of its hits on one enemy (0 = every tick), its charges (0 = until its life ends).
var gap_ticks := 0
var charges := 1
## A crack's length and a segment's half width (m); two shots this many ticks apart or fewer link (LINK).
var length_m := 0.0
var width_m := 0.15
var link_ticks := 0
## An anchor's pull (reach, m a tick) and bend (reach, 1/4096 turns a tick).
var pull_radius_m := 0.0
var pull_step_m := 0.0
var bend_radius_m := 0.0
var bend_step := 0
## A mark breaks from this far round (1/4096 turns); a replay waits this many ticks.
var turn_units := 1024
var delay_ticks := 0
## A fragment's most per enemy (+ per level); a consumer's period (ticks) and most releases.
var stack_max := 1
var stack_per_level := 0
var period_ticks := 0
var release_max := 0
## An activation staggers the enemy it lands on (EnemyAi's recover).
var stagger := false


## A copy at card level `level` (1..5): life, alive cap and stack cap grown by their steps × (level − 1).
func at_level(level: int) -> RemnantRule:
	var r := RemnantRule.new()
	for f: StringName in FIELDS:
		r.set(f, get(f))
	var n := maxi(0, level - 1)
	r.life_ticks = life_ticks + life_per_level * n
	r.max_alive = max_alive + max_per_level * n
	r.stack_max = stack_max + stack_per_level * n
	return r


## True if a level changes it.
func levels() -> bool:
	return life_per_level != 0 or max_per_level != 0 or stack_per_level != 0


func hash_into(h: StateHasher) -> void:
	h.add_string("remnant")
	for f in FIELDS:
		var v: Variant = get(f)
		if v is float:
			h.add_f32(v)
		else:
			h.add_int(int(v))
