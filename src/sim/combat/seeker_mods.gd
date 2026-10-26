class_name SeekerMods
extends RefCounted
## v0.9.5 FC7 (docs/roadmap/v0.9.5/FORM_COMBOS.md S1-S11): what eleven cards do to the Seekers form. One handler per
## card. A dart ignores these cards' generic ops (WandCompile.run: it only notes the id in modifier_ids), and this file
## reads them from there: mask(spec).
## - At the volley (Attacks._bolts): the count of darts (count(): Twin x2, Big Shot 2, Rapid Fire 5), their angles
##   (offsets(): Halo's even circle), damage and size (damage_permille(), wide()), Pierce's extra hits (pierce()),
##   Ricochet's wall bounces (bounces()), Echo's second volley waiting as rows (add_echo()).
## - At the spawn (World._apply_spawns -> on_spawn): a dart with cards gets a K_BALL row (launch heading, born tick).
## - In flight: steer() (ProjectileMoves.steer, before the homing rule) runs Orbit's lap, Mine's hold and Halo's
##   straight flight in that order from the dart's birth; pick() (Seekers.target) gives Pierce's next un-hit enemy and a
##   Split child's own enemy; on_hit() (World._projectile_hits) records Pierce's hit, sheds Split's two children and
##   makes Ring's ring.
## - Each tick (advance()): the darts to open (Echo's volley, Split's children), the rings, the rows of darts that are
##   gone, and the bound: at most live_max live darts a hero (cull(): the oldest end first).
## - Rows (World.mx sk_*), at most ROWS_MAX; hashed only while any is set (older digests unchanged).
## - Numbers: data/wand/attack_slots.tres, the seekers row's `params` (SlotTable.params); DEFAULTS are the same values,
##   read by a world without the table (a lab) and checked against the data by the content test.
## Pure: integer maths (angles in 1/4096 turns, Kin), no randomness, one clock.

const TWIN := 1
const HALO := 2
const RING := 4
const PIERCE := 8
const RICOCHET := 16
const ECHO := 32
const BIG := 64
const RAPID := 128
const SPLIT := 256
const MINE := 512
const ORBIT := 1024
## The cards by bit.
const CARD_IDS: Array[StringName] = [
	&"gun_twin",
	&"halo_shot",
	&"gun_ring",
	&"gun_pierce",
	&"gun_ricochet",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"split_shot",
	&"gun_mine",
	&"orbit_rounds",
]
const CARD_BITS: Array[int] = [
	TWIN, HALO, RING, PIERCE, RICOCHET, ECHO, BIG, RAPID, SPLIT, MINE, ORBIT
]
## What a row is (sk_kind & KIND_MASK): a live dart's state, a dart to open (an Echo ghost, a Split child), a ring.
const K_BALL := 0
const K_OPEN := 1
const K_RING := 2
const KIND_MASK := 3
## Row flags (sk_kind): the dart starts no follow-ups (a ghost, a child); it is a Split child (its own enemy, no
## phases, no ring); it has shed its children.
const F_NOFOLLOW := 4
const F_CHILD := 8
const F_SPLIT := 16
const ROWS_MAX := 64
## A ring is drawn this many ticks.
const RING_VIEW_TICKS := 12
## Seekers.target's answer when this file has no say.
const NO_PICK := -3
## The seekers row's numbers (units in the names; data/wand/attack_slots.tres carries the same).
const DEFAULTS := {
	"twin_mult": 2,
	"twin_share": 600,
	"halo_straight_ticks": 18,
	"ring_mm": 1000,
	"ring_share": 300,
	"pierce_extra": 2,
	"ricochet_bounces": 3,
	"echo_delay_ticks": 18,
	"echo_share": 500,
	"big_count": 2,
	"big_damage": 2000,
	"big_wide": 1500,
	"rapid_count": 5,
	"rapid_damage": 650,
	"rapid_wide": 700,
	"split_count": 2,
	"split_share": 350,
	"split_deg": 30,
	"mine_hold_ticks": 36,
	"orbit_mm": 2500,
	"orbit_ticks": 60,
	"live_max": 24,
}


# --- Cards and numbers --------------------------------------------------------------------------------------------
## The bit mask of the Seekers cards the dart `spec` carries (0: plain Seekers, or not seekers: nothing here runs).
static func mask(spec: AttackSpec) -> int:
	if spec == null or spec.seekers <= 0 or spec.modifier_ids.is_empty():
		return 0
	var m := 0
	for k in CARD_IDS.size():
		if spec.modifier_ids.has(String(CARD_IDS[k])):
			m |= CARD_BITS[k]
	return m


## `id` is one of the eleven cards (WandCompile.run: on the Seekers its generic ops are skipped).
static func is_card(id: StringName) -> bool:
	return CARD_IDS.has(id)


## Card `m` stands on the Seekers `s` (WandCompile.run): its id is noted.
static func note_card(s: AttackSpec, m: ModifierTable) -> void:
	if not s.modifier_ids.has(String(m.id)):
		s.modifier_ids.append(String(m.id))


## The seekers row's number `key` (data, else the default).
static func param(w: World, key: String) -> int:
	var t := w.slot_table
	if t != null:
		var p: Dictionary = t.params.get(&"seekers", {})
		if p.has(key):
			return int(p[key])
	return int(DEFAULTS[key])


static func mm(v: int) -> float:
	return v / 1000.0


static func share(dmg: int, permille: int) -> int:
	return maxi(1, dmg * permille / 1000)


## The darts in a volley of `spec` with cards `m`: Big Shot 2, Rapid Fire 5 (both: the plain 3), Twin doubles.
static func count(w: World, spec: AttackSpec, m: int) -> int:
	var n := maxi(1, spec.count)
	if m & BIG != 0 and m & RAPID == 0:
		n = param(w, "big_count")
	elif m & RAPID != 0 and m & BIG == 0:
		n = param(w, "rapid_count")
	if m & TWIN != 0:
		n *= param(w, "twin_mult")
	return n


## The dart angles (offsets from the aim): the plain fan of count() darts, or Halo's even circle (the first at the aim).
static func offsets(w: World, spec: AttackSpec, m: int) -> PackedInt32Array:
	var n := count(w, spec, m)
	var out := PackedInt32Array()
	if m & HALO != 0:
		for k in n:
			out.append(spec.aim_offset + k * SimTick.ANGLE_UNITS / n)
		return out
	if n == 1:
		out.append(spec.aim_offset)
		return out
	var half := spec.spread / 2
	for k in n:
		out.append(spec.aim_offset - half + 2 * half * k / (n - 1))
	return out


## The damage factor (per mille) of each dart: Twin 60 %, Big Shot x 2.0, Rapid Fire x 0.65.
static func damage_permille(w: World, m: int) -> int:
	var f := 1000
	if m & TWIN:
		f = f * param(w, "twin_share") / 1000
	if m & BIG:
		f = f * param(w, "big_damage") / 1000
	if m & RAPID:
		f = f * param(w, "rapid_damage") / 1000
	return f


## The dart's radius factor (per mille): Big Shot x 1.5, Rapid Fire x 0.7.
static func wide(w: World, m: int) -> int:
	var f := 1000
	if m & BIG:
		f = f * param(w, "big_wide") / 1000
	if m & RAPID:
		f = f * param(w, "rapid_wide") / 1000
	return f


## Ricochet: the wall bounces a dart is launched with.
static func bounces(w: World, m: int, base: int) -> int:
	return param(w, "ricochet_bounces") if m & RICOCHET else base


## Pierce: the extra hits (after the first) a dart goes through.
static func pierce(w: World, m: int) -> int:
	return param(w, "pierce_extra") if m & PIERCE else 0


static func lap_ticks(w: World, m: int) -> int:
	return param(w, "orbit_ticks") if m & ORBIT else 0


static func hold_ticks(w: World, m: int) -> int:
	return param(w, "mine_hold_ticks") if m & MINE else 0


static func straight_ticks(w: World, m: int) -> int:
	return param(w, "halo_straight_ticks") if m & HALO else 0


## The life (ticks) of a dart: its flight, with Orbit's lap and Mine's hold on top.
static func life(w: World, spec: AttackSpec, m: int) -> int:
	return spec.life_ticks + lap_ticks(w, m) + hold_ticks(w, m)


# --- The volley -----------------------------------------------------------------------------------------------------
## Echo: a ghost dart of the dart just launched from `at` along `ang` (damage `dmg` before the share) waits.
static func add_echo(w: World, at: Vector2, ang: int, dmg: int, r: float, bounce: int) -> void:
	var j := _add(
		w,
		K_OPEN,
		0,
		at,
		w.tick + param(w, "echo_delay_ticks"),
		share(dmg, param(w, "echo_share")),
		ang,
		w.take_root()
	)
	if j >= 0:
		w.mx.sk_r[j] = int(round(r * 1000.0))
		w.mx.sk_aux[j] = bounce


# --- Rows -----------------------------------------------------------------------------------------------------------
## The row of dart projectile `pid` (a K_BALL), or -1.
static func row_of(s: ModifierState, pid: int) -> int:
	for k in s.sk_kind.size():
		if s.sk_kind[k] & KIND_MASK == K_BALL and s.sk_pid[k] == pid:
			return k
	return -1


static func _add(
	w: World, kind: int, pid: int, at: Vector2, due: int, dmg: int, ang: int, root: int
) -> int:
	var s := w.mx
	if s.sk_kind.size() >= ROWS_MAX:
		return -1
	s.sk_next += 1
	s.sk_id.append(s.sk_next)
	s.sk_kind.append(kind)
	s.sk_pid.append(pid)
	s.sk_at.append(at)
	s.sk_due.append(due)
	s.sk_born.append(w.tick)
	s.sk_ang.append(ang)
	s.sk_dmg.append(dmg)
	s.sk_r.append(0)
	s.sk_aux.append(0)
	s.sk_aux2.append(0)
	s.sk_root.append(root)
	return s.sk_kind.size() - 1


static func _remove(s: ModifierState, k: int) -> void:
	var id: int = s.sk_id[k]
	s.sk_id.remove_at(k)
	s.sk_kind.remove_at(k)
	s.sk_pid.remove_at(k)
	s.sk_at.remove_at(k)
	s.sk_due.remove_at(k)
	s.sk_born.remove_at(k)
	s.sk_ang.remove_at(k)
	s.sk_dmg.remove_at(k)
	s.sk_r.remove_at(k)
	s.sk_aux.remove_at(k)
	s.sk_aux2.remove_at(k)
	s.sk_root.remove_at(k)
	if s.sk_kind.is_empty():
		s.sk_clear()
		return
	var q := 0
	while q < s.sk_hit_row.size():
		if s.sk_hit_row[q] == id:
			s.sk_hit_row.remove_at(q)
			s.sk_hit_actor.remove_at(q)
		else:
			q += 1


static func _hit_before(s: ModifierState, rid: int, aid: int) -> bool:
	for q in s.sk_hit_row.size():
		if s.sk_hit_row[q] == rid and s.sk_hit_actor[q] == aid:
			return true
	return false


## Dart projectile `pi` just spawned (World._apply_spawns): with cards it gets a K_BALL row.
static func on_spawn(w: World, pi: int) -> void:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER:
		return
	var spec := Attacks.projectile_spec(w, pi)
	if mask(spec) == 0:
		return
	var ang := Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))
	var k := _add(w, K_BALL, p.ids[pi], Vector2.ZERO, w.tick, 0, ang, p.root_id[pi])
	if k >= 0:
		w.mx.sk_r[k] = ang  # the launch heading


# --- Flight ---------------------------------------------------------------------------------------------------------
## Before dart `pi`'s homing (ProjectileMoves.steer): Orbit's lap, then Mine's hold, then Halo's straight flight, each
## from the dart's birth. True: its velocity is set for this tick (the homing rule does not run).
static func steer(w: World, pi: int) -> bool:
	var s := w.mx
	if s.sk_kind.is_empty():
		return false
	var p := w.projectiles
	var k := row_of(s, p.ids[pi])
	if k < 0 or s.sk_kind[k] & F_CHILD:
		return false
	var m := mask(Attacks.projectile_spec(w, pi))
	var lap := lap_ticks(w, m)
	var hold := hold_ticks(w, m)
	var t: int = w.tick - s.sk_born[k]
	var sp: float = p.speed[pi]
	var heading: int = s.sk_r[k]
	if t < lap:  # one lap round the hero
		var a := (heading + t * SimTick.ANGLE_UNITS / lap) & 4095
		var at := Vector2(p.pos_x[pi], p.pos_y[pi])
		var chord := w.player_pos() + Kin.dir(a) * mm(param(w, "orbit_mm")) - at
		p.vel_x[pi] = chord.x
		p.vel_y[pi] = chord.y
		return true
	if t < lap + hold:  # hangs still
		p.vel_x[pi] = 0.0
		p.vel_y[pi] = 0.0
		return true
	if lap + hold > 0 and t == lap + hold:  # launched: along its heading, or (Mine) straight at its target
		var go := heading
		if m & MINE != 0 and m & HALO == 0:
			var want := Seekers.target(w, pi)
			if want >= 0:
				go = Kin.angle_of(w.actors.pos(want) - Vector2(p.pos_x[pi], p.pos_y[pi]))
		var v := Kin.dir(go) * sp
		p.vel_x[pi] = v.x
		p.vel_y[pi] = v.y
		return m & HALO != 0
	return t < lap + hold + straight_ticks(w, m)


## Seekers.target's override for dart `pi`: a Split child's own enemy, a Pierce dart's next un-hit enemy, STRAIGHT when
## there is none, else NO_PICK.
static func pick(w: World, pi: int) -> int:
	var s := w.mx
	if s.sk_kind.is_empty():
		return NO_PICK
	var p := w.projectiles
	var k := row_of(s, p.ids[pi])
	if k < 0:
		return NO_PICK
	var child: bool = s.sk_kind[k] & F_CHILD != 0
	var rid: int = s.sk_id[k]
	var any_hit := false
	for q in s.sk_hit_row.size():
		if s.sk_hit_row[q] == rid:
			any_hit = true
			break
	if not child and not any_hit:
		return NO_PICK
	var at := Vector2(p.pos_x[pi], p.pos_y[pi])
	var skip: int = s.sk_aux[k] - 1 if child else -1
	var rank: int = s.sk_aux2[k] if child else 0
	var ds := PackedFloat32Array()
	var ids := PackedInt32Array()
	for i in w.enemies_near(at, Seekers.SEEK_M):
		var aid: int = w.actors.ids[i]
		if w.actors.invuln[i] > 0 or aid == skip or _hit_before(s, rid, aid):
			continue
		var d := Kin.length(w.actors.pos(i) - at)
		var j := ds.size()
		while j > 0 and (ds[j - 1] > d or (ds[j - 1] == d and ids[j - 1] > i)):
			j -= 1
		ds.insert(j, d)
		ids.insert(j, i)
	if ids.is_empty():
		return Seekers.STRAIGHT
	return ids[rank % ids.size()]


## Dart projectile `pi` (of the player) just hit enemy `target` (World._projectile_hits): Pierce notes the hit, Ring
## makes its ring, Split sheds its children once.
static func on_hit(w: World, pi: int, target: int) -> void:
	var s := w.mx
	if s.sk_kind.is_empty():
		return
	var p := w.projectiles
	var k := row_of(s, p.ids[pi])
	if k < 0:
		return
	var spec := Attacks.projectile_spec(w, pi)
	var m := mask(spec)
	var flags: int = s.sk_kind[k]
	if m & PIERCE != 0:
		s.sk_hit_row.append(s.sk_id[k])
		s.sk_hit_actor.append(w.actors.ids[target])
	var tpos := w.actors.pos(target)
	if m & RING != 0 and flags & F_CHILD == 0:
		_add(
			w,
			K_RING,
			0,
			tpos,
			w.tick + RING_VIEW_TICKS,
			share(p.damage[pi], param(w, "ring_share")),
			0,
			w.take_root()
		)
	if m & SPLIT == 0 or flags & (F_SPLIT | F_NOFOLLOW | F_CHILD) != 0:
		return
	s.sk_kind[k] |= F_SPLIT
	var ang := Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))
	var n := param(w, "split_count")
	var turn := SimTick.ANGLE_UNITS * param(w, "split_deg") / 360
	for c in n:
		var a := ang
		if n > 1:  # fanned evenly from -turn to +turn
			a = (ang - turn + 2 * turn * c / (n - 1)) & 4095
		# just past the body along its own heading (a child spawned inside it would hit it again)
		var from := tpos + Kin.dir(a) * (w.actors.radius[target] + p.radius[pi] + 0.02)
		var j := _add(
			w,
			K_OPEN | F_CHILD | F_NOFOLLOW,
			0,
			from,
			w.tick,
			share(p.damage[pi], param(w, "split_share")),
			a,
			w.take_root()
		)
		if j >= 0:
			s.sk_r[j] = int(round(p.radius[pi] * 1000.0))
			s.sk_aux[j] = w.actors.ids[target] + 1  # it seeks other enemies than this one
			s.sk_aux2[j] = c


# --- State, each tick -----------------------------------------------------------------------------------------------
## Tick phase 6 (ModifierRuntime.advance): the darts to open, the rings, the rows of darts that are gone, the bound.
static func advance(w: World) -> void:
	var s := w.mx
	if s.sk_kind.is_empty():
		return
	var spec := Modifiers.bolt(w) if PlayerBuild.has_gun(w) else null
	if spec == null or spec.seekers <= 0:
		s.sk_clear()
		return
	var ids := w.projectiles.ids
	var k := 0
	while k < s.sk_kind.size():
		var kind: int = s.sk_kind[k] & KIND_MASK
		if kind == K_OPEN:
			if w.tick >= s.sk_due[k]:
				_open(w, spec, k)
				continue
		elif kind == K_RING:
			if s.sk_aux[k] == 0:
				s.sk_aux[k] = 1
				_ring(w, spec, k)
			if w.tick >= s.sk_due[k]:
				_remove(s, k)
				continue
		else:
			var at := ids.bsearch(s.sk_pid[k])
			if at >= ids.size() or ids[at] != s.sk_pid[k]:
				_remove(s, k)  # its dart is gone
				continue
		k += 1
	cull(w)


## Ring `k` lands: every enemy within its radius takes a hit, once.
static func _ring(w: World, spec: AttackSpec, k: int) -> void:
	var s := w.mx
	var at: Vector2 = s.sk_at[k]
	var c: AttackContext = null
	for i in w.enemies_near(at, Stats.area(w, mm(param(w, "ring_mm")))):
		if c == null:
			c = AttackContext.make(at, 0, s.sk_dmg[k], w.take_root(), SimEvent.TAG_AREA, &"")
			c.depth = spec.depth
			c.proc_pct = maxi(1, 100 >> spec.depth)
			c.secondary = true
		Attacks.land(w, spec, c, i, at, w.actors.pos(i))


## Row `k` (a K_OPEN) opens its dart and goes: an Echo ghost flies the volley's line; a Split child seeks its enemy.
static func _open(w: World, spec: AttackSpec, k: int) -> void:
	var s := w.mx
	var flags: int = s.sk_kind[k]
	var at: Vector2 = s.sk_at[k]
	var ang: int = s.sk_ang[k]
	var dmg: int = s.sk_dmg[k]
	var r: float = s.sk_r[k] / 1000.0
	var aux: int = s.sk_aux[k]
	var aux2: int = s.sk_aux2[k]
	var root: int = s.sk_root[k]
	_remove(s, k)
	var m := mask(spec)
	var child := flags & F_CHILD != 0
	var bounce := aux  # a ghost: the bounces of the dart it echoes
	var life_ticks := life(w, spec, m)
	if child:
		life_ticks = spec.life_ticks
		bounce = bounces(w, m, 0)
	var p := w.projectiles
	var id := w.take_id()
	p.add(
		id,
		w.actors.ids[0],
		ActorStore.TEAM_PLAYER,
		at,
		Kin.dir(ang) * spec.speed,
		r,
		maxi(1, life_ticks),
		dmg,
		SimEvent.TAG_PROJECTILE,
		bounce
	)
	var pi := p.size() - 1
	p.spec_key[pi] = spec.key
	p.set_second(pi, ProjectileStore.SECONDARY)
	ProjectileMoves.on_spawn(w, pi, 0 if child else pierce(w, m))
	var j := _add(
		w, K_BALL | F_NOFOLLOW | (F_CHILD if child else 0), id, Vector2.ZERO, w.tick, 0, ang, root
	)
	if j >= 0:
		s.sk_r[j] = ang
		if child:
			s.sk_aux[j] = aux
			s.sk_aux2[j] = aux2


# --- The bound ------------------------------------------------------------------------------------------------------
## The player's dart projectiles (indices, ascending) now.
static func _live(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for pi in w.projectiles.size():
		if Seekers.is_dart(w, pi):
			out.append(pi)
	return out


## At most live_max darts a hero while the cards are on: the oldest end first.
static func cull(w: World) -> void:
	var cap := param(w, "live_max")
	if w.mx.sk_kind.is_empty() or w.projectiles.size() <= cap or not PlayerBuild.has_gun(w):
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
## The lightning rings showing now: [{pos, r (m)}].
static func read_rings(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := w.mx
	if s.sk_kind.is_empty():
		return out
	var r := Stats.area(w, mm(param(w, "ring_mm")))
	for k in s.sk_kind.size():
		if s.sk_kind[k] & KIND_MASK == K_RING:
			out.append({"pos": s.sk_at[k], "r": r})
	return out
