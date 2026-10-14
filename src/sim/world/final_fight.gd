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

## v0.8.0 FB3 (owner F6, F7; BossNemesis, NemesisBuild): the mimic body's state. As it rises (NemesisBuild.prepare)
## the fight reads the player's build once: the run's weapon (`weapon`, a BossAttackTable.WEAPON_*), the Nemesis's hit
## and its cap (`hit`, `hit_cap`), the player's combo arcs (`combo_half`, `combo_reach`: a Blade run's steps as its
## wand made them), its ranged form (`shot`) and the hostile copies of the strongest cards (`casts`); `ready` once read.
## While it fights, the fight records the player's path (a ring of the last ECHO_MAX ticks' positions, `echo_x` and
## `echo_y`, `echo_head` its next slot, `echo_n` how many are held) and their dashes (`dash_due`: the tick the Nemesis
## answers the last one, -1 none; `dash_dir` its way); the Nemesis's own dash (`dash_t` ticks left, `dash_vel` m per
## tick) and its stance (`stance`, BossTable.STANCE_*, for `stance_t` more ticks). An FB2 save lacks them
## (WorldSnapshot.ADDED_SINCE_V05): a fresh mimic state, read again at the Nemesis's next tick (its HP stays as saved).

## v0.8.0 FB2: the meter's ring holds this many seconds (a body reads its last dps_seconds of them).
const DPS_SECONDS := BossSchemas.DPS_MAX_SECONDS
## v0.8.0 FB3: the echo's ring holds this many ticks (BossTable.echo_ticks is at most this).
const ECHO_MAX := 120

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
## v0.8.0 FB3: the mimic body (class doc).
var ready := false
var weapon := BossAttackTable.WEAPON_BLADE
var hit := 0
var hit_cap := 0
var combo_half := PackedInt32Array()
var combo_reach := PackedFloat32Array()
var shot: NemesisCast = null
var casts: Array[NemesisCast] = []
var echo_x := PackedFloat32Array()
var echo_y := PackedFloat32Array()
var echo_head := 0
var echo_n := 0
var dash_due := -1
var dash_dir := Vector2.ZERO
var dash_t := 0
var dash_vel := Vector2.ZERO
var stance := 0
var stance_t := 0


func _init() -> void:
	dps_secs.resize(DPS_SECONDS)
	echo_x.resize(ECHO_MAX)
	echo_y.resize(ECHO_MAX)


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


## v0.8.0 FB3: records the player at `at` this tick in the echo ring.
func note_echo(at: Vector2) -> void:
	if echo_x.size() != ECHO_MAX:
		echo_x.resize(ECHO_MAX)
		echo_y.resize(ECHO_MAX)
	echo_x[echo_head] = at.x
	echo_y[echo_head] = at.y
	echo_head = (echo_head + 1) % ECHO_MAX
	echo_n = mini(echo_n + 1, ECHO_MAX)


## v0.8.0 FB3: where the player stood `ago` ticks before the last one recorded (the oldest held when the ring holds
## fewer; `fallback` when it holds none).
func echo_at(ago: int, fallback: Vector2) -> Vector2:
	if echo_n <= 0 or echo_x.size() != ECHO_MAX:
		return fallback
	var k := clampi(ago, 0, echo_n - 1)
	var j := (echo_head - 1 - k + ECHO_MAX * 2) % ECHO_MAX
	return Vector2(echo_x[j], echo_y[j])


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
	if not ready and echo_n == 0:
		return  # v0.8.0 FB3: no mimic body has fought yet (an earlier fight hashes as before)
	for v in [weapon, hit, hit_cap, echo_head, echo_n, dash_due, dash_t, stance, stance_t]:
		h.add_int(v)
	h.add_int(1 if ready else 0)
	h.add_ints(combo_half)
	h.add_f32s(combo_reach)
	h.add_f32s(echo_x)
	h.add_f32s(echo_y)
	for v in [dash_dir.x, dash_dir.y, dash_vel.x, dash_vel.y]:
		h.add_f32(v)
	h.add_int(0 if shot == null else 1)
	if shot != null:
		shot.hash_into(h)
	h.add_int(casts.size())
	for c in casts:
		c.hash_into(h)
