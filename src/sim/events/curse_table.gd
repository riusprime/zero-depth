class_name CurseTable
extends RefCounted
## One curse's compiled numbers (v0.5.0 EV; EventCompiler from CurseDefinition): its effect (Curses.Effect), the
## amount in per mille (a count for EXTRA_ENEMY), the threat it adds and its draw weight.

var id := &""
var name_key := &""
var desc_key := &""
var effect := 0
var amount := 0
var threat := 1
var weight := 0
