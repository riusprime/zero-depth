class_name VoidMods
extends RefCounted
## v0.9.5 FC3 (docs/roadmap/v0.9.5/FORM_COMBOS.md V1-V10): what ten cards do to the Void form. One handler per card.
## A void ignores these cards' generic ops (WandCompile.run: it only notes the id in modifier_ids, and Split's level as
## "bomblets:N"), and this file reads them from there: mask(spec).
## - At the throw (Attacks._bolts): Big Shot's +20 % damage and 30 % slower flight, Rapid Fire's 0.7 damage and half
##   life (damage_permille(), speed(), life()), Ricochet's wall bounces (bounces(), the world's own wall pass reflects
##   the shot), Orbit's extra second of life, Backfire's second void thrown behind (back_throw()).
## - At the spawn (World._apply_spawns -> on_spawn): a void with cards gets a row (kind K_SHOT) holding its aura and
##   pull radius (Big Shot's, Rapid Fire's) and its steering state.
## - In flight (ProjectileMoves.steer -> steer()): Orbit circles the hero once, Homing turns toward the densest group,
##   Mine stops it at the aim point for mine_hold_ms.
## - At its end (Attacks.on_projectile_end -> on_end): Ring queues a growing lightning ring (K_RING), Echo and Split
##   queue stationary voids (K_SPAWN rows, opened by advance() on the next tick). Those voids start no follow-ups.
## - Bounded: at most live_max voids per hero (the oldest ends first); no void pulls a boss (VoidShots.pull_permille).
## - Rows (World.mx vm_*), at most ROWS_MAX; hashed only while any is set (older digests unchanged).
## - Numbers: data/wand/attack_slots.tres, the void row's `params` (SlotTable.params); DEFAULTS are the same values,
##   read by a world without the table (a lab) and checked against the data by the content test.
## Pure: integer maths (angles in 1/4096 turns, Kin), no randomness, one clock.

const RING := 1
const BACKFIRE := 2
const RICOCHET := 4
const HOMING := 8
const ECHO := 16
const BIG := 32
const RAPID := 64
const SPLIT := 128
const MINE := 256
const ORBIT := 512
## The cards by bit.
const CARD_IDS: Array[StringName] = [
	&"gun_ring",
	&"gun_backfire",
	&"gun_ricochet",
	&"gun_homing",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"split_shot",
	&"gun_mine",
	&"orbit_rounds",
]
const CARD_BITS: Array[int] = [
	RING, BACKFIRE, RICOCHET, HOMING, ECHO, BIG, RAPID, SPLIT, MINE, ORBIT
]
## What a row is (vm_kind & KIND_MASK): a live void's state, a void to open, a ring growing.
const K_SHOT := 0
const K_SPAWN := 1
const K_RING := 2
const KIND_MASK := 3
## Row flags (vm_kind): the void starts no follow-ups; its mine holds; its orbit is done; it has a homing target.
const F_NOFOLLOW := 4
const F_STOPPED := 8
const F_ORBITED := 16
const F_TARGET := 32
const KIND_NAMES: Array[StringName] = [&"shot", &"spawn", &"ring"]
const ROWS_MAX := 64
const HZ := 60
const BOMBLETS := "bomblets:"
## The void row's numbers (units in the names; data/wand/attack_slots.tres carries the same).
const DEFAULTS := {
	"ring_mm": 3000,
	"ring_ms": 300,
	"ring_share": 600,
	"ring_ticks": 5,
	"back_share": 1000,
	"ricochet_bounces": 64,
	"home_range_mm": 6000,
	"home_group_mm": 2000,
	"home_every_ms": 500,
	"home_turn_dps": 90,
	"echo_share": 600,
	"echo_life": 500,
	"echo_aura": 500,
	"echo_pull": 500,
	"big_aura_mm": 1300,
	"big_pull_mm": 4000,
	"big_speed": 700,
	"big_damage": 1200,
	"rapid_period_ms": 400,
	"rapid_life": 500,
	"rapid_aura_mm": 700,
	"rapid_damage": 700,
	"split_dist_mm": 1500,
	"split_life_ms": 1000,
	"split_share": 400,
	"split_aura_mm": 600,
	"split_pull_mm": 1800,
	"mine_hold_ms": 3000,
	"orbit_mm": 2500,
	"orbit_ms": 1000,
	"live_max": 6,
}


# --- Cards and numbers --------------------------------------------------------------------------------------------
## The bit mask of the Void cards the void `spec` carries (0: a plain Void, or not a void: nothing here runs).
static func mask(spec: AttackSpec) -> int:
	if spec == null or spec.void_mm <= 0 or spec.modifier_ids.is_empty():
		return 0
	var m := 0
	for k in CARD_IDS.size():
		if spec.modifier_ids.has(String(CARD_IDS[k])):
			m |= CARD_BITS[k]
	return m


## `id` is one of the ten cards (WandCompile.run: on a void its generic ops are skipped).
static func is_card(id: StringName) -> bool:
	return CARD_IDS.has(id)


## Card `m` stands on the void `s` (WandCompile.run): its id is noted; Split also notes its level's minis.
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


## Split's mini voids an ending (its level: 2, 3 or 4).
static func mini_count(spec: AttackSpec) -> int:
	for id in spec.modifier_ids:
		if id.begins_with(BOMBLETS):
			return clampi(int(id.substr(BOMBLETS.length())), 1, 8)
	return 2


## The void row's number `key` (data, else the default).
static func param(w: World, key: String) -> int:
	var t := w.slot_table
	if t != null:
		var p: Dictionary = t.params.get(&"void", {})
		if p.has(key):
			return int(p[key])
	return int(DEFAULTS[key])


static func ticks(ms: int) -> int:
	return maxi(1, ms * HZ / 1000)


static func mm(v: int) -> float:
	return v / 1000.0


static func share(dmg: int, permille: int) -> int:
	return maxi(1, dmg * permille / 1000)


## The damage factor (per mille): Big Shot's +20 % (FC4: was +60 %), Rapid Fire's 0.7 a tick.
static func damage_permille(w: World, m: int) -> int:
	var f := 1000
	if m & BIG:
		f = f * param(w, "big_damage") / 1000
	if m & RAPID:
		f = f * param(w, "rapid_damage") / 1000
	return f


## The flight speed: Big Shot's 30 % slower.
static func speed(w: World, spec: AttackSpec) -> float:
	if mask(spec) & BIG == 0:
		return spec.speed
	return spec.speed * param(w, "big_speed") / 1000.0


## The life (ticks) of a void thrown from `spec`: Rapid Fire's half, Orbit's lap on top.
static func life(w: World, spec: AttackSpec) -> int:
	var l := flight_life(w, spec)
	if mask(spec) & ORBIT:
		l += ticks(param(w, "orbit_ms"))
	return l


## The life (ticks) of a void of `spec` without Orbit's lap: Rapid Fire's half.
static func flight_life(w: World, spec: AttackSpec) -> int:
	var l := spec.life_ticks
	if mask(spec) & RAPID:
		l = maxi(1, l * param(w, "rapid_life") / 1000)
	return l


## Ricochet: the wall bounces a void is thrown with (the world's wall pass reflects it, its life unchanged).
static func bounces(w: World, spec: AttackSpec) -> int:
	return param(w, "ricochet_bounces") if mask(spec) & RICOCHET else spec.bounces


## Rapid Fire: the throw period `base` (ticks) of the plain 0.6 s becomes rapid_period_ms.
static func period(w: World, spec: AttackSpec, base: int) -> int:
	if mask(spec) & RAPID == 0 or spec.period_ticks <= 0:
		return base
	return maxi(1, base * ticks(param(w, "rapid_period_ms")) / spec.period_ticks)


## The aura radius (mm, before the area stat) of the void projectile `sid`: its row's, else the spec's.
static func aura_mm(w: World, spec: AttackSpec, sid: int) -> int:
	var s := w.mx
	if not s.vm_kind.is_empty():
		var k := row_of(s, sid)
		if k >= 0 and s.vm_aura[k] > 0:
			return s.vm_aura[k]
	return spec.void_mm


## The pull radius (mm) of the void projectile `sid`.
static func pull_mm(w: World, spec: AttackSpec, sid: int) -> int:
	var s := w.mx
	if not s.vm_kind.is_empty():
		var k := row_of(s, sid)
		if k >= 0 and s.vm_pull[k] > 0:
			return s.vm_pull[k]
	return spec.void_pull_mm


## The aura and the pull (mm) a fresh void of `spec` has with its cards.
static func radii(w: World, spec: AttackSpec) -> Vector2i:
	var m := mask(spec)
	var a := spec.void_mm
	var p := spec.void_pull_mm
	if m & BIG:
		a = param(w, "big_aura_mm")
		p = param(w, "big_pull_mm")
	if m & RAPID:
		a = a * param(w, "rapid_aura_mm") / maxi(1, spec.void_mm)
	return Vector2i(a, p)


# --- The throw ------------------------------------------------------------------------------------------------------
## Backfire: a second void thrown straight behind the player's own throw (Attacks._bolts, once a volley), at
## back_share of its damage. `gap`: the muzzle distance; the others are the throw's.
static func back_throw(
	w: World, spec: AttackSpec, ctx: AttackContext, dmg: int, r: float, gap: float
) -> void:
	var dir := -Kin.dir(ctx.angle)
	var to := ctx.origin + dir * gap
	w.queue_projectile(
		w.actors.ids[0],
		ActorStore.TEAM_PLAYER,
		to,
		dir * speed(w, spec),
		share(dmg, param(w, "back_share")),
		r,
		maxi(1, life(w, spec)),
		ctx.tags,
		bounces(w, spec),
		spec.key
	)
	w.set_pending_second(ProjectileStore.SECONDARY)


## FC4 (V9): with Mine, only one void at a time: the Void does not fire while one is out (flying or held).
static func held(w: World) -> bool:
	var s := w.mx
	if s.vm_kind.is_empty() or mask(Modifiers.bolt(w)) & MINE == 0:
		return false
	for k in s.vm_kind.size():
		if s.vm_kind[k] & KIND_MASK == K_SHOT:
			return true
	return false


# --- Rows -----------------------------------------------------------------------------------------------------------
## The row of void projectile `sid` (a K_SHOT), or -1.
static func row_of(s: ModifierState, sid: int) -> int:
	for k in s.vm_kind.size():
		if s.vm_kind[k] & KIND_MASK == K_SHOT and s.vm_pid[k] == sid:
			return k
	return -1


static func _add(
	w: World, kind: int, pid: int, at: Vector2, due: int, dmg: int, ang: int, root: int
) -> int:
	var s := w.mx
	if s.vm_kind.size() >= ROWS_MAX:
		return -1
	s.vm_next += 1
	s.vm_id.append(s.vm_next)
	s.vm_kind.append(kind)
	s.vm_pid.append(pid)
	s.vm_at.append(at)
	s.vm_stop.append(Vector2.ZERO)
	s.vm_due.append(due)
	s.vm_born.append(w.tick)
	s.vm_ang.append(ang)
	s.vm_aura.append(0)
	s.vm_pull.append(0)
	s.vm_dmg.append(dmg)
	s.vm_life.append(0)
	s.vm_r.append(0)
	s.vm_root.append(root)
	return s.vm_kind.size() - 1


static func _remove(s: ModifierState, k: int) -> void:
	var id: int = s.vm_id[k]
	s.vm_id.remove_at(k)
	s.vm_kind.remove_at(k)
	s.vm_pid.remove_at(k)
	s.vm_at.remove_at(k)
	s.vm_stop.remove_at(k)
	s.vm_due.remove_at(k)
	s.vm_born.remove_at(k)
	s.vm_ang.remove_at(k)
	s.vm_aura.remove_at(k)
	s.vm_pull.remove_at(k)
	s.vm_dmg.remove_at(k)
	s.vm_life.remove_at(k)
	s.vm_r.remove_at(k)
	s.vm_root.remove_at(k)
	if s.vm_kind.is_empty():
		s.vm_clear()
		return
	var keep := PackedInt32Array()
	for key in s.vm_hit:
		if (key >> 16) != id:
			keep.append(key)
	s.vm_hit = keep


## Void projectile `pi` just spawned (World._apply_spawns): with cards it gets its row (radii, state).
static func on_spawn(w: World, pi: int) -> void:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER:
		return
	var spec := Attacks.projectile_spec(w, pi)
	var m := mask(spec)
	if m == 0:
		return
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var sp := Kin.length(v)
	var ang := Kin.angle_of(v)
	var k := _add(w, K_SHOT, p.ids[pi], Vector2.ZERO, w.tick, 0, ang, p.root_id[pi])
	if k < 0:
		return
	var s := w.mx
	var r := radii(w, spec)
	s.vm_aura[k] = r.x
	s.vm_pull[k] = r.y
	if m & (HOMING | MINE | ORBIT) == 0:
		return
	p.moves = true
	p.speed[pi] = sp
	if m & MINE:
		var flight := (
			sp * float(maxi(1, p.life[pi] - (ticks(param(w, "orbit_ms")) if m & ORBIT else 0)))
		)
		var d := clampf(w.aim_dist_cm / 100.0, 0.5, maxf(0.5, flight - 0.5))
		s.vm_stop[k] = w.player_pos() + Kin.dir(ang) * d


# --- Flight ---------------------------------------------------------------------------------------------------------
## Before void projectile `pi`'s sweep (ProjectileMoves.steer): Orbit's lap, Mine's stop, Homing's turn.
static func steer(w: World, pi: int) -> void:
	var s := w.mx
	if s.vm_kind.is_empty():
		return
	var p := w.projectiles
	var k := row_of(s, p.ids[pi])
	if k < 0 or s.vm_kind[k] & F_STOPPED:
		return
	var m := mask(Attacks.projectile_spec(w, pi))
	var at := Vector2(p.pos_x[pi], p.pos_y[pi])
	var sp: float = p.speed[pi]
	var ang: int = s.vm_ang[k]
	if m & ORBIT and not s.vm_kind[k] & F_ORBITED:
		var n := ticks(param(w, "orbit_ms"))
		var done := w.tick - s.vm_born[k]
		if done <= n:
			var a := (ang + done * SimTick.ANGLE_UNITS / n) & 4095
			var chord := w.player_pos() + Kin.dir(a) * mm(param(w, "orbit_mm")) - at
			p.vel_x[pi] = chord.x
			p.vel_y[pi] = chord.y
			return
		var out := Kin.dir(ang) * sp
		p.vel_x[pi] = out.x
		p.vel_y[pi] = out.y
		s.vm_kind[k] |= F_ORBITED
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	if m & MINE and (at + v - s.vm_stop[k]).dot(Kin.dir(ang)) >= 0.0:
		p.pos_x[pi] = s.vm_stop[k].x
		p.pos_y[pi] = s.vm_stop[k].y
		p.vel_x[pi] = 0.0
		p.vel_y[pi] = 0.0
		p.life[pi] = ticks(param(w, "mine_hold_ms"))
		s.vm_kind[k] |= F_STOPPED
		return
	if m & HOMING and sp > 0.0:
		_home(w, pi, k, at, sp)


## Homing: every home_every_ms the target is the enemy with most enemies within home_group_mm of it, among those
## within home_range_mm of the void (a tie keeps the lower index); the void turns toward it at home_turn_dps.
static func _home(w: World, pi: int, k: int, at: Vector2, sp: float) -> void:
	var s := w.mx
	var p := w.projectiles
	if w.tick >= s.vm_due[k]:
		s.vm_due[k] = w.tick + ticks(param(w, "home_every_ms"))
		var best := densest(w, at)
		if best >= 0:
			s.vm_at[k] = w.actors.pos(best)
			s.vm_kind[k] |= F_TARGET
		else:
			s.vm_kind[k] &= ~F_TARGET
	if not s.vm_kind[k] & F_TARGET:
		return
	var step := SimTick.ANGLE_UNITS * param(w, "home_turn_dps") / (360 * HZ)
	var want := Kin.angle_of(s.vm_at[k] - at)
	var cur := Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))
	var nv := Kin.dir(Kin.turn_toward(cur, want, step)) * sp
	p.vel_x[pi] = nv.x
	p.vel_y[pi] = nv.y


## The enemy within home_range_mm of `at` with the most enemies within home_group_mm of it (itself counted), or -1.
static func densest(w: World, at: Vector2) -> int:
	var best := -1
	var best_n := 0
	var group := mm(param(w, "home_group_mm"))
	for i in w.enemies_near(at, mm(param(w, "home_range_mm"))):
		if w.actors.invuln[i] > 0:
			continue
		var n := w.enemies_near(w.actors.pos(i), group).size()
		if n > best_n:
			best = i
			best_n = n
	return best


# --- The end --------------------------------------------------------------------------------------------------------
## Void projectile `pi` of `spec` ended at `at` (Attacks.on_projectile_end): its row goes; Ring, Echo and Split queue.
static func on_end(w: World, spec: AttackSpec, pi: int, at: Vector2) -> void:
	var s := w.mx
	if s.vm_kind.is_empty():
		return
	var p := w.projectiles
	var k := row_of(s, p.ids[pi])
	if k < 0:
		return
	var flags: int = s.vm_kind[k]
	var aura: int = s.vm_aura[k]
	var pull: int = s.vm_pull[k]
	var ang: int = s.vm_ang[k]
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	if Kin.length(v) > 0.0:
		ang = Kin.angle_of(v)
	_remove(s, k)
	var m := mask(spec)
	if flags & F_NOFOLLOW or m & (RING | ECHO | SPLIT) == 0:
		return
	var dmg: int = p.damage[pi]
	if m & RING:
		var r := int(round(Stats.area(w, mm(param(w, "ring_mm"))) * 1000.0))
		var due := w.tick + ticks(param(w, "ring_ms"))
		var d := share(dmg * param(w, "ring_ticks"), param(w, "ring_share"))
		var j := _add(w, K_RING, 0, at, due, d, ang, w.take_root())
		if j >= 0:
			s.vm_r[j] = r
	if m & ECHO:
		var j := _add(
			w, K_SPAWN, 0, at, w.tick, share(dmg, param(w, "echo_share")), ang, w.take_root()
		)
		if j >= 0:
			s.vm_life[j] = maxi(1, flight_life(w, spec) * param(w, "echo_life") / 1000)
			s.vm_aura[j] = maxi(1, aura * param(w, "echo_aura") / 1000)
			s.vm_pull[j] = maxi(1, pull * param(w, "echo_pull") / 1000)
	if m & SPLIT:
		var n := mini_count(spec)
		for q in n:
			var a := (ang + q * SimTick.ANGLE_UNITS / n) & 4095
			var to := BombMods.clear_point(w, at, Kin.dir(a), mm(param(w, "split_dist_mm")))
			var j := _add(
				w, K_SPAWN, 0, to, w.tick, share(dmg, param(w, "split_share")), a, w.take_root()
			)
			if j >= 0:
				s.vm_life[j] = ticks(param(w, "split_life_ms"))
				s.vm_aura[j] = param(w, "split_aura_mm")
				s.vm_pull[j] = param(w, "split_pull_mm")


# --- State, each tick -----------------------------------------------------------------------------------------------
## Tick phase 6 (ModifierRuntime.advance): the cap, the voids to open, the rings, the rows of voids that are gone.
static func advance(w: World) -> void:
	var s := w.mx
	var spec := Modifiers.bolt(w) if PlayerBuild.has_gun(w) else null
	if spec == null or spec.void_mm <= 0:
		if not s.vm_kind.is_empty():
			s.vm_clear()
		return
	if s.vm_kind.is_empty():
		cull(w)
		return
	var ids := w.projectiles.ids
	var k := 0
	while k < s.vm_kind.size():
		var kind: int = s.vm_kind[k] & KIND_MASK
		if kind == K_SHOT:
			var at := ids.bsearch(s.vm_pid[k])
			if at >= ids.size() or ids[at] != s.vm_pid[k]:
				_remove(s, k)  # its void is gone without ending here (a new room): no follow-ups
				continue
		elif kind == K_SPAWN:
			if w.tick >= s.vm_due[k]:
				_open(w, spec, k)
				continue
		elif kind == K_RING:
			if _ring(w, spec, k):
				continue
		k += 1
	cull(w)


## Row `k` (a K_SPAWN) opens a stationary void and goes.
static func _open(w: World, spec: AttackSpec, k: int) -> void:
	var s := w.mx
	var at: Vector2 = s.vm_at[k]
	var dmg: int = s.vm_dmg[k]
	var life_ticks: int = s.vm_life[k]
	var aura: int = s.vm_aura[k]
	var pull: int = s.vm_pull[k]
	var ang: int = s.vm_ang[k]
	var root: int = s.vm_root[k]
	_remove(s, k)
	var p := w.projectiles
	var id := w.take_id()
	p.add(
		id,
		w.actors.ids[0],
		ActorStore.TEAM_PLAYER,
		at,
		Vector2.ZERO,
		spec.radius_m,
		life_ticks,
		dmg,
		SimEvent.TAG_PROJECTILE,
		0
	)
	var pi := p.size() - 1
	p.spec_key[pi] = spec.key
	p.set_second(pi, ProjectileStore.SECONDARY)
	var j := _add(w, K_SHOT | F_NOFOLLOW, id, Vector2.ZERO, w.tick, 0, ang, root)
	if j >= 0:
		s.vm_aura[j] = aura
		s.vm_pull[j] = pull


## Ring row `k` this tick: its radius, the enemies it newly reaches; true if it ended (removed).
static func _ring(w: World, spec: AttackSpec, k: int) -> bool:
	var s := w.mx
	var at: Vector2 = s.vm_at[k]
	var born: int = s.vm_born[k]
	var due: int = s.vm_due[k]
	var span := maxi(1, due - born)
	var id: int = s.vm_id[k]
	var now := mini(w.tick - born, span)
	if now > 0:
		var r := mm(int(s.vm_r[k]) * now / span)
		var c := AttackContext.make(at, 0, s.vm_dmg[k], s.vm_root[k], SimEvent.TAG_AREA, &"")
		c.depth = spec.depth
		c.proc_pct = maxi(1, 100 >> spec.depth)
		c.secondary = true
		for i in w.enemies_near(at, r):
			var key := id * 65536 + i
			if s.vm_hit.has(key):
				continue
			s.vm_hit.append(key)
			Attacks.land(w, spec, c, i, at, w.actors.pos(i))
	if w.tick >= due:
		_remove(s, k)
		return true
	return false


## The player's void projectiles (indices, ascending) now.
static func _live(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for pi in w.projectiles.size():
		if VoidShots.is_void_projectile(w, pi):
			out.append(pi)
	return out


## At most live_max voids a hero: the oldest end first (as they end: their follow-ups queue).
static func cull(w: World) -> void:
	if w.projectiles.size() <= param(w, "live_max") or not PlayerBuild.has_gun(w):
		return
	var live := _live(w)
	var over := live.size() - param(w, "live_max")
	if over <= 0:
		return
	var p := w.projectiles
	var gone := PackedInt32Array()
	for q in over:
		var pi := live[q]
		gone.append(pi)
		Attacks.on_projectile_end(w, pi, Vector2(p.pos_x[pi], p.pos_y[pi]))
	p.remove_sorted(gone)


## The rings growing, for the view: [{pos, r (m, the ring's largest), age, span}].
static func read_rings(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := w.mx
	for k in s.vm_kind.size():
		if s.vm_kind[k] & KIND_MASK == K_RING:
			(
				out
				. append(
					{
						"pos": s.vm_at[k],
						"r": s.vm_r[k] / 1000.0,
						"age": w.tick - s.vm_born[k],
						"span": maxi(1, s.vm_due[k] - s.vm_born[k]),
					}
				)
			)
	return out
