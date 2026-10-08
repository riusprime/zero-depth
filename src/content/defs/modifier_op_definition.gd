class_name ModifierOpDefinition
extends Resource
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md §2): one rule of a modifier, a sub-resource of ModifierDefinition.ops.
## Numbers are in content units (seconds, degrees, metres per second); ContentCompiler.compile_modifier converts them
## to sim units with the same functions the item compiler uses, so a migrated item keeps its exact numbers.
## The op's stage is the modifier's unless `stage` names another (a card that both fans and weakens its shots):
## every op runs in the stage its field belongs to (FIELD_STAGE), which the validator checks.

## Appended, never renumbered. Numeric ops change one spec field: SET, ADD, MAX, MIN (by value) and MUL_PERMILLE
## (field × value / 1000). SET_FORM changes what the attack is. STATUS feeds an engine status on hit (stacks, one
## application every `every` landed hits; 0 = every hit). ELEMENT names an element the view draws. HOOK adds an
## attack the spec spawns (its trigger, form, tags, size and damage below).
enum Op { SET, ADD, MAX, MIN, MUL_PERMILLE, SET_FORM, STATUS, ELEMENT, HOOK }

## The forms of the design's §1 (AttackSpec.Form mirrors these numbers).
enum Form { ARC, BOLT, RING, BEAM, ZONE, ORBITER, LOB, BURST }

## When a hook fires (AttackSpec.Trigger mirrors these numbers). ON_HIT: each landed hit; ON_KILL: a hit that
## kills; ON_NTH: an Nth step of the combo (the spec's nth_every) when it resolves.
enum Trigger { ON_HIT, ON_KILL, ON_NTH }

## The spec fields a numeric op may change, in content units, and the stage each belongs to
## (ModifierDefinition.Stage numbers: FORM 0, PATTERN 1, BEHAVIOUR 2, PAYLOAD 3, HOOK 4, SCALE 5).
const FIELD_STAGE := {
	&"count": 1,
	&"spread_degrees": 1,
	&"repeat_delay_seconds": 1,
	&"repeat_damage_permille": 1,
	&"bounces": 2,
	&"pierce": 2,
	&"damage": 3,
	&"damage_permille": 3,
	&"nth_every": 3,
	&"nth_damage_permille": 3,
	&"hitstop_seconds": 3,
	&"arc_degrees": 5,
	&"reach_m": 5,
	&"reach_bonus_permille": 5,
	&"radius_m": 5,
	&"speed_mps": 5,
	&"life_seconds": 5,
	&"period_seconds": 5,
	&"rate_bonus_permille": 5,
}
## Engine statuses a STATUS op may feed (the v0.3.0 engines), and the elements an ELEMENT op may name: the design's
## five, plus bleed (the v0.3.0 bleed engine, drawn red until the element art of MX stage 3).
const STATUSES: Array[StringName] = [&"burn", &"shock", &"bleed", &"frost", &"slow"]
const ELEMENTS: Array[StringName] = [&"ember", &"storm", &"frost", &"venom", &"void", &"bleed"]

@export var op := Op.ADD
## -1: the modifier's stage; otherwise a ModifierDefinition.Stage.
@export var stage := -1
## Numeric ops: a FIELD_STAGE key.
@export var field: StringName = &""
@export var value := 0.0
## SET_FORM, and HOOK's spawned attack.
@export var form := Form.ARC
## STATUS.
@export var status: StringName = &""
@export var stacks := 0
@export var every := 0
## ELEMENT.
@export var element: StringName = &""
## HOOK: when, the spawned attack's tags (ModifierDefinition.TAGS), its radius (a burst) or reach (a beam's jump),
## its damage (flat, or a share of the parent's base damage), a trigger every Nth time (0 = each time), and the
## effect id its hits carry.
@export var hook_trigger := Trigger.ON_HIT
@export var hook_tags: PackedStringArray = PackedStringArray()
@export var hook_radius_m := 0.0
@export var hook_reach_m := 0.0
@export var hook_damage := 0
@export var hook_damage_permille := 0
@export var hook_every := 0
@export var hook_effect: StringName = &""


## The stage this op runs in, given its modifier's.
func stage_in(modifier_stage: int) -> int:
	return modifier_stage if stage < 0 else stage


## The stage the op's kind requires (-1: any numeric field's own stage).
func required_stage() -> int:
	match op:
		Op.SET_FORM:
			return 0
		Op.STATUS, Op.ELEMENT:
			return 3
		Op.HOOK:
			return 4
	return int(FIELD_STAGE.get(field, -1))


func is_numeric() -> bool:
	return op in [Op.SET, Op.ADD, Op.MAX, Op.MIN, Op.MUL_PERMILLE]
