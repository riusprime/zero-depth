class_name StarboundTable
extends RefCounted
## v0.10.5 W3-P10b (owner W7): one Starbound card's compiled numbers (ContentCompiler.compile_starbound from
## StarboundDefinition), per stack: `amount` (Arc Jump: jumps; the others per mille), `cap` (Rising Edge, Fervour: per
## mille; Echo Cast: the most repeats; 0 none), `reach_m` and `share_permille` (Arc Jump: of the hit before; Detonation:
## on bosses and elites). Read-only in play (loadout).

var id := &""
## Its index (Starbound.ARC_JUMP ..), StarboundDefinition.CARDS order.
var card := 0
var name_key := &""
var desc_key := &""
var weight := 0
var amount := 0
var cap := 0
var reach_m := 0.0
var share_permille := 0
