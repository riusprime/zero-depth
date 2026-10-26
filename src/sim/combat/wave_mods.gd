class_name WaveMods
extends RefCounted
## v0.9.5 FC8 (docs/roadmap/v0.9.5/FORM_COMBOS.md W1-W8): what eight cards do to the Wave form. One handler per card.
## A wave ignores these cards' generic ops (WandCompile.run: it only notes the id in modifier_ids), and this file reads
## them from there: mask(spec). Twin and Backfire are the Wave's own (GunForms, Attacks) and are not touched here.
## - At the throw (Attacks._bolts): Big Shot's and Rapid Fire's damage and speed (damage_permille(), speed()),
##   Ricochet's one wall bounce (bounces()), Echo's ghost wave waiting as a row (add_echo()). Rapid Fire's period is
##   period() (ItemEffects.shot_period_ticks). Big Shot's and Rapid Fire's width is width_mm(), read by WaveShots.
## - At the spawn (World._apply_spawns -> on_spawn): a wave with cards gets a K_WAVE row (its width, heading, launch
##   point); Homing picks its target there.
## - Each tick (advance(), ModifierRuntime): the waves to open (Echo's ghost, Split's two children), each live wave's
##   Homing bend, Mine's stop and Spiral's sway, the rows of waves that are gone, and the bound (cull(): at most
##   live_max live waves a hero, the oldest end first).
## - At the end of a wave's run (Attacks.on_projectile_end -> on_end): Split queues its two children.
## - Rows (World.mx wm_*), at most ROWS_MAX; hashed only while any is set (older digests unchanged).
## - Numbers: data/wand/attack_slots.tres, the wave row's `params` (SlotTable.params); DEFAULTS are the same values,
##   read by a world without the table (a lab) and checked against the data by the content test.
## Pure: integer maths (angles in 1/4096 turns, Kin's tables), no randomness, one clock.

const RICOCHET := 1
const HOMING := 2
const ECHO := 4
const BIG := 8
const RAPID := 16
const SPLIT := 32
const MINE := 64
const SPIRAL := 128
## The cards by bit.
const CARD_IDS: Array[StringName] = [
	&"gun_ricochet",
	&"gun_homing",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"split_shot",
	&"gun_mine",
	&"gun_spiral",
]
const CARD_BITS: Array[int] = [RICOCHET, HOMING, ECHO, BIG, RAPID, SPLIT, MINE, SPIRAL]
## What a row is (wm_kind & KIND_MASK): a live wave's state, a wave to open (an Echo ghost, a Split child).
const K_WAVE := 0
const K_OPEN := 1
const KIND_MASK := 3
## Row flags (wm_kind): the wave starts no follow-ups (a ghost, a child); it is a Split child (straight, no cards of
## its own); it has split; its Mine is churning.
const F_NOFOLLOW := 4
const F_SMALL := 8
const F_SPLIT := 16
const F_HELD := 32
const ROWS_MAX := 64
const HZ := 60
## The wave row's numbers (units in the names; data/wand/attack_slots.tres carries the same).
const DEFAULTS := {
	"ricochet_bounces": 1,
	"home_cone_deg": 90,
	"home_turn_dps": 45,
	"home_group_mm": 2000,
	"echo_delay_ms": 400,
	"echo_share": 500,
	"big_width_mm": 5000,
	"big_speed": 750,
	"big_damage": 1600,
	"rapid_width_mm": 2000,
	"rapid_period_ms": 550,
	"rapid_damage": 700,
	"split_deg": 45,
	"split_len_mm": 3000,
	"split_share": 500,
	"split_wide": 500,
	"mine_out_mm": 4000,
	"mine_hold_ms": 1500,
	"spiral_mm": 800,
	"spiral_ms": 1000,
	"live_max": 8,
}
## The ModifierState fields an older save lacks (WorldSnapshot._apply_object reads this list; that file is at its cap).
const SNAPSHOT_FIELDS: Array[StringName] = [
	&"wm_next",
	&"wm_id",
	&"wm_kind",
	&"wm_pid",
	&"wm_at",
	&"wm_due",
	&"wm_born",
	&"wm_ang",
	&"wm_dmg",
	&"wm_r",
	&"wm_w",
	&"wm_aux",
	&"wm_aux2",
	&"wm_root",
]


# --- Cards and numbers --------------------------------------------------------------------------------------------
## The bit mask of the Wave cards the wave `spec` carries (0: a plain Wave, or not a wave: nothing here runs).
static func mask(spec: AttackSpec) -> int:
	if spec == null or spec.wave_mm <= 0 or spec.modifier_ids.is_empty():
		return 0
	var m := 0
	for k in CARD_IDS.size():
		if spec.modifier_ids.has(String(CARD_IDS[k])):
			m |= CARD_BITS[k]
	return m


## `id` is one of the eight cards (WandCompile.run: on a wave its generic ops are skipped).
static func is_card(id: StringName) -> bool:
	return CARD_IDS.has(id)


## Card `m` stands on the wave `s` (WandCompile.run): its id is noted.
static func note_card(s: AttackSpec, m: ModifierTable) -> void:
	if not s.modifier_ids.has(String(m.id)):
		s.modifier_ids.append(String(m.id))


## The wave row's number `key` (data, else the default).
static func param(w: World, key: String) -> int:
	var t := w.slot_table
	if t != null:
		var p: Dictionary = t.params.get(&"wave", {})
		if p.has(key):
			return int(p[key])
	return int(DEFAULTS[key])


static func ticks(ms: int) -> int:
	return maxi(1, ms * HZ / 1000)


static func mm(v: int) -> float:
	return v / 1000.0


static func share(dmg: int, permille: int) -> int:
	return maxi(1, dmg * permille / 1000)


## The damage factor (per mille) of a throw: Big Shot x 1.6, Rapid Fire x 0.7.
static func damage_permille(w: World, m: int) -> int:
	var f := 1000
	if m & BIG:
		f = f * param(w, "big_damage") / 1000
	if m & RAPID:
		f = f * param(w, "rapid_damage") / 1000
	return f


## The flight speed (m a tick) of a wave of `spec` with cards `m`: Big Shot x 0.75.
static func speed(w: World, spec: AttackSpec, m: int) -> float:
	var f := 1000
	if m & BIG:
		f = param(w, "big_speed")
	return spec.speed * f / 1000.0


## The band's width (mm) of a wave of `spec` with cards `m`: Big Shot 5 m, Rapid Fire 2 m (both: the two factors
## multiply, 5 x 2 / 3 m).
static func width_mm(w: World, spec: AttackSpec, m: int) -> int:
	var wd := spec.wave_mm
	if m & BIG:
		wd = param(w, "big_width_mm")
	if m & RAPID:
		wd = wd * param(w, "rapid_width_mm") / maxi(1, spec.wave_mm)
	return wd


## Ricochet: the wall bounces a wave is thrown with (once).
static func bounces(w: World, m: int, base: int) -> int:
	return param(w, "ricochet_bounces") if m & RICOCHET else base


## Rapid Fire: the throw period `base` (ticks) of the plain 0.9 s becomes rapid_period_ms.
static func period(w: World, spec: AttackSpec, base: int) -> int:
	if mask(spec) & RAPID == 0 or spec.period_ticks <= 0:
		return base
	return maxi(1, base * ticks(param(w, "rapid_period_ms")) / spec.period_ticks)


# --- The throw ------------------------------------------------------------------------------------------------------
## Echo: a ghost wave of the wave just thrown from `at` along `ang` (damage `dmg` before the share) waits.
static func add_echo(w: World, at: Vector2, ang: int, dmg: int, r: float, bounce: int) -> void:
	var spec := Modifiers.bolt(w)
	var j := _add(
		w,
		K_OPEN | F_NOFOLLOW,
		0,
		at,
		w.tick + ticks(param(w, "echo_delay_ms")),
		share(dmg, param(w, "echo_share")),
		ang,
		w.take_root()
	)
	if j >= 0:
		w.mx.wm_r[j] = int(round(r * 1000.0))
		w.mx.wm_w[j] = width_mm(w, spec, mask(spec))
		w.mx.wm_aux[j] = bounce


# --- Rows -----------------------------------------------------------------------------------------------------------
## The row of wave projectile `pid` (a K_WAVE), or -1.
static func row_of(s: ModifierState, pid: int) -> int:
	for k in s.wm_kind.size():
		if s.wm_kind[k] & KIND_MASK == K_WAVE and s.wm_pid[k] == pid:
			return k
	return -1


static func _add(
	w: World, kind: int, pid: int, at: Vector2, due: int, dmg: int, ang: int, root: int
) -> int:
	var s := w.mx
	if s.wm_kind.size() >= ROWS_MAX:
		return -1
	s.wm_next += 1
	s.wm_id.append(s.wm_next)
	s.wm_kind.append(kind)
	s.wm_pid.append(pid)
	s.wm_at.append(at)
	s.wm_due.append(due)
	s.wm_born.append(w.tick)
	s.wm_ang.append(ang)
	s.wm_dmg.append(dmg)
	s.wm_r.append(0)
	s.wm_w.append(0)
	s.wm_aux.append(0)
	s.wm_aux2.append(0)
	s.wm_root.append(root)
	return s.wm_kind.size() - 1


static func _remove(s: ModifierState, k: int) -> void:
	s.wm_id.remove_at(k)
	s.wm_kind.remove_at(k)
	s.wm_pid.remove_at(k)
	s.wm_at.remove_at(k)
	s.wm_due.remove_at(k)
	s.wm_born.remove_at(k)
	s.wm_ang.remove_at(k)
	s.wm_dmg.remove_at(k)
	s.wm_r.remove_at(k)
	s.wm_w.remove_at(k)
	s.wm_aux.remove_at(k)
	s.wm_aux2.remove_at(k)
	s.wm_root.remove_at(k)
	if s.wm_kind.is_empty():
		s.wm_clear()


## Wave projectile `pi` just spawned (World._apply_spawns): with cards it gets a K_WAVE row.
static func on_spawn(w: World, pi: int) -> void:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER or pi >= p.spec_key.size() or p.spec_key[pi] == "":
		return
	var spec := Attacks.projectile_spec(w, pi)
	var m := mask(spec)
	if m == 0:
		return
	var at := Vector2(p.pos_x[pi], p.pos_y[pi])
	var ang := Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))
	var k := _add(w, K_WAVE, p.ids[pi], at, w.tick, 0, ang, p.root_id[pi])
	if k < 0:
		return
	w.mx.wm_w[k] = width_mm(w, spec, m)
	if m & HOMING != 0:
		_pick(w, pi, k)


# --- The band's width and heading (WaveShots) -------------------------------------------------------------------------
## Wave projectile `pi`'s band width (mm): its row's, else the spec's.
static func band_mm(w: World, pi: int, spec: AttackSpec) -> int:
	var s := w.mx
	if not s.wm_kind.is_empty():
		var k := row_of(s, w.projectiles.ids[pi])
		if k >= 0:
			return s.wm_w[k]
	return spec.wave_mm


## Wave projectile `pi`'s heading as a unit vector: its velocity, else (a Mine churning in place) its row's, else
## zero.
static func heading(w: World, pi: int) -> Vector2:
	var p := w.projectiles
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var sp := Kin.length(v)
	if sp > 0.0:
		return v / sp
	var s := w.mx
	if not s.wm_kind.is_empty():
		var k := row_of(s, p.ids[pi])
		if k >= 0:
			return Kin.dir(s.wm_ang[k])
	return Vector2.ZERO


# --- Flight ---------------------------------------------------------------------------------------------------------
## Homing: row `k`'s wave (projectile `pi`) picks its target once: of the enemies within its reach and 90 degrees ahead,
## the one with the most enemies within home_group_mm (the lowest index on a tie). Stored as the actor id + 1.
static func _pick(w: World, pi: int, k: int) -> void:
	var p := w.projectiles
	var s := w.mx
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var reach := Kin.length(v) * p.life[pi]
	var at := Vector2(p.pos_x[pi], p.pos_y[pi])
	var heading_a := Kin.angle_of(v)
	var half := SimTick.ANGLE_UNITS * param(w, "home_cone_deg") / 720
	var best := -1
	var best_n := 0
	for i in w.enemies_near(at, reach):
		if w.actors.invuln[i] > 0:
			continue
		if Kin.angle_diff(Kin.angle_of(w.actors.pos(i) - at), heading_a) > half:
			continue
		var n := w.enemies_near(w.actors.pos(i), mm(param(w, "home_group_mm"))).size()
		if n > best_n:
			best = i
			best_n = n
	if best >= 0:
		s.wm_aux[k] = w.actors.ids[best] + 1


## Row `k`'s wave `pi` bends toward its Homing target, at most home_turn_dps a second.
static func _bend(w: World, pi: int, k: int) -> void:
	var s := w.mx
	if s.wm_aux[k] <= 0:
		return
	var i := w.actors.index_of(s.wm_aux[k] - 1)
	if i < 0 or w.actors.dead[i] == 1:
		return
	var p := w.projectiles
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var sp := Kin.length(v)
	if sp <= 0.0:
		return
	var cur := Kin.angle_of(v)
	var to := Kin.angle_of(w.actors.pos(i) - Vector2(p.pos_x[pi], p.pos_y[pi]))
	var step := SimTick.ANGLE_UNITS * param(w, "home_turn_dps") / (360 * HZ)
	var turned := Kin.turn_toward(cur, to, step)
	if turned == cur:
		return
	var nv := Kin.dir(turned) * sp
	p.vel_x[pi] = nv.x
	p.vel_y[pi] = nv.y


## Row `k`'s wave `pi` has rolled mine_out_mm from where it left: it stops and churns mine_hold_ms (its life becomes the
## hold; the per-enemy waits of this shot last as long).
static func _stop(w: World, pi: int, k: int) -> void:
	var s := w.mx
	var p := w.projectiles
	var hold := ticks(param(w, "mine_hold_ms"))
	p.vel_x[pi] = 0.0
	p.vel_y[pi] = 0.0
	p.life[pi] = hold
	s.wm_kind[k] |= F_HELD
	for q in s.void_shot.size():
		if s.void_shot[q] == p.ids[pi]:
			s.void_next[q] = w.tick + hold + 2


## Spiral: the wave's sideways offset (mm) from its line at `age` ticks: spiral_mm x sin(2 pi age / period).
static func _sway(w: World, age: int) -> int:
	var n := ticks(param(w, "spiral_ms"))
	var phase := (age * SimTick.ANGLE_UNITS / n) & 4095
	return roundi(param(w, "spiral_mm") * Kin.dir(phase).y)


## Row `k`'s live wave `pi` this tick: Homing's bend, Mine's stop, Spiral's sway; its heading is kept for the band.
static func _fly(w: World, pi: int, k: int, m: int) -> void:
	var s := w.mx
	var p := w.projectiles
	var flags: int = s.wm_kind[k]
	if flags & F_HELD != 0 or Vector2(p.vel_x[pi], p.vel_y[pi]) == Vector2.ZERO:
		return
	if flags & F_SMALL == 0:
		if m & HOMING != 0:
			_bend(w, pi, k)
		var v := Vector2(p.vel_x[pi], p.vel_y[pi])
		s.wm_ang[k] = Kin.angle_of(v)
		var at := Vector2(p.pos_x[pi], p.pos_y[pi])
		if m & MINE != 0 and (at - s.wm_at[k]).length() >= mm(param(w, "mine_out_mm")):
			_stop(w, pi, k)
			return
		if m & SPIRAL != 0:
			var age: int = w.tick - s.wm_born[k]
			var d := mm(_sway(w, age) - _sway(w, age - 1)) if age > 0 else 0.0
			var side := Kin.dir(s.wm_ang[k] + 1024) * d
			p.pos_x[pi] += side.x
			p.pos_y[pi] += side.y
	else:
		s.wm_ang[k] = Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))


# --- The end of a run -----------------------------------------------------------------------------------------------
## Wave projectile `pi` (of the player) ended at `at` (Attacks.on_projectile_end): Split queues its two children, once.
static func on_end(w: World, spec: AttackSpec, pi: int, at: Vector2) -> void:
	var s := w.mx
	if s.wm_kind.is_empty() or mask(spec) & SPLIT == 0:
		return
	var p := w.projectiles
	var k := row_of(s, p.ids[pi])
	if k < 0 or s.wm_kind[k] & (F_SPLIT | F_NOFOLLOW | F_SMALL):
		return
	s.wm_kind[k] |= F_SPLIT
	var ang: int = s.wm_ang[k]
	var dmg := share(p.damage[pi], param(w, "split_share"))
	var turn := SimTick.ANGLE_UNITS * param(w, "split_deg") / 360
	var life_ticks := maxi(
		1, roundi(mm(param(w, "split_len_mm")) / maxf(speed(w, spec, mask(spec)), 0.001))
	)
	var wide: int = s.wm_w[k] * param(w, "split_wide") / 1000
	var r := p.radius[pi]
	for side in 2:
		var a := (ang + (turn if side == 0 else -turn)) & 4095
		var j := _add(w, K_OPEN | F_SMALL | F_NOFOLLOW, 0, at, w.tick, dmg, a, w.take_root())
		if j >= 0:
			s.wm_r[j] = int(round(r * 1000.0))
			s.wm_w[j] = wide
			s.wm_aux2[j] = life_ticks


# --- State, each tick -----------------------------------------------------------------------------------------------
## Tick phase 6 (ModifierRuntime.advance): the waves to open, each live wave's flight, the rows of waves that are gone,
## the bound.
static func advance(w: World) -> void:
	var s := w.mx
	if s.wm_kind.is_empty():
		return
	var spec := Modifiers.bolt(w) if PlayerBuild.has_gun(w) else null
	if spec == null or spec.wave_mm <= 0:
		s.wm_clear()
		return
	var m := mask(spec)
	var ids := w.projectiles.ids
	var k := 0
	while k < s.wm_kind.size():
		if s.wm_kind[k] & KIND_MASK == K_OPEN:
			if w.tick >= s.wm_due[k]:
				_open(w, spec, k)
				continue
		else:
			var at := ids.bsearch(s.wm_pid[k])
			if at >= ids.size() or ids[at] != s.wm_pid[k]:
				_remove(s, k)  # its wave is gone
				continue
			_fly(w, at, k, m)
		k += 1
	cull(w)


## Row `k` (a K_OPEN) opens its wave and goes: an Echo ghost flies the same line; a Split child flies on.
static func _open(w: World, spec: AttackSpec, k: int) -> void:
	var s := w.mx
	var flags: int = s.wm_kind[k]
	var at: Vector2 = s.wm_at[k]
	var ang: int = s.wm_ang[k]
	var dmg: int = s.wm_dmg[k]
	var r: float = s.wm_r[k] / 1000.0
	var wide: int = s.wm_w[k]
	var bounce: int = s.wm_aux[k]
	var life_ticks: int = s.wm_aux2[k] if s.wm_aux2[k] > 0 else spec.life_ticks
	var root: int = s.wm_root[k]
	_remove(s, k)
	var m := mask(spec)
	var small := flags & F_SMALL != 0
	var sp := speed(w, spec, m)
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
		0 if small else bounce
	)
	var pi := p.size() - 1
	p.spec_key[pi] = spec.key
	p.set_second(pi, ProjectileStore.SECONDARY)
	ProjectileMoves.on_spawn(w, pi)
	var j := _add(w, K_WAVE | (flags & (F_NOFOLLOW | F_SMALL)), id, at, w.tick, 0, ang, root)
	if j >= 0:
		s.wm_w[j] = wide
		if not small and m & HOMING != 0:
			_pick(w, pi, j)


# --- The bound ------------------------------------------------------------------------------------------------------
## The player's wave projectiles (indices, ascending) now.
static func _live(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for pi in w.projectiles.size():
		if WaveShots.is_wave_projectile(w, pi):
			out.append(pi)
	return out


## At most live_max waves a hero while the cards are on: the oldest end first (and do not split).
static func cull(w: World) -> void:
	var cap := param(w, "live_max")
	if w.mx.wm_kind.is_empty() or w.projectiles.size() <= cap or not PlayerBuild.has_gun(w):
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
		var k := row_of(w.mx, p.ids[pi])
		if k >= 0:
			w.mx.wm_kind[k] |= F_SPLIT
		Attacks.on_projectile_end(w, pi, Vector2(p.pos_x[pi], p.pos_y[pi]))
	p.remove_sorted(gone)
