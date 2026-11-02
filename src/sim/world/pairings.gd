class_name Pairings
extends RefCounted
## v0.10.5 O15 (docs/roadmap/v0.10.5/O15_PAIRINGS.md): authored enemy duos in the spawner. After a lead-kind pack's
## spots are chosen, each row of the lead kind whose floor has come and whose partner kind is unlocked rolls its
## chance (ai stream, one draw per eligible row); a hit adds `count` partners on valid walkable spots by placement,
## relative to the pack's anchor and the hero. Partners are limited to the room left under the alive cap (they are the
## first dropped). The spawner never runs in boss rooms, sealed arenas or Lockdown formations, and no partner stands
## in the boss room.

const BEHIND_M := 2.0
const FLANK_M := 4.0
const IN_FRONT_M := 1.5
const ABOVE_BEHIND_M := 2.5
## Nudges tried when a placed spot is not walkable: extra metres outward / inward, then turns (1/4096).
const NUDGE_M: Array[float] = [0.0, 1.0, -1.0, 2.0]
const NUDGE_TURN: Array[int] = [0, 256, -256, 512, -512]


## The rows that roll for a pack of `lead_kind` (indices), in file order.
static func rows_for(
	w: World, t: SpawnTable, lead_kind: int, open_kinds: PackedInt32Array
) -> PackedInt32Array:
	var out := PackedInt32Array()
	var pt := t.pairings
	if pt == null:
		return out
	for r in pt.size():
		if pt.lead[r] != lead_kind or w.floor_index < pt.from_floor[r]:
			continue
		if not open_kinds.has(pt.partner[r]):
			continue
		out.append(r)
	return out


## Rolls the rows for a pack at `anchor` and spawns the partners that fit in `room` (the alive cap's slack left).
## Returns how many arrived.
static func add_partners(
	w: World,
	t: SpawnTable,
	lead_kind: int,
	anchor: Vector2,
	room: int,
	ticks: int,
	open_kinds: PackedInt32Array
) -> int:
	var added := 0
	var pt := t.pairings
	for r in rows_for(w, t, lead_kind, open_kinds):
		if w.rng_ai.range_int(0, 999) >= pt.chance[r]:
			continue
		var spots := spots_for(w, pt.placement[r], pt.count[r], anchor)
		var fired := false
		for q in spots:
			if added >= room:
				break
			w.add_enemy(pt.partner[r], q)
			SpawnDirector.scale_arrival(w, w.actors.size() - 1, ticks)
			added += 1
			fired = true
		if fired and not w.pairs_seen.has(r):
			w.pairs_seen.append(r)
	return added


## Up to `count` valid spots for `placement` around `anchor`, hero-relative.
static func spots_for(w: World, placement: int, count: int, anchor: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var p := w.player_pos()
	var away := anchor - p
	away = away.normalized() if Kin.length(away) > 0.001 else Vector2.RIGHT
	if placement == PairingTable.Place.FAR_SIDE:
		var q := _far_side(w, anchor)
		if q != Vector2.INF:
			out.append(q)
		return out
	for k in count:
		var base := Vector2.ZERO
		match placement:
			PairingTable.Place.BEHIND:
				base = away * BEHIND_M
			PairingTable.Place.ABOVE_BEHIND:
				base = away * ABOVE_BEHIND_M
			PairingTable.Place.IN_FRONT:
				base = -away * IN_FRONT_M
			_:  # FLANKING: a side per partner, ±90° from the hero's line
				var side := Vector2(-away.y, away.x)
				base = (side if k % 2 == 0 else -side) * FLANK_M
		var q := _valid(w, anchor, base, out)
		if q != Vector2.INF:
			out.append(q)
	return out


## The anchor's room's spawn point farthest from the hero (not in the boss room).
static func _far_side(w: World, anchor: Vector2) -> Vector2:
	var p := w.player_pos()
	var home := w.floor_layout.room_of(anchor) if w.floor_layout != null else -1
	var best := Vector2.INF
	var best_d := -1.0
	for q in w.spawn_points:
		if w.floor_layout != null:
			var qr := w.floor_layout.room_of(q)
			if qr != home or qr == w.floor_layout.boss_room:
				continue
		var d := Kin.length(q - p)
		if d > best_d:
			best_d = d
			best = q
	return best


## `anchor + base`, nudged until it is a walkable spot of the anchor's room clear of the hero; INF when none is.
static func _valid(w: World, anchor: Vector2, base: Vector2, taken: PackedVector2Array) -> Vector2:
	var len_b := Kin.length(base)
	var ang := Kin.angle_of(base)
	var home := w.floor_layout.room_of(anchor) if w.floor_layout != null else -1
	for turn in NUDGE_TURN:
		for extra in NUDGE_M:
			var d := len_b + extra
			if d <= 0.5:
				continue
			var q := anchor + Kin.dir(ang + turn) * d
			if (
				SpawnDirector.spot_ok(w, q, home, w.spawner.min_distance_m * 0.5)
				and not _crowded(q, taken)
			):
				return q
	return Vector2.INF


static func _crowded(q: Vector2, taken: PackedVector2Array) -> bool:
	for o in taken:
		if Kin.length(q - o) < 0.8:
			return true
	return false
