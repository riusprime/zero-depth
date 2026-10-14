class_name FinalFight
extends RefCounted
## v0.8.0 FB1 (owner O16-O17; FINAL_BOSS.md F3): the final boss's fight state, one per World that holds it (the final
## arena, or the Playground when the owner summons it; World.final_fight, null everywhere else). One fight, three
## bodies: `tables` are the bodies' boss tables in order (the Colossus, the Prism, the Nemesis), `phase` the body
## fighting now (its actor id `body_id`), `shatter_t` the ticks left of the shatter between two bodies (0 = none) out of
## `shatter_ticks`, `phase_tick` the tick the current body began (its rise), and `won` once the last body fell (on
## `won_tick`). FinalBoss runs it. Hashed and saved (WorldSnapshot: a state class; ADDED_SINCE_V05 lists the World
## field, so a save made before FB1, which has no final fight, loads as before).

var tables := PackedInt32Array()
var shatter_ticks := 90
var phase := 0
var body_id := -1
var shatter_t := 0
var phase_tick := 0
var won := false
var won_tick := -1
## The fight's name (RunTable.final_name_key; setup, not hashed: the boss bar's title).
var name_key := &""


static func create(p_tables: PackedInt32Array, p_shatter_ticks: int) -> FinalFight:
	var f := FinalFight.new()
	f.tables = p_tables.duplicate()
	f.shatter_ticks = maxi(1, p_shatter_ticks)
	return f


## The body fighting now is the last one.
func last_phase() -> bool:
	return phase >= tables.size() - 1


func hash_into(h: StateHasher) -> void:
	h.add_ints(tables)
	for v in [shatter_ticks, phase, body_id, shatter_t, phase_tick, 1 if won else 0, won_tick]:
		h.add_int(v)
