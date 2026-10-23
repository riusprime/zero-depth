class_name BossShade
extends RefCounted
## v0.9.0 NB4 (owner Q24, "ok go for those"; docs/roadmap/v0.9.0/BOSSES_4_5.md row N4; PLAN NB "Keep the empty hood";
## SIM_CONTRACTS §10m): the Lantern Shade's signature, Lights out, and its Snuff.
## - The lanterns: while a Shade lives its room has lamp_count lanterns on its edge (lamp_inset_m in from the middle of
##   each wall of the sealed room, BossStore.arena; without one, round where the Shade stood, FALLBACK_HALF_M each way).
##   Before the first Lights Out the room is lit and they only stand there.
## - Lights Out (a shielded `pattern` with dark_ticks, on the boss's cadence: BossTide.due): dark_ticks after it starts
##   the room goes dark for the rest of the fight and every lantern is lit afresh (lamp_ticks). In the dark only
##   light_m round the player and lamp_m round each lit lantern are lit; a lantern burns down, and the player passing
##   within relight_m (plus their radius) relights it to lamp_ticks.
## - Hittable only when lit: in the dark a hit on the Shade sparks off (Damage, like a shield) unless its body touches
##   the light (unlit()).
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


## BossAi.start_attack (through BossTide.on_start): a Lights Out starting sets when the dark falls.
static func on_start(w: World, i: int, atk: BossAttackTable) -> void:
	if atk.dark_ticks <= 0:
		return
	_own(w, i)
	w.bosses.shade_at = w.tick + atk.dark_ticks
	w.bosses.shade_from = w.tick


## Tick phase 6 (BossSignatures.advance): finds the Shade (its lanterns placed), lets the dark fall when due, burns the
## lanterns down and relights the ones the player passes.
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
		return
	var t := BossAi.table_of(w, i)
	if bs.arena.has_area():
		_place(w, t, bs.arena)  # the sealed room's walls (its lanterns follow them)
	if bs.shade_at >= 0 and w.tick >= bs.shade_at:
		bs.shade_dark = 1
		bs.shade_at = -1
		var lit := PackedInt32Array()
		lit.resize(bs.lamp_x.size())
		lit.fill(t.lamp_ticks)
		bs.lamp_t = lit
		return
	if bs.shade_dark == 0:
		return
	var p := w.player_pos()
	var reach := t.relight_m + w.player.radius_m
	var lt := bs.lamp_t
	for k in lt.size():
		if not w.player_dead() and Kin.length(Vector2(bs.lamp_x[k], bs.lamp_y[k]) - p) <= reach:
			lt[k] = t.lamp_ticks
		elif lt[k] > 0:
			lt[k] -= 1
	bs.lamp_t = lt


## The Shade boss i takes the room's light (the first one; one Shade at a time): its lanterns placed, lit.
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
	var lit := PackedInt32Array()
	lit.resize(bs.lamp_x.size())
	lit.fill(t.lamp_ticks)
	bs.lamp_t = lit


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
	var bs := w.bosses
	var i := w.actors.index_of(bs.shade_boss)
	if i < 0:
		return true
	var t := BossAi.table_of(w, i)
	if not w.player_dead() and Kin.length(p - w.player_pos()) <= t.light_m + r:
		return true
	for k in bs.lamp_t.size():
		if bs.lamp_t[k] > 0 and Kin.length(p - Vector2(bs.lamp_x[k], bs.lamp_y[k])) <= t.lamp_m + r:
			return true
	return false


## Damage: the Shade i stands in the dark, so a hit sparks off it (it is only hittable when lit).
static func unlit(w: World, i: int) -> bool:
	if w.bosses.shade_boss != w.actors.ids[i] or not dark(w):
		return false
	return not lit(w, w.actors.pos(i), w.actors.radius[i])


## Tick phase 6, a Snuff circle at c struck (BossDodge.resolve_marks): the lit lantern nearest c goes out.
static func snuff(w: World, atk: BossAttackTable, c: Vector2) -> void:
	if not atk.snuff or not dark(w):
		return
	var bs := w.bosses
	var best := -1
	var best_d := INF
	for k in bs.lamp_t.size():
		if bs.lamp_t[k] <= 0:
			continue
		var d := Kin.length(Vector2(bs.lamp_x[k], bs.lamp_y[k]) - c)
		if d < best_d:
			best_d = d
			best = k
	if best >= 0:
		var lt := bs.lamp_t
		lt[best] = 0
		bs.lamp_t = lt


## World._remove_dead (through BossSignatures.on_boss_gone): the room relights.
static func on_boss_gone(w: World, boss_id: int) -> void:
	if w.bosses.shade_boss == boss_id:
		w.bosses.clear_shade()


## The view's read (WorldReader.boss_light): {} with no Shade; else "dark" (the room snuffed), "falling" (0..1000:
## how far the next Lights Out is to its dark, -1 with none coming), "light_m" (the player's circle), "lamp_m",
## "lamp_ticks", "lamps" (one {"pos", "lit", "left" (ticks), "frac" (0..1 of its burn left)} per lantern), "boss"
## (the Shade's actor index) and "boss_lit" (its body touches the light: hittable).
static func state(w: World) -> Dictionary:
	var bs := w.bosses
	if bs.shade_boss < 0:
		return {}
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
	return {
		"dark": bs.shade_dark == 1,
		"falling": falling,
		"light_m": t.light_m,
		"lamp_m": t.lamp_m,
		"lamp_ticks": t.lamp_ticks,
		"lamps": lamps,
		"boss": i,
		"boss_lit": not unlit(w, i),
	}
