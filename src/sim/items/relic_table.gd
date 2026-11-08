class_name RelicTable
extends RefCounted
## v0.11.0 O14b (OWNER_QUESTIONS §J N1): one relic's compiled numbers (ContentCompiler.compile_relics from
## RelicDefinition): how many times a run it fires, the HP a saved killing blow leaves, the shock ring's radius and
## damage. Read-only in play (loadout).

var id := &""
## Its index (Relics.CITY_HEART ..), RelicDefinition.RELICS order.
var relic := 0
var name_key := &""
var desc_key := &""
var uses := 1
var saved_hp := 1
var ring_radius_m := 4.0
var ring_damage := 0
