class_name GlaiveMods
extends RefCounted
## v0.9.5 FC6 (docs/roadmap/v0.9.5/FORM_COMBOS.md G1-G11): what eleven cards do to the Glaive form. One handler per
## card. A disc ignores these cards' generic ops (WandCompile.run: it only notes the id in modifier_ids), and this file
## reads them from there: mask(spec).
## - At the throw (Attacks._bolts): Halo's four discs round the aim (halo_offsets()), Big Shot's and Rapid Fire's size,
##   speed and damage (wide(), speed(), damage_permille()), Orbit's lap on top of the life (life()), Ricochet's wall
##   bounces (bounces()), Backfire's disc thrown behind (back_throw()), Echo's ghost disc waiting as a row (add_echo()).
##   Rapid Fire's throw period is period() (ItemEffects.shot_period_ticks).
## - At the spawn (World._apply_spawns -> on_spawn): a disc with cards gets a K_BALL row (its heading, Mine's and
##   Orbit's state, Homing's outward target).
## - In flight: steer() (ProjectileMoves.steer, before the return rule) runs Orbit's lap and Mine's hold; steer_after()
##   (after it) bends the disc for Homing, out and back, and drops Ricochet's bounces once it turns home; hold()
##   (World._projectile_hits) lets a held Mine disc spin in place and hit; on_hit() (World._projectile_hits) makes
##   Split shed its two small discs.
## - Each tick (advance()): the ghosts and small discs to open, Ring's hits round every live disc, the rows of discs
##   that are gone, and the bound: at most live_max live discs a hero (cull(): the oldest end first).
## - Rows (World.mx gm_*), at most ROWS_MAX; hashed only while any is set (older digests unchanged).
## - Numbers: data/wand/attack_slots.tres, the glaive row's `params` (SlotTable.params); DEFAULTS are the same values,
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
const ORBIT := 1024
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
	&"orbit_rounds",
]
const CARD_BITS: Array[int] = [
	HALO, RING, BACKFIRE, RICOCHET, HOMING, ECHO, BIG, RAPID, SPLIT, MINE, ORBIT
]
## What a row is (gm_kind & KIND_MASK): a live disc's state, a disc to open (an Echo ghost, a Split small disc).
const K_BALL := 0
const K_OPEN := 1
const KIND_MASK := 3
## Row flags (gm_kind): the disc starts no follow-ups (a ghost, a small disc); it is a Split small disc (no return,
## no cards of its own); it has shed its small discs; its Mine is holding; its Mine has held; its Orbit lap is done.
const F_NOFOLLOW := 4
const F_SMALL := 8
const F_SPLIT := 16
const F_HELD := 32
const F_MINED := 64
const F_ORBITED := 128
const ROWS_MAX := 64
const HZ := 60
## A small disc pierces everything on its 4 m (it has no return rule to carry it through).
const SMALL_PIERCE := 99
## The glaive row's numbers (units in the names; data/wand/attack_slots.tres carries the same).
const DEFAULTS := {
	"halo_count": 4,
	"halo_share": 500,
	"ring_mm": 1000,
	"ring_share": 400,
	"ring_gap_ticks": 30,
	"back_share": 1000,
	"ricochet_bounces": 2,
	"home_range_mm": 6000,
	"home_turn_dps": 90,
	"home_cone_deg": 90,
	"home_back_ms": 1000,
	"echo_delay_ms": 300,
	"echo_share": 500,
	"big_wide": 1500,
	"big_speed": 750,
	"big_damage": 1600,
	"rapid_period_ms": 450,
	"rapid_wide": 700,
	"rapid_speed": 1250,
	"rapid_damage": 700,
	"split_deg": 30,
	"split_len_mm": 4000,
	"split_share": 300,
	"split_wide": 700,
	"mine_hold_ms": 1200,
	"mine_gap_ticks": 30,
	"orbit_mm": 2500,
	"orbit_ms": 1000,
	"live_max": 8,
}


# --- Cards and numbers --------------------------------------------------------------------------------------------
## The bit mask of the Glaive cards the disc `spec` carries (0: a plain Glaive, or not a glaive: nothing here runs).
static func mask(spec: AttackSpec) -> int:
	if spec == null or spec.glaive <= 0 or spec.modifier_ids.is_empty():
		return 0
	var m := 0
	for k in CARD_IDS.size():
		if spec.modifier_ids.has(String(CARD_IDS[k])):
			m |= CARD_BITS[k]
	return m


## `id` is one of the eleven cards (WandCompile.run: on a glaive its generic ops are skipped).
static func is_card(id: StringName) -> bool:
	return CARD_IDS.has(id)


## Card `m` stands on the glaive `s` (WandCompile.run): its id is noted.
static func note_card(s: AttackSpec, m: ModifierTable) -> void:
	if not s.modifier_ids.has(String(m.id)):
		s.modifier_ids.append(String(m.id))


## The glaive row's number `key` (data, else the default).
static func param(w: World, key: String) -> int:
	var t := w.slot_table
	if t != null:
		var p: Dictionary = t.params.get(&"glaive", {})
		if p.has(key):
			return int(p[key])
	return int(DEFAULTS[key])


static func ticks(ms: int) -> int:
	return maxi(1, ms * HZ / 1000)


static func mm(v: int) -> float:
	return v / 1000.0


static func share(dmg: int, permille: int) -> int:
	return maxi(1, dmg * permille / 1000)


## The damage factor (per mille) of a throw: Big Shot x 1.6, Rapid Fire x 0.7, Halo's 50 % each disc.
static func damage_permille(w: World, m: int) -> int:
	var f := 1000
	if m & BIG:
		f = f * param(w, "big_damage") / 1000
	if m & RAPID:
		f = f * param(w, "rapid_damage") / 1000
	if m & HALO:
		f = f * param(w, "halo_share") / 1000
	return f


## The disc's radius factor (per mille): Big Shot x 1.5, Rapid Fire x 0.7.
static func wide(w: World, m: int) -> int:
	var f := 1000
	if m & BIG:
		f = f * param(w, "big_wide") / 1000
	if m & RAPID:
		f = f * param(w, "rapid_wide") / 1000
	return f


## The flight speed of a disc of `spec` with cards `m`: Big Shot x 0.75, Rapid Fire x 1.25.
static func speed(w: World, spec: AttackSpec, m: int) -> float:
	var f := 1000
	if m & BIG:
		f = f * param(w, "big_speed") / 1000
	if m & RAPID:
		f = f * param(w, "rapid_speed") / 1000
	return spec.speed * f / 1000.0


## Orbit's lap (ticks) a disc flies before its flight.
static func lap_ticks(w: World, m: int) -> int:
	return ticks(param(w, "orbit_ms")) if m & ORBIT else 0


## The life (ticks) of a disc thrown from `spec`: its flight, with Orbit's lap on top.
static func life(w: World, spec: AttackSpec, m: int) -> int:
	return spec.life_ticks + lap_ticks(w, m)


## Ricochet: the wall bounces a disc is thrown with (they stop when it turns home).
static func bounces(w: World, m: int, base: int) -> int:
	return param(w, "ricochet_bounces") if m & RICOCHET else base


## Halo: the disc angles (offsets from the aim), every 360 / halo_count degrees, the first at the aim.
static func halo_offsets(w: World, m: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if m & HALO == 0:
		return out
	var n := maxi(1, param(w, "halo_count"))
	for k in n:
		out.append(k * SimTick.ANGLE_UNITS / n)
	return out


## Rapid Fire: the throw period `base` (ticks) of the plain 0.7 s becomes rapid_period_ms.
static func period(w: World, spec: AttackSpec, base: int) -> int:
	if mask(spec) & RAPID == 0 or spec.period_ticks <= 0:
		return base
	return maxi(1, base * ticks(param(w, "rapid_period_ms")) / spec.period_ticks)


# --- The throw ------------------------------------------------------------------------------------------------------
## Backfire: a second disc straight behind the player's own throw (Attacks._bolts, once), at back_share of its damage.
static func back_throw(
	w: World,
	spec: AttackSpec,
	ctx: AttackContext,
	dmg: int,
	r: float,
	gap: float,
	sp: float,
	life_ticks: int,
	bounce: int
) -> void:
	var dir := -Kin.dir(ctx.angle)
	w.queue_projectile(
		w.actors.ids[0],
		ActorStore.TEAM_PLAYER,
		ctx.origin + dir * gap,
		dir * sp,
		share(dmg, param(w, "back_share")),
		r,
		maxi(1, life_ticks),
		ctx.tags,
		bounce,
		spec.key
	)
	w.set_pending_second(ProjectileStore.SECONDARY)


## Echo: a ghost disc of the disc just thrown from `at` along `ang` (damage `dmg` before the share) waits.
static func add_echo(w: World, at: Vector2, ang: int, dmg: int, r: float, bounce: int) -> void:
	var j := _add(
		w,
		K_OPEN,
		0,
		at,
		w.tick + ticks(param(w, "echo_delay_ms")),
		share(dmg, param(w, "echo_share")),
		ang,
		w.take_root()
	)
	if j >= 0:
		w.mx.gm_r[j] = int(round(r * 1000.0))
		w.mx.gm_aux[j] = bounce


# --- Rows -----------------------------------------------------------------------------------------------------------
## The row of disc projectile `pid` (a K_BALL), or -1.
static func row_of(s: ModifierState, pid: int) -> int:
	for k in s.gm_kind.size():
		if s.gm_kind[k] & KIND_MASK == K_BALL and s.gm_pid[k] == pid:
			return k
	return -1


static func _add(
	w: World, kind: int, pid: int, at: Vector2, due: int, dmg: int, ang: int, root: int
) -> int:
	var s := w.mx
	if s.gm_kind.size() >= ROWS_MAX:
		return -1
	s.gm_next += 1
	s.gm_id.append(s.gm_next)
	s.gm_kind.append(kind)
	s.gm_pid.append(pid)
	s.gm_at.append(at)
	s.gm_due.append(due)
	s.gm_born.append(w.tick)
	s.gm_ang.append(ang)
	s.gm_dmg.append(dmg)
	s.gm_r.append(0)
	s.gm_aux.append(0)
	s.gm_aux2.append(0)
	s.gm_root.append(root)
	return s.gm_kind.size() - 1


static func _remove(s: ModifierState, k: int) -> void:
	var id: int = s.gm_id[k]
	s.gm_id.remove_at(k)
	s.gm_kind.remove_at(k)
	s.gm_pid.remove_at(k)
	s.gm_at.remove_at(k)
	s.gm_due.remove_at(k)
	s.gm_born.remove_at(k)
	s.gm_ang.remove_at(k)
	s.gm_dmg.remove_at(k)
	s.gm_r.remove_at(k)
	s.gm_aux.remove_at(k)
	s.gm_aux2.remove_at(k)
	s.gm_root.remove_at(k)
	if s.gm_kind.is_empty():
		s.gm_clear()
		return
	var q := 0
	while q < s.gm_hit_row.size():
		if absi(s.gm_hit_row[q]) == id:  # Ring's gaps are the row's id, Mine's its negative
			s.gm_hit_row.remove_at(q)
			s.gm_hit_actor.remove_at(q)
			s.gm_hit_until.remove_at(q)
		else:
			q += 1


## Row `k` has hit actor `aid` within its gap: it may not hit again until the gap ends.
static func _blocked(s: ModifierState, rid: int, aid: int) -> bool:
	for q in s.gm_hit_row.size():
		if s.gm_hit_row[q] == rid and s.gm_hit_actor[q] == aid:
			return true
	return false


## The hit gaps that have ended by tick `now` go.
static func _expire(s: ModifierState, now: int) -> void:
	var q := 0
	while q < s.gm_hit_row.size():
		if s.gm_hit_until[q] <= now:
			s.gm_hit_row.remove_at(q)
			s.gm_hit_actor.remove_at(q)
			s.gm_hit_until.remove_at(q)
		else:
			q += 1


## Disc projectile `pi` just spawned (World._apply_spawns): with cards it gets a K_BALL row.
static func on_spawn(w: World, pi: int) -> void:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER:
		return
	var spec := Attacks.projectile_spec(w, pi)
	var m := mask(spec)
	if m == 0:
		return
	var ang := Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))
	var k := _add(w, K_BALL, p.ids[pi], Vector2.ZERO, w.tick, 0, ang, p.root_id[pi])
	if k < 0:
		return
	w.mx.gm_r[k] = ang  # the launch heading: Orbit's lap starts and ends on it
	_lap(w, pi, m)


## Orbit's lap is flown before the flight: the life holds it, the turn-home clock (life0) does not.
static func _lap(w: World, pi: int, m: int) -> void:
	var p := w.projectiles
	if m & ORBIT != 0 and p.moves and pi < p.life0.size():
		p.life0[pi] = maxi(1, p.life0[pi] - lap_ticks(w, m))


# --- Flight ---------------------------------------------------------------------------------------------------------
## Before disc `pi`'s return rule (ProjectileMoves.steer): Orbit's lap, Mine's hold. True: its velocity is set for this
## tick (the return rule does not run).
static func steer(w: World, pi: int) -> bool:
	var s := w.mx
	if s.gm_kind.is_empty():
		return false
	var p := w.projectiles
	var k := row_of(s, p.ids[pi])
	if k < 0 or s.gm_kind[k] & F_SMALL:
		return false
	var m := mask(Attacks.projectile_spec(w, pi))
	var sp: float = p.speed[pi]
	if m & ORBIT and not s.gm_kind[k] & F_ORBITED:
		var n := ticks(param(w, "orbit_ms"))
		var done := w.tick - s.gm_born[k]
		var ang: int = s.gm_r[k]
		if done <= n:
			var a := (ang + done * SimTick.ANGLE_UNITS / n) & 4095
			var at := Vector2(p.pos_x[pi], p.pos_y[pi])
			var chord := w.player_pos() + Kin.dir(a) * mm(param(w, "orbit_mm")) - at
			p.vel_x[pi] = chord.x
			p.vel_y[pi] = chord.y
			return true
		var out := Kin.dir(ang) * sp
		p.vel_x[pi] = out.x
		p.vel_y[pi] = out.y
		s.gm_kind[k] |= F_ORBITED
	if m & MINE == 0:
		return false
	if s.gm_kind[k] & F_HELD:
		if w.tick < s.gm_due[k]:
			return true
		s.gm_kind[k] = (s.gm_kind[k] & ~F_HELD) | F_MINED  # the hold is over: the return rule turns it home
		return false
	if s.gm_kind[k] & F_MINED == 0 and p.ret[pi] == 1 and p.life[pi] * 2 <= p.life0[pi]:
		p.vel_x[pi] = 0.0
		p.vel_y[pi] = 0.0
		s.gm_due[k] = w.tick + ticks(param(w, "mine_hold_ms"))
		s.gm_kind[k] |= F_HELD
		return true
	return false


## After disc `pi`'s return rule (ProjectileMoves.steer): Ricochet's bounces end as it turns home; Homing bends it.
static func steer_after(w: World, pi: int) -> void:
	var s := w.mx
	if s.gm_kind.is_empty():
		return
	var p := w.projectiles
	var k := row_of(s, p.ids[pi])
	if k < 0 or s.gm_kind[k] & (F_SMALL | F_HELD):
		return
	var m := mask(Attacks.projectile_spec(w, pi))
	var back: bool = p.ret[pi] == 2
	if back and s.gm_aux2[k] == 0:
		s.gm_aux2[k] = w.tick  # the tick it turned home
		if m & RICOCHET:
			p.bounces[pi] = 0
	if m & HOMING == 0:
		return
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var sp: float = p.speed[pi]
	if sp <= 0.0 or v == Vector2.ZERO:
		return
	var cur: int = s.gm_ang[k] if back else Kin.angle_of(v)
	var want := -1
	if not back:
		want = _target(w, pi, cur, 0)
		if want >= 0:
			s.gm_aux[k] = w.actors.ids[want] + 1
	elif w.tick - s.gm_aux2[k] < ticks(param(w, "home_back_ms")):
		want = _target(w, pi, cur, s.gm_aux[k])
	if want >= 0:
		var step := SimTick.ANGLE_UNITS * param(w, "home_turn_dps") / (360 * HZ)
		var at := Vector2(p.pos_x[pi], p.pos_y[pi])
		var to := Kin.angle_of(w.actors.pos(want) - at)
		var nv := Kin.dir(Kin.turn_toward(cur, to, step)) * sp
		p.vel_x[pi] = nv.x
		p.vel_y[pi] = nv.y
		v = nv
	s.gm_ang[k] = Kin.angle_of(v)


## The nearest enemy within home_range_mm of disc `pi` and within home_cone_deg of its heading `cur`, not the one whose
## id + 1 is `skip`, not one it overlaps (the lowest index on a tie), or -1.
static func _target(w: World, pi: int, cur: int, skip: int) -> int:
	var p := w.projectiles
	var at := Vector2(p.pos_x[pi], p.pos_y[pi])
	var cone := SimTick.ANGLE_UNITS * param(w, "home_cone_deg") / 360
	var best := -1
	var best_d := 0.0
	for i in w.enemies_near(at, mm(param(w, "home_range_mm"))):
		if w.actors.invuln[i] > 0 or (skip > 0 and w.actors.ids[i] == skip - 1):
			continue
		var d := w.actors.pos(i) - at
		var touch := p.radius[pi] + w.actors.radius[i]
		var dl := d.length_squared()
		if dl <= touch * touch or Kin.angle_diff(Kin.angle_of(d), cur) > cone:
			continue
		if best < 0 or dl < best_d:
			best = i
			best_d = dl
	return best


## Disc `pi` is holding at its far point (Mine): enemies it touches take a hit, each at most once per mine_gap_ticks
## (the world skips its sweep). True: it holds.
static func hold(w: World, pi: int) -> bool:
	var s := w.mx
	if s.gm_kind.is_empty():
		return false
	var p := w.projectiles
	var k := row_of(s, p.ids[pi])
	if k < 0 or s.gm_kind[k] & F_HELD == 0:
		return false
	var spec := Attacks.projectile_spec(w, pi)
	var sec := SecondaryProc.of_projectile(w, pi) != 1000
	_pulse(
		w,
		spec,
		k,
		Vector2(p.pos_x[pi], p.pos_y[pi]),
		p.radius[pi],
		p.damage[pi],
		SimEvent.TAG_PROJECTILE,
		sec,
		param(w, "mine_gap_ticks")
	)
	return true


## Row `k`'s disc at `at` hurts the enemies within `r` (damage `dmg`) that its gap lets: each once per `gap` ticks.
static func _pulse(
	w: World,
	spec: AttackSpec,
	k: int,
	at: Vector2,
	r: float,
	dmg: int,
	tags: int,
	sec: bool,
	gap: int
) -> void:
	var s := w.mx
	var rid: int = s.gm_id[k] * (1 if tags == SimEvent.TAG_AREA else -1)  # Ring's gaps and Mine's are apart
	var c: AttackContext = null
	for i in w.enemies_near(at, r):
		var aid: int = w.actors.ids[i]
		if _blocked(s, rid, aid):
			continue
		if c == null:
			c = AttackContext.make(at, 0, dmg, w.take_root(), tags, &"")
			c.depth = spec.depth
			c.proc_pct = maxi(1, 100 >> spec.depth)
			c.secondary = sec
		s.gm_hit_row.append(rid)
		s.gm_hit_actor.append(aid)
		s.gm_hit_until.append(w.tick + gap)
		Attacks.land(w, spec, c, i, at, w.actors.pos(i))


## Disc projectile `pi` (of the player) just hit enemy `target` (World._projectile_hits): Split sheds its two small
## discs, once, on its first hit.
static func on_hit(w: World, pi: int, target: int) -> void:
	var s := w.mx
	if s.gm_kind.is_empty():
		return
	var p := w.projectiles
	var k := row_of(s, p.ids[pi])
	if k < 0 or s.gm_kind[k] & (F_SPLIT | F_NOFOLLOW | F_SMALL):
		return
	var spec := Attacks.projectile_spec(w, pi)
	var m := mask(spec)
	if m & SPLIT == 0:
		return
	s.gm_kind[k] |= F_SPLIT
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var ang := Kin.angle_of(v)
	var r := p.radius[pi] * param(w, "split_wide") / 1000.0
	var past := w.actors.radius[target] + r + 0.02  # just past the body, as the disc itself
	var from := w.actors.pos(target) + Kin.dir(ang) * past
	var dmg := share(p.damage[pi], param(w, "split_share"))
	var turn := SimTick.ANGLE_UNITS * param(w, "split_deg") / 360
	for side in 2:
		var a := (ang + (turn if side == 0 else -turn)) & 4095
		var j := _add(w, K_OPEN | F_SMALL | F_NOFOLLOW, 0, from, w.tick, dmg, a, w.take_root())
		if j >= 0:
			s.gm_r[j] = int(round(r * 1000.0))


# --- State, each tick -----------------------------------------------------------------------------------------------
## Tick phase 6 (ModifierRuntime.advance): the discs to open, Ring's hits, the rows of discs that are gone, the bound.
static func advance(w: World) -> void:
	var s := w.mx
	if s.gm_kind.is_empty():
		return
	var spec := Modifiers.bolt(w) if PlayerBuild.has_gun(w) else null
	if spec == null or spec.glaive <= 0:
		s.gm_clear()
		return
	_expire(s, w.tick)
	var ids := w.projectiles.ids
	var ringed := mask(spec) & RING != 0
	var k := 0
	while k < s.gm_kind.size():
		if s.gm_kind[k] & KIND_MASK == K_OPEN:
			if w.tick >= s.gm_due[k]:
				_open(w, spec, k)
				continue
		else:
			var at := ids.bsearch(s.gm_pid[k])
			if at >= ids.size() or ids[at] != s.gm_pid[k]:
				_remove(s, k)  # its disc is gone
				continue
			if ringed and s.gm_kind[k] & F_SMALL == 0:
				_ring(w, spec, k, at)
		k += 1
	cull(w)


## Ring: the enemies within the ring round disc (projectile index `pi`) of row `k` take a hit, each once per gap.
static func _ring(w: World, spec: AttackSpec, k: int, pi: int) -> void:
	var p := w.projectiles
	var r := Stats.area(w, mm(param(w, "ring_mm")))
	_pulse(
		w,
		spec,
		k,
		Vector2(p.pos_x[pi], p.pos_y[pi]),
		r,
		share(p.damage[pi], param(w, "ring_share")),
		SimEvent.TAG_AREA,
		true,
		param(w, "ring_gap_ticks")
	)


## Row `k` (a K_OPEN) opens its disc and goes: an Echo ghost flies the same line; a Split small disc flies on.
static func _open(w: World, spec: AttackSpec, k: int) -> void:
	var s := w.mx
	var flags: int = s.gm_kind[k]
	var at: Vector2 = s.gm_at[k]
	var ang: int = s.gm_ang[k]
	var dmg: int = s.gm_dmg[k]
	var r: float = s.gm_r[k] / 1000.0
	var bounce: int = s.gm_aux[k]
	var root: int = s.gm_root[k]
	_remove(s, k)
	var m := mask(spec)
	var small := flags & F_SMALL != 0
	var sp := speed(w, spec, m)
	var life_ticks := life(w, spec, m)
	if small:
		life_ticks = maxi(1, roundi(mm(param(w, "split_len_mm")) / maxf(sp, 0.001)))  # sp: metres a tick
		bounce = 0
	var p := w.projectiles
	var id := w.take_id()
	p.add(
		id,
		w.actors.ids[0],
		ActorStore.TEAM_PLAYER,
		at,
		Kin.dir(ang) * sp,
		r,
		maxi(1, life_ticks),
		dmg,
		SimEvent.TAG_PROJECTILE,
		bounce
	)
	var pi := p.size() - 1
	p.spec_key[pi] = spec.key
	p.set_second(pi, ProjectileStore.SECONDARY)
	ProjectileMoves.on_spawn(w, pi)  # its return rule, as any disc's
	if small:  # it flies on 4 m through whatever it meets and ends: no return
		p.ret[pi] = 0
		p.pierce_left[pi] = SMALL_PIERCE
		p.life0[pi] = maxi(1, life_ticks)
	else:
		_lap(w, pi, m)
	var j := _add(
		w, K_BALL | F_NOFOLLOW | (F_SMALL if small else 0), id, Vector2.ZERO, w.tick, 0, ang, root
	)
	if j >= 0:
		s.gm_r[j] = ang


# --- The bound ------------------------------------------------------------------------------------------------------
## The player's disc projectiles (indices, ascending) now.
static func _live(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for pi in w.projectiles.size():
		if Glaive.is_disc(w, pi):
			out.append(pi)
	return out


## At most live_max discs a hero while the cards are on: the oldest end first.
static func cull(w: World) -> void:
	var cap := param(w, "live_max")
	if w.mx.gm_kind.is_empty() or w.projectiles.size() <= cap or not PlayerBuild.has_gun(w):
		return
	var live := _live(w)
	var over := live.size() - cap
	if over <= 0:
		return
	var p := w.projectiles
	var gone := PackedInt32Array()
	for q in over:
		var pi := live[q]
		gone.append(pi)
		Attacks.on_projectile_end(w, pi, Vector2(p.pos_x[pi], p.pos_y[pi]))
	p.remove_sorted(gone)


# --- For the view ---------------------------------------------------------------------------------------------------
## The lightning rings round the discs now: [{pos, r (m)}].
static func read_rings(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := w.mx
	if s.gm_kind.is_empty():
		return out
	var p := w.projectiles
	var r := Stats.area(w, mm(param(w, "ring_mm")))
	for k in s.gm_kind.size():
		if s.gm_kind[k] & KIND_MASK != K_BALL or s.gm_kind[k] & F_SMALL:
			continue
		var at := p.ids.bsearch(s.gm_pid[k])
		if at >= p.ids.size() or p.ids[at] != s.gm_pid[k]:
			continue
		if mask(Attacks.projectile_spec(w, at)) & RING != 0:
			out.append({"pos": Vector2(p.pos_x[at], p.pos_y[at]), "r": r})
	return out
