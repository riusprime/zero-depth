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
## attack the spec spawns (its trigger, form, tags, size and damage below). v0.6.5 WN1: TRIGGER, a wand trigger card's
## one op: it cuts the wand (the cards to its right build the child spell cast on `hook_trigger`; Modifiers).
enum Op { SET, ADD, MAX, MIN, MUL_PERMILLE, SET_FORM, STATUS, ELEMENT, HOOK, TRIGGER }

## The forms of the design's §1 (AttackSpec.Form mirrors these numbers). v0.6.0 MX4: WEAPON, a hook's child only: a
## copy of the weapon's last attack (the Blade's current combo step, or the Gun's shot), resolved when it launches
## (Long Shadow's afterimage, Meltdown Edge's circle).
enum Form { ARC, BOLT, RING, BEAM, ZONE, ORBITER, LOB, BURST, WEAPON }

## When a hook fires (AttackSpec.Trigger mirrors these numbers). ON_HIT: each landed hit; ON_KILL: a hit that
## kills; ON_NTH: an Nth step of the combo (the spec's nth_every) when it resolves. v0.6.0 MX4: ON_END: where the
## attack ends (an arc's tip, a bolt's end, a burst, a bomb's blast, a ring at its radius; the dash's end);
## ON_LAUNCH: as the attack launches, from where it leaves (the dash's start, every MOVE step walked, a blink's
## start, a vent); EVERY_NTH: every hook_every-th launch of the spec launches the child instead (Bomb Rounds).
## v0.6.5 WN1 (the wand's triggers): ON_CRIT, a landed critical hit; ON_FINISHER, the combo's last step's hits (a
## TRIGGER op only: Modifiers compiles it into the last step's ON_HIT).
enum Trigger { ON_HIT, ON_KILL, ON_NTH, ON_END, ON_LAUNCH, EVERY_NTH, ON_CRIT, ON_FINISHER }

## v0.6.0 MX4: when a hook may fire: always, or only while the heat is at Overclock (Heat Sink Rounds). v0.6.5 WN4:
## COUNTER, only on a slash that counters (within its counter window after a dash: Counter, B16).
enum When { ALWAYS, OVERCLOCK, COUNTER }

## v0.6.5 WN1: the triggers a TRIGGER op may cut on (WAND.md T1–T4).
const WAND_TRIGGERS: Array[int] = [
	Trigger.ON_HIT, Trigger.ON_KILL, Trigger.ON_END, Trigger.ON_FINISHER, Trigger.ON_CRIT
]

## The spec fields a numeric op may change, in content units: [stage, sim field, unit]. The stage each belongs to
## (ModifierDefinition.Stage numbers: FORM 0, PATTERN 1, BEHAVIOUR 2, PAYLOAD 3, HOOK 4, SCALE 5); the AttackSpec
## field it changes (ModifierCompiler applies it); and how its value converts to sim units: "" as is, "ticks" seconds
## to ticks, "half_turns" a full width in degrees to a half width in 1/4096 turns, "turns" degrees to 1/4096 turns,
## "per_tick" metres per second to metres per tick, "turn_rate" degrees per second to 1/4096 turns per tick ("range"
## is the virtual field Modifiers scales per form). One table, so a field the validator accepts is always one the
## compiler applies (plain strings and ints: content imports nothing from the sim).
const FIELD_STAGE := {
	&"count": [1, &"count", ""],
	&"spread_degrees": [1, &"spread", "turns"],
	&"repeat_delay_seconds": [1, &"repeat_delay_ticks", "ticks"],
	&"repeat_damage_permille": [1, &"repeat_damage_permille", ""],
	&"bounces": [2, &"bounces", ""],
	&"pierce": [2, &"pierce", ""],
	&"damage": [3, &"damage", ""],
	&"damage_permille": [3, &"damage_permille", ""],
	&"nth_every": [3, &"nth_every", ""],
	&"nth_damage_permille": [3, &"nth_damage_permille", ""],
	&"hitstop_seconds": [3, &"hitstop_ticks", "ticks"],
	&"arc_degrees": [5, &"half_arc", "half_turns"],
	&"reach_m": [5, &"reach_m", ""],
	&"reach_bonus_permille": [5, &"reach_bonus_permille", ""],
	&"radius_m": [5, &"radius_m", ""],
	&"speed_mps": [5, &"speed", "per_tick"],
	&"life_seconds": [5, &"life_ticks", "ticks"],
	&"period_seconds": [5, &"period_ticks", "ticks"],
	&"rate_bonus_permille": [5, &"rate_bonus_permille", ""],
	# v0.6.0 MX4 (the M-list's runner features; AttackSpec names each).
	&"mirror": [0, &"mirror", ""],
	&"directions": [1, &"directions", ""],
	&"back_damage_permille": [1, &"back_permille", ""],
	&"aim_offset_degrees": [1, &"aim_offset", "turns"],
	&"chains": [2, &"chains", ""],
	&"homing_dps": [2, &"homing", "turn_rate"],
	&"returns": [2, &"returns", ""],
	&"orbit_seconds": [2, &"orbit_ticks", "ticks"],
	&"intangible": [2, &"intangible", ""],
	&"barrier_seconds": [3, &"barrier_ticks", "ticks"],
	&"charge_seconds": [3, &"charge_ticks", "ticks"],
	&"charge_permille": [3, &"charge_permille", ""],
	&"resonance_permille": [3, &"resonance_permille", ""],
	&"heat_rate_permille": [5, &"heat_rate_permille", ""],
	&"range": [5, &"range", ""],
	# v0.6.5 WN3 (the Gun pool: GunForms)
	&"twin": [1, &"twin", ""],
	&"spiral_degrees": [2, &"spiral", "turns"],
	&"mine_seconds": [2, &"mine_ticks", "ticks"],
	&"hold_seconds": [3, &"hold_ticks", "ticks"],
	&"hold_permille": [3, &"hold_permille", ""],
	# v0.6.5 WN4 (the Blade pool; AttackSpec names each).
	&"motion": [0, &"motion", ""],
	&"echo_mirror": [1, &"echo_mirror", ""],
	&"step_m": [2, &"step_m", ""],
	&"parry": [3, &"parry", ""],
	&"counter_seconds": [3, &"counter_ticks", "ticks"],
	&"counter_permille": [3, &"counter_permille", ""],
	&"carry": [3, &"carry", ""],
	&"knockback_m": [3, &"knockback_m", ""],
	&"line_m": [5, &"line_m", ""],
	# v0.8.0 BL (BLADE_AUDIT B1: Double Slash +1 repeat a level)
	&"repeats": [1, &"repeats", ""],
	# v0.8.0 PF2 (owner O9): a bolt hook's projectiles alive at once, at most (Blade Storm's blades)
	&"alive_max": [1, &"alive_max", ""],
	# v0.8.0 P2 (owner O24, Void): a shot's chance to leave a black hole (per mille) and its pulses' damage share
	&"hole_chance_permille": [3, &"hole_permille", ""],
	&"hole_damage_permille": [3, &"hole_damage_permille", ""],
	# v0.8.0 AO (owner O37): a Ring's share of the damage when it is more than one ring or pulse, and Swirl's motion
	&"ring_share_permille": [3, &"ring_share_permille", ""],
	&"swirl": [2, &"swirl", ""],
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
## v0.6.5 WN1 (TRIGGER): the trigger on a Gun run when it differs from hook_trigger (-1: the same). T4 is On Finisher
## with the Blade and On Crit with the Gun.
@export var hook_trigger_gun := -1
## v0.6.5 WN3 (WAND.md rule 6, a duplicate levels the card up 1–5): added to `value` per level above 1, in the same
## units (a numeric op; a HOOK op: to hook_damage_permille). 0 = the op is the same at every level.
@export var per_level := 0.0
## v0.8.0 BL (BLADE_AUDIT B2): per_level counts only for the levels above this one (1: from level 2, as before; 2: from
## level 3 on, so a drawback stays whole at levels 1 and 2 and shrinks from 3).
@export var per_level_after := 1
## v0.6.5 WN5b (TRIGGER; WAND.md's legendary "On Hit ×2": the cast repeats twice): how many times the cut's child spell
## is cast each time the trigger fires (1..3), each cast hook_delay_seconds after the one before.
@export var hook_casts := 1


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
		Op.HOOK, Op.TRIGGER:
			return 4
	return int(FIELD_STAGE[field][0]) if FIELD_STAGE.has(field) else -1


func is_numeric() -> bool:
	return op in [Op.SET, Op.ADD, Op.MAX, Op.MIN, Op.MUL_PERMILLE]
