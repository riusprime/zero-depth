class_name ModifierOp
extends RefCounted
## One compiled ModifierOpDefinition in sim units (its field named as AttackSpec names it). Loadout.

## ModifierOpDefinition.Op, same numbers. TRIGGER, a wand trigger card's cut (Modifiers).
## REMNANT, a hook that leaves a remnant (`remnant`; Remnants), its child cast when it activates.
enum Op { SET, ADD, MAX, MIN, MUL_PERMILLE, SET_FORM, STATUS, ELEMENT, HOOK, TRIGGER, REMNANT }

## Every field at_level and overlevelled copy as they are (all but hook_tags, child_ops and remnant).
const COPIED: Array[StringName] = [
	&"op",
	&"stage",
	&"field",
	&"value",
	&"form",
	&"status",
	&"stacks",
	&"every",
	&"element",
	&"trigger",
	&"radius_m",
	&"reach_m",
	&"damage",
	&"damage_permille",
	&"hook_every",
	&"effect_id",
	&"delay_ticks",
	&"when",
	&"trigger_gun",
	&"per_level",
	&"per_level_after",
	&"casts",
	&"alt",  # v0.8.0 MR
	&"level_values",  # v0.9.5 CLV
]
## The share fields an overlevel grows on a MUL_PERMILLE op (a share of the hit, in per mille).
const OVERLEVEL_FIELDS: Array[StringName] = [&"share_permille"]

var op: int = Op.ADD
## The stage it runs in (ModifierTable.Stage).
var stage := 0
## Numeric ops: an AttackSpec field (INT_FIELDS or FLOAT_FIELDS), and the value in that field's units (an int
## field's value is whole: the compiler rounds it once).
var field := &""
var value := 0.0
## SET_FORM and HOOK: AttackSpec.Form.
var form := 0
## STATUS.
var status := &""
var stacks := 0
var every := 0
## ELEMENT.
var element := &""
## HOOK (see AttackHook): trigger, the child's tags, radius (a burst) or reach (a beam's jump), damage, every, effect.
var trigger := 0
var hook_tags := PackedStringArray()
var radius_m := 0.0
var reach_m := 0.0
var damage := 0
var damage_permille := 0
var hook_every := 0
var effect_id := &""
## HOOK: the child launches this many ticks after its trigger (0 = at once), only when `when` holds
## (ModifierOpDefinition.When: 0 always, 1 at Overclock), shaped by `child_ops` before the build compiles it.
var delay_ticks := 0
var when := 0
var child_ops: Array[ModifierOp] = []
## TRIGGER: `trigger` is the cut's trigger (ModifierOpDefinition.Trigger: ON_HIT, ON_KILL, ON_END,
## ON_FINISHER, ON_CRIT); on a Gun run `trigger_gun` instead when it is not -1.
var trigger_gun := -1
## WAND.md rule 6: added to `value` (a HOOK op: to damage_permille) per level above 1 (ModifierTable.at).
var per_level := 0.0
## BLADE_AUDIT B2: a drawback that shrinks from level 3: per_level counts only for the levels above this
## one (1: every level above 1, as before; 2: from level 3 on).
var per_level_after := 1
## The value at level 1, 2, 3... in sim units (a step that isn't linear: Twin's copies and share); empty =
## `value` + `per_level` as before. A level past the list takes its last entry.
var level_values := PackedFloat32Array()
## TRIGGER: the child spell is cast this many times per trigger, each delay_ticks after the one before.
var casts := 1
## An op of the card's other reading: it runs only on a
## spec of the card's alt_target that carries no hook child of its target yet (ModifierTable.alt_target; WandCompile).
var alt := false
## REMNANT: the remnant it leaves (null on every other op).
var remnant: RemnantRule


## A copy at card level `level` (1..5): its value, a hook's damage share and its child ops' values each
## grown by their per_level × (level − 1) (× (level − per_level_after), never below 0). Compile-time only
## (Modifiers.build_modifiers).
func at_level(level: int) -> ModifierOp:
	var o := ModifierOp.new()
	# Every field but hook_tags and child_ops (copied below), in one list (audit G-17: COPIED).
	for f: StringName in COPIED:
		o.set(f, get(f))
	o.hook_tags = hook_tags.duplicate()
	if remnant != null:  # Its life and caps grow too
		o.remnant = remnant.at_level(level)
	var n := maxi(0, level - maxi(1, per_level_after))  # B2's late steps
	if not level_values.is_empty():  # v0.9.5 CLV
		var lv := level_values[mini(level, level_values.size()) - 1]
		o.value = roundi(lv) if AttackSpec.is_int_field(field) else lv
	elif op == Op.HOOK or op == Op.REMNANT:
		o.damage_permille = damage_permille + roundi(per_level * n)
	elif AttackSpec.is_int_field(field):
		o.value = value + roundi(per_level * n)
	else:
		o.value = value + per_level * n
	for c in child_ops:
		o.child_ops.append(c.at_level(level))
	return o


## True if this op or a child op grows with the level.
func levels() -> bool:
	if per_level != 0.0 or level_values.size() > 1 or (remnant != null and remnant.levels()):
		return true
	for c in child_ops:
		if c.levels():
			return true
	return false


## This op is a share of the hit an overlevel grows (OVERLEVEL_FIELDS on a MUL_PERMILLE op, a HOOK's or
## a REMNANT's child share).
func is_share() -> bool:
	if op == Op.HOOK or op == Op.REMNANT:
		return true
	return op == Op.MUL_PERMILLE and OVERLEVEL_FIELDS.has(field)


## Overlevels; CardLevels.overlevel_permille: a copy whose share is × `permille` / 1000 (a MUL_PERMILLE
## op its value, a HOOK's or a REMNANT's child its damage share and flat damage); null when this op is no share.
## Shares are per mille, so the step is exact. Compile-time only (ModifierTable.overlevelled).
func overlevelled(permille: int) -> ModifierOp:
	if not is_share():
		return null
	var o := ModifierOp.new()
	for f: StringName in COPIED:
		o.set(f, get(f))
	o.hook_tags = hook_tags.duplicate()
	o.remnant = remnant
	o.child_ops = child_ops.duplicate()
	if op == Op.MUL_PERMILLE:
		o.value = float(roundi(value) * permille / 1000)
	else:
		o.damage_permille = damage_permille * permille / 1000
		o.damage = damage * permille / 1000
	return o
