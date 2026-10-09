class_name CurseTable
extends RefCounted
## One curse's compiled numbers (v0.5.0 EV; EventCompiler from CurseDefinition): its effect (Curses.Effect), the
## amount in per mille (a count for the count effects, ticks for hit_stun), the threat it adds and its draw weight.
## v0.6.0 CU: an optional second drawback (effect_2, -1 = none) and the upside of a trade-off curse (up_effect, -1 =
## a plain curse) with its sentence.

var id := &""
var name_key := &""
var desc_key := &""
var effect := 0
var amount := 0
var effect_2 := -1
var amount_2 := 0
var up_effect := -1
var up_amount := 0
var up_desc_key := &""
var threat := 1
var weight := 0


func is_trade_off() -> bool:
	return up_effect >= 0
