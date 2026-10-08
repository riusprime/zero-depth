class_name ModifierOp
extends RefCounted
## v0.6.0 MX1: one compiled ModifierOpDefinition in sim units (its field named as AttackSpec names it). Loadout.

## ModifierOpDefinition.Op, same numbers.
enum Op { SET, ADD, MAX, MIN, MUL_PERMILLE, SET_FORM, STATUS, ELEMENT, HOOK }

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
