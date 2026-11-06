class_name WispMods
extends RefCounted
## v0.9.5 FC9 (docs/roadmap/v0.9.5/FORM_COMBOS.md P1-P6): what the Gun's cards do to the Wisps form.
## - Eight projectile cards (Pierce, Ricochet, Homing, Echo, Big Shot, Rapid Fire, Split, Spiral) are not handled here:
##   they compile onto the Wisps spec as on the Orbs (the wisps launch that very spec: Wisps._fire), so each wisp's shot
##   carries them through the same per-card code the orbs' shots use. The one generalisation: Echo's repeat is open to
##   a wisp's shot (AttackContext.wisp; Attacks.launch).
## - Five cards are the wisps' own (WandCompile.run: it only notes the id in modifier_ids; mask(spec) reads them):
##   P1 Twin, a fourth wisp (count()); P2 Halo, six wisps at 60 % damage each (count(), share()); P3 Ring, each shot
##   rings where it hits (on_hit(): 1 m, the shot's damage, each enemy once, drawn as the Void's and the Glaive's
##   lightning ring); P5 Mine, each wisp drops a mine every mine_gap_ticks (drops(); the mine is the Mine card's, built
##   by WandCompile._wisp_mine as an ON_WISP hook), at most live_max live mines (cull(): the oldest end first);
##   P6 Orbit, the wisps circle at orbit_mm and hurt what they touch at orbit_share of a shot, each enemy once per
##   orbit_gap_ticks per wisp (touch()).
## - Rows (World.mx pm_*): the rings the view draws and Orbit's hit gaps; hashed only while set (older digests
##   unchanged), listed in SNAPSHOT_FIELDS (an older save loads with none).
## - Numbers: data/wand/attack_slots.tres, the wisps row's `params` (SlotTable.params); DEFAULTS are the same values,
##   read by a world without the table (a lab) and checked against the data by the content test.
## Pure: integer maths and the clock (the wisps' places are World.tick's), no randomness, one clock.

const TWIN := 1
const HALO := 2
const RING := 4
const MINE := 8
const ORBIT := 16
## The cards by bit.
const CARD_IDS: Array[StringName] = [
	&"gun_twin", &"halo_shot", &"gun_ring", &"gun_mine", &"orbit_rounds"
]
const CARD_BITS: Array[int] = [TWIN, HALO, RING, MINE, ORBIT]
const MINE_ID := &"gun_mine"
const ROWS_MAX := 16
const HZ := 60
## A wisp touches enemies this close to its centre (m; its drawn orb is about 0.4 across).
const TOUCH_M := 0.4
## The wisps row's numbers (units in the names; data/wand/attack_slots.tres carries the same).
const DEFAULTS := {
	"twin_wisps": 1,
	"halo_wisps": 6,
	"halo_share": 600,
	"ring_mm": 1000,
	"ring_ms": 300,
	"mine_gap_ticks": 120,
	"live_max": 6,
	"orbit_mm": 3500,
	"orbit_share": 500,
	"orbit_gap_ticks": 30,
}
## The ModifierState fields an older save lacks (WorldSnapshot._apply_object reads this list).
const SNAPSHOT_FIELDS: Array[StringName] = [
	&"pm_ring_at", &"pm_ring_born", &"pm_hit_wisp", &"pm_hit_actor", &"pm_hit_until", &"pm_carry"
]


# --- Cards and numbers --------------------------------------------------------------------------------------------
## The bit mask of the Wisps' own cards the wisps spec `spec` carries (0: plain wisps, or not wisps).
static func mask(spec: AttackSpec) -> int:
	if spec == null or spec.wisps <= 0 or spec.modifier_ids.is_empty():
		return 0
	var m := 0
	for k in CARD_IDS.size():
		if spec.modifier_ids.has(String(CARD_IDS[k])):
			m |= CARD_BITS[k]
	return m


## `id` is one of the five cards (WandCompile.run: on the wisps its generic ops are skipped).
static func is_card(id: StringName) -> bool:
	return CARD_IDS.has(id)


## Card `m` stands on the wisps `s` (WandCompile.run): its id is noted.
static func note_card(s: AttackSpec, m: ModifierTable) -> void:
	if not s.modifier_ids.has(String(m.id)):
		s.modifier_ids.append(String(m.id))


## The wisps row's number `key` (data, else the default).
static func param(w: World, key: String) -> int:
	var t := w.slot_table
	if t != null:
		var p: Dictionary = t.params.get(&"wisps", {})
		if p.has(key):
			return int(p[key])
	return int(DEFAULTS[key])


static func mm(v: int) -> float:
	return v / 1000.0


## How many wisps circle the hero: the card's three; Halo six; Twin one more.
static func count(w: World, spec: AttackSpec) -> int:
	var m := mask(spec)
	var n := spec.wisps
	if m & HALO != 0:
		n = param(w, "halo_wisps")
	if m & TWIN != 0:
		n += param(w, "twin_wisps")
	return n


## The wisps' circle radius (m): Orbit's, else the form's.
static func radius_m(w: World, spec: AttackSpec) -> float:
	return mm(param(w, "orbit_mm")) if mask(spec) & ORBIT != 0 else Wisps.ORBIT_R_M


## A wisp shot's damage `dmg` under Halo's share.
static func share(w: World, spec: AttackSpec, dmg: int) -> int:
	if mask(spec) & HALO == 0:
		return dmg
	return maxi(1, (dmg * param(w, "halo_share") + 500) / 1000)


## v0.9.5 FC9b: the whole damage `milli` thousandths deal now; the rest waits in ModifierState.pm_carry (the Seekers'
## rule, SeekerMods.take), so six wisps at 60 % of a shot keep the 0.6. A short carry deals 0 (no minimum of 1).
static func take(w: World, milli: int) -> int:
	var total := w.mx.pm_carry + milli
	w.mx.pm_carry = total % 1000
	return total / 1000


# --- Ring ---------------------------------------------------------------------------------------------------------
## Wisp shot `pi` just hit enemy `target` at `at` (World._projectile_hits): with Ring, the enemies within ring_mm of
## the hit point other than the one struck take the shot's damage, each once, and the ring is drawn.
static func on_hit(w: World, pi: int, target: int, at: Vector2) -> void:
	var p := w.projectiles
	if p.second_of(pi) != ProjectileStore.REPEAT:  # a wisp's shot is a plain repeat (an Echo's ghost is secondary too)
		return
	var spec := Attacks.projectile_spec(w, pi)
	if spec == null or mask(spec) & RING == 0 or not Wisps.is_wisp_shot(w, pi):
		return
	var s := w.mx
	if s.pm_ring_born.size() >= ROWS_MAX:
		s.pm_ring_at.remove_at(0)
		s.pm_ring_born.remove_at(0)
	s.pm_ring_at.append(at)
	s.pm_ring_born.append(w.tick)
	var c := AttackContext.make(at, 0, p.damage[pi], w.take_root(), SimEvent.TAG_AREA, &"")
	c.depth = spec.depth
	c.proc_pct = maxi(1, 100 >> spec.depth)
	c.secondary = true
	for i in w.enemies_near(at, Stats.area(w, mm(param(w, "ring_mm")))):
		if i != target:
			Attacks.land(w, spec, c, i, at, w.actors.pos(i))


## The rings drawn now, for the view: [{pos, r (m, the ring's largest), age, span (ticks)}].
static func read_rings(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := w.mx
	var r := Stats.area(w, mm(param(w, "ring_mm")))
	var span := maxi(1, param(w, "ring_ms") * HZ / 1000)
	for k in s.pm_ring_born.size():
		out.append(
			{"pos": s.pm_ring_at[k], "r": r, "age": w.tick - s.pm_ring_born[k], "span": span}
		)
	return out


# --- Each tick ----------------------------------------------------------------------------------------------------
## Tick phase 6 (Wisps.advance, the wisps being on): the rings and gaps that have run out go; Orbit's touches; Mine's
## drops and bound.
static func advance(w: World, spec: AttackSpec, n: int) -> void:
	var s := w.mx
	if s.pm_touched():
		_expire(w, s)
	var m := mask(spec)
	if m & ORBIT != 0:
		touch(w, spec, n)
	if m & MINE != 0:
		drops(w, spec, n)


static func _expire(w: World, s: ModifierState) -> void:
	var span := maxi(1, param(w, "ring_ms") * HZ / 1000)
	while not s.pm_ring_born.is_empty() and w.tick - s.pm_ring_born[0] >= span:
		s.pm_ring_at.remove_at(0)
		s.pm_ring_born.remove_at(0)
	var q := 0
	while q < s.pm_hit_wisp.size():
		if s.pm_hit_until[q] <= w.tick:
			s.pm_hit_wisp.remove_at(q)
			s.pm_hit_actor.remove_at(q)
			s.pm_hit_until.remove_at(q)
		else:
			q += 1


# --- Orbit --------------------------------------------------------------------------------------------------------
## Orbit: each wisp hurts the enemies it touches for orbit_share of a wisp shot, each enemy at most once per
## orbit_gap_ticks per wisp.
static func touch(w: World, spec: AttackSpec, n: int) -> void:
	var s := w.mx
	var milli := Wisps.shot_milli(w, spec) * param(w, "orbit_share") / 1000  # v0.9.5 FC9b: thousandths
	var dmg := 0
	var gap := param(w, "orbit_gap_ticks")
	var c: AttackContext = null
	for k in n:
		var at := Wisps.pos(w, k, n)
		for i in w.enemies_near(at, TOUCH_M):
			var aid: int = w.actors.ids[i]
			if _blocked(s, k, aid):
				continue
			if c == null:
				c = AttackContext.make(at, 0, dmg, w.take_root(), SimEvent.TAG_PROJECTILE, &"")
				c.depth = spec.depth
				c.proc_pct = maxi(1, 100 >> spec.depth)
			s.pm_hit_wisp.append(k)
			s.pm_hit_actor.append(aid)
			s.pm_hit_until.append(w.tick + gap)
			c.origin = at
			c.damage = take(w, milli)
			Attacks.land(w, spec, c, i, at, w.actors.pos(i))


static func _blocked(s: ModifierState, k: int, aid: int) -> bool:
	for q in s.pm_hit_wisp.size():
		if s.pm_hit_wisp[q] == k and s.pm_hit_actor[q] == aid:
			return true
	return false


# --- Mine ---------------------------------------------------------------------------------------------------------
## The Mine hook of `spec` (null: none compiled).
static func mine_hook(spec: AttackSpec) -> AttackHook:
	var hooks := spec.hooks_on(AttackSpec.Trigger.ON_WISP)
	return hooks[0] if not hooks.is_empty() else null


## Mine: each wisp whose turn it is (every mine_gap_ticks, staggered like its shots) drops a mine where it is.
static func drops(w: World, spec: AttackSpec, n: int) -> void:
	var k := mine_hook(spec)
	if k == null:
		return
	var gap := maxi(1, param(w, "mine_gap_ticks"))
	for q in n:
		if Wisps.wait(w, q, n, gap) != 0:
			continue
		var from := Wisps.pos(w, q, n)
		var dmg := Wisps.shot_damage(w, spec)
		var ctx := AttackContext.make(
			from, Wisps.turn(w, q, n), dmg, w.take_root(), SimEvent.TAG_PROJECTILE, &""
		)
		ctx.repeat = true  # no root launch
		Attacks.run_hook(w, k, ctx, from, -1)


## At most live_max live wisp mines a hero (World._apply_spawns, once the tick's mines have spawned): the oldest end
## first, as a mine ends (its zone).
static func cull(w: World) -> void:
	if w.projectiles.size() <= param(w, "live_max") or not Wisps.active(w):
		return
	var spec := Modifiers.bolt(w)
	var k := mine_hook(spec) if mask(spec) & MINE != 0 else null
	if k == null:
		return
	var p := w.projectiles
	var live := PackedInt32Array()
	for pi in p.size():
		if (
			p.team[pi] == ActorStore.TEAM_PLAYER
			and pi < p.spec_key.size()
			and p.spec_key[pi] == k.child.key
		):
			live.append(pi)
	var over := live.size() - param(w, "live_max")
	if over <= 0:
		return
	var gone := PackedInt32Array()
	for q in over:
		var pi := live[q]
		gone.append(pi)
		Attacks.on_projectile_end(w, pi, Vector2(p.pos_x[pi], p.pos_y[pi]))
	p.remove_sorted(gone)
