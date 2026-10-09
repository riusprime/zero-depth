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

## The forms of the design's §1 (AttackSpec.Form mirrors these numbers). v0.6.0 MX4: WEAPON, a hook's child only: a
## copy of the weapon's last attack (the Blade's current combo step, or the Gun's shot), resolved when it launches
## (Long Shadow's afterimage, Meltdown Edge's circle).
enum Form { ARC, BOLT, RING, BEAM, ZONE, ORBITER, LOB, BURST, WEAPON }

## When a hook fires (AttackSpec.Trigger mirrors these numbers). ON_HIT: each landed hit; ON_KILL: a hit that
## kills; ON_NTH: an Nth step of the combo (the spec's nth_every) when it resolves. v0.6.0 MX4: ON_END: where the
## attack ends (an arc's tip, a bolt's end, a burst, a bomb's blast, a ring at its radius; the dash's end);
## ON_LAUNCH: as the attack launches, from where it leaves (the dash's start, every MOVE step walked, a blink's
## start, a vent); EVERY_NTH: every hook_every-th launch of the spec launches the child instead (Bomb Rounds).
enum Trigger { ON_HIT, ON_KILL, ON_NTH, ON_END, ON_LAUNCH, EVERY_NTH }

## v0.6.0 MX4: when a hook may fire: always, or only while the heat is at Overclock (Heat Sink Rounds).
enum When { ALWAYS, OVERCLOCK }

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
	# v0.6.0 MX4 (the M-list's runner features; AttackSpec names each).
	&"mirror": 0,
	&"directions": 1,
	&"back_damage_permille": 1,
	&"aim_offset_degrees": 1,
	&"chains": 2,
	&"homing_dps": 2,
	&"returns": 2,
	&"orbit_seconds": 2,
	&"intangible": 2,
	&"pull_m": 3,
	&"barrier_seconds": 3,
	&"charge_seconds": 3,
	&"charge_permille": 3,
	&"resonance_permille": 3,
	&"heat_rate_permille": 5,
	&"range": 5,
}
## Engine statuses a STATUS op may feed (the v0.3.0 engines), and the elements an ELEMENT op may name: the design's
## five, plus bleed (the v0.3.0 bleed engine, drawn red until the element art of MX stage 3).
## v0.6.0 MX4: poison (Venom Core's engine, Venom).
const STATUSES: Array[StringName] = [&"burn", &"shock", &"bleed", &"frost", &"slow", &"poison"]
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
## v0.6.0 MX4: the hook's child launches this long after its trigger (0 = at once); it fires only `hook_when`; and
## `hook_ops` shape the child before the build's modifiers compile it (any op but HOOK, in order, each in its own
## field's units: a count, a speed, a life, a status, an element...).
@export var hook_delay_seconds := 0.0
@export var hook_when := When.ALWAYS
@export var hook_ops: Array[Resource] = []  # ModifierOpDefinitions (Resource: a script never types itself)


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
