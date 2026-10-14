class_name FinalFight
extends RefCounted
## v0.8.0 FB1 (owner O16-O17; FINAL_BOSS.md F3): the final boss's fight state, one per World that holds it (the final
## arena, or the Playground when the owner summons it; World.final_fight, null everywhere else). One fight, three
## bodies: `tables` are the bodies' boss tables in order (the Colossus, the Prism, the Nemesis), `phase` the body
## fighting now (its actor id `body_id`), `shatter_t` the ticks left of the shatter between two bodies (0 = none) out of
## `shatter_ticks`, `phase_tick` the tick the current body began (its rise), and `won` once the last body fell (on
## `won_tick`). FinalBoss runs it. Hashed and saved (WorldSnapshot: a state class; ADDED_SINCE_V05 lists the World
## field, so a save made before FB1, which has no final fight, loads as before).
## v0.8.0 FB2 (owner F7, "Phase-by-phase mix"): the fight's centre `home` (where the first body rose; the Prism floats
## back to it) and the damage meter (FinalBoss.note_damage / measure): the damage the player dealt in each of the
## last DPS_SECONDS closed seconds of the fight's measured time (a ring, `dps_head` its next slot, `dps_closed`
## seconds closed so far), the damage of the second running (`dps_acc`) and its ticks counted (`dps_t`). An FB1 save
## lacks them (WorldSnapshot.ADDED_SINCE_V05): the base's fresh values (the arena's centre, an empty meter).

## v0.8.0 FB2: the meter's ring holds this many seconds (a body reads its last dps_seconds of them).
const DPS_SECONDS := BossSchemas.DPS_MAX_SECONDS

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
## v0.8.0 FB2: the fight's centre, and the damage meter (one-second buckets, a ring of DPS_SECONDS).
var home := Vector2.ZERO
var dps_secs := PackedInt32Array()
var dps_head := 0
var dps_closed := 0
var dps_acc := 0
var dps_t := 0


func _init() -> void:
	dps_secs.resize(DPS_SECONDS)


static func create(p_tables: PackedInt32Array, p_shatter_ticks: int) -> FinalFight:
	var f := FinalFight.new()
	f.tables = p_tables.duplicate()
	f.shatter_ticks = maxi(1, p_shatter_ticks)
	return f


## v0.8.0 FB2: closes the second running into the ring.
func close_second() -> void:
	if dps_secs.size() != DPS_SECONDS:
		dps_secs.resize(DPS_SECONDS)
	dps_secs[dps_head] = dps_acc
	dps_head = (dps_head + 1) % DPS_SECONDS
	dps_closed = mini(dps_closed + 1, DPS_SECONDS)
	dps_acc = 0
	dps_t = 0


## v0.8.0 FB2: [the damage of the last `n` closed seconds (at most what closed), how many seconds that is].
func measured(n: int) -> Array[int]:
	var k := mini(clampi(n, 0, DPS_SECONDS), dps_closed)
	var sum := 0
	for j in k:
		sum += dps_secs[(dps_head - 1 - j + DPS_SECONDS) % DPS_SECONDS]
	return [sum, k]


## The body fighting now is the last one.
func last_phase() -> bool:
	return phase >= tables.size() - 1


func hash_into(h: StateHasher) -> void:
	h.add_ints(tables)
	for v in [shatter_ticks, phase, body_id, shatter_t, phase_tick, 1 if won else 0, won_tick]:
		h.add_int(v)
	h.add_f32(home.x)  # v0.8.0 FB2
	h.add_f32(home.y)
	h.add_ints(dps_secs)
	for v in [dps_head, dps_closed, dps_acc, dps_t]:
		h.add_int(v)
