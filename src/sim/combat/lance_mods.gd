class_name LanceMods
extends RefCounted
## v0.9.5 FC4 (docs/roadmap/v0.9.5/FORM_COMBOS.md N1-N9): what nine cards do to the Lance form. One handler per card.
## A lance ignores these cards' generic ops (WandCompile.run: it only notes the id in modifier_ids), and this file reads
## them from there: mask(spec).
## - The charge (GunForms.hold, Lance.orb): Big Shot needs 0.3 s more to fill, Rapid Fire fills 40 % faster
##   (hold_ticks()); Big Shot's ball is twice as wide (wide(), PlayerKit._fire_bolt).
## - At the release (Attacks._bolts): damage_permille() (Big Shot +60 %, Rapid Fire -30 %, Halo's 50 % each on a full
##   charge), halo_offsets() (a full charge: six lances round the hero), bounces() (Ricochet, full charge only),
##   back_throw() (Backfire), add_echo() (Echo's ghost lance waits as a row).
## - At the spawn (World._apply_spawns -> on_spawn): a lance with cards gets a K_BALL row (Split counts its spitters).
## - In flight: ProjectileMoves.steer -> steer() (Homing bends it); World._projectile_hits -> on_hit() (Split's shards).
## - At its end (Attacks.on_projectile_end -> on_end): Ring queues a growing lightning ring (K_RING).
## - Rows (World.mx lm_*, advance() each tick): K_BALL a live lance, K_ECHO a ghost lance to open, K_RING a ring
##   growing (each enemy once), K_SHARD a split shard (view only; its hits land when it is made). At most ROWS_MAX; a
##   row that does not fit is not added. Hashed only while any is set (older digests unchanged).
## - Numbers: data/wand/attack_slots.tres, the lance row's `params` (SlotTable.params); DEFAULTS are the same values,
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
]
const CARD_BITS: Array[int] = [HALO, RING, BACKFIRE, RICOCHET, HOMING, ECHO, BIG, RAPID, SPLIT]
## What a row is (lm_kind & KIND_MASK): a live lance, a ghost lance to open, a ring growing, a shard (view).
const K_BALL := 0
const K_ECHO := 1
const K_RING := 2
const K_SHARD := 3
const KIND_MASK := 7
## Row flag (lm_kind): the lance starts no follow-ups (an Echo's ghost).
const F_NOFOLLOW := 8
const ROWS_MAX := 96
const HZ := 60
## The lance row's numbers (units in the names; data/wand/attack_slots.tres carries the same).
const DEFAULTS := {
	"halo_count": 6,
	"halo_share": 500,
	"ring_mm": 2000,
	"ring_ms": 250,
	"ring_share": 500,
	"back_share": 500,
	"ricochet_bounces": 1,
	"home_range_mm": 12000,
	"home_cone_deg": 60,
	"home_turn_dps": 60,
	"echo_delay_ms": 400,
	"echo_share": 500,
	"big_wide": 2000,
	"big_damage": 1600,
	"big_hold_ms": 300,
	"rapid_charge": 1400,
	"rapid_damage": 700,
	"split_len_mm": 3000,
	"split_width_mm": 250,
	"split_share": 250,
	"split_max": 6,
	"split_ticks": 8,
}


# --- Cards and numbers --------------------------------------------------------------------------------------------
## The bit mask of the Lance cards the lance `spec` carries (0: a plain Lance, or not a lance: nothing here runs).
static func mask(spec: AttackSpec) -> int:
	if spec == null or spec.lance <= 0 or spec.modifier_ids.is_empty():
		return 0
	var m := 0
	for k in CARD_IDS.size():
		if spec.modifier_ids.has(String(CARD_IDS[k])):
			m |= CARD_BITS[k]
	return m


## `id` is one of the nine cards (WandCompile.run: on a lance its generic ops are skipped).
static func is_card(id: StringName) -> bool:
	return CARD_IDS.has(id)


## Card `m` stands on the lance `s` (WandCompile.run): its id is noted.
static func note_card(s: AttackSpec, m: ModifierTable) -> void:
	if not s.modifier_ids.has(String(m.id)):
		s.modifier_ids.append(String(m.id))


## The lance row's number `key` (data, else the default).
static func param(w: World, key: String) -> int:
	var t := w.slot_table
	if t != null:
		var p: Dictionary = t.params.get(&"lance", {})
		if p.has(key):
			return int(p[key])
	return int(DEFAULTS[key])


static func ticks(ms: int) -> int:
	return maxi(1, ms * HZ / 1000)


static func mm(v: int) -> float:
	return v / 1000.0


static func share(dmg: int, permille: int) -> int:
	return maxi(1, dmg * permille / 1000)


## A release at `pm` (per mille of the damage) was a full charge.
static func is_full(spec: AttackSpec, pm: int) -> bool:
	return spec.hold_ticks > 0 and pm >= spec.hold_permille


## The ticks the charge takes to fill: Big Shot 0.3 s more, then Rapid Fire 40 % faster.
static func hold_ticks(w: World, spec: AttackSpec) -> int:
	var m := mask(spec)
	var h := spec.hold_ticks
	if m & BIG:
		h += ticks(param(w, "big_hold_ms"))
	if m & RAPID:
		h = maxi(1, h * 1000 / param(w, "rapid_charge"))
	return h


## The ball's width factor (per mille): Big Shot's twice as wide.
static func wide(w: World, spec: AttackSpec) -> int:
	return param(w, "big_wide") if mask(spec) & BIG else 1000


## The damage factor (per mille) of a release: Big Shot +60 %, Rapid Fire x 0.7, a full Halo's 50 % each lance.
static func damage_permille(w: World, m: int, full: bool) -> int:
	var f := 1000
	if m & BIG:
		f = f * param(w, "big_damage") / 1000
	if m & RAPID:
		f = f * param(w, "rapid_damage") / 1000
	if m & HALO and full:
		f = f * param(w, "halo_share") / 1000
	return f


## Halo: a full charge's lance angles (offsets from the aim), every 360 / halo_count degrees, the first at the aim.
static func halo_offsets(w: World, m: int, full: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	if m & HALO == 0 or not full:
		return out
	var n := maxi(1, param(w, "halo_count"))
	for k in n:
		out.append(k * SimTick.ANGLE_UNITS / n)
	return out


## Ricochet: the wall bounces of a release (one, on a full charge only).
static func bounces(w: World, m: int, full: bool, base: int) -> int:
	return param(w, "ricochet_bounces") if m & RICOCHET and full else base


# --- The release ----------------------------------------------------------------------------------------------------
## Backfire: a lance straight behind the player's own release at back_share of its damage (Attacks._bolts, once).
static func back_throw(
	w: World,
	spec: AttackSpec,
	ctx: AttackContext,
	dmg: int,
	r: float,
	gap: float,
	life: int,
	bounce: int
) -> void:
	var dir := -Kin.dir(ctx.angle)
	w.queue_projectile(
		w.actors.ids[0],
		ActorStore.TEAM_PLAYER,
		ctx.origin + dir * gap,
		dir * spec.speed,
		share(dmg, param(w, "back_share")),
		r,
		maxi(1, life),
		ctx.tags,
		bounce,
		spec.key
	)
	w.set_pending_second(ProjectileStore.SECONDARY)


## Echo: a ghost lance of the lance just launched from `at` along `ang` (damage `dmg` before the share) waits.
static func add_echo(w: World, at: Vector2, ang: int, dmg: int, r: float, bounce: int) -> void:
	var j := _add(
		w,
		K_ECHO,
		0,
		at,
		w.tick + ticks(param(w, "echo_delay_ms")),
		share(dmg, param(w, "echo_share")),
		ang,
		w.take_root()
	)
	if j >= 0:
		w.mx.lm_r[j] = int(round(r * 1000.0))
		w.mx.lm_aux[j] = bounce


# --- Rows -----------------------------------------------------------------------------------------------------------
## The row of lance projectile `pid` (a K_BALL), or -1.
static func row_of(s: ModifierState, pid: int) -> int:
	for k in s.lm_kind.size():
		if s.lm_kind[k] & KIND_MASK == K_BALL and s.lm_pid[k] == pid:
			return k
	return -1


static func _add(
	w: World, kind: int, pid: int, at: Vector2, due: int, dmg: int, ang: int, root: int
) -> int:
	var s := w.mx
	if s.lm_kind.size() >= ROWS_MAX:
		return -1
	s.lm_next += 1
	s.lm_id.append(s.lm_next)
	s.lm_kind.append(kind)
	s.lm_pid.append(pid)
	s.lm_at.append(at)
	s.lm_due.append(due)
	s.lm_born.append(w.tick)
	s.lm_ang.append(ang)
	s.lm_dmg.append(dmg)
	s.lm_r.append(0)
	s.lm_aux.append(0)
	s.lm_root.append(root)
	return s.lm_kind.size() - 1


static func _remove(s: ModifierState, k: int) -> void:
	var id: int = s.lm_id[k]
	s.lm_id.remove_at(k)
	s.lm_kind.remove_at(k)
	s.lm_pid.remove_at(k)
	s.lm_at.remove_at(k)
	s.lm_due.remove_at(k)
	s.lm_born.remove_at(k)
	s.lm_ang.remove_at(k)
	s.lm_dmg.remove_at(k)
	s.lm_r.remove_at(k)
	s.lm_aux.remove_at(k)
	s.lm_root.remove_at(k)
	if s.lm_kind.is_empty():
		s.lm_clear()
		return
	var keep := PackedInt32Array()
	for key in s.lm_hit:
		if (key >> 16) != id:
			keep.append(key)
	s.lm_hit = keep


## Lance projectile `pi` just spawned (World._apply_spawns): with cards it gets a K_BALL row.
static func on_spawn(w: World, pi: int) -> void:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER:
		return
	var spec := Attacks.projectile_spec(w, pi)
	if mask(spec) == 0:
		return
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	_add(w, K_BALL, p.ids[pi], Vector2.ZERO, w.tick, 0, Kin.angle_of(v), p.root_id[pi])


# --- Flight ---------------------------------------------------------------------------------------------------------
## Before lance projectile `pi`'s sweep (ProjectileMoves.steer): Homing bends it toward the nearest enemy ahead.
static func steer(w: World, pi: int) -> void:
	var s := w.mx
	if s.lm_kind.is_empty():
		return
	var p := w.projectiles
	if row_of(s, p.ids[pi]) < 0:
		return
	if mask(Attacks.projectile_spec(w, pi)) & HOMING == 0:
		return
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var sp := Kin.length(v)
	if sp <= 0.0:
		return
	var at := Vector2(p.pos_x[pi], p.pos_y[pi])
	var cur := Kin.angle_of(v)
	var cone := SimTick.ANGLE_UNITS * param(w, "home_cone_deg") / 360
	var best := -1
	var best_d := 0.0
	for i in w.enemies_near(at, mm(param(w, "home_range_mm"))):
		if w.actors.invuln[i] > 0:
			continue
		var d := w.actors.pos(i) - at
		var touch := p.radius[pi] + w.actors.radius[i]
		var dl := d.length_squared()
		if dl <= touch * touch or Kin.angle_diff(Kin.angle_of(d), cur) > cone:
			continue
		if best < 0 or dl < best_d:
			best = i
			best_d = dl
	if best < 0:
		return
	var step := SimTick.ANGLE_UNITS * param(w, "home_turn_dps") / (360 * HZ)
	var want := Kin.angle_of(w.actors.pos(best) - at)
	var nv := Kin.dir(Kin.turn_toward(cur, want, step)) * sp
	p.vel_x[pi] = nv.x
	p.vel_y[pi] = nv.y


## Lance projectile `pi` (of the player) just hit enemy `target` (World._projectile_hits): Split spits two shards
## sideways, for the first split_max enemies a lance pierces.
static func on_hit(w: World, pi: int, target: int) -> void:
	var s := w.mx
	if s.lm_kind.is_empty():
		return
	var p := w.projectiles
	var k := row_of(s, p.ids[pi])
	if k < 0:
		return
	var spec := Attacks.projectile_spec(w, pi)
	if mask(spec) & SPLIT == 0 or s.lm_aux[k] >= param(w, "split_max"):
		return
	s.lm_aux[k] += 1
	var from := w.actors.pos(target)
	var ang := Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))
	var dmg := share(p.damage[pi], param(w, "split_share"))
	for side in 2:
		_shard(w, spec, from, (ang + (1024 if side == 0 else 3072)) & 4095, dmg, target)


## One shard from `from` along `ang`: every enemy but `skip` along its line (split_len_mm, stopped by a wall) takes
## `dmg` once, now; a row keeps its line for the view.
static func _shard(
	w: World, spec: AttackSpec, from: Vector2, ang: int, dmg: int, skip: int
) -> void:
	var dir := Kin.dir(ang)
	var to := BombMods.clear_point(w, from, dir, mm(param(w, "split_len_mm")))
	var seg := to - from
	var rr := mm(param(w, "split_width_mm"))
	var c := AttackContext.make(from, ang, dmg, w.take_root(), SimEvent.TAG_SHRAPNEL, &"")
	c.depth = spec.depth
	c.proc_pct = maxi(1, 100 >> spec.depth)
	c.secondary = true
	var len2 := seg.length_squared()
	for i in w.enemies_near(from + seg * 0.5, Kin.length(seg) * 0.5 + rr):
		if i == skip:
			continue
		var at := w.actors.pos(i)
		var t := clampf((at - from).dot(seg) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
		if (from + seg * t).distance_to(at) > rr + w.actors.radius[i]:
			continue
		Attacks.land(w, spec, c, i, from, at)
	var j := _add(w, K_SHARD, 0, from, w.tick + maxi(1, param(w, "split_ticks")), 0, ang, 0)
	if j >= 0:
		w.mx.lm_r[j] = int(round(Kin.length(seg) * 1000.0))


# --- The end --------------------------------------------------------------------------------------------------------
## Lance projectile `pi` of `spec` ended at `at` (Attacks.on_projectile_end): its row goes; Ring queues a ring.
static func on_end(w: World, spec: AttackSpec, pi: int, at: Vector2) -> void:
	var s := w.mx
	if s.lm_kind.is_empty():
		return
	var p := w.projectiles
	var k := row_of(s, p.ids[pi])
	if k < 0:
		return
	var flags: int = s.lm_kind[k]
	var ang: int = s.lm_ang[k]
	_remove(s, k)
	if flags & F_NOFOLLOW or mask(spec) & RING == 0:
		return
	var r := int(round(Stats.area(w, mm(param(w, "ring_mm"))) * 1000.0))
	var due := w.tick + ticks(param(w, "ring_ms"))
	var j := _add(
		w, K_RING, 0, at, due, share(p.damage[pi], param(w, "ring_share")), ang, w.take_root()
	)
	if j >= 0:
		s.lm_r[j] = r


# --- State, each tick -----------------------------------------------------------------------------------------------
## Tick phase 6 (ModifierRuntime.advance): the ghosts to open, the rings, the shards, the rows of lances that are gone.
static func advance(w: World) -> void:
	var s := w.mx
	if s.lm_kind.is_empty():
		return
	var spec := Modifiers.bolt(w) if PlayerBuild.has_gun(w) else null
	if spec == null or spec.lance <= 0:
		s.lm_clear()
		return
	var ids := w.projectiles.ids
	var k := 0
	while k < s.lm_kind.size():
		var kind: int = s.lm_kind[k] & KIND_MASK
		if kind == K_BALL:
			var at := ids.bsearch(s.lm_pid[k])
			if at >= ids.size() or ids[at] != s.lm_pid[k]:
				_remove(s, k)  # its lance is gone without ending here (a new room): no follow-ups
				continue
		elif kind == K_ECHO:
			if w.tick >= s.lm_due[k]:
				_open(w, spec, k)
				continue
		elif kind == K_RING:
			if _ring(w, spec, k):
				continue
		elif w.tick >= s.lm_due[k]:  # K_SHARD
			_remove(s, k)
			continue
		k += 1


## Row `k` (a K_ECHO) opens a ghost lance on the same line and goes.
static func _open(w: World, spec: AttackSpec, k: int) -> void:
	var s := w.mx
	var at: Vector2 = s.lm_at[k]
	var ang: int = s.lm_ang[k]
	var dmg: int = s.lm_dmg[k]
	var r: float = s.lm_r[k] / 1000.0
	var bounce: int = s.lm_aux[k]
	var root: int = s.lm_root[k]
	_remove(s, k)
	var p := w.projectiles
	var id := w.take_id()
	p.add(
		id,
		w.actors.ids[0],
		ActorStore.TEAM_PLAYER,
		at,
		Kin.dir(ang) * spec.speed,
		r,
		maxi(1, spec.life_ticks),
		dmg,
		SimEvent.TAG_PROJECTILE,
		bounce
	)
	var pi := p.size() - 1
	p.spec_key[pi] = spec.key
	p.set_second(pi, ProjectileStore.SECONDARY)
	ProjectileMoves.on_spawn(w, pi)  # its pierce, as any lance's
	var j := _add(w, K_BALL | F_NOFOLLOW, id, Vector2.ZERO, w.tick, 0, ang, root)
	if j >= 0:
		s.lm_aux[j] = 0


## Ring row `k` this tick: its radius, the enemies it newly reaches; true if it ended (removed).
static func _ring(w: World, spec: AttackSpec, k: int) -> bool:
	var s := w.mx
	var at: Vector2 = s.lm_at[k]
	var born: int = s.lm_born[k]
	var due: int = s.lm_due[k]
	var span := maxi(1, due - born)
	var id: int = s.lm_id[k]
	var now := mini(w.tick - born, span)
	if now > 0:
		var r := mm(int(s.lm_r[k]) * now / span)
		var c := AttackContext.make(at, 0, s.lm_dmg[k], s.lm_root[k], SimEvent.TAG_AREA, &"")
		c.depth = spec.depth
		c.proc_pct = maxi(1, 100 >> spec.depth)
		c.secondary = true
		for i in w.enemies_near(at, r):
			var key := id * 65536 + i
			if s.lm_hit.has(key):
				continue
			s.lm_hit.append(key)
			Attacks.land(w, spec, c, i, at, w.actors.pos(i))
	if w.tick >= due:
		_remove(s, k)
		return true
	return false


# --- For the view ---------------------------------------------------------------------------------------------------
## The rings growing: [{pos, r (m, the ring's largest), age, span}].
static func read_rings(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := w.mx
	for k in s.lm_kind.size():
		if s.lm_kind[k] & KIND_MASK == K_RING:
			(
				out
				. append(
					{
						"pos": s.lm_at[k],
						"r": s.lm_r[k] / 1000.0,
						"age": w.tick - s.lm_born[k],
						"span": maxi(1, s.lm_due[k] - s.lm_born[k]),
					}
				)
			)
	return out


## The split shards in view: [{from, to, age, span}].
static func read_shards(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := w.mx
	for k in s.lm_kind.size():
		if s.lm_kind[k] & KIND_MASK == K_SHARD:
			var from: Vector2 = s.lm_at[k]
			(
				out
				. append(
					{
						"from": from,
						"to": from + Kin.dir(s.lm_ang[k]) * (s.lm_r[k] / 1000.0),
						"age": w.tick - s.lm_born[k],
						"span": maxi(1, s.lm_due[k] - s.lm_born[k]),
					}
				)
			)
	return out
