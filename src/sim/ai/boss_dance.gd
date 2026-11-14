class_name BossDance
extends RefCounted
## The Tidecaller's dance (BossTable.dance, a BossDanceTable; BossStore.dance_*): two casts of the room itself,
## beside the boss's attacks (they are not attacks: it goes on fighting), and the Maelstrom (BossMaelstrom).
## - Riptide, from rip_phase: the room is cut into four strips along its longer side (SafeArea.strips). A row is
##   rip_casts casts: each warns three strips, then a wave runs down them from the room's low end to its high end in
##   rip_wave_ticks; as its front passes a hero standing in a warned strip that hero loses rip_hit per mille of max
##   HP, once a cast (a hero that steps into a strip behind the front is not hit). The safe strips follow the written
##   order (BossDanceTable.SAFE_ORDER) or its mirror, one draw a row. The next cast's warning begins as the wave
##   ends. The first row begins rip_first_ticks into rip_phase, then one every rip_every_ticks (start to start).
##   Before the Maelstrom a row waits for the Pull to end, and the Pull waits for a row (holds_pull).
## - High Tide, from ht_phase: its cast shows one dry circle (dry_spot: at least ht_gap_m from the hero, inside the
##   room, clear of walls, its centre out of the Maelstrom's eye), which the objective markers point at
##   (ObjectiveMarkers.TIDE_DRY); then for ht_flood_ticks a hero outside it loses ht_hit per mille of max HP every
##   ht_step_ticks. A row of Riptide and a High Tide never run together: the later one waits.
## - Neither begins while the boss rises or kneels at a phase change; one running goes on. Both end with the boss
##   (on_boss_gone) and when the hero is dead or has left the room (cancel).
## Pure: the ai stream only (a row's mirror, the dry circle's spot, the Maelstrom's way).

const M := BossAttackTable.Move
const STRIPS := BossDanceTable.STRIPS
## STATUS_APPLY effects for the views and the tests (source the boss). RIP_CAST: a cast's warning begins (amount =
## its ticks, amount_applied = the safe strip, pos = that strip's centre). RIP_WAVE: its wave starts (amount = its
## ticks, amount_applied = the safe strip). RIP_HIT: the wave hit (target the hero, amount = the HP it cost).
## HT_CAST: a High Tide's cast begins (pos = the dry circle's centre, amount = the cast's ticks). HT_FLOOD: the water
## is up (amount = its ticks). HT_END: it is over.
const RIP_CAST := &"riptide_cast"
const RIP_WAVE := &"riptide_wave"
const RIP_HIT := &"riptide_hit"
const HT_CAST := &"high_tide_cast"
const HT_FLOOD := &"high_tide"
const HT_END := &"high_tide_end"
## The damage's effect ids (the HIT and DAMAGE events).
const RIP_EFFECT := &"boss_riptide"
const HT_EFFECT := &"boss_high_tide"
## Spots drawn for the dry circle at each gap before the room is scanned.
const TRIES := 32
## The dry circle's edge keeps this far from the room's walls.
const EDGE_M := 1.0
## The scan's step when no draw fits.
const SCAN_M := 1.0
## Round the boss when the fight has no room (a test world): this far each way.
const NO_ROOM_HALF_M := 12.0


## Tick phase 6 (BossSignatures.advance): the boss with a dance runs its casts and its Maelstrom.
static func advance(w: World) -> void:
	var i := _dancer(w)
	if i < 0:
		return
	if BossSlow.fight_over(w):
		cancel(w)
		return
	var d := BossAi.table_of(w, i).dance
	var phase := w.bosses.phase[BossAi.entry_of(w, i)]
	_riptide(w, i, d, phase)
	_high_tide(w, i, d, phase)
	BossMaelstrom.advance(w, i, d, phase)


## The boss that runs the dance (its actor index), or -1. The first live one with a dance takes the clocks once it
## has risen; one at a time.
static func _dancer(w: World) -> int:
	var bs := w.bosses
	var a := w.actors
	if bs.dance_boss >= 0:
		var i := a.index_of(bs.dance_boss)
		return i if i >= 0 and a.dead[i] == 0 else -1
	for b in bs.size():
		var t: BossTable = w.boss_tables[bs.table[b]]
		var i := a.index_of(bs.ids[b])
		if t.dance == null or i < 0 or a.dead[i] == 1 or a.state[i] == EnemyAi.State.SPAWN:
			continue
		bs.clear_dance()
		bs.dance_boss = bs.ids[b]
		return i
	return -1


## The floor the dance is on: the boss room's interior, or a square round the boss without one.
static func room_of(w: World, i: int) -> Rect2:
	var room := w.bosses.arena
	if room.has_area():
		return room
	var h := Vector2(NO_ROOM_HALF_M, NO_ROOM_HALF_M)
	return Rect2(w.actors.pos(i) - h, h * 2.0)


## True while boss i may begin no cast: it kneels at a phase change, or (before the Maelstrom) its Pull runs.
static func _held(w: World, i: int, d: BossDanceTable, phase: int) -> bool:
	if w.actors.state[i] == BossAi.GATE:
		return true
	return phase < d.mael_phase and not BossTide.state(w, i).is_empty()


## BossTide: true while boss i (entry b) casts no Pull: from the Maelstrom's phase on, and while a row of Riptide
## or a High Tide runs.
static func holds_pull(w: World, i: int, b: int) -> bool:
	var d := BossAi.table_of(w, i).dance
	if d == null:
		return false
	var bs := w.bosses
	if bs.phase[b] >= d.mael_phase:
		return true
	return bs.dance_boss == w.actors.ids[i] and (bs.dance_rip_from >= 0 or bs.dance_ht_from >= 0)


# --- Riptide ------------------------------------------------------------------------------------------------------


static func _riptide(w: World, i: int, d: BossDanceTable, phase: int) -> void:
	var bs := w.bosses
	if phase >= d.rip_phase and bs.dance_rip_due < 0:
		bs.dance_rip_due = w.tick + d.rip_first_ticks
	if bs.dance_rip_from < 0:
		if bs.dance_rip_due < 0 or w.tick < bs.dance_rip_due:
			return
		if bs.dance_ht_from >= 0 or _held(w, i, d, phase):
			return
		bs.dance_rip_due = w.tick + d.rip_every_ticks
		bs.dance_rip_mirror = w.rng_ai.range_int(0, 1)
		_cast(w, i, d, 0)
		return
	var s := w.tick - bs.dance_rip_from - d.warn_ticks(bs.dance_rip_n)
	if s < 0:
		return
	if s == 0:
		var e := _event(w, i, RIP_WAVE, w.actors.pos(i))
		e.amount = d.rip_wave_ticks
		e.amount_applied = d.safe_strip(bs.dance_rip_n, bs.dance_rip_mirror)
		return
	_sweep(w, i, d, s)
	if s >= d.rip_wave_ticks:
		if bs.dance_rip_n + 1 >= d.rip_casts:
			bs.dance_rip_from = -1
		else:
			_cast(w, i, d, bs.dance_rip_n + 1)


## Cast n of the row begins its warning.
static func _cast(w: World, i: int, d: BossDanceTable, n: int) -> void:
	var bs := w.bosses
	bs.dance_rip_n = n
	bs.dance_rip_from = w.tick
	bs.dance_rip_hit = 0
	var safe := d.safe_strip(n, bs.dance_rip_mirror)
	var e := _event(w, i, RIP_CAST, SafeArea.strips(room_of(w, i), STRIPS)[safe].get_center())
	e.amount = d.warn_ticks(n)
	e.amount_applied = safe


## The wave's step s (1..rip_wave_ticks): the hero in a warned strip the front passes this tick is hit, once a cast.
static func _sweep(w: World, i: int, d: BossDanceTable, s: int) -> void:
	var bs := w.bosses
	if bs.dance_rip_hit == 1 or w.player_dead():
		return
	var room := room_of(w, i)
	var p := w.player_pos()
	var along_x := SafeArea.runs_along_x(room)
	var length := room.size.x if along_x else room.size.y
	var at := (p.x - room.position.x) if along_x else (p.y - room.position.y)
	var r := w.player.radius_m
	if at < front_m(d, length, s - 1) - r or at > front_m(d, length, s) + r:
		return
	var safe: Array[Rect2] = [
		SafeArea.strips(room, STRIPS)[d.safe_strip(bs.dance_rip_n, bs.dance_rip_mirror)]
	]
	var got := SafeArea.check(
		w, i, safe, [], d.rip_hit, SafeArea.Mode.ONCE, d.rip_cause, RIP_EFFECT
	)
	if got <= 0:
		return
	bs.dance_rip_hit = 1
	var e := _event(w, i, RIP_HIT, w.player_pos())
	e.target_id = w.actors.ids[0]
	e.amount = got


## How far down a strip of `length` the wave's front is after step s, metres from the room's low end.
static func front_m(d: BossDanceTable, length: float, s: int) -> float:
	return length * clampi(s, 0, d.rip_wave_ticks) / maxi(1, d.rip_wave_ticks)


# --- High Tide ----------------------------------------------------------------------------------------------------


static func _high_tide(w: World, i: int, d: BossDanceTable, phase: int) -> void:
	var bs := w.bosses
	if phase >= d.ht_phase and bs.dance_ht_due < 0:
		bs.dance_ht_due = w.tick + d.ht_first_ticks
	if bs.dance_ht_from < 0:
		if bs.dance_ht_due < 0 or w.tick < bs.dance_ht_due:
			return
		if bs.dance_rip_from >= 0 or _held(w, i, d, phase):
			return
		bs.dance_ht_due = w.tick + d.ht_every_ticks
		var c := dry_spot(w, i, d)
		if not c.is_finite():
			return  # No dry floor to give: none this time
		bs.dance_ht_from = w.tick
		bs.dance_ht_x = c.x
		bs.dance_ht_y = c.y
		w.objectives.point(ObjectiveMarkers.TIDE_DRY, c)
		_event(w, i, HT_CAST, c).amount = d.ht_cast_ticks
		return
	var s := w.tick - bs.dance_ht_from - d.ht_cast_ticks
	if s < 0:
		return
	if s == 0:
		_event(w, i, HT_FLOOD, dry_centre(w)).amount = d.ht_flood_ticks
		return
	if s % d.ht_step_ticks == 0:
		var dry: Array[Vector3] = [Vector3(bs.dance_ht_x, bs.dance_ht_y, d.ht_radius_m)]
		SafeArea.check(w, i, [], dry, d.ht_hit, SafeArea.Mode.STEP, d.tide_cause, HT_EFFECT)
	if s >= d.ht_flood_ticks:
		_end_tide(w, i)


## The dry circle's centre (of the High Tide running).
static func dry_centre(w: World) -> Vector2:
	return Vector2(w.bosses.dance_ht_x, w.bosses.dance_ht_y)


static func _end_tide(w: World, i: int) -> void:
	_event(w, i, HT_END, dry_centre(w))
	w.bosses.dance_ht_from = -1
	w.objectives.clear(ObjectiveMarkers.TIDE_DRY)


## A spot for the dry circle: the first of TRIES draws that fits (fits()); with none, the fitting spot farthest from
## the hero on a SCAN_M grid over the room; with none, the gap is halved, twice at most. Vector2.INF when the room
## has no such floor.
static func dry_spot(w: World, i: int, d: BossDanceTable) -> Vector2:
	var area := room_of(w, i).grow(-(d.ht_radius_m + EDGE_M))
	if not area.has_area():
		return Vector2.INF
	var sx := int(area.size.x * 100.0)
	var sy := int(area.size.y * 100.0)
	var gap := d.ht_gap_m
	for halved in 3:
		for k in TRIES:
			var p := (
				area.position + Vector2(w.rng_ai.range_int(0, sx), w.rng_ai.range_int(0, sy)) * 0.01
			)
			if fits(w, i, d, p, gap):
				return p
		var best := Vector2.INF
		var best_d := -1.0
		for gy in int(area.size.y / SCAN_M) + 1:
			for gx in int(area.size.x / SCAN_M) + 1:
				var p := area.position + Vector2(gx, gy) * SCAN_M
				var far := Kin.length(p - w.player_pos())
				if far > best_d and fits(w, i, d, p, gap):
					best = p
					best_d = far
		if best.is_finite():
			return best
		gap *= 0.5
	return Vector2.INF


## True when a dry circle at p is `gap` from the hero, clear of walls, and its centre is half its radius outside the
## Maelstrom's eye round boss i (so the hero can stand in it without being eaten).
static func fits(w: World, i: int, d: BossDanceTable, p: Vector2, gap: float) -> bool:
	if Kin.length(p - w.player_pos()) < gap:
		return false
	var eye := w.actors.radius[i] + d.mael_eye_m + d.ht_radius_m * 0.5
	return Kin.length(p - w.actors.pos(i)) >= eye and EnemyAi.clear_of_walls(w, p, d.ht_radius_m)


# --- the end of a fight -----------------------------------------------------------------------------------------


## The hero is dead or outside the room: the casts running end and a throw stops (the clocks stay).
static func cancel(w: World) -> void:
	var bs := w.bosses
	bs.dance_rip_from = -1
	bs.dance_throw = 0
	if bs.dance_ht_from >= 0:
		var i := w.actors.index_of(bs.dance_boss)
		if i >= 0:
			_end_tide(w, i)
		bs.dance_ht_from = -1
		w.objectives.clear(ObjectiveMarkers.TIDE_DRY)


## BossSignatures.on_boss_gone: the boss that ran the dance takes it and its marker with it.
static func on_boss_gone(w: World, boss_id: int) -> void:
	if w.bosses.dance_boss != boss_id:
		return
	w.bosses.clear_dance()
	w.objectives.clear(ObjectiveMarkers.TIDE_DRY)


static func _event(w: World, i: int, effect: StringName, at: Vector2) -> SimEvent:
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, at)
	e.effect_id = effect
	return e


# --- the view's read (WorldReader.boss_dance) -------------------------------------------------------------------


## {} with no boss running a dance; else "boss" (its actor index), "room" (Rect2), "along_x" (the strips run along
## x), "strips" (the four, Rect2, from the room's low side), "riptide" ({} or the cast running: "cast" (its place in
## the row), "casts", "safe" (a strip's index), "struck" (the other three), "warn" (0..1000 through the warning, -1
## once the wave runs), "warn_left" (ticks), "wave" (0..1000 down the strips, -1 before), "front" (metres from the
## room's low end), "hit"), "riptide_in" (ticks until the next row may begin, -1 not in its phase yet), "high_tide"
## ({} or "centre", "radius", "cast" (0..1000, -1 once the water is up), "flood" (0..1000, -1 before), "left" (ticks
## of the flood left), "inside" (the hero stands in the dry circle)), "high_tide_in", and "maelstrom"
## (BossMaelstrom.state).
static func state(w: World) -> Dictionary:
	var bs := w.bosses
	var i := w.actors.index_of(bs.dance_boss) if bs.dance_boss >= 0 else -1
	if i < 0:
		return {}
	var d := BossAi.table_of(w, i).dance
	var room := room_of(w, i)
	return {
		"boss": i,
		"room": room,
		"along_x": SafeArea.runs_along_x(room),
		"strips": SafeArea.strips(room, STRIPS),
		"riptide": _riptide_state(w, d, room),
		"riptide_in": maxi(0, bs.dance_rip_due - w.tick) if bs.dance_rip_due >= 0 else -1,
		"high_tide": _tide_state(w, d),
		"high_tide_in": maxi(0, bs.dance_ht_due - w.tick) if bs.dance_ht_due >= 0 else -1,
		"maelstrom": BossMaelstrom.state(w, i, d),
	}


static func _riptide_state(w: World, d: BossDanceTable, room: Rect2) -> Dictionary:
	var bs := w.bosses
	if bs.dance_rip_from < 0:
		return {}
	var warn := d.warn_ticks(bs.dance_rip_n)
	var t := w.tick - bs.dance_rip_from
	var s := t - warn
	var safe := d.safe_strip(bs.dance_rip_n, bs.dance_rip_mirror)
	var struck: Array[int] = []
	for k in STRIPS:
		if k != safe:
			struck.append(k)
	var length := room.size.x if SafeArea.runs_along_x(room) else room.size.y
	return {
		"cast": bs.dance_rip_n,
		"casts": d.rip_casts,
		"safe": safe,
		"struck": struck,
		"warn": clampi(t * 1000 / maxi(1, warn), 0, 1000) if s < 0 else -1,
		"warn_left": maxi(0, -s),
		"wave": clampi(s * 1000 / maxi(1, d.rip_wave_ticks), 0, 1000) if s >= 0 else -1,
		"front": front_m(d, length, s),
		"hit": bs.dance_rip_hit == 1,
	}


static func _tide_state(w: World, d: BossDanceTable) -> Dictionary:
	var bs := w.bosses
	if bs.dance_ht_from < 0:
		return {}
	var t := w.tick - bs.dance_ht_from
	var s := t - d.ht_cast_ticks
	var c := dry_centre(w)
	var dry: Array[Vector3] = [Vector3(c.x, c.y, d.ht_radius_m)]
	return {
		"centre": c,
		"radius": d.ht_radius_m,
		"cast": clampi(t * 1000 / maxi(1, d.ht_cast_ticks), 0, 1000) if s < 0 else -1,
		"flood": clampi(s * 1000 / maxi(1, d.ht_flood_ticks), 0, 1000) if s >= 0 else -1,
		"left": d.ht_flood_ticks - maxi(0, s),
		"inside": SafeArea.inside(w.player_pos(), [], dry),
	}
