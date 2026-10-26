class_name LaserMods
extends RefCounted
## v0.9.5 FC1 (owner: "homing + laser would make the laser follow the neares enemy making a smooth curve, and with
## pierce it would make a smooth curve trying to hit the closest 5 enemies"; docs/roadmap/v0.9.5/FORM_COMBOS.md L1-L11):
## what eleven cards do to the Laser's beam. One handler per card. A held beam ignores these cards' generic ops
## (WandCompile.run: it only notes the card in modifier_ids), and this file reads them from there: mask(spec).
## - Geometry (plan(), a pure read, the one the tick's hits and the view's beams share, EI-07): the main path of each
##   lane (straight; bent by Homing; reflected once by Ricochet) and the extra beams (Halo's fan, Backfire, Split's
##   fork) and Ring's circle, each a {from, to, hits, at, wall, kind, lane, share, ...} dictionary.
## - State (World.mx lz_*, advance() each tick): the beam's aim (Homing and Big Shot lag the player's aim), Homing's
##   targets (re-picked every 0.2 s), the ticks held (Rapid Fire's ramp), Echo's waiting strikes and Mine's mines.
## - Numbers: data/wand/attack_slots.tres, the laser row's `params` (SlotTable.params); DEFAULTS are the same values,
##   read by a world without the table (a lab) and checked against the data by the content test.
## Caps: a beam is no projectile, so none of this counts in the projectile caps; a kind hits an enemy at most once a
## tick (fire()), the path has at most MAX_LEGS legs, Echo keeps at most 8 ticks and Mine 4 mines.
## Pure: integer maths (angles in 1/4096 turns, Kin), no randomness, one clock.

const HALO := 1
const RING := 2
const BACKFIRE := 4
const HOMING := 8
const RICOCHET := 16
const ECHO := 32
const BIG := 64
const RAPID := 128
const SPLIT := 256
const MINE := 512
const SPIRAL := 1024
## The cards by bit.
const CARD_IDS: Array[StringName] = [
	&"halo_shot",
	&"gun_ring",
	&"gun_backfire",
	&"gun_homing",
	&"gun_ricochet",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"split_shot",
	&"gun_mine",
	&"gun_spiral",
]
const CARD_BITS: Array[int] = [
	HALO, RING, BACKFIRE, HOMING, RICOCHET, ECHO, BIG, RAPID, SPLIT, MINE, SPIRAL
]
## What a beam dictionary's `kind` is.
const K_MAIN := &"main"
const K_HALO := &"halo"
const K_RING := &"ring"
const K_BACK := &"back"
const K_SPLIT := &"split"
## The most legs of one path (a curve of short steps, a bounce).
const MAX_LEGS := 14
const ECHO_TICKS_MAX := 8
const HZ := 60
## The laser row's numbers (units in the names; data/wand/attack_slots.tres carries the same).
const DEFAULTS := {
	"halo_len_mm": 3000,
	"halo_turn_deg": 30,
	"halo_share": 400,
	"ring_mm": 1400,
	"ring_share": 500,
	"back_mm": 4500,
	"back_share": 1000,
	"home_dps": 120,
	"home_repick_ms": 200,
	"home_step_mm": 1500,
	"home_bend_deg": 25,
	"home_chain": 5,
	"echo_delay_ms": 400,
	"echo_share": 500,
	"big_width": 2000,
	"big_damage": 1600,
	"big_turn": 700,
	"follow_dps": 720,
	"rapid_period_ms": 50,
	"rapid_ramp_ms": 2000,
	"rapid_width": 500,
	"rapid_damage_permille": 650,
	"split_mm": 4000,
	"split_deg": 25,
	"split_share": 500,
	"mine_every_ms": 1000,
	"mine_mm": 1500,
	"mine_share": 5000,
	"mine_max": 4,
	"mine_life_ms": 4000,
	"mine_trigger_mm": 600,
	"spiral_deg": 12,
	"spiral_hz": 2,
}


# --- Cards and numbers --------------------------------------------------------------------------------------------
## The bit mask of the laser cards the held beam `spec` carries (0: a plain Laser, nothing here runs).
static func mask(spec: AttackSpec) -> int:
	if spec == null or spec.modifier_ids.is_empty():
		return 0
	var m := 0
	for k in CARD_IDS.size():
		if spec.modifier_ids.has(String(CARD_IDS[k])):
			m |= CARD_BITS[k]
	return m


## `id` is one of the eleven cards (WandCompile.run: on a held beam its generic ops are skipped).
static func is_card(id: StringName) -> bool:
	return CARD_IDS.has(id)


## The laser row's number `key` (data, else the default).
static func param(w: World, key: String) -> int:
	var t := w.slot_table
	if t != null:
		var p: Dictionary = t.params.get(&"laser", {})
		if p.has(key):
			return int(p[key])
	return int(DEFAULTS[key])


static func ticks(ms: int) -> int:
	return maxi(1, ms * HZ / 1000)


static func deg(d: int) -> int:
	return d * SimTick.ANGLE_UNITS / 360


static func mm(v: int) -> float:
	return v / 1000.0


## Units of angle a tick turns at `dps` degrees a second (dithered over the clock: exact on average).
static func turn_step(dps: int, tick: int) -> int:
	var u := deg(dps)
	return u * (tick + 1) / HZ - u * tick / HZ


## The tick damage factor (per mille): Big Shot's +60 %; Rapid Fire's ticks come faster, so each deals less (FC2
## follow-up: 1000 down to rapid_damage_permille along the same ramp as the period, so a ramped beam deals about 1.3x
## a plain one).
static func damage_permille(w: World, m: int) -> int:
	var f := param(w, "big_damage") if m & BIG else 1000
	if m & RAPID:
		var ramp := ticks(param(w, "rapid_ramp_ms"))
		var h := clampi(w.mx.lz_hold, 0, ramp)
		f = f * (1000 - (1000 - param(w, "rapid_damage_permille")) * h / ramp) / 1000
	return f


## The beam's width factor (per mille): Big Shot's double, Rapid Fire's thinning with the ramp.
static func width_permille(w: World, m: int) -> int:
	var f := 1000
	if m & BIG:
		f = f * param(w, "big_width") / 1000
	if m & RAPID:
		var ramp := ticks(param(w, "rapid_ramp_ms"))
		var h := clampi(w.mx.lz_hold, 0, ramp)
		f = f * (1000 - (1000 - param(w, "rapid_width")) * h / ramp) / 1000
	return f


## Rapid Fire: the tick period `base` shortens to rapid_period_ms over rapid_ramp_ms of holding.
static func rapid_period(w: World, spec: AttackSpec, base: int) -> int:
	if not Laser.held(spec) or mask(spec) & RAPID == 0:
		return base
	var quick := ticks(param(w, "rapid_period_ms"))
	if base <= quick:
		return base
	var ramp := ticks(param(w, "rapid_ramp_ms"))
	var h := clampi(w.mx.lz_hold, 0, ramp)
	return base - (base - quick) * h / ramp


## Spiral: the beam's side-to-side turn now (1/4096 turns), a triangle wave on the sim clock.
static func spiral_offset(w: World) -> int:
	var hz := param(w, "spiral_hz")
	var period := maxi(1, HZ / hz)
	var u := ((w.tick % period) * 120 + 60) / period  # 0..119 over one wave, the peaks on whole ticks
	var v := u if u < 30 else (60 - u if u < 90 else u - 120)  # -30..30
	return deg(param(w, "spiral_deg")) * v / 30


## The heading the main beam has now: the player's aim (or the lagging one Homing and Big Shot keep), plus Spiral.
static func heading(w: World, m: int, angle: int) -> int:
	var a := angle
	if m & (HOMING | BIG) != 0 and w.mx.lz_aim >= 0:
		a = w.mx.lz_aim
	if m & SPIRAL:
		a += spiral_offset(w)
	return a & 4095


# --- Geometry -----------------------------------------------------------------------------------------------------
## One straight sweep from `from` along `dir` for `length`, `r` wide: stopped by a wall, or by its `most`-th enemy
## (the ones in `seen` don't count). {from, to, hits (nearest first), at, wall (it ended on one), wall_k (its index
## or -1)}.
static func ray(
	w: World, from: Vector2, dir: Vector2, length: float, r: float, most: int, seen: Dictionary
) -> Dictionary:
	var to := from + dir * length
	var wall := 1.0
	var wall_k := -1
	for k in w.walls_along(from, to, r):  # the grid's superset of the walls
		var s := Collide.sweep_vs_obb(from, to, r, w.walls[k])
		if s >= 0.0 and s < wall:
			wall = s
			wall_k = k
	var ts := PackedFloat32Array()
	var ids := PackedInt32Array()
	var a := w.actors
	for i in range(1, a.size()):  # every actor (phase 4 runs before the tick's grid)
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1 or seen.has(i):
			continue
		var s := Collide.sweep_vs_circle(from, to, r, a.pos(i), a.radius[i])
		if s < 0.0 or s >= wall:
			continue
		var at := ts.size()  # nearest first; a tie keeps the lower index
		while at > 0 and ts[at - 1] > s:
			at -= 1
		ts.insert(at, s)
		ids.insert(at, i)
	var end := wall
	var hit_wall := wall < 1.0
	if ids.size() >= most:
		ids.resize(most)
		ts.resize(most)
		end = ts[most - 1]
		hit_wall = false
	var pts := PackedVector2Array()
	for s in ts:
		pts.append(from + (to - from) * s)
	return {
		"from": from,
		"to": from + (to - from) * end,
		"hits": ids,
		"at": pts,
		"wall": hit_wall,
		"wall_k": wall_k if hit_wall else -1,
	}


## The beams of `spec` from `origin` along `angle` now with the laser cards (Laser.trace calls it for a card-carrying
## beam): the lanes' main legs, then the centre lane's extras. Each also has kind, lane, share (per mille of the tick's
## damage), wmul (width per mille), impact (draw an impact at `to`) and end (the lane's last main leg).
static func plan(w: World, spec: AttackSpec, origin: Vector2, angle: int) -> Array[Dictionary]:
	var m := mask(spec)
	var out: Array[Dictionary] = []
	var base := heading(w, m, angle)
	var wmul := width_permille(w, m)
	var r := spec.radius_m * wmul / 1000.0
	var lanes := GunForms.lanes(spec, Laser.LANE_RADIUS_M)
	var turns := GunForms.lane_turns(spec)
	var centre := (lanes.size() - 1) / 2
	for li in lanes.size():
		var ang := (base + turns[li]) & 4095
		var dir := Kin.dir(ang)
		var from := origin + dir * w.player.radius_m + Vector2(-dir.y, dir.x) * lanes[li]
		var path := _path(w, spec, m, from, ang, r)
		var legs: Array[Dictionary] = path["legs"]
		for k in legs.size():
			var leg := legs[k]
			leg["kind"] = K_MAIN
			leg["lane"] = li
			leg["share"] = 1000
			leg["wmul"] = wmul
			leg["end"] = k == legs.size() - 1
			leg["impact"] = k == legs.size() - 1 and (leg["hits"].size() > 0 or bool(leg["wall"]))
			out.append(leg)
		if li == centre:
			_extras(w, spec, m, origin, base, path, r, wmul, li, out)
	return out


## The main path of one lane: {legs, tip (where it ends), heading (its last leg's), first (the first enemy hit, or -1),
## first_at, first_heading}. Straight unless Homing bends it or Ricochet reflects it.
static func _path(
	w: World, spec: AttackSpec, m: int, from: Vector2, ang: int, r: float
) -> Dictionary:
	var most := maxi(0, spec.pierce) + 1
	var seen := {}
	var legs: Array[Dictionary] = []
	var out := {"legs": legs, "first": -1, "first_at": from, "first_heading": ang, "heading": ang}
	var homing := m & HOMING != 0
	var bounce := m & RICOCHET != 0
	var targets := w.mx.lz_targets if homing else PackedInt32Array()
	var a := w.actors
	var pos := from
	var hd := ang
	var remain := spec.reach_m
	var got := 0
	var bounced := false
	var ti := 0
	var bend := deg(param(w, "home_bend_deg"))
	var step_m := mm(param(w, "home_step_mm"))
	while remain > 0.01 and legs.size() < MAX_LEGS and got < most:
		var steering := false
		if homing:
			while ti < targets.size() and _gone(w, targets[ti]):
				ti += 1
			steering = ti < targets.size()
			if steering:
				hd = Kin.turn_toward(hd, Kin.angle_of(a.pos(targets[ti]) - pos), bend)
		var len := minf(step_m, remain) if steering else remain
		var leg := ray(w, pos, Kin.dir(hd), len, r, most - got, seen)
		for id in leg["hits"]:
			seen[id] = true
		if got == 0 and leg["hits"].size() > 0:
			out["first"] = leg["hits"][0]
			out["first_at"] = leg["at"][0]
			out["first_heading"] = hd
		got += leg["hits"].size()
		legs.append(leg)
		remain -= Kin.length(leg["to"] - leg["from"])
		pos = leg["to"]
		out["heading"] = hd
		if got >= most:
			break
		if leg["wall"]:
			if not bounce or bounced:
				break
			var box: Obb = w.walls[leg["wall_k"]]
			var n := _normal(box, pos, r)
			var d := Kin.dir(hd)
			hd = Kin.angle_of(d - n * (2.0 * d.dot(n)))
			pos += n * 0.03
			bounced = true
			continue
		if steering and Kin.length(a.pos(targets[ti]) - pos) <= r + a.radius[targets[ti]] + 0.3:
			ti += 1
	out["tip"] = legs.back()["to"]
	out["seen"] = seen
	return out


static func _gone(w: World, i: int) -> bool:
	return i <= 0 or i >= w.actors.size() or w.actors.dead[i] == 1


## The outward normal of the wall box at the point `p` on its (grown) face.
static func _normal(box: Obb, p: Vector2, r: float) -> Vector2:
	var d := p - box.center
	var lx := d.dot(box.axis_u)
	var ly := d.dot(box.axis_v)
	if absf(lx) / (box.half.x + r) >= absf(ly) / (box.half.y + r):
		return box.axis_u if lx >= 0.0 else -box.axis_u
	return box.axis_v if ly >= 0.0 else -box.axis_v


static func _extras(
	w: World,
	spec: AttackSpec,
	m: int,
	origin: Vector2,
	base: int,
	path: Dictionary,
	r: float,
	wmul: int,
	lane: int,
	out: Array[Dictionary]
) -> void:
	var most := maxi(0, spec.pierce) + 1
	var tip: Vector2 = path["tip"]
	var hd: int = path["heading"]
	if m & HALO:
		var span := deg(param(w, "halo_turn_deg"))
		for k in range(-1, 2):
			var d := Kin.dir((hd + k * span) & 4095)
			var b := ray(w, tip, d, mm(param(w, "halo_len_mm")), r, most, path["seen"])  # past what the beam hit
			_tag(b, K_HALO, lane, param(w, "halo_share"), wmul)
			out.append(b)
	if m & RING:
		var ring_r := mm(param(w, "ring_mm"))
		var ids := w.enemies_near(tip, ring_r)
		var pts := PackedVector2Array()
		for i in ids:
			pts.append(w.actors.pos(i))
		var b := {"from": tip, "to": tip, "hits": ids, "at": pts, "wall": false, "circle": ring_r}
		_tag(b, K_RING, lane, param(w, "ring_share"), wmul)
		b["impact"] = false
		out.append(b)
	if m & BACKFIRE:
		var d := Kin.dir((base + 2048) & 4095)
		var from := origin + d * w.player.radius_m
		var b := ray(w, from, d, mm(param(w, "back_mm")), r, most, {})
		_tag(b, K_BACK, lane, param(w, "back_share"), wmul)
		out.append(b)
	if m & SPLIT and int(path["first"]) > 0:
		var at: Vector2 = path["first_at"]
		var fh: int = path["first_heading"]
		var span := deg(param(w, "split_deg"))
		for s in [-1, 1]:
			var d := Kin.dir((fh + s * span) & 4095)
			var b := ray(w, at, d, mm(param(w, "split_mm")), r, most, {int(path["first"]): true})
			_tag(b, K_SPLIT, lane, param(w, "split_share"), wmul)
			out.append(b)


static func _tag(b: Dictionary, kind: StringName, lane: int, share: int, wmul: int) -> void:
	b["kind"] = kind
	b["lane"] = lane
	b["share"] = share
	b["wmul"] = wmul
	b["end"] = true
	b["impact"] = b["hits"].size() > 0 or bool(b["wall"])


# --- State, each tick ---------------------------------------------------------------------------------------------
## Tick phase 6 (ModifierRuntime.advance): the beam's aim and targets while it fires, the ramp, Echo's strikes and the
## mines' triggers. A plain Laser (no card here) touches nothing.
static func advance(w: World) -> void:
	var s := w.mx
	var spec := Modifiers.bolt(w) if PlayerBuild.has_gun(w) else null
	var m := mask(spec) if Laser.held(spec) else 0
	if m == 0:
		if s.lz_touched():
			s.lz_clear()
		return
	if Laser.firing(w):
		s.lz_hold += 1
		if m & (HOMING | BIG):
			_steer(w, spec, m)
	else:
		s.lz_hold = 0
		s.lz_aim = -1
		s.lz_targets = PackedInt32Array()
		s.lz_mine_next = 0
	_echo_strikes(w, spec)
	_mine_triggers(w, spec)


## Homing and Big Shot: the beam's aim follows its wish (the player's aim, or the nearest enemy's direction with
## Homing) at most home_dps (follow_dps for Big Shot alone) a second, Big Shot 30 % slower still.
static func _steer(w: World, spec: AttackSpec, m: int) -> void:
	var s := w.mx
	var want := w.aim_angle
	if m & HOMING:
		_pick(w, spec)
		if s.lz_targets.size() > 0:
			want = Kin.angle_of(w.actors.pos(s.lz_targets[0]) - w.player_pos())
	var cur := s.lz_aim if s.lz_aim >= 0 else w.aim_angle
	var dps := param(w, "home_dps") if m & HOMING else param(w, "follow_dps")
	if m & BIG:
		dps = dps * param(w, "big_turn") / 1000
	s.lz_aim = Kin.turn_toward(cur, want, turn_step(dps, w.tick))


## Homing's targets: the nearest enemies within the beam's reach, nearest first (the nearest alone, or with Pierce up to
## pierce + 1, at most home_chain), picked again every home_repick_ms and when one is gone.
static func _pick(w: World, spec: AttackSpec) -> void:
	var s := w.mx
	var stale := s.lz_targets.is_empty() or w.tick % ticks(param(w, "home_repick_ms")) == 0
	for i in s.lz_targets:
		stale = stale or _gone(w, i)
	if not stale:
		return
	var hero := w.player_pos()
	var found := w.enemies_near(hero, spec.reach_m)
	var ds: Array[float] = []
	var ids: Array[int] = []
	for i in found:
		var d := Kin.length(w.actors.pos(i) - hero)
		var at := ids.size()  # nearest first; a tie keeps the lower index
		while at > 0 and (ds[at - 1] > d or (ds[at - 1] == d and ids[at - 1] > i)):
			at -= 1
		ds.insert(at, d)
		ids.insert(at, i)
	var n := mini(ids.size(), mini(param(w, "home_chain"), maxi(0, spec.pierce) + 1))
	var out := PackedInt32Array()
	for k in n:
		out.append(ids[k])
	s.lz_targets = out


## One tick of the beam (Laser.fire, `beams` its plan, `milli` the thousandths of damage it deals): Echo stores the
## main legs to strike again, Mine drops a mine at the tip every mine_every_ms.
static func after_tick(w: World, m: int, beams: Array[Dictionary], dmg: int, milli: int) -> void:
	var s := w.mx
	if m & ECHO and dmg > 0:
		var e := maxi(1, dmg * param(w, "echo_share") / 1000)
		_echo_store(w, beams, e)
	if m & MINE:
		if s.lz_mine_next == 0:
			s.lz_mine_next = w.tick + ticks(param(w, "mine_every_ms"))
		elif w.tick >= s.lz_mine_next:
			s.lz_mine_next = w.tick + ticks(param(w, "mine_every_ms"))
			var tip := _tip(beams)
			if s.lz_mine_at.size() >= param(w, "mine_max"):
				s.lz_mine_at.remove_at(0)
				s.lz_mine_born.remove_at(0)
				s.lz_mine_dmg.remove_at(0)
			s.lz_mine_at.append(tip)
			s.lz_mine_born.append(w.tick)
			s.lz_mine_dmg.append(maxi(1, milli * param(w, "mine_share") / 1000000))


static func _tip(beams: Array[Dictionary]) -> Vector2:
	var tip: Vector2 = beams[0]["to"]
	for b in beams:
		if b["kind"] == K_MAIN and bool(b["end"]):
			tip = b["to"]
			break
	return tip


static func _echo_store(w: World, beams: Array[Dictionary], dmg: int) -> void:
	var s := w.mx
	var due := w.tick + ticks(param(w, "echo_delay_ms"))
	var groups := 0
	var last := -1
	for d in s.lz_echo_due:
		if d != last:
			groups += 1
			last = d
	if groups >= ECHO_TICKS_MAX:  # the oldest tick's strike is dropped
		var first: int = s.lz_echo_due[0]
		while s.lz_echo_due.size() > 0 and s.lz_echo_due[0] == first:
			_echo_remove(s, 0)
	for b in beams:
		if b["kind"] != K_MAIN:
			continue
		s.lz_echo_due.append(due)
		s.lz_echo_from.append(b["from"])
		s.lz_echo_to.append(b["to"])
		s.lz_echo_r.append(float(b["wmul"]) * spec_radius(w) / 1000.0)
		s.lz_echo_dmg.append(dmg)


static func spec_radius(w: World) -> float:
	return Modifiers.bolt(w).radius_m


static func _echo_remove(s: ModifierState, k: int) -> void:
	s.lz_echo_due.remove_at(k)
	s.lz_echo_from.remove_at(k)
	s.lz_echo_to.remove_at(k)
	s.lz_echo_r.remove_at(k)
	s.lz_echo_dmg.remove_at(k)


## The waiting strikes whose tick has come: each hits every enemy on its leg (once for its tick).
static func _echo_strikes(w: World, spec: AttackSpec) -> void:
	var s := w.mx
	var k := 0
	var seen := {}
	var root := -1
	while k < s.lz_echo_due.size():
		if s.lz_echo_due[k] > w.tick:
			k += 1
			continue
		if root < 0:
			root = w.take_root()
		var due: int = s.lz_echo_due[k]
		var from: Vector2 = s.lz_echo_from[k]
		var to: Vector2 = s.lz_echo_to[k]
		var c := AttackContext.make(
			from, 0, s.lz_echo_dmg[k], root, SimEvent.TAG_AREA, spec.effect_id
		)
		c.secondary = true
		var a := w.actors
		for i in range(1, a.size()):
			if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1 or seen.has(due * 100000 + i):
				continue
			var t := Collide.sweep_vs_circle(from, to, s.lz_echo_r[k], a.pos(i), a.radius[i])
			if t < 0.0:
				continue
			seen[due * 100000 + i] = true
			Laser.hit(w, spec, c, i, from, a.pos(i), false)
		_echo_remove(s, k)


## The mines: one expires after mine_life_ms; an enemy on it sets it off, a mine_mm burst of its stored damage.
static func _mine_triggers(w: World, spec: AttackSpec) -> void:
	var s := w.mx
	var k := 0
	var life := ticks(param(w, "mine_life_ms"))
	var trig := mm(param(w, "mine_trigger_mm"))
	var burst := mm(param(w, "mine_mm"))
	while k < s.lz_mine_at.size():
		var at: Vector2 = s.lz_mine_at[k]
		if w.tick - s.lz_mine_born[k] >= life:
			_mine_remove(s, k)
			continue
		if w.enemies_near(at, trig).is_empty():
			k += 1
			continue
		var dmg: int = s.lz_mine_dmg[k]
		_mine_remove(s, k)
		var c := AttackContext.make(at, 0, dmg, w.take_root(), SimEvent.TAG_AREA, spec.effect_id)
		c.secondary = true
		for i in w.enemies_near(at, burst):
			Laser.hit(w, spec, c, i, at, w.actors.pos(i), false)


static func _mine_remove(s: ModifierState, k: int) -> void:
	s.lz_mine_at.remove_at(k)
	s.lz_mine_born.remove_at(k)
	s.lz_mine_dmg.remove_at(k)
