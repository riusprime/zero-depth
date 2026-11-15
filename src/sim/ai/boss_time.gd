class_name BossTime
extends RefCounted
## The Clockwork Judge fights with time (BossTable.time, a BossTimeTable; BossFightStore.time_*). This class runs the
## Time Wave, its hour orbs and the slow fields, and ticks the stopped gears (BossGears) and the Rewind
## (BossRewind).
## - The Time Wave: a `time_wave` attack on its own cadence (wave_due: the first wave_first_ticks after the Judge may
##   first attack, then every wave_every_ticks from one cast's start to the next; never by the weighted pick, and
##   only between two attacks, so never during the echo). Its windup is the cast; the tick it ends the hero's weapon
##   loses wave_cut per mille (BossSlow.apply). It cannot be dodged or dashed through and deals no damage. A cast a
##   phase gate cut short is cast again after the gate.
## - The hour orbs: with the wave the last wave's orbs go and orb_count new ones are placed (BossPickups), each
##   giving part of the cut back. Each spot is drawn from the ai stream inside the boss room, the first that is
##   orb_gap_m from the hero and from this wave's other orbs, clear of walls and of the Judge's body; when no spot
##   is that far apart the gap is halved, twice at most. Until orb_late_phase an orb stays until taken or the next
##   wave; from it on it runs out (the late table's life). The objective markers point at them (ObjectiveMarkers
##   JUDGE_ORB).
## - The stopped gears: from gear_phase the wave also raises walls across the lines to the orbs (BossGears).
## - The slow fields: from field_phase one is laid every field_every_ticks half-way between the hero and the Judge
##   (BossShotFields). While a hero's shot crawls inside one toward the Judge and the Judge is between two attacks,
##   it steps sideways out of the shot's line at `dodge` (never into a wall, never out of its room).
## - Everything ends with the Judge (on_boss_gone); the gears, a pending toll and a Bell's Verdict also end when the
##   hero is dead or has left the sealed arena (the cut, the orbs and the fields end themselves then:
##   BossSlow.fight_over).
## Pure: the ai stream only (the orbs' spots).

const M := BossAttackTable.Move
## STATUS_APPLY effects for the views and the tests (source the Judge). CAST: the Time Wave's cast begins (amount =
## its ticks). WAVE: it lands (target the hero, amount = the cut, per mille). FIELD: a slow field is laid (pos = its
## centre, amount = its id).
const CAST := &"time_wave_cast"
const WAVE := &"time_wave"
const FIELD := &"time_field"
## Spots drawn per orb at each gap before the gap is halved.
const TRIES := 32
## An orb's edge keeps this far from the room's walls.
const EDGE_M := 1.0
## Round the Judge when the fight has no room (a test world): this far each way.
const NO_ROOM_HALF_M := 12.0
## The Judge steps out of a crawling shot's line until its edge is this far from the shot's.
const DODGE_CLEAR_M := 0.3


## Tick phase 3 (BossJudge.record), every live boss: a boss with time mechanics takes its clocks (the first one to
## think owns them), starts its fields' clock in their phase and keeps its trails (BossRewind).
static func think(w: World, i: int, t: BossTable) -> void:
	var tt := t.time
	if tt == null:
		return
	var bs := w.bosses
	var fs := w.boss_fight
	var id := w.actors.ids[i]
	if fs.time_boss != id:
		if fs.time_boss >= 0 and w.actors.index_of(fs.time_boss) >= 0:
			return  # One at a time: another Judge runs them
		fs.clear_time()
		fs.time_boss = id
	var phase := bs.phase[BossAi.entry_of(w, i)]
	if phase >= tt.field_phase and fs.time_field_due < 0:
		fs.time_field_due = w.tick + tt.field_every_ticks
	BossRewind.think(w, i, tt, phase)


## The phase's Time Wave: its first `time_wave` attack (an index into the table's attacks), or -1.
static func wave_attack(t: BossTable, phase: int) -> int:
	if phase < 0 or phase >= t.phase_attacks.size():
		return -1
	for k in t.phase_attacks[phase]:
		if t.attacks[k].move == M.TIME_WAVE:
			return k
	return -1


## Tick phase 3 (BossTide.due, boss i between two attacks and no signature due): the Time Wave's index when its
## cadence says it is due and the cooldown `cd` is over, BossTide.HOLD when due but the cooldown still runs, else
## -1. The first call starts the clock.
static func wave_due(w: World, i: int, b: int, t: BossTable, cd: int) -> int:
	var bs := w.bosses
	var fs := w.boss_fight
	var tt := t.time
	if tt == null or fs.time_boss != w.actors.ids[i] or w.player_dead():
		return -1
	if fs.time_wave_due < 0:
		fs.time_wave_due = w.tick + tt.wave_first_ticks
	if w.tick < fs.time_wave_due or BossSlow.fight_over(w):
		return -1
	var k := wave_attack(t, bs.phase[b])
	return BossTide.HOLD if k >= 0 and cd > 0 else k


## BossJudge.on_start: a Time Wave's cast begins.
static func on_cast(w: World, i: int, atk: BossAttackTable) -> void:
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, w.actors.pos(i))
	e.effect_id = CAST
	e.amount = atk.windup_ticks


## Tick phase 6 (BossJudge.resolve), the tick the cast ends: the wave lands (the class comment's rule).
static func resolve_wave(w: World, i: int, b: int, atk: BossAttackTable) -> void:
	var bs := w.bosses
	var fs := w.boss_fight
	var tt := BossAi.table_of(w, i).time
	if tt == null:
		return
	var id := w.actors.ids[i]
	fs.time_wave_due = w.tick - atk.windup_ticks + tt.wave_every_ticks
	BossSlow.apply(w, id, tt.wave_cut)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, w.actors.ids[0], w.actors.pos(i))
	e.effect_id = WAVE
	e.amount = tt.wave_cut
	BossPickups.on_boss_gone(w, id)  # The last wave's orbs go
	BossGears.drop(w, id)  # And its gears
	var phase := bs.phase[b]
	var orbs := place_orbs(w, i, tt, phase)
	if phase >= tt.gear_phase:
		BossGears.raise(w, i, tt, orbs)
	point_at_orbs(w)


## Places the wave's orbs for boss i in `phase` (the class comment's rule). Returns where they lie.
static func place_orbs(w: World, i: int, tt: BossTimeTable, phase: int) -> PackedVector2Array:
	var table := tt.orb_late if phase >= tt.orb_late_phase else tt.orb
	var out := PackedVector2Array()
	var area := room_of(w, i).grow(-(table.radius_m + EDGE_M))
	if not area.has_area():
		return out
	for n in tt.orb_count:
		var gap := tt.orb_gap_m
		for halved in 3:
			var p := _orb_spot(w, i, table, area, gap, out)
			if p.is_finite():
				BossPickups.place(w, w.actors.ids[i], table, p)
				out.append(p)
				break
			gap *= 0.5
	return out


## A spot for one orb inside `area`, `gap` from the hero and from `placed`, or Vector2.INF when TRIES draws find
## none.
static func _orb_spot(
	w: World, i: int, table: BossPickupTable, area: Rect2, gap: float, placed: PackedVector2Array
) -> Vector2:
	var sx := int(area.size.x * 100.0)
	var sy := int(area.size.y * 100.0)
	var body := w.actors.radius[i] + table.radius_m + w.player.radius_m * 2.0
	for k in TRIES:
		var p := (
			area.position + Vector2(w.rng_ai.range_int(0, sx), w.rng_ai.range_int(0, sy)) * 0.01
		)
		if Kin.length(p - w.player_pos()) < gap or Kin.length(p - w.actors.pos(i)) < body:
			continue
		var apart := true
		for q: Vector2 in placed:
			apart = apart and Kin.length(p - q) >= gap
		if apart and EnemyAi.clear_of_walls(w, p, table.radius_m):
			return p
	return Vector2.INF


## The floor the orbs lie on: the boss room's interior, or a square round the boss without one.
static func room_of(w: World, i: int) -> Rect2:
	var room := w.bosses.arena
	if room.has_area():
		return room
	var h := Vector2(NO_ROOM_HALF_M, NO_ROOM_HALF_M)
	return Rect2(w.actors.pos(i) - h, h * 2.0)


## The objective markers point at the Judge's orbs lying now, and at nothing else for that reason.
static func point_at_orbs(w: World) -> void:
	var bs := w.bosses
	var fs := w.boss_fight
	w.objectives.clear(ObjectiveMarkers.JUDGE_ORB)
	for k in bs.pk_x.size():
		if bs.pk_boss[k] == fs.time_boss:
			w.objectives.point(ObjectiveMarkers.JUDGE_ORB, Vector2(bs.pk_x[k], bs.pk_y[k]))


## Tick phase 6 (BossSignatures.advance, after the pickups and the fields): the gears whose time is up go; with the
## hero dead or outside the arena every gear and a pending toll go; else the Bell tolls, a field is laid when due
## and the Judge steps out of a crawling shot's line. The markers follow the orbs taken or gone.
static func advance(w: World) -> void:
	var bs := w.bosses
	var fs := w.boss_fight
	if fs.time_boss < 0:
		return
	var i := w.actors.index_of(fs.time_boss)
	if i < 0 or w.actors.dead[i] == 1:
		return  # on_boss_gone clears it the tick the body is removed
	if BossSlow.fight_over(w):
		BossGears.drop(w, BossGears.ALL)
		BossRewind.cancel(w)
	else:
		BossGears.drop(w)
		var t := BossAi.table_of(w, i)
		BossRewind.advance(w, i, t)
		_lay_field(w, i, t.time)
		_sidestep(w, i, t)
	if (
		w.objectives.reasons.count(String(ObjectiveMarkers.JUDGE_ORB))
		!= bs.pk_boss.count(fs.time_boss)
	):
		point_at_orbs(w)


## A slow field half-way between the hero and boss i when its clock says so (not during a phase gate).
static func _lay_field(w: World, i: int, tt: BossTimeTable) -> void:
	var bs := w.boss_fight
	if tt.field == null or bs.time_field_due < 0 or w.tick < bs.time_field_due:
		return
	bs.time_field_due = w.tick + tt.field_every_ticks
	if w.actors.state[i] == BossAi.GATE:
		return
	var id := w.actors.ids[i]
	var c := (w.player_pos() + w.actors.pos(i)) * 0.5
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, c)
	e.effect_id = FIELD
	e.amount = BossShotFields.place(w, id, tt.field, c)


## Boss i, between two attacks, steps sideways out of the line of the first hero's shot that crawls inside a slow
## field toward it: away from the line, at the table's dodge speed, only onto floor clear of walls inside its room.
static func _sidestep(w: World, i: int, t: BossTable) -> void:
	var a := w.actors
	if t.time.dodge <= 0.0 or a.state[i] != EnemyAi.State.MOVE or w.bosses.sf_x.is_empty():
		return
	var ps := w.projectiles
	var at := a.pos(i)
	for k in ps.size():
		if ps.team[k] != ActorStore.TEAM_PLAYER:
			continue
		var p := Vector2(ps.pos_x[k], ps.pos_y[k])
		var v := Vector2(ps.vel_x[k], ps.vel_y[k])
		var speed := Kin.length(v)
		if speed <= 0.0 or BossShotFields.speed_at(w, p) >= 1000:
			continue
		var dir := v / speed
		var rel := at - p
		var side := dir.x * rel.y - dir.y * rel.x  # How far the Judge's centre is to the left of the shot's line
		if rel.dot(dir) <= 0.0 or absf(side) >= a.radius[i] + ps.radius[k] + DODGE_CLEAR_M:
			continue
		var away := Vector2(-dir.y, dir.x) * (1.0 if side >= 0.0 else -1.0)
		var to := at + away * (t.time.dodge * ItemProcs.slow_factor(w, i))
		if room_of(w, i).has_point(to) and EnemyAi.clear_of_walls(w, to, a.radius[i]):
			a.set_pos(i, to)
		return


## BossSignatures.on_boss_gone: boss `boss_id` is gone: its gears go; the Judge that ran the clocks takes them, the
## trails and the markers with it (its cut, orbs and fields go through BossSlow, BossPickups and BossShotFields).
static func on_boss_gone(w: World, boss_id: int) -> void:
	BossGears.drop(w, boss_id)
	if w.boss_fight.time_boss != boss_id:
		return
	w.boss_fight.clear_time()
	w.objectives.clear(ObjectiveMarkers.JUDGE_ORB)


## The view's read (WorldReader.boss_time): {} with no Judge running them; else "boss" (its actor index), "cut" (the
## attack speed taken now, per mille), "wave" (0..1000 through the Time Wave's cast, -1 when none is cast),
## "wave_in" (ticks until the next cast may begin; 0 = due, -1 = its clock has not started), "gears"
## (BossGears.rows), "returned" (true once the Judge went back to its own past), and the Rewind's keys
## (BossRewind.state). The orbs and the fields: WorldReader.boss_pickups, boss_shot_fields.
static func state(w: World) -> Dictionary:
	var bs := w.boss_fight
	var i := w.actors.index_of(bs.time_boss) if bs.time_boss >= 0 else -1
	if i < 0:
		return {}
	var out := BossRewind.state(w, i)
	var atk := BossAi.attack_of(w, i)
	var casting := (
		atk != null and atk.move == M.TIME_WAVE and w.actors.state[i] == EnemyAi.State.WINDUP
	)
	out["boss"] = i
	out["cut"] = BossSlow.cut(w)
	out["wave"] = (
		clampi(w.actors.state_t[i] * 1000 / maxi(1, atk.windup_ticks), 0, 1000) if casting else -1
	)
	out["wave_in"] = maxi(0, bs.time_wave_due - w.tick) if bs.time_wave_due >= 0 else -1
	out["gears"] = BossGears.rows(w)
	out["returned"] = bs.time_back == 1
	return out
