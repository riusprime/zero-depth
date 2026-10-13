class_name ModifierOp
extends RefCounted
## v0.6.0 MX1: one compiled ModifierOpDefinition in sim units (its field named as AttackSpec names it). Loadout.

## ModifierOpDefinition.Op, same numbers. v0.6.5 WN1: TRIGGER, a wand trigger card's cut (Modifiers).
enum Op { SET, ADD, MAX, MIN, MUL_PERMILLE, SET_FORM, STATUS, ELEMENT, HOOK, TRIGGER }

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
## v0.6.0 MX4 (HOOK): the child launches this many ticks after its trigger (0 = at once), only when `when` holds
## (ModifierOpDefinition.When: 0 always, 1 at Overclock), shaped by `child_ops` before the build compiles it.
var delay_ticks := 0
var when := 0
var child_ops: Array[ModifierOp] = []
## v0.6.5 WN1 (TRIGGER): `trigger` is the cut's trigger (ModifierOpDefinition.Trigger: ON_HIT, ON_KILL, ON_END,
## ON_FINISHER, ON_CRIT); on a Gun run `trigger_gun` instead when it is not -1.
var trigger_gun := -1
## v0.6.5 WN3 (WAND.md rule 6): added to `value` (a HOOK op: to damage_permille) per level above 1 (ModifierTable.at).
var per_level := 0.0
## v0.6.5 WN5b (TRIGGER): the child spell is cast this many times per trigger, each delay_ticks after the one before.
var casts := 1


## v0.6.5 WN3: a copy at card level `level` (1..5): its value, a hook's damage share and its child ops' values each
## grown by their per_level × (level − 1). Compile-time only (Modifiers.build_modifiers).
func at_level(level: int) -> ModifierOp:
	var o := ModifierOp.new()
	for f: StringName in [
		&"op", &"stage", &"field", &"value", &"form", &"status", &"stacks", &"every", &"element"
	]:
		o.set(f, get(f))
	for f: StringName in [
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
		&"casts",
	]:
		o.set(f, get(f))
	o.hook_tags = hook_tags.duplicate()
	var n := level - 1
	if op == Op.HOOK:
		o.damage_permille = damage_permille + roundi(per_level * n)
	elif field in AttackSpec.INT_FIELDS:
		o.value = value + roundi(per_level * n)
	else:
		o.value = value + per_level * n
	for c in child_ops:
		o.child_ops.append(c.at_level(level))
	return o


## v0.6.5 WN3: true if this op or a child op grows with the level.
func levels() -> bool:
	if per_level != 0.0:
		return true
	for c in child_ops:
		if c.levels():
			return true
	return false
