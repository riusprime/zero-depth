class_name BossShade
extends RefCounted
## v0.9.0 NB4 (owner Q24, "ok go for those"; docs/roadmap/v0.9.0/BOSSES_4_5.md row N4; PLAN NB "Keep the empty hood";
## SIM_CONTRACTS §10m): the Lantern Shade's signature, Lights out, and its Snuff.
## - The lanterns: while a Shade lives its room has lamp_count lanterns on its edge (lamp_inset_m in from the middle of
##   each wall of the sealed room, BossStore.arena; without one, round where the Shade stood, FALLBACK_HALF_M each way).
##   They start out.
## - Lights Out (a `pattern` with dark_ticks, on the boss's cadence: BossTide.due): dark_ticks after the first
##   one starts the room goes dark. In the dark only light_m round the player and lamp_m round each lit lantern are lit.
## - v0.11.0 O4 (owner Q10 a, PLAN L6: "40 % damage in the dark, 150 % inside a lit pool; a lantern stays lit 6 s;
##   dark 9 s / light 4 s"): from that first dark the dark and the light alternate on their own clock (the table's
##   dark_hold_ticks, then light_hold_ticks, repeating); a Lights Out starting while that cycle runs only plays its
##   wisps. A table with no light_hold_ticks keeps the light until its next Lights Out's dark (NB4b); one with no
##   dark_hold_ticks keeps the dark until the Shade dies.
## - The lanterns are the player's lever: passing within relight_m (plus their radius) lights one for lamp_ticks, dark
##   or light, and it burns down after; a Snuff puts lit ones out.
## - v0.11.0 O4: never immune. A hit on the Shade is scaled by light_permille: lit_mult_permille (150 %) while its body
##   touches a lit lantern's pool (dark or light), dark_mult_permille (40 %) while it stands in the dark, else 1000
##   (in the full light, or touched by the player's own light_m circle). Tagged TAG_SHADE_LIT / TAG_SHADE_DARK.
## - v0.11.0 O4 (L4, Q12): while dark the hint marker (ObjectiveMarkers.SHADE_LANTERN) points at every unlit lantern;
##   cleared in the light and when the Shade is gone.
## - v0.10.5 O2a (owner L3): Lights Out is shielded only through its telegraph (shield_seconds 0); the wisps fly open.
##   v0.11.0 O4b (owner: "Bring it back"): kept; every other moment the Shade is never immune.
## - The Snuff (a `marks` attack with snuff): each struck circle puts out the lit lantern nearest its centre.
## - The dark is sim state (BossStore.shade_* and lamp_*, snapshotted and hashed while a Shade lives); the darkness
##   drawn is the view reading it (WorldReader.boss_light). The Shade gone, the room relights.
## Pure: no stream is drawn here; everything follows from the clock and positions.

## The room's half-size used round the Shade when there is no sealed boss room (a test world).
const FALLBACK_HALF_M := 7.0


## True for the boss table of a Lantern Shade.
static func is_shade(t: BossTable) -> bool:
	return t != null and t.lamp_count > 0


## True once the room is dark.
static func dark(w: World) -> bool:
	return w.bosses.shade_boss >= 0 and w.bosses.shade_dark == 1


## BossAi.start_attack (through BossTide.on_start): a Lights Out starting sets when the dark falls (O4: only before
## the dark and light have begun to alternate on their own clock).
static func on_start(w: World, i: int, atk: BossAttackTable) -> void:
	if atk.dark_ticks <= 0:
		return
	_own(w, i)
	var bs := w.bosses
	if bs.shade_dark == 1 or bs.shade_until >= 0:
		return  # O4: the cycle runs; this Lights Out only plays its wisps
	bs.shade_at = w.tick + atk.dark_ticks
	bs.shade_from = w.tick


## Tick phase 6 (BossSignatures.advance): finds the Shade (its lanterns placed), lets the dark fall when due and lift
## when its stretch is over (NB4b), then (O4) fall again when the light's stretch is over; burns the lanterns down
## and lights the ones the player passes; points the hint at the unlit ones in the dark.
static func advance(w: World) -> void:
	var bs := w.bosses
	if bs.shade_boss < 0:
		if bs.size() == 0:
			return
		for b in bs.size():
			var i := w.actors.index_of(bs.ids[b])
			if i >= 0 and is_shade(BossAi.table_of(w, i)):
				_own(w, i)
				break
		if bs.shade_boss < 0:
			return
	var i := w.actors.index_of(bs.shade_boss)
	if i < 0:
		bs.clear_shade()
		w.objectives.clear(ObjectiveMarkers.SHADE_LANTERN)
		return
	var t := BossAi.table_of(w, i)
	if bs.arena.has_area():
		_place(w, t, bs.arena)  # the sealed room's walls (its lanterns follow them)
	if bs.shade_at >= 0 and w.tick >= bs.shade_at:
		_fall(w, t)
	elif bs.shade_until >= 0 and w.tick >= bs.shade_until:
		if bs.shade_dark == 1:
			bs.shade_dark = 0  # NB4b: the dark's stretch is over
			bs.shade_until = w.tick + t.light_hold_ticks if t.light_hold_ticks > 0 else -1
		else:
			_fall(w, t)  # O4: the light's stretch is over
	_burn(w, t)
	_hint(w)


## The dark falls for the table's dark_hold_ticks (the lanterns keep what they had left).
static func _fall(w: World, t: BossTable) -> void:
	var bs := w.bosses
	bs.shade_dark = 1
	bs.shade_at = -1
	bs.shade_until = w.tick + t.dark_hold_ticks if t.dark_hold_ticks > 0 else -1


## O4: every lantern burns a tick down; one the player stands within reach of is lit to lamp_ticks.
static func _burn(w: World, t: BossTable) -> void:
	var bs := w.bosses
	var p := w.player_pos()
	var reach := t.relight_m + w.player.radius_m
	var lt := bs.lamp_t
	for k in lt.size():
		if not w.player_dead() and Kin.length(Vector2(bs.lamp_x[k], bs.lamp_y[k]) - p) <= reach:
			lt[k] = t.lamp_ticks
		elif lt[k] > 0:
			lt[k] -= 1
	bs.lamp_t = lt


## O4 (L4, Q12): in the dark the hint points at every unlit lantern; in the light, none.
static func _hint(w: World) -> void:
	var bs := w.bosses
	w.objectives.clear(ObjectiveMarkers.SHADE_LANTERN)
	if bs.shade_dark != 1:
		return
	for k in bs.lamp_t.size():
		if bs.lamp_t[k] <= 0:
			w.objectives.point(ObjectiveMarkers.SHADE_LANTERN, Vector2(bs.lamp_x[k], bs.lamp_y[k]))


## The Shade boss i takes the room's light (the first one; one Shade at a time): its lanterns placed, out (O4).
static func _own(w: World, i: int) -> void:
	var bs := w.bosses
	var id := w.actors.ids[i]
	if bs.shade_boss == id:
		return
	if bs.shade_boss >= 0 and w.actors.index_of(bs.shade_boss) >= 0:
		return
	bs.clear_shade()
	bs.shade_boss = id
	var t := BossAi.table_of(w, i)
	var half := Vector2(FALLBACK_HALF_M, FALLBACK_HALF_M)
	var room := bs.arena if bs.arena.has_area() else Rect2(w.actors.pos(i) - half, half * 2.0)
	_place(w, t, room)
	var out := PackedInt32Array()
	out.resize(bs.lamp_x.size())
	out.fill(0)
	bs.lamp_t = out


## The lanterns' spots: lamp_inset_m in from the middle of each wall of `room` (north, east, south, west), then more
## round the room's middle if a table asks for more than four.
static func _place(w: World, t: BossTable, room: Rect2) -> void:
	var c := room.get_center()
	var hx := maxf(0.0, room.size.x * 0.5 - t.lamp_inset_m)
	var hy := maxf(0.0, room.size.y * 0.5 - t.lamp_inset_m)
	var spots: Array[Vector2] = [
		Vector2(c.x, c.y - hy),
		Vector2(c.x + hx, c.y),
		Vector2(c.x, c.y + hy),
		Vector2(c.x - hx, c.y)
	]
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	for k in t.lamp_count:
		var s: Vector2 = spots[k % 4] if k < 4 else c.lerp(spots[k % 4], 0.5)
		xs.append(s.x)
		ys.append(s.y)
	w.bosses.lamp_x = xs
	w.bosses.lamp_y = ys


## True when a disc of radius r at p touches the light: always before the dark (or with no Shade); in the dark, within
## light_m of the player or lamp_m of a lit lantern.
static func lit(w: World, p: Vector2, r: float = 0.0) -> bool:
	if not dark(w):
		return true
	var i := w.actors.index_of(w.bosses.shade_boss)
	if i < 0:
		return true
	var t := BossAi.table_of(w, i)
	if not w.player_dead() and Kin.length(p - w.player_pos()) <= t.light_m + r:
		return true
	return in_pool(w, p, r)


## O4: True when a disc of radius r at p touches a lit lantern's pool (lamp_m round it), dark or light.
static func in_pool(w: World, p: Vector2, r: float = 0.0) -> bool:
	var bs := w.bosses
	var i := w.actors.index_of(bs.shade_boss)
	if i < 0:
		return false
	var t := BossAi.table_of(w, i)
	for k in bs.lamp_t.size():
		if bs.lamp_t[k] > 0 and Kin.length(p - Vector2(bs.lamp_x[k], bs.lamp_y[k])) <= t.lamp_m + r:
			return true
	return false


## O4 (owner Q10 a): the per-mille of a hit the actor i takes from the room's light: 1000 for anything but the Shade;
## for it, lit_mult_permille in a lit lantern's pool, dark_mult_permille in the dark (outside the player's own
## light), else 1000. Never 0. Damage.hit and Damage.tick_dot apply it; the boss bar and the forecasts read it.
static func light_permille(w: World, i: int) -> int:
	var bs := w.bosses
	if bs.shade_boss < 0 or bs.shade_boss != w.actors.ids[i]:
		return 1000
	var t := BossAi.table_of(w, i)
	var p := w.actors.pos(i)
	var r := w.actors.radius[i]
	if in_pool(w, p, r):
		return maxi(1, t.lit_mult_permille)
	if lit(w, p, r):
		return 1000
	return maxi(1, t.dark_mult_permille)


## O4: [per-mille, tag] for a player's hit on actor i (Damage.hit): the light's multiplier and TAG_SHADE_LIT or
## TAG_SHADE_DARK (0 at 1000).
static func hit_mult(w: World, i: int) -> Array[int]:
	var pm := light_permille(w, i)
	if pm > 1000:
		return [pm, SimEvent.TAG_SHADE_LIT]
	if pm < 1000:
		return [pm, SimEvent.TAG_SHADE_DARK]
	return [1000, 0]


## Tick phase 6, a Snuff circle at c struck (BossDodge.resolve_marks): the atk.snuff_count lit lanterns nearest c go
## out (v0.9.5 BH3, B10: two; one before). O4: dark or light (a lit lantern's pool matters in both).
static func snuff(w: World, atk: BossAttackTable, c: Vector2) -> void:
	if not atk.snuff or w.bosses.shade_boss < 0:
		return
	var bs := w.bosses
	var lt := bs.lamp_t
	for n in maxi(1, atk.snuff_count):
		var best := -1
		var best_d := INF
		for k in lt.size():
			if lt[k] <= 0:
				continue
			var d := Kin.length(Vector2(bs.lamp_x[k], bs.lamp_y[k]) - c)
			if d < best_d:
				best_d = d
				best = k
		if best < 0:
			break
		lt[best] = 0
	bs.lamp_t = lt


## World._remove_dead (through BossSignatures.on_boss_gone): the room relights (and the hint goes).
static func on_boss_gone(w: World, boss_id: int) -> void:
	if w.bosses.shade_boss == boss_id:
		w.bosses.clear_shade()
		w.objectives.clear(ObjectiveMarkers.SHADE_LANTERN)


## The view's read (WorldReader.boss_light): {} with no Shade; else "dark" (the room snuffed), "falling" (0..1000:
## how far the first Lights Out is to its dark, -1 with none coming), "dark_left" (NB4b: ticks until the dark lifts, -1
## when not dark or dark until the Shade dies), "light_left" (O4: ticks until the dark falls again, -1 when dark or
## none due), "light_m" (the player's circle), "lamp_m", "lamp_ticks", "lamps" (one {"pos", "lit", "left" (ticks),
## "frac" (0..1 of its burn left)} per lantern), "boss" (the Shade's actor index), "boss_lit" (its damage taken is
## not cut by the dark) and "boss_mult" (O4: its light_permille now).
static func state(w: World) -> Dictionary:
	var bs := w.bosses
	if bs.shade_boss < 0:
		return BossInterphase.light(w)  # v0.9.5 BH6: the Fallen's Lights Out interphase shows the same dark
	var i := w.actors.index_of(bs.shade_boss)
	if i < 0:
		return {}
	var t := BossAi.table_of(w, i)
	var falling := -1
	if bs.shade_at >= 0:
		var span := maxi(1, bs.shade_at - bs.shade_from)
		falling = clampi((w.tick - bs.shade_from) * 1000 / span, 0, 1000)
	var lamps: Array[Dictionary] = []
	for k in bs.lamp_x.size():
		var left := bs.lamp_t[k] if k < bs.lamp_t.size() else 0
		(
			lamps
			. append(
				{
					"pos": Vector2(bs.lamp_x[k], bs.lamp_y[k]),
					"lit": left > 0,
					"left": left,
					"frac": clampf(float(left) / maxf(1.0, t.lamp_ticks), 0.0, 1.0),
				}
			)
		)
	var mult := light_permille(w, i)
	var until := maxi(0, bs.shade_until - w.tick) if bs.shade_until >= 0 else -1
	return {
		"dark": bs.shade_dark == 1,
		"falling": falling,
		"dark_left": until if bs.shade_dark == 1 else -1,
		"light_left": until if bs.shade_dark == 0 else -1,
		"light_m": t.light_m,
		"lamp_m": t.lamp_m,
		"lamp_ticks": t.lamp_ticks,
		"lamps": lamps,
		"boss": i,
		"boss_lit": mult >= 1000,
		"boss_mult": mult,
	}
