class_name BombMods
extends RefCounted
## v0.9.5 FC2 (docs/roadmap/v0.9.5/FORM_COMBOS.md B1-B10): what ten cards do to the Bomb form. One handler per card.
## A bomb ignores these cards' generic ops (WandCompile.run: it only notes the id in modifier_ids, and Split's level as
## "bomblets:N"), and this file reads them from there: mask(spec).
## - At the throw (Attacks._bolts -> on_throw): Halo's cross of four bombs and Backfire's bomb at the hero's feet
##   wait as rows; Big Shot throws 25 % slower (speed()); Rapid Fire shortens the period (period()).
## - At the landing (Bomb.blast -> on_land): Ricochet skips the landing point on, Homing moves it to the nearest
##   enemy, Mine leaves the bomb waiting as a row instead of bursting; otherwise it bursts (Bomb.burst) at
##   damage_permille() and the follow-ups queue as rows: Ring (a growing lightning ring), Echo (the blast again),
##   Split (bomblets).
## - Rows (World.mx bm_*, advance() each tick): K_BURST a delayed blast with no follow-ups (Echo, a bomblet), K_DROP
##   a bomb with a fuse that bursts like a thrown one (Halo, Backfire), K_MINE a waiting bomb, K_RING a growing ring
##   that hits each enemy once. At most ROWS_MAX rows; a row that does not fit is not added (no projectile cap is
##   touched: a row is no projectile).
## - Numbers: data/wand/attack_slots.tres, the bomb row's `params` (SlotTable.params); DEFAULTS are the same values,
##   read by a world without the table (a lab) and checked against the data by the content test.
## Pure: integer maths (angles in 1/4096 turns, Kin), no randomness, one clock.

const HALO := 1
const RING := 2
const BACKFIRE := 4
const RICOCHET := 8
const HOMING := 16
const ECHO := 32
const BIG := 64
const RAPID := 128
const SPLIT := 256
const MINE := 512
## The cards by bit.
const CARD_IDS: Array[StringName] = [
	&"halo_shot",
	&"gun_ring",
	&"gun_backfire",
	&"gun_ricochet",
	&"gun_homing",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"split_shot",
	&"gun_mine",
]
const CARD_BITS: Array[int] = [
	HALO, RING, BACKFIRE, RICOCHET, HOMING, ECHO, BIG, RAPID, SPLIT, MINE
]
## What a row is (bm_kind & KIND_MASK); SEC marks a secondary bomb (its proc is the secondary's).
const K_BURST := 0
const K_DROP := 1
const K_MINE := 2
const K_RING := 3
const KIND_MASK := 7
const SEC := 8
## The kinds by name (WorldReader.bomb_rows gives them to the view).
const KIND_NAMES: Array[StringName] = [&"burst", &"drop", &"mine", &"ring"]
const ROWS_MAX := 64
const HZ := 60
## The wall sweep's radius (m) for a skip, Halo's cross and the bomblets.
const SKIP_R := 0.12
const BOMBLETS := "bomblets:"
## The bomb row's numbers (units in the names; data/wand/attack_slots.tres carries the same).
const DEFAULTS := {
	"halo_dist_mm": 3000,
	"halo_delay_ms": 200,
	"halo_share": 1000,
	"ring_mm": 3500,
	"ring_ms": 400,
	"ring_share": 500,
	"back_fuse_ms": 500,
	"back_share": 1000,
	"ricochet_mm": 2000,
	"home_range_mm": 3000,
	"echo_delay_ms": 500,
	"echo_share": 500,
	"big_blast_mm": 3300,
	"big_damage": 1600,
	"big_speed": 750,
	"rapid_period_ms": 600,
	"rapid_blast_mm": 1600,
	"rapid_damage": 650,
	"split_dist_mm": 2000,
	"split_fuse_ms": 300,
	"split_share": 400,
	"split_blast_mm": 1200,
	"mine_trigger_mm": 1500,
	"mine_max": 5,
	"mine_life_ms": 12000,
}


# --- Cards and numbers --------------------------------------------------------------------------------------------
## The bit mask of the Bomb cards the bomb `spec` carries (0: a plain Bomb, or not a bomb: nothing here runs).
static func mask(spec: AttackSpec) -> int:
	if spec == null or spec.blast_mm <= 0 or spec.modifier_ids.is_empty():
		return 0
	var m := 0
	for k in CARD_IDS.size():
		if spec.modifier_ids.has(String(CARD_IDS[k])):
			m |= CARD_BITS[k]
	return m


## `id` is one of the ten cards (WandCompile.run: on a bomb its generic ops are skipped).
static func is_card(id: StringName) -> bool:
	return CARD_IDS.has(id)


## Card `m` stands on the bomb `s` (WandCompile.run): its id is noted; Split also notes its level's bomblets.
static func note_card(s: AttackSpec, m: ModifierTable) -> void:
	if not s.modifier_ids.has(String(m.id)):
		s.modifier_ids.append(String(m.id))
	if m.id != &"split_shot":
		return
	for op in m.ops:
		for c in op.child_ops:
			if c.field == &"count":
				for k in range(s.modifier_ids.size() - 1, -1, -1):
					if s.modifier_ids[k].begins_with(BOMBLETS):
						s.modifier_ids.remove_at(k)
				s.modifier_ids.append(BOMBLETS + str(int(round(c.value))))


## Split's bomblets a blast (its level: 2, 3 or 4).
static func bomblet_count(spec: AttackSpec) -> int:
	for id in spec.modifier_ids:
		if id.begins_with(BOMBLETS):
			return clampi(int(id.substr(BOMBLETS.length())), 1, 8)
	return 2


## The bomb row's number `key` (data, else the default).
static func param(w: World, key: String) -> int:
	var t := w.slot_table
	if t != null:
		var p: Dictionary = t.params.get(&"bomb", {})
		if p.has(key):
			return int(p[key])
	return int(DEFAULTS[key])


static func ticks(ms: int) -> int:
	return maxi(1, ms * HZ / 1000)


static func mm(v: int) -> float:
	return v / 1000.0


static func share(dmg: int, permille: int) -> int:
	return maxi(1, dmg * permille / 1000)


## The blast radius (mm) of the bomb `spec` before the area stat: Big Shot's 3.3 m, Rapid Fire's 1.6 m (both: the
## 1.6 m's share of the 2.2 m on the 3.3 m, 2.4 m).
static func blast_mm(w: World, spec: AttackSpec) -> int:
	var m := mask(spec)
	var r := spec.blast_mm
	if m & BIG:
		r = param(w, "big_blast_mm")
	if m & RAPID:
		r = r * param(w, "rapid_blast_mm") / maxi(1, spec.blast_mm)
	return r


## The damage factor (per mille): Big Shot's +60 %, Rapid Fire's 65 % a blast.
static func damage_permille(w: World, m: int) -> int:
	var f := 1000
	if m & BIG:
		f = f * param(w, "big_damage") / 1000
	if m & RAPID:
		f = f * param(w, "rapid_damage") / 1000
	return f


## The throw's speed (m/s): Big Shot's 25 % slower.
static func speed(w: World, spec: AttackSpec) -> float:
	if mask(spec) & BIG == 0:
		return spec.speed
	return spec.speed * param(w, "big_speed") / 1000.0


## Rapid Fire: the throw period `base` (ticks) of the plain 1.0 s becomes rapid_period_ms.
static func period(w: World, spec: AttackSpec, base: int) -> int:
	if mask(spec) & RAPID == 0:
		return base
	return maxi(1, base * param(w, "rapid_period_ms") / 1000)


# --- The throw and the landing --------------------------------------------------------------------------------------
## The player's own throw of `dmg` (a bolt's) from `origin` along `angle` (Attacks._bolts, once a volley): Halo's cross
## and Backfire's drop wait as rows.
static func on_throw(w: World, spec: AttackSpec, origin: Vector2, angle: int, dmg: int) -> void:
	var m := mask(spec)
	if m & (HALO | BACKFIRE) == 0:
		return
	var d := share(dmg, damage_permille(w, m))
	var r_mm := int(round(Bomb.radius_m(w, spec) * 1000.0))
	if m & HALO:
		var due := w.tick + ticks(param(w, "halo_delay_ms"))
		for k in 4:
			var a := (angle + k * 1024) & 4095
			var to := clear_point(w, origin, Kin.dir(a), mm(param(w, "halo_dist_mm")))
			_add(w, K_DROP | SEC, to, due, r_mm, share(d, param(w, "halo_share")), a, w.take_root())
	if m & BACKFIRE:
		var due := w.tick + ticks(param(w, "back_fuse_ms"))
		_add(
			w,
			K_DROP | SEC,
			origin,
			due,
			r_mm,
			share(d, param(w, "back_share")),
			angle,
			w.take_root()
		)


## Bomb projectile `pi` ended at `at` (Bomb.blast with cards): see the class doc.
static func on_land(
	w: World, spec: AttackSpec, m: int, pi: int, at: Vector2, secondary: bool
) -> int:
	var p := w.projectiles
	var ang := Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))
	var dmg := share(p.damage[pi], damage_permille(w, m))
	var to := at
	if m & RICOCHET:
		to = skip(w, at, Kin.dir(ang), mm(param(w, "ricochet_mm")))
	if m & HOMING:
		to = home(w, to)
	if m & MINE:
		_place_mine(w, spec, m, to, ang, dmg, secondary, p.root_id[pi])
		return 0
	return _primary(w, spec, m, p.root_id[pi], to, ang, dmg, secondary)


## A bomb's own blast and what follows it (a mine's, a drop's and a thrown bomb's alike). -1: merged into a blast
## already set off this tick (no follow-ups).
static func _primary(
	w: World, spec: AttackSpec, m: int, root: int, at: Vector2, ang: int, dmg: int, secondary: bool
) -> int:
	var r := Bomb.radius_m(w, spec)
	var landed := Bomb.burst(w, spec, root, at, r, dmg, secondary)
	if landed >= 0:
		_follow(w, spec, m, at, ang, r, dmg)
	return landed


## The rows a blast of `r` m and `dmg` leaves: Ring, Echo, Split's bomblets.
static func _follow(
	w: World, spec: AttackSpec, m: int, at: Vector2, ang: int, r: float, dmg: int
) -> void:
	var r_mm := int(round(r * 1000.0))
	if m & RING:
		var ring := int(round(Stats.area(w, mm(param(w, "ring_mm"))) * 1000.0))
		var due := w.tick + ticks(param(w, "ring_ms"))
		_add(w, K_RING | SEC, at, due, ring, share(dmg, param(w, "ring_share")), ang, w.take_root())
	if m & ECHO:
		var due := w.tick + ticks(param(w, "echo_delay_ms"))
		_add(
			w, K_BURST | SEC, at, due, r_mm, share(dmg, param(w, "echo_share")), ang, w.take_root()
		)
	if m & SPLIT:
		var n := bomblet_count(spec)
		var small := int(round(Stats.area(w, mm(param(w, "split_blast_mm"))) * 1000.0))
		var due := w.tick + ticks(param(w, "split_fuse_ms"))
		for k in n:
			var a := (ang + k * SimTick.ANGLE_UNITS / n) & 4095
			var to := clear_point(w, at, Kin.dir(a), mm(param(w, "split_dist_mm")))
			var d := share(dmg, param(w, "split_share"))
			_add(w, K_BURST | SEC, to, due, small, d, a, w.take_root())


## Mine: the bomb waits at `at`; a 6th (mine_max + 1) sets the oldest off.
static func _place_mine(
	w: World, spec: AttackSpec, m: int, at: Vector2, ang: int, dmg: int, secondary: bool, root: int
) -> void:
	var s := w.mx
	var live := 0
	var oldest := -1
	for k in s.bm_kind.size():
		if s.bm_kind[k] & KIND_MASK == K_MINE:
			live += 1
			if oldest < 0:
				oldest = k
	if live >= param(w, "mine_max") and oldest >= 0:
		_fire(w, spec, m, oldest)
	var due := w.tick + ticks(param(w, "mine_life_ms"))
	var r_mm := int(round(Bomb.radius_m(w, spec) * 1000.0))
	_add(w, K_MINE | (SEC if secondary else 0), at, due, r_mm, dmg, ang, root)


# --- Geometry -------------------------------------------------------------------------------------------------------
## The farthest point of the way from `from` along `dir` for `dist` m before a wall: {at, s (0..1 of the way), k (the
## wall's index or -1)}.
static func _way(w: World, from: Vector2, dir: Vector2, dist: float) -> Dictionary:
	var to := from + dir * dist
	var s := 1.0
	var wk := -1
	for k in w.walls_along(from, to, SKIP_R):
		var t := Collide.sweep_vs_obb(from, to, SKIP_R, w.walls[k])
		if t >= 0.0 and t < s:
			s = t
			wk = k
	return {"at": from + (to - from) * s, "s": s, "k": wk}


## `dist` m on from `from` along `dir`, stopped by a wall.
static func clear_point(w: World, from: Vector2, dir: Vector2, dist: float) -> Vector2:
	return _way(w, from, dir, dist)["at"]


## Ricochet: the landing point `from` skips `dist` m further along `dir` (its travel); a wall in the way stops the skip.
static func skip(w: World, from: Vector2, dir: Vector2, dist: float) -> Vector2:
	return clear_point(w, from, dir, dist)


## Homing: the position of the nearest enemy within home_range_mm of `at` (a tie keeps the lower index), else `at`.
static func home(w: World, at: Vector2) -> Vector2:
	var best := -1
	var best_d := 0.0
	for i in w.enemies_near(at, mm(param(w, "home_range_mm"))):
		var d := Kin.length(w.actors.pos(i) - at)
		if best < 0 or d < best_d:
			best = i
			best_d = d
	return w.actors.pos(best) if best >= 0 else at


# --- Rows -----------------------------------------------------------------------------------------------------------
static func _add(
	w: World, kind: int, at: Vector2, due: int, r_mm: int, dmg: int, ang: int, root: int
) -> void:
	var s := w.mx
	if s.bm_kind.size() >= ROWS_MAX:
		return
	s.bm_next += 1
	s.bm_id.append(s.bm_next)
	s.bm_kind.append(kind)
	s.bm_at.append(at)
	s.bm_due.append(due)
	s.bm_born.append(w.tick)
	s.bm_r.append(r_mm)
	s.bm_dmg.append(dmg)
	s.bm_ang.append(ang)
	s.bm_root.append(root)


static func _remove(s: ModifierState, k: int) -> void:
	var id: int = s.bm_id[k]
	s.bm_id.remove_at(k)
	s.bm_kind.remove_at(k)
	s.bm_at.remove_at(k)
	s.bm_due.remove_at(k)
	s.bm_born.remove_at(k)
	s.bm_r.remove_at(k)
	s.bm_dmg.remove_at(k)
	s.bm_ang.remove_at(k)
	s.bm_root.remove_at(k)
	if s.bm_kind.is_empty():
		s.bm_clear()
		return
	var keep := PackedInt32Array()
	for key in s.bm_hit:
		if (key >> 16) != id:
			keep.append(key)
	s.bm_hit = keep


## Row `k` goes off (and is removed): a blast, and for a drop or a mine its follow-ups.
static func _fire(w: World, spec: AttackSpec, m: int, k: int) -> void:
	var s := w.mx
	var kind: int = s.bm_kind[k]
	var at: Vector2 = s.bm_at[k]
	var r: float = s.bm_r[k] / 1000.0
	var dmg: int = s.bm_dmg[k]
	var ang: int = s.bm_ang[k]
	var root: int = s.bm_root[k]
	_remove(s, k)
	var sec := kind & SEC != 0
	if kind & KIND_MASK == K_BURST:
		Bomb.burst(w, spec, root, at, r, dmg, true)
		return
	var landed := Bomb.burst(w, spec, root, at, r, dmg, sec)
	if landed >= 0:
		_follow(w, spec, m, at, ang, r, dmg)


# --- State, each tick -----------------------------------------------------------------------------------------------
## Tick phase 6 (ModifierRuntime.advance): the rows whose time has come go off, a mine whose enemy is near goes off, a
## ring grows and hits. Rows of a build that is no bomb any more are dropped.
static func advance(w: World) -> void:
	var s := w.mx
	if s.bm_kind.is_empty():
		return
	var spec := Modifiers.bolt(w) if PlayerBuild.has_gun(w) else null
	if spec == null or spec.blast_mm <= 0:
		s.bm_clear()
		return
	var m := mask(spec)
	var trig := mm(param(w, "mine_trigger_mm"))
	var k := 0
	while k < s.bm_kind.size():
		var kind: int = s.bm_kind[k] & KIND_MASK
		var due: int = s.bm_due[k]
		if kind == K_RING:
			if _ring(w, spec, k):
				continue  # removed
		elif kind == K_MINE:
			if w.tick >= due or not w.enemies_near(s.bm_at[k], trig).is_empty():
				_fire(w, spec, m, k)
				continue
		elif w.tick >= due:
			_fire(w, spec, m, k)
			continue
		k += 1


## Ring row `k` this tick: its radius, the enemies it newly reaches; true if it ended (removed).
static func _ring(w: World, spec: AttackSpec, k: int) -> bool:
	var s := w.mx
	var at: Vector2 = s.bm_at[k]
	var born: int = s.bm_born[k]
	var due: int = s.bm_due[k]
	var span := maxi(1, due - born)
	var id: int = s.bm_id[k]
	var now := mini(w.tick - born, span)
	if now > 0:
		var r := mm(int(s.bm_r[k]) * now / span)
		var c := AttackContext.make(at, 0, s.bm_dmg[k], s.bm_root[k], SimEvent.TAG_AREA, &"")
		c.depth = spec.depth
		c.proc_pct = maxi(1, 100 >> spec.depth)
		c.secondary = true
		for i in w.enemies_near(at, r):
			var key := id * 65536 + i
			if s.bm_hit.has(key):
				continue
			s.bm_hit.append(key)
			Attacks.land(w, spec, c, i, at, w.actors.pos(i))
	if w.tick >= due:
		_remove(s, k)
		return true
	return false
