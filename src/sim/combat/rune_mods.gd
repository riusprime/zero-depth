class_name RuneMods
extends RefCounted
## v0.9.5 FC5 (docs/roadmap/v0.9.5/FORM_COMBOS.md R1-R9): what nine cards do to the Rune Explosion form. One handler per
## card. A rune burst ignores these cards' generic ops (WandCompile.run only notes the id in modifier_ids); this file
## reads them from there: mask(spec). Twin (R1) is the form's own (RuneExplosion.fire: a second shield at 70 %).
## - At the cast (RuneExplosion.fire): Big Shot and Rapid Fire change the radius, the damage and (period()) the rhythm,
##   Homing centres the burst on the nearest enemy within 6 m (a fixed centre, a K_BURST row), Echo queues a second
##   at the same place 36 ticks later at 60 %, Mine leaves a trap there.
## - At full size (RuneExplosion.advance -> on_full): Ring holds a lightning ring 48 ticks hitting each enemy once more,
##   Ricochet shrinks the shield back to nothing over the growth ticks, hitting each enemy once more at 50 %.
## - At each hit (RuneExplosion._hit -> on_hit): Split throws shards outward from the enemy, +-30 degrees about the
##   centre-to-enemy direction, 25 % damage, 4 m, at most 24 live.
## - Follow-ups (Ring, Ricochet, Echo, Mine, Split) start none of their own: an Echo burst and a Mine burst are K_BURST
##   rows with F_NOFOLLOW. Bounded: at most mine_max traps (the oldest ends first), split_live_max shards, 64 rows.
## - Rows (World.mx rm_*), hashed only while any is set (older digests unchanged).
## - Numbers: data/wand/attack_slots.tres, the rune_explosion row's `params` (SlotTable.params); DEFAULTS are the same
##   values, read by a world without the table (a lab) and checked against the data by the content test.
## Pure: integer maths (angles in 1/4096 turns, Kin), no randomness, one clock.

const RING := 1
const RICOCHET := 2
const HOMING := 4
const ECHO := 8
const BIG := 16
const RAPID := 32
const SPLIT := 64
const MINE := 128
## The cards by bit.
const CARD_IDS: Array[StringName] = [
	&"gun_ring",
	&"gun_ricochet",
	&"gun_homing",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"split_shot",
	&"gun_mine",
]
const CARD_BITS: Array[int] = [RING, RICOCHET, HOMING, ECHO, BIG, RAPID, SPLIT, MINE]
## What a row is (rm_kind & KIND_MASK): a burst's meta, a held ring, a shrinking shield, a trap, a shard.
const K_BURST := 0
const K_HOLD := 1
const K_SHRINK := 2
const K_MINE := 3
const K_SHARD := 4
const KIND_MASK := 15
## Row flags (rm_kind): the burst has a fixed centre; the burst starts no follow-ups.
const F_FIXED := 16
const F_NOFOLLOW := 32
const ROWS_MAX := 64
## The ModifierState fields an older save lacks (WorldSnapshot._apply_object reads this list beside ADDED_SINCE_V05).
const SNAPSHOT_FIELDS: Array[StringName] = [
	&"rm_next",
	&"rm_id",
	&"rm_kind",
	&"rm_at",
	&"rm_born",
	&"rm_life",
	&"rm_dmg",
	&"rm_root",
	&"rm_r",
	&"rm_ref",
	&"rm_ang",
	&"rm_hit_row",
	&"rm_hit_foe",
]
## All bursts alive (waiting included) never pass this; a follow-up burst past it is dropped.
const BURSTS_MAX := 12
const HZ := 60
## The row's numbers (units in the names; data/wand/attack_slots.tres carries the same).
const DEFAULTS := {
	"ring_ticks": 48,
	"ring_share": 1000,
	"ricochet_share": 500,
	"home_range_mm": 6000,
	"echo_delay_ticks": 36,
	"echo_share": 600,
	"big_radius_mm": 5000,
	"big_damage": 1600,
	"big_period_ticks": 90,
	"rapid_radius_mm": 2500,
	"rapid_damage": 700,
	"rapid_period_ticks": 42,
	"split_count": 2,
	"split_share": 250,
	"split_range_mm": 4000,
	"split_spread_deg": 30,
	"split_ticks": 24,
	"split_hit_mm": 300,
	"split_live_max": 24,
	"mine_life_ticks": 240,
	"mine_trigger_mm": 600,
	"mine_radius_mm": 2000,
	"mine_share": 1000,
	"mine_max": 4,
}


# --- Cards and numbers --------------------------------------------------------------------------------------------
## The bit mask of the Rune cards the rune spec `spec` carries (0: a plain burst, or not a rune: nothing here runs).
static func mask(spec: AttackSpec) -> int:
	if spec == null or spec.rune_mm <= 0 or spec.modifier_ids.is_empty():
		return 0
	var m := 0
	for k in CARD_IDS.size():
		if spec.modifier_ids.has(String(CARD_IDS[k])):
			m |= CARD_BITS[k]
	return m


## `id` is one of the eight cards (WandCompile.run: on a rune burst its generic ops are skipped).
static func is_card(id: StringName) -> bool:
	return CARD_IDS.has(id)


## Card `m` stands on the rune spec `s` (WandCompile.run): its id is noted.
static func note_card(s: AttackSpec, m: ModifierTable) -> void:
	if not s.modifier_ids.has(String(m.id)):
		s.modifier_ids.append(String(m.id))


## The row's number `key` (data, else the default).
static func param(w: World, key: String) -> int:
	var t := w.slot_table
	if t != null:
		var p: Dictionary = t.params.get(&"rune_explosion", {})
		if p.has(key):
			return int(p[key])
	return int(DEFAULTS[key])


static func share(dmg: int, permille: int) -> int:
	return maxi(1, (dmg * permille + 500) / 1000)


## Which of Big Shot and Rapid Fire the spec took last (the later card sets the radius and the rhythm), 0 for neither.
static func _size_card(spec: AttackSpec) -> int:
	var last := 0
	for id in spec.modifier_ids:
		if id == "gun_big_shot":
			last = BIG
		elif id == "gun_rapid_fire":
			last = RAPID
	return last


## The full radius (mm, before the area stat): the form's, Big Shot's 5 m or Rapid Fire's 2.5 m.
static func radius_mm(w: World, spec: AttackSpec) -> int:
	if mask(spec) == 0:
		return spec.rune_mm
	match _size_card(spec):
		BIG:
			return param(w, "big_radius_mm")
		RAPID:
			return param(w, "rapid_radius_mm")
	return spec.rune_mm


## The shot's damage with Big Shot's x1.6 and Rapid Fire's x0.7.
static func damage(w: World, spec: AttackSpec, dmg: int) -> int:
	var m := mask(spec)
	if m & BIG != 0:
		dmg = share(dmg, param(w, "big_damage"))
	if m & RAPID != 0:
		dmg = share(dmg, param(w, "rapid_damage"))
	return dmg


## The shot period `base` (ticks) with Big Shot's 90 ticks or Rapid Fire's 42 (the later card) in place of the form's.
static func period(w: World, spec: AttackSpec, base: int) -> int:
	if spec.period_ticks <= 0:
		return base
	var t := 0
	match _size_card(spec) if mask(spec) != 0 else 0:
		BIG:
			t = param(w, "big_period_ticks")
		RAPID:
			t = param(w, "rapid_period_ticks")
	if t <= 0:
		return base
	return maxi(1, base * t / spec.period_ticks)


# --- Rows ---------------------------------------------------------------------------------------------------------
static func _add(
	s: ModifierState,
	kind: int,
	at: Vector2,
	born: int,
	life: int,
	dmg: int,
	root: int,
	r_mm: int,
	ref: int,
	ang: int
) -> int:
	if s.rm_kind.size() >= ROWS_MAX:
		return -1
	s.rm_next += 1
	s.rm_id.append(s.rm_next)
	s.rm_kind.append(kind)
	s.rm_at.append(at)
	s.rm_born.append(born)
	s.rm_life.append(life)
	s.rm_dmg.append(dmg)
	s.rm_root.append(root)
	s.rm_r.append(r_mm)
	s.rm_ref.append(ref)
	s.rm_ang.append(ang)
	return s.rm_kind.size() - 1


static func _remove(s: ModifierState, k: int) -> void:
	var id := s.rm_id[k]
	for j in range(s.rm_hit_row.size() - 1, -1, -1):
		if s.rm_hit_row[j] == id:
			s.rm_hit_row.remove_at(j)
			s.rm_hit_foe.remove_at(j)
	s.rm_id.remove_at(k)
	s.rm_kind.remove_at(k)
	s.rm_at.remove_at(k)
	s.rm_born.remove_at(k)
	s.rm_life.remove_at(k)
	s.rm_dmg.remove_at(k)
	s.rm_root.remove_at(k)
	s.rm_r.remove_at(k)
	s.rm_ref.remove_at(k)
	s.rm_ang.remove_at(k)


static func _count(s: ModifierState, kind: int) -> int:
	var n := 0
	for q in s.rm_kind.size():
		if s.rm_kind[q] & KIND_MASK == kind:
			n += 1
	return n


## The K_BURST row of burst `uid`, or -1 (a plain burst: it follows the hero and starts follow-ups).
static func _burst_row(s: ModifierState, uid: int) -> int:
	for q in s.rm_kind.size():
		if s.rm_kind[q] & KIND_MASK == K_BURST and s.rm_ref[q] == uid:
			return q
	return -1


## Where burst `uid` is centred: its fixed place, else `hero`.
static func centre_of(s: ModifierState, uid: int, hero: Vector2) -> Vector2:
	if s.rm_kind.is_empty():
		return hero
	var q := _burst_row(s, uid)
	if q >= 0 and s.rm_kind[q] & F_FIXED != 0:
		return s.rm_at[q]
	return hero


## Burst `uid` starts no follow-ups (an Echo's or a Mine's burst).
static func no_follow(s: ModifierState, uid: int) -> bool:
	if s.rm_kind.is_empty():
		return false
	var q := _burst_row(s, uid)
	return q >= 0 and s.rm_kind[q] & F_NOFOLLOW != 0


## Burst `uid` left: its meta row goes.
static func forget(s: ModifierState, uid: int) -> void:
	if s.rm_kind.is_empty():
		return
	var q := _burst_row(s, uid)
	if q >= 0:
		_remove(s, q)


## Every row goes (the hero died, or the shot is no rune burst any more).
static func clear(s: ModifierState) -> void:
	if s.rm_touched():
		s.rm_clear()


## Homing: where a burst cast from `hero` is centred (the nearest enemy within 6 m, the lowest index on a tie), else
## `hero` (and the burst follows the hero).
static func target(w: World, spec: AttackSpec, hero: Vector2) -> Dictionary:
	if mask(spec) & HOMING == 0:
		return {"fixed": false, "at": hero}
	var range_m := param(w, "home_range_mm") / 1000.0
	var best := -1
	var best_d := 0.0
	for i in w.enemies_near(hero, range_m):
		var d := Kin.length(w.actors.pos(i) - hero)
		if d > range_m:
			continue
		if best < 0 or d < best_d or (d == best_d and i < best):
			best = i
			best_d = d
	if best < 0:
		return {"fixed": false, "at": hero}
	return {"fixed": true, "at": w.actors.pos(best)}


## A burst `uid` of `spec` was cast (RuneExplosion.fire) at `at`: a fixed centre keeps its place.
static func note_burst(s: ModifierState, uid: int, at: Vector2, flags: int) -> void:
	_add(s, K_BURST | flags, at, 0, 0, 0, 0, 0, uid, 0)


## The first burst of a cast at `at` with damage `dmg`, radius `r` (m): Echo's glyph and Mine's trap.
static func on_cast(w: World, spec: AttackSpec, at: Vector2, dmg: int, r: float) -> void:
	var m := mask(spec)
	var s := w.mx
	if m & ECHO != 0 and s.rune_uid.size() < BURSTS_MAX:
		var euid := s.rune_next
		s.rune_next += 1
		s.rune_uid.append(euid)
		s.rune_key.append(spec.key)
		s.rune_born.append(w.tick + param(w, "echo_delay_ticks"))
		s.rune_radius.append(r)
		s.rune_damage.append(share(dmg, param(w, "echo_share")))
		s.rune_root.append(w.take_root())
		note_burst(s, euid, at, F_FIXED | F_NOFOLLOW)
	if m & MINE != 0:
		while _count(s, K_MINE) >= param(w, "mine_max"):
			for q in s.rm_kind.size():  # the oldest ends first
				if s.rm_kind[q] & KIND_MASK == K_MINE:
					_remove(s, q)
					break
		_add(
			s,
			K_MINE,
			at,
			w.tick,
			param(w, "mine_life_ticks"),
			share(dmg, param(w, "mine_share")),
			w.take_root(),
			0,
			0,
			0
		)


## Burst `uid` (radius `r` m, damage `dmg`) reached full size at `at` (RuneExplosion.advance): Ring holds, Ricochet
## shrinks. Echo's and Mine's bursts start none.
static func on_full(w: World, spec: AttackSpec, uid: int, at: Vector2, r: float, dmg: int) -> void:
	var m := mask(spec)
	if m & (RING | RICOCHET) == 0:
		return
	var s := w.mx
	if no_follow(s, uid):
		return
	var r_mm := roundi(r * 1000.0)
	if m & RING != 0:
		_add(
			s,
			K_HOLD,
			at,
			w.tick,
			param(w, "ring_ticks"),
			share(dmg, param(w, "ring_share")),
			w.take_root(),
			r_mm,
			uid,
			0
		)
	if m & RICOCHET != 0:
		_add(
			s,
			K_SHRINK,
			at,
			w.tick,
			maxi(1, spec.rune_ticks),
			share(dmg, param(w, "ricochet_share")),
			w.take_root(),
			r_mm,
			uid,
			0
		)


## Burst `uid` hit actor `i` (now at `pos`) from `centre` (RuneExplosion._hit): Split throws its shards outward.
static func on_hit(
	w: World, spec: AttackSpec, uid: int, dmg: int, i: int, centre: Vector2, pos: Vector2
) -> void:
	if mask(spec) & SPLIT == 0:
		return
	var s := w.mx
	if no_follow(s, uid):
		return
	var away := pos - centre
	var base := Kin.angle_of(away) if Kin.length(away) > 0.0 else w.aim_angle
	var n := maxi(1, param(w, "split_count"))
	var spread := param(w, "split_spread_deg") * SimTick.ANGLE_UNITS / 360
	var d := share(dmg, param(w, "split_share"))
	for j in n:
		if _count(s, K_SHARD) >= param(w, "split_live_max"):
			return
		var off := 0 if n == 1 else -spread + 2 * spread * j / (n - 1)
		_add(
			s,
			K_SHARD,
			pos,
			w.tick,
			param(w, "split_ticks"),
			d,
			w.take_root(),
			0,
			w.actors.ids[i],
			(base + off) & 4095
		)


# --- The tick --------------------------------------------------------------------------------------------------------
## Tick phase 6 (ModifierRuntime.advance, after RuneExplosion.advance): the traps, rings, shrinking shields and shards.
static func advance(w: World) -> void:
	var s := w.mx
	if s.rm_kind.is_empty():
		return
	var spec := Modifiers.bolt(w) if PlayerBuild.has_gun(w) else null
	if spec == null or spec.rune_mm <= 0 or w.player_dead():
		s.rm_clear()
		return
	var k := 0
	while k < s.rm_kind.size():
		var kind: int = s.rm_kind[k] & KIND_MASK
		var gone := false
		match kind:
			K_HOLD:
				gone = _hold(w, spec, k)
			K_SHRINK:
				gone = _shrink(w, spec, k)
			K_MINE:
				gone = _mine(w, spec, k)
			K_SHARD:
				gone = _shard(w, spec, k)
		if gone:
			_remove(s, k)
		else:
			k += 1


static func _ctx(
	s: ModifierState, k: int, at: Vector2, spec: AttackSpec, tags: int
) -> AttackContext:
	var c := AttackContext.make(at, 0, s.rm_dmg[k], s.rm_root[k], tags, &"")
	c.depth = spec.depth
	c.proc_pct = maxi(1, 100 >> spec.depth)
	c.secondary = true
	return c


static func _hit_before(s: ModifierState, id: int, foe: int) -> bool:
	for j in s.rm_hit_row.size():
		if s.rm_hit_row[j] == id and s.rm_hit_foe[j] == foe:
			return true
	return false


## Ring row `k`: each enemy in the full radius takes one more hit; true when its time is over.
static func _hold(w: World, spec: AttackSpec, k: int) -> bool:
	var s := w.mx
	var age := w.tick - s.rm_born[k]
	if age >= s.rm_life[k]:
		return true
	var at: Vector2 = s.rm_at[k]
	var c := _ctx(s, k, at, spec, SimEvent.TAG_AREA)
	for i in w.enemies_near(at, s.rm_r[k] / 1000.0):
		var aid := w.actors.ids[i]
		if _hit_before(s, s.rm_id[k], aid):
			continue
		s.rm_hit_row.append(s.rm_id[k])
		s.rm_hit_foe.append(aid)
		Attacks.land(w, spec, c, i, at, w.actors.pos(i))
	return false


## Ricochet row `k`: the edge shrinks from full to 0 over its life, hitting each enemy it reaches once more.
static func _shrink(w: World, spec: AttackSpec, k: int) -> bool:
	var s := w.mx
	var age := mini(w.tick - s.rm_born[k], s.rm_life[k])
	if age >= 1:
		var at: Vector2 = s.rm_at[k]
		var full: int = s.rm_r[k]
		var edge := float(full * (s.rm_life[k] - age) / s.rm_life[k]) / 1000.0
		var c := _ctx(s, k, at, spec, SimEvent.TAG_AREA)
		for i in w.enemies_near(at, full / 1000.0):
			var aid := w.actors.ids[i]
			if _hit_before(s, s.rm_id[k], aid):
				continue
			var d := Kin.length(w.actors.pos(i) - at)
			if edge > d + w.actors.radius[i]:
				continue
			s.rm_hit_row.append(s.rm_id[k])
			s.rm_hit_foe.append(aid)
			Attacks.land(w, spec, c, i, at, w.actors.pos(i))
	return w.tick - s.rm_born[k] >= s.rm_life[k]


## Mine row `k`: an enemy within the trigger distance sets it off as a Mine burst (fixed, no follow-ups); true if gone.
static func _mine(w: World, spec: AttackSpec, k: int) -> bool:
	var s := w.mx
	if w.tick - s.rm_born[k] >= s.rm_life[k]:
		return true
	var at: Vector2 = s.rm_at[k]
	if w.enemies_near(at, param(w, "mine_trigger_mm") / 1000.0).is_empty():
		return false
	if s.rune_uid.size() < BURSTS_MAX:
		var uid := s.rune_next
		s.rune_next += 1
		s.rune_uid.append(uid)
		s.rune_key.append(spec.key)
		s.rune_born.append(w.tick)
		s.rune_radius.append(Stats.area(w, param(w, "mine_radius_mm") / 1000.0))
		s.rune_damage.append(s.rm_dmg[k])
		s.rune_root.append(s.rm_root[k])
		note_burst(s, uid, at, F_FIXED | F_NOFOLLOW)
	return true


## The place of shard row `k` now.
static func shard_pos(w: World, k: int) -> Vector2:
	var s := w.mx
	var age := clampi(w.tick - s.rm_born[k], 0, s.rm_life[k])
	var reach := param(w, "split_range_mm") * age / maxi(1, s.rm_life[k])
	return s.rm_at[k] + Kin.dir(s.rm_ang[k]) * (reach / 1000.0)


## Shard row `k`: flies its range, ends on the first enemy it touches (not the one it came from); true if gone.
static func _shard(w: World, spec: AttackSpec, k: int) -> bool:
	var s := w.mx
	var age := w.tick - s.rm_born[k]
	if age >= 1:
		var pos := shard_pos(w, k)
		var c := _ctx(s, k, pos, spec, SimEvent.TAG_PROJECTILE)
		var hit := -1
		for i in w.enemies_near(pos, param(w, "split_hit_mm") / 1000.0):
			if w.actors.ids[i] == s.rm_ref[k]:
				continue
			if hit < 0 or i < hit:
				hit = i
		if hit >= 0:
			Attacks.land(w, spec, c, hit, pos, w.actors.pos(hit))
			return true
	return age >= s.rm_life[k]


# --- For the views ---------------------------------------------------------------------------------------------------
## What the cards leave on the floor now: {holds, shrinks, mines, shards, glyphs}, each an array of dictionaries
## (pos, radius (m), age, life) in row order; glyphs are the Echo bursts still waiting (pos, radius, wait ticks).
static func read(w: World) -> Dictionary:
	var out := {"holds": [], "shrinks": [], "mines": [], "shards": [], "glyphs": []}
	var s := w.mx
	for k in s.rm_kind.size():
		var kind: int = s.rm_kind[k] & KIND_MASK
		var age := w.tick - s.rm_born[k]
		match kind:
			K_HOLD:
				out["holds"].append(
					{
						"pos": s.rm_at[k],
						"radius": s.rm_r[k] / 1000.0,
						"age": age,
						"life": s.rm_life[k]
					}
				)
			K_SHRINK:
				out["shrinks"].append(
					{
						"pos": s.rm_at[k],
						"radius":
						(
							s.rm_r[k]
							* clampi(s.rm_life[k] - age, 0, s.rm_life[k])
							/ s.rm_life[k]
							/ 1000.0
						),
						"age": age,
						"life": s.rm_life[k]
					}
				)
			K_MINE:
				out["mines"].append(
					{
						"pos": s.rm_at[k],
						"radius": param(w, "mine_trigger_mm") / 1000.0,
						"age": age,
						"life": s.rm_life[k]
					}
				)
			K_SHARD:
				out["shards"].append(
					{"pos": shard_pos(w, k), "radius": 0.0, "age": age, "life": s.rm_life[k]}
				)
	for k in s.rune_uid.size():
		if w.tick < s.rune_born[k] and no_follow(s, s.rune_uid[k]):
			out["glyphs"].append(
				{
					"pos": centre_of(s, s.rune_uid[k], w.player_pos()),
					"radius": s.rune_radius[k],
					"age": 0,
					"life": s.rune_born[k] - w.tick
				}
			)
	return out
