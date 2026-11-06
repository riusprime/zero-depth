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

## v0.8.0 N2 (owner O41: "each phase takes 1-2 minutes 1 minute being the most op and longer if you are not op";
## O42, O52: The Fallen "should mimic and nerf you … only at certain times … on and off"; FinalPace): the pace of the
## body fighting now: `paced` once its HP was set from the meter (at `pace_dps`, the measured damage per second × 1000
## it was set from), `pace_budget` the damage it may still take now (× 1000: its rate cap's bucket), and `copying`
## while The Fallen's attack in progress began in a mimic window (it swings and casts the player's build). An older
## save lacks them (WorldSnapshot.ADDED_SINCE_V05): a fresh pace (unpaced, an empty bucket), set again from the meter.

## v0.9.5 BH6 (owner, 2026-10-25; BOSSES_HARD.md HC4-HC6; BossInterphase): The Fallen's interphases and dashes.
## `ip_done` has bit k once interphase k began; `ip_stage` is 0 (none), 1 (a threshold reached: it finishes its move),
## 2 (vanished: the set `ip_set` runs, `ip_t` ticks in) or 3 (the return telegraph); `ip_prev` the set of the last
## interphase (a set is never drawn twice in a row), `ip_total` every tick spent in stages 2 and 3 (the pace's clock
## leaves them out). `ip_a`, `ip_b` the next tick (of the stage) of the set's two repeating hazards, `ip_n` the draws
## made, `ip_dir` and `ip_angle0` the beams' turn and first angle, `ip_r` the arena's radius, `ip_grace` the tick before
## which no interphase hit lands. Eruptions (`er_*`: place, strike tick), spike lines (`sl_*`: first place, way, tick it
## starts to move, length, its middle's offset across, hit) and lanterns (`lamp_t`: burn ticks left) are the set's.
## `rd_*` the dash between moves: `rd_pending` (one is due when the next move would begin), `rd_t` ticks of its
## telegraph left, `rd_to` where it goes. An older save lacks them (WorldSnapshot.ADDED_SINCE_V05): none begun, none
## pending.

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
## v0.8.0 N2: the body's pace and The Fallen's window copy (class doc).
var paced := false
var pace_dps := 0
var pace_budget := 0
var copying := false
## v0.9.5 BH6: the interphases and the dash between moves (class doc).
var ip_done := 0
var ip_stage := 0
var ip_t := 0
var ip_set := -1
var ip_prev := -1
var ip_total := 0
var ip_a := 0
var ip_b := 0
var ip_n := 0
var ip_dir := 1
var ip_angle0 := 0
var ip_grace := 0
var ip_r := 0.0
var er_x := PackedFloat32Array()
var er_y := PackedFloat32Array()
var er_t := PackedInt32Array()
var sl_x := PackedFloat32Array()
var sl_y := PackedFloat32Array()
var sl_a := PackedInt32Array()
var sl_t := PackedInt32Array()
var sl_len := PackedFloat32Array()
var sl_off := PackedFloat32Array()
var sl_hit := PackedInt32Array()
var lamp_t := PackedInt32Array()
var rd_pending := 0
var rd_t := 0
var rd_to := Vector2.ZERO


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
	for v in [1 if paced else 0, pace_dps, pace_budget, 1 if copying else 0]:  # v0.8.0 N2
		h.add_int(v)
	if ip_done != 0 or ip_stage != 0 or ip_prev >= 0 or rd_pending != 0 or rd_t != 0:
		_hash_interphase(h)  # v0.9.5 BH6: only once an interphase or a dash has begun (an earlier fight hashes as before)
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


func _hash_interphase(h: StateHasher) -> void:
	for v in [
		ip_done,
		ip_stage,
		ip_t,
		ip_set,
		ip_prev,
		ip_total,
		ip_a,
		ip_b,
		ip_n,
		ip_dir,
		ip_angle0,
		ip_grace
	]:
		h.add_int(v)
	h.add_f32s(er_x)
	h.add_f32s(er_y)
	h.add_ints(er_t)
	h.add_f32s(sl_x)
	h.add_f32s(sl_y)
	h.add_ints(sl_a)
	h.add_ints(sl_t)
	h.add_f32s(sl_len)
	h.add_f32s(sl_off)
	h.add_ints(sl_hit)
	h.add_ints(lamp_t)
	h.add_f32(ip_r)
	for v in [rd_pending, rd_t]:
		h.add_int(v)
	h.add_f32(rd_to.x)
	h.add_f32(rd_to.y)
