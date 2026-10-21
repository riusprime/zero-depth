class_name Remnants
extends RefCounted
## v0.8.0 RM (owner O91: "Expand interactions through reusable mechanics … Build reusable remnants, connections and
## events—not hardcoded modifier-pair scripts. Define inheritance, lifetimes, hit intervals and activation limits.
## Later modifiers should affect child attacks consistently"; docs/design/WAND.md rule 12; SIM_CONTRACTS §8l): the
## remnant store and its rules. A remnant is a small sim object a card leaves and a later attack (or time) activates.
## One store (World.mx: ModifierState.rem_*, oldest first) and one set of rules, keyed by the remnant's kind and its
## card's numbers (RemnantRule), serve every card; no rule names a card.
##
## - Left: a REMNANT op compiles into a hook (WandCompile) whose child is the remnant's cast, built by its card and
##   the cards to its right, like a trigger's child. It is left on a hit (Attacks.run_hook hands such a hook here,
##   on_hook: CONTACT, HIT), between consecutive projectiles (LINK: Attacks._bolts marks them, World._apply_spawns
##   links them, on_link), or along the attack's path once it is done (PATH: on_arc, on_bolt_end).
## - Inheritance: a remnant keeps the hook level of the attack that left it: its activation is that attack's child
##   (depth + 1, proc halved; Attacks.MAX_HOOK_DEPTH bounds it: an attack at the deepest level leaves none), its cast
##   runs with the card's id on World.hook_chain (a remnant's cast never leaves the same remnant; its child spec's
##   lineage holds the card too), and a replay (DELAY) launches as a repeat (it never replays or recasts).
## - Limits (WandTable, data/wand/wand.tres): each card's own cap (its rule's max_alive), a cap per kind and
##   remnant_max in all; a new one past a cap replaces the oldest (REMNANT_END, END_REPLACED). At most
##   remnant_activations_max activations a tick, then one LIMIT event (EFFECT_LIMIT); each cast also counts toward
##   Attacks' 256 launches a tick. A rule's gap_ticks is the least time between two of its hits on one enemy (per
##   remnant, or per path: a slash's arc is one replay), its charges how many activations it has (0: until its life).
## - Tick phase 6 (ModifierRuntime.advance, after the launch queue): remnants past their life, whose cast left the
##   build, or whose enemy is gone end; threads follow their projectiles, marks their enemies; then each remnant, oldest
##   first, runs its activation (ENEMY_CROSS, ATTACK_CROSS by projectiles, PULL, DELAY), then the consumers (Grand
##   Finale). Iteration is by uid in store order: deterministic, no randomness (EI-05), the one clock (EI-03).
## - Events: REMNANT_SPAWN, REMNANT_ACTIVATE, REMNANT_END (the views and the tests read them; they change nothing).
## Dodge Imprint (a dash spec's imprint_ticks) is kept here too: the dash's start point, which the next weapon attack
## is cast from (imprint).

const K := RemnantRule.Kind
const A := RemnantRule.Activate
const S := RemnantRule.Spawn
## Why a remnant ended (REMNANT_END's amount).
const END_EXPIRED := 0
const END_SPENT := 1
const END_REPLACED := 2
const END_CONSUMED := 3
const END_GONE := 4
## The LIMIT event's effect id past remnant_activations_max in a tick.
const EFFECT_LIMIT := &"remnant_cap"
## A stagger's STATUS_APPLY effect id (EnemyAi's recover, from a breaking mark).
const EFFECT_STAGGER := &"remnant_stagger"
## A pull stops this far (m) from the anchor (as BlackHoles.CORE_GAP_M).
const CORE_GAP_M := 0.3
## A slash's path replays as this many chords along its arc (at PATH_REACH of its reach).
const ARC_CHORDS := 3
const PATH_REACH := 0.75
## The store's per-remnant columns (ModifierState.rem_*), removed together.
const COLUMNS: Array[StringName] = [
	&"rem_uid",
	&"rem_kind",
	&"rem_card",
	&"rem_key",
	&"rem_slot",
	&"rem_section",
	&"rem_depth",
	&"rem_proc",
	&"rem_root",
	&"rem_born",
	&"rem_life",
	&"rem_gap",
	&"rem_charges",
	&"rem_basis",
	&"rem_a",
	&"rem_b",
	&"rem_dir",
	&"rem_target",
	&"rem_target2",
	&"rem_count",
	&"rem_group",
]

## The wand's numbers in a lab world without World.wand_table: WandTable's defaults (they mirror wand.tres).
static var _defaults := WandTable.new()


static func table(w: World) -> WandTable:
	return w.wand_table if w.wand_table != null else _defaults


# --- Left by a hit (Attacks.run_hook) -------------------------------------------------------------------------------
## Remnant hook `k` on a hit of `parent` at `at` on actor `exclude` (-1: not a hit). Leaves its remnant, or (a mark
## turned far enough, a finisher on a fragment) activates the one there. True if something activated.
static func on_hook(
	w: World, k: AttackHook, parent: AttackContext, at: Vector2, exclude: int
) -> bool:
	if (
		parent.depth + 1 > Attacks.MAX_HOOK_DEPTH
		or w.hook_chain.has(String(k.id))
		or w.player_dead()
	):
		return false
	var r := k.remnant
	if exclude < 0 and r.kind != K.ANCHOR:
		return false
	if r.kind == K.MARK:
		return _mark(w, k, parent, exclude)
	if r.kind == K.FRAGMENT:
		return _fragment(w, k, parent, exclude)
	if _once(w, k, parent.root):  # a crack along the attack, or an anchor where it hit
		var d := Kin.dir(parent.angle) * (r.length_m * 0.5) if r.kind == K.SEGMENT else Vector2.ZERO
		var n := _add(w, k, parent, parent.base_damage)
		_set_line(w, n, at - d, at + d, parent.angle)
		_spawned(w, n, -1)
	return false


## One CONTACT crack or HIT anchor of card `k` per root a tick (a slash that hits five enemies leaves one).
static func _once(w: World, k: AttackHook, root: int) -> bool:
	var s := w.mx
	for n in s.rem_uid.size():
		if s.rem_born[n] == w.tick and s.rem_root[n] == root and s.rem_card[n] == String(k.id):
			return false
	return true


## A MARK hit: on an unmarked enemy it marks the hit's direction; on a marked one, a hit from rule.turn_units or more
## away breaks it (the cast at this hit's damage, and a stagger when the rule has one).
static func _mark(w: World, k: AttackHook, parent: AttackContext, i: int) -> bool:
	var a := w.actors
	var ang := _hit_angle(w, parent, i)
	var n := _on_enemy(w, k, a.ids[i])
	if n < 0:
		n = _add(w, k, parent, parent.base_damage)
		_set_on(w, n, i, ang)
		_spawned(w, n, a.ids[i])
		return false
	if Kin.angle_diff(ang, w.mx.rem_dir[n]) < k.remnant.turn_units:
		return false
	var got := _cast(w, n, a.pos(i), ang, parent.base_damage, parent.root, i, k)
	if got and k.remnant.stagger:
		_stagger(w, i)
	_end(w, n, END_SPENT)
	return got


## A FRAGMENT hit: a combo step lodges one more (up to the rule's stack_max, its life refreshed); the finisher
## (k.extract) extracts them all: one cast at its damage × the count.
static func _fragment(w: World, k: AttackHook, parent: AttackContext, i: int) -> bool:
	var a := w.actors
	var n := _on_enemy(w, k, a.ids[i])
	if k.extract:
		if n < 0:
			return false
		var count := w.mx.rem_count[n]
		var got := _cast(
			w, n, a.pos(i), parent.angle, parent.base_damage * count, parent.root, i, k
		)
		_end(w, n, END_CONSUMED)
		return got
	if n < 0:
		n = _add(w, k, parent, parent.base_damage)
		_set_on(w, n, i, parent.angle)
		w.mx.rem_count[n] = 1
		_spawned(w, n, a.ids[i])
		return false
	var s := w.mx
	s.rem_count[n] = mini(s.rem_count[n] + 1, maxi(1, k.remnant.stack_max))
	s.rem_born[n] = w.tick  # refreshed: it lasts its life from the newest
	s.rem_basis[n] = parent.base_damage
	return false


## The direction of a hit on actor `i`: from the attack's origin to the enemy (a slash, a burst), or the attack's own
## way when it hit where it is (a projectile's hit point is the context's origin).
static func _hit_angle(w: World, parent: AttackContext, i: int) -> int:
	var to := w.actors.pos(i) - parent.origin
	if to.length_squared() < 0.0001:
		return parent.angle
	return Kin.angle_of(to)


## The remnant card `k` left on enemy id `id` (from any of its specs: a mark a bolt left, a fragment a combo step
## lodged), or -1.
static func _on_enemy(w: World, k: AttackHook, id: int) -> int:
	var s := w.mx
	for n in s.rem_uid.size():
		if s.rem_target[n] == id and s.rem_card[n] == String(k.id) and s.rem_kind[n] >= K.MARK:
			return n
	return -1


static func _stagger(w: World, i: int) -> void:
	var a := w.actors
	if not EnemyAi.is_enemy_kind(a.kinds[i]) or BossAi.is_boss_kind(a.kinds[i]) or a.dead[i] == 1:
		return
	if a.state[i] == EnemyAi.State.SPAWN or a.state[i] == EnemyAi.State.RECOVER:
		return
	EnemyAi.enter_state(a, i, EnemyAi.State.RECOVER)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[0], a.ids[0], a.ids[i], a.pos(i))
	e.effect_id = EFFECT_STAGGER


# --- Left by a link or a path --------------------------------------------------------------------------------------
## The LINK hook of `spec` (its first), or null: Attacks._bolts marks the bolts it queues with its key.
static func link_of(spec: AttackSpec) -> AttackHook:
	for k in spec.hooks:
		if k.remnant != null and k.remnant.spawn == S.LINK:
			return k
	return null


## Player projectile `pi` spawned with the LINK mark `key` (World._apply_spawns): it links to the last one marked
## so within the rule's link_ticks (a volley's bolts, two shots close together) with a thread between them.
static func on_link(w: World, pi: int, key: String) -> void:
	var k := Modifiers.book(w).remnant_hook(key)
	if k == null or w.player_dead():
		return
	var s := w.mx
	var p := w.projectiles
	var prev := p.ids.find(s.link_id) if s.link_id >= 0 else -1
	var linked := prev >= 0 and s.link_key == key and w.tick - s.link_tick <= k.remnant.link_ticks
	if linked and k.child.depth <= Attacks.MAX_HOOK_DEPTH:
		var ctx := _ctx_of(w, k, p.root_id[pi], p.damage[pi])
		var n := _add(w, k, ctx, p.damage[pi])
		var a := Vector2(p.pos_x[prev], p.pos_y[prev])
		var b := Vector2(p.pos_x[pi], p.pos_y[pi])
		_set_line(w, n, a, b, Kin.angle_of(b - a))
		s.rem_target[n] = s.link_id
		s.rem_target2[n] = p.ids[pi]
		_spawned(w, n, -1)
	s.link_id = p.ids[pi]
	s.link_tick = w.tick
	s.link_key = key


## A slash of `spec` swept from ctx.origin (reach `reach`): it erupts the cracks it crosses (ATTACK_CROSS, a later
## attack's) and leaves its PATH (its arc, as ARC_CHORDS chords) when the spec has one (Attacks._arc).
static func on_arc(w: World, spec: AttackSpec, ctx: AttackContext, reach: float) -> void:
	var s := w.mx
	var edge := w.player.radius_m
	if not s.rem_uid.is_empty():
		for uid in s.rem_uid.duplicate():
			var n := s.rem_uid.find(uid)
			if n < 0 or s.rem_root[n] == ctx.root or _activate_of(w, n) != A.ATTACK_CROSS:
				continue
			for p: Vector2 in [s.rem_a[n], (s.rem_a[n] + s.rem_b[n]) * 0.5, s.rem_b[n]]:
				var hit := AttackShapes.arc_touches(
					ctx.origin, edge, ctx.angle, spec.half_arc, reach, p, 0.1
				)
				if hit:
					_erupt(w, n, p, ctx.angle, ctx.damage, ctx.root)
					break
	var k := _path_of(spec)
	if k == null or ctx.depth + 1 > Attacks.MAX_HOOK_DEPTH or w.hook_chain.has(String(k.id)):
		return
	var r := edge + reach * PATH_REACH
	var half := spec.half_arc
	var first := -1
	var from := ctx.origin + Kin.dir(ctx.angle - half) * r
	for c in ARC_CHORDS:
		var ang := ctx.angle - half + 2 * half * (c + 1) / ARC_CHORDS
		var to := ctx.origin + Kin.dir(ang) * r
		var n := _add(w, k, ctx, ctx.damage)
		_set_line(w, n, from, to, Kin.angle_of(to - from))
		if first < 0:
			first = s.rem_uid[n]
		s.rem_group[n] = first
		_spawned(w, n, -1)
		from = to


## Player projectile `pi` of `spec` ended at `at` (Attacks.on_projectile_end): its PATH (the line it flew, from where
## it was fired) when the spec has one.
static func on_bolt_end(w: World, spec: AttackSpec, pi: int, at: Vector2) -> void:
	var k := _path_of(spec)
	if k == null or spec.depth + 1 > Attacks.MAX_HOOK_DEPTH or w.hook_chain.has(String(k.id)):
		return
	var p := w.projectiles
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var flown := maxi(1, spec.life_ticks - p.life[pi]) if spec.life_ticks > 0 else 1
	var from := at - v * float(flown)
	var ctx := _ctx_of(w, k, p.root_id[pi], p.damage[pi])
	var n := _add(w, k, ctx, p.damage[pi])
	_set_line(w, n, from, at, Kin.angle_of(v))
	_spawned(w, n, -1)


static func _path_of(spec: AttackSpec) -> AttackHook:
	for k in spec.hooks:
		if k.remnant != null and k.remnant.spawn == S.PATH:
			return k
	return null


## The context a link or a path remnant takes its hook level from: its cast's spec's depth (one below the attack).
static func _ctx_of(w: World, k: AttackHook, root: int, dmg: int) -> AttackContext:
	var c := AttackContext.make(w.player_pos(), 0, dmg, root, 0, &"")
	c.depth = maxi(0, k.child.depth - 1)
	c.proc_pct = maxi(1, 100 >> c.depth)
	return c


# --- The store -----------------------------------------------------------------------------------------------------
## A new remnant of hook `k` left by `parent` (its hook level, its root), its damage basis `basis`: room is made under
## the caps first (the oldest replaced). Returns its index (the newest: the last).
static func _add(w: World, k: AttackHook, parent: AttackContext, basis: int) -> int:
	var r := k.remnant
	var t := table(w)
	var s := w.mx
	_make_room(w, String(k.id), r.kind, maxi(1, r.max_alive), t)
	s.rem_next += 1
	s.rem_uid.append(s.rem_next)
	s.rem_kind.append(r.kind)
	s.rem_card.append(String(k.id))
	s.rem_key.append(k.child.key)
	s.rem_slot.append(k.slot)
	s.rem_section.append(k.section)
	s.rem_depth.append(parent.depth + 1)
	s.rem_proc.append(maxi(1, parent.proc_pct / 2))
	s.rem_root.append(parent.root)
	s.rem_born.append(w.tick)
	s.rem_life.append(maxi(1, r.life_ticks))
	s.rem_gap.append(r.gap_ticks)
	s.rem_charges.append(r.charges if r.charges > 0 else -1)
	s.rem_basis.append(maxi(1, basis))
	s.rem_a.append(Vector2.ZERO)
	s.rem_b.append(Vector2.ZERO)
	s.rem_dir.append(0)
	s.rem_target.append(-1)
	s.rem_target2.append(-1)
	s.rem_count.append(0)
	s.rem_group.append(s.rem_next)
	return s.rem_uid.size() - 1


static func _set_line(w: World, n: int, a: Vector2, b: Vector2, dir: int) -> void:
	w.mx.rem_a[n] = a
	w.mx.rem_b[n] = b
	w.mx.rem_dir[n] = dir


static func _set_on(w: World, n: int, i: int, dir: int) -> void:
	w.mx.rem_a[n] = w.actors.pos(i)
	w.mx.rem_b[n] = w.actors.pos(i)
	w.mx.rem_dir[n] = dir
	w.mx.rem_target[n] = w.actors.ids[i]


static func _spawned(w: World, n: int, target: int) -> void:
	var s := w.mx
	var pid := w.actors.ids[0]
	var e := w.emit_event(
		SimEvent.Kind.REMNANT_SPAWN, pid, pid, target if target >= 0 else pid, _where(w, n)
	)
	e.effect_id = StringName(s.rem_card[n])
	e.amount = s.rem_kind[n]
	e.root_id = s.rem_root[n]


## Room for one more remnant of card `card` (its cap `own`), of kind `kind` and in all: the oldest go first.
static func _make_room(w: World, card: String, kind: int, own: int, t: WandTable) -> void:
	var s := w.mx
	var kind_cap := t.remnant_kind_max[kind] if kind < t.remnant_kind_max.size() else t.remnant_max
	while _count(s.rem_card, card) >= own:
		_end(w, s.rem_card.find(card), END_REPLACED)
	while _count_kind(s, kind) >= maxi(1, kind_cap):
		_end(w, s.rem_kind.find(kind), END_REPLACED)
	while s.rem_uid.size() >= maxi(1, t.remnant_max):
		_end(w, 0, END_REPLACED)


static func _count(arr: PackedStringArray, key: String) -> int:
	return arr.count(key)


static func _count_kind(s: ModifierState, kind: int) -> int:
	return s.rem_kind.count(kind)


## Remnant `n` ends (REMNANT_END, amount `why`); its hit gaps go with its path's last remnant.
static func _end(w: World, n: int, why: int) -> void:
	var s := w.mx
	if n < 0 or n >= s.rem_uid.size():
		return
	var pid := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.REMNANT_END, pid, pid, pid, _where(w, n))
	e.effect_id = StringName(s.rem_card[n])
	e.amount = why
	var group := s.rem_group[n]
	for f: StringName in COLUMNS:
		var arr: Variant = s.get(f)
		arr.remove_at(n)
		s.set(f, arr)
	if s.rem_group.has(group):
		return
	for g in range(s.gap_uid.size() - 1, -1, -1):
		if s.gap_uid[g] == group:
			s.gap_uid.remove_at(g)
			s.gap_target.remove_at(g)
			s.gap_tick.remove_at(g)


## Where remnant `n` is (a segment's middle, an anchor's point, a mark's or a fragment's enemy's last place).
static func _where(w: World, n: int) -> Vector2:
	return (w.mx.rem_a[n] + w.mx.rem_b[n]) * 0.5


static func _activate_of(w: World, n: int) -> int:
	var k := Modifiers.book(w).remnant_hook(w.mx.rem_key[n])
	return -1 if k == null else k.remnant.activate


# --- Activations ---------------------------------------------------------------------------------------------------
## Remnant `n` activates at `at` (way `ang`): its hook's child (or `hook`'s: the hit that broke or extracted it) is
## cast at `basis` × the hook's share, with the remnant's hook level, on root `root`, under the tick's activation cap
## and the hook guard. `i`: the enemy it fires on (-1: none). True if the cast landed.
static func _cast(
	w: World, n: int, at: Vector2, ang: int, basis: int, root: int, i: int, hook: AttackHook = null
) -> bool:
	var s := w.mx
	var k := hook if hook != null else Modifiers.book(w).remnant_hook(s.rem_key[n])
	if k == null or not _room(w):
		return false
	var spec := k.child
	var dmg := maxi(1, basis * k.damage_permille / 1000) if k.damage <= 0 else k.damage
	var c := AttackContext.make(at, ang, dmg, root, Attacks.tags_of(spec), spec.effect_id)
	c.depth = s.rem_depth[n]
	c.proc_pct = s.rem_proc[n]
	c.repeat = k.remnant.activate == A.DELAY  # a replay never replays (nor recasts)
	var pid := w.actors.ids[0]
	var e := w.emit_event(
		SimEvent.Kind.REMNANT_ACTIVATE, pid, pid, w.actors.ids[i] if i >= 0 else pid, at
	)
	e.effect_id = StringName(s.rem_card[n])
	e.amount = dmg
	e.root_id = root
	if s.rem_charges[n] > 0:
		s.rem_charges[n] -= 1
	w.hook_chain.append(String(k.id))
	var landed := Attacks.launch(w, spec, c)
	w.hook_chain.remove_at(w.hook_chain.size() - 1)
	return landed


## One more activation this tick fits (WandTable.remnant_activations_max); the first that doesn't leaves a LIMIT.
static func _room(w: World) -> bool:
	var s := w.mx
	if s.rem_act_tick != w.tick:
		s.rem_act_tick = w.tick
		s.rem_act_n = 0
	var cap := table(w).remnant_activations_max
	s.rem_act_n += 1
	if s.rem_act_n <= cap:
		return true
	if s.rem_act_n == cap + 1:
		var pid := w.actors.ids[0]
		var lim := w.emit_event(SimEvent.Kind.LIMIT, pid, pid, pid, w.player_pos())
		lim.effect_id = EFFECT_LIMIT
		lim.amount = cap
		lim.ancestry = w.hook_chain.duplicate()
	return false


## A crack `n` crossed by a later attack (damage `dmg`, root `root`) at `at`: it erupts there and is spent.
static func _erupt(w: World, n: int, at: Vector2, ang: int, dmg: int, root: int) -> void:
	var uid := w.mx.rem_uid[n]
	_cast(w, n, at, ang, dmg, root, -1)
	n = w.mx.rem_uid.find(uid)
	if n >= 0 and w.mx.rem_charges[n] == 0:
		_end(w, n, END_SPENT)


# --- Tick phase 6 --------------------------------------------------------------------------------------------------
## ModifierRuntime.advance: ends, follows, then each remnant's activation, then the consumers (class doc).
static func advance(w: World) -> void:
	var s := w.mx
	if s.imprint_until >= 0 and w.tick > s.imprint_until:
		s.imprint_until = -1
	if s.rem_uid.is_empty() and Modifiers.book(w).consumers.is_empty():
		return
	_expire(w)
	if w.player_dead():
		return
	for uid in s.rem_uid.duplicate():
		var n := s.rem_uid.find(uid)
		if n < 0:
			continue
		var k := Modifiers.book(w).remnant_hook(s.rem_key[n])
		if k == null:
			continue
		var act := k.remnant.activate
		if act == A.ENEMY_CROSS:
			_cross_enemies(w, n, k, false)
		elif act == A.ATTACK_CROSS:
			_cross_shots(w, n)
		elif act == A.PULL:
			_pull(w, n, k.remnant)
		elif act == A.DELAY and w.tick - s.rem_born[n] >= k.remnant.delay_ticks:
			_cross_enemies(w, n, k, true)
			n = s.rem_uid.find(uid)
			if n >= 0:
				_end(w, n, END_SPENT)
	_consume(w)


## Remnants past their life, whose cast left the build, or whose enemy is gone end; threads follow their projectiles
## and marks their enemies.
static func _expire(w: World) -> void:
	var s := w.mx
	var book := Modifiers.book(w)
	for n in range(s.rem_uid.size() - 1, -1, -1):
		if book.remnant_hook(s.rem_key[n]) == null:
			_end(w, n, END_GONE)
		elif w.tick - s.rem_born[n] >= s.rem_life[n]:
			_end(w, n, END_EXPIRED)
		elif s.rem_kind[n] >= K.MARK:
			var i := w.actors.index_of(s.rem_target[n])
			if i < 0 or w.actors.dead[i] == 1:
				_end(w, n, END_GONE)
			else:
				s.rem_a[n] = w.actors.pos(i)
				s.rem_b[n] = w.actors.pos(i)
		elif s.rem_target2[n] >= 0:  # a thread: its ends ride its projectiles while they fly
			var p := w.projectiles
			var pa := p.ids.find(s.rem_target[n])
			var pb := p.ids.find(s.rem_target2[n])
			if pa >= 0:
				s.rem_a[n] = Vector2(p.pos_x[pa], p.pos_y[pa])
			if pb >= 0:
				s.rem_b[n] = Vector2(p.pos_x[pb], p.pos_y[pb])


## The enemies touching segment `n` (its half width) take its cast, each at most once each gap_ticks (per path);
## `once`: a replay (every enemy touching it once, now).
static func _cross_enemies(w: World, n: int, k: AttackHook, once: bool) -> void:
	var s := w.mx
	var a := s.rem_a[n]
	var b := s.rem_b[n]
	var width := k.remnant.width_m
	var uid := s.rem_uid[n]
	var reach := Kin.length(b - a) * 0.5 + width
	for i in w.enemies_near((a + b) * 0.5, reach):
		n = s.rem_uid.find(uid)
		if n < 0:
			return
		if w.actors.dead[i] == 1 or w.actors.invuln[i] > 0:
			continue
		if Collide.sweep_vs_circle(a, b, width, w.actors.pos(i), w.actors.radius[i]) < 0.0:
			continue
		if not _gap_ok(w, n, w.actors.ids[i], once):
			continue
		_cast(w, n, w.actors.pos(i), s.rem_dir[n], s.rem_basis[n], w.take_root(), i)
		n = s.rem_uid.find(uid)
		if n >= 0 and s.rem_charges[n] == 0:
			_end(w, n, END_SPENT)
			return


## Remnant `n` (its path) may hit enemy `id` now: the last hit was at least its gap ago (a replay: never before);
## the hit is recorded.
static func _gap_ok(w: World, n: int, id: int, once: bool) -> bool:
	var s := w.mx
	var group := s.rem_group[n]
	for g in s.gap_uid.size():
		if s.gap_uid[g] == group and s.gap_target[g] == id:
			if once or w.tick - s.gap_tick[g] < maxi(1, s.rem_gap[n]):
				return false
			s.gap_tick[g] = w.tick
			return true
	s.gap_uid.append(group)
	s.gap_target.append(id)
	s.gap_tick.append(w.tick)
	return true


## A crack `n` crossed this tick by a player projectile of a later attack (its move this tick, from pos − vel to pos,
## crossing the crack): it erupts where it was crossed, at that projectile's damage.
static func _cross_shots(w: World, n: int) -> void:
	var s := w.mx
	var p := w.projectiles
	var a := s.rem_a[n]
	var b := s.rem_b[n]
	for pi in p.size():
		if p.team[pi] != ActorStore.TEAM_PLAYER or p.root_id[pi] == s.rem_root[n]:
			continue
		var at := Vector2(p.pos_x[pi], p.pos_y[pi])
		var from := at - Vector2(p.vel_x[pi], p.vel_y[pi])
		if not _crosses(from, at, a, b, p.radius[pi] + 0.1):
			continue
		_erupt(w, n, at, Kin.angle_of(at - from), p.damage[pi], p.root_id[pi])
		return


## Whether segment p→q crosses (or passes within `r` of) segment a→b. Pure arithmetic.
static func _crosses(p: Vector2, q: Vector2, a: Vector2, b: Vector2, r: float) -> bool:
	var d1 := _side(a, b, p)
	var d2 := _side(a, b, q)
	var d3 := _side(p, q, a)
	var d4 := _side(p, q, b)
	if ((d1 > 0.0) != (d2 > 0.0)) and ((d3 > 0.0) != (d4 > 0.0)):
		return true
	return Collide.sweep_vs_circle(a, b, r, q, 0.0) >= 0.0


static func _side(a: Vector2, b: Vector2, p: Vector2) -> float:
	return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)


## Anchor `n` pulls the enemies within its reach toward it (not a boss, not one still spawning in) and bends the
## player's projectiles within its bend reach toward it (turned by at most bend_step a tick, their speed kept).
static func _pull(w: World, n: int, r: RemnantRule) -> void:
	var at := w.mx.rem_a[n]
	var a := w.actors
	for i in w.enemies_near(at, r.pull_radius_m):
		if a.invuln[i] > 0 or BossAi.is_boss_kind(a.kinds[i]):
			continue
		var to := at - a.pos(i)
		var dist := Kin.length(to)
		var step := minf(r.pull_step_m, maxf(0.0, dist - CORE_GAP_M))
		if dist > 0.0 and step > 0.0:
			a.set_pos(i, a.pos(i) + to * (step / dist))
	if r.bend_step <= 0 or r.bend_radius_m <= 0.0:
		return
	var p := w.projectiles
	var r2 := r.bend_radius_m * r.bend_radius_m
	for pi in p.size():
		if p.team[pi] != ActorStore.TEAM_PLAYER:
			continue
		if p.moves and pi < p.orbit_t.size() and p.orbit_t[pi] > 0:
			continue  # an orbiting shot keeps its orbit
		var pos := Vector2(p.pos_x[pi], p.pos_y[pi])
		var to := at - pos
		if to.length_squared() > r2 or to.length_squared() < 0.0001:
			continue
		var v := Vector2(p.vel_x[pi], p.vel_y[pi])
		var speed := Kin.length(v)
		if speed <= 0.0:
			continue
		var turned := (
			Kin.dir(Kin.turn_toward(Kin.angle_of(v), Kin.angle_of(to), r.bend_step)) * speed
		)
		p.vel_x[pi] = turned.x
		p.vel_y[pi] = turned.y


## The consumers (Grand Finale: each once by its slot): every period_ticks since the last release, each takes the
## remnants left by the cards left of it in its trigger section (oldest first, at most release_max), each releasing its
## cast at the remnant's damage basis where the remnant is.
static func _consume(w: World) -> void:
	var s := w.mx
	var done := PackedInt32Array()
	for k in Modifiers.book(w).consumers:
		if done.has(k.slot) or w.tick - s.finale_tick < maxi(1, k.remnant.period_ticks):
			continue
		done.append(k.slot)
		var picked := PackedInt32Array()
		for n in s.rem_uid.size():
			if picked.size() >= k.remnant.release_max:
				break
			if s.rem_section[n] == k.section and s.rem_slot[n] >= 0 and s.rem_slot[n] < k.slot:
				picked.append(s.rem_uid[n])
		if picked.is_empty():
			continue
		s.finale_tick = w.tick
		for uid in picked:
			_release(w, k, uid)


## Consumer `k` takes remnant `uid`: its cast (k's child, at k's share of the remnant's damage) where it is.
static func _release(w: World, k: AttackHook, uid: int) -> void:
	var s := w.mx
	var n := s.rem_uid.find(uid)
	if n < 0 or not _room(w):
		return
	var at := _where(w, n)
	var dmg := maxi(1, s.rem_basis[n] * k.damage_permille / 1000)
	var c := AttackContext.make(
		at, s.rem_dir[n], dmg, w.take_root(), Attacks.tags_of(k.child), k.child.effect_id
	)
	c.depth = k.child.depth
	c.proc_pct = maxi(1, 100 >> c.depth)
	var pid := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.REMNANT_ACTIVATE, pid, pid, pid, at)
	e.effect_id = k.id
	e.amount = dmg
	_end(w, n, END_CONSUMED)
	if c.depth > Attacks.MAX_HOOK_DEPTH or w.hook_chain.has(String(k.id)):
		return
	w.hook_chain.append(String(k.id))
	Attacks.launch(w, k.child, c)
	w.hook_chain.remove_at(w.hook_chain.size() - 1)


# --- Dodge Imprint ---------------------------------------------------------------------------------------------------
## The dash just started (ModifierRuntime.on_dash_start): with a dash spec's imprint, its start is kept for the dash and
## imprint_ticks after it.
static func on_dash_start(w: World) -> void:
	var d := Modifiers.dash(w)
	if d == null or d.imprint_ticks <= 0:
		return
	w.mx.imprint_at = w.player_pos()
	w.mx.imprint_until = w.tick + maxi(0, w.dash_ticks_left) + d.imprint_ticks


## A root weapon attack launching with `ctx` (Attacks.launch): while an imprint stands it is cast from the dash's start
## at × imprint_permille, and the imprint is spent (one REMNANT_ACTIVATE, effect the dash card's).
static func imprint(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	var s := w.mx
	if s.imprint_until < w.tick or not spec.has_tag(&"weapon"):
		return
	var d := Modifiers.dash(w)
	if d == null or d.imprint_ticks <= 0:
		s.imprint_until = -1
		return
	var pm := d.imprint_permille if d.imprint_permille > 0 else 1000
	ctx.origin = s.imprint_at
	ctx.damage = maxi(1, ctx.damage * pm / 1000)
	ctx.base_damage = maxi(1, ctx.base_damage * pm / 1000)
	s.imprint_until = -1
	var pid := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.REMNANT_ACTIVATE, pid, pid, pid, s.imprint_at)
	e.effect_id = _imprint_card(d)
	e.amount = ctx.damage


static func _imprint_card(d: AttackSpec) -> StringName:
	return (
		StringName(d.modifier_ids[d.modifier_ids.size() - 1])
		if not d.modifier_ids.is_empty()
		else &""
	)


# --- Reads ---------------------------------------------------------------------------------------------------------
## The remnants for the views (WorldReader.remnants): [{uid, kind, card, a, b, dir, age, life, count, target}], oldest
## first, and the standing imprint as {"imprint": pos} when there is one. Plain data.
static func read(w: World) -> Dictionary:
	var s := w.mx
	var out := []
	for n in s.rem_uid.size():
		(
			out
			. append(
				{
					"uid": s.rem_uid[n],
					"kind": s.rem_kind[n],
					"card": StringName(s.rem_card[n]),
					"a": s.rem_a[n],
					"b": s.rem_b[n],
					"dir": s.rem_dir[n],
					"age": w.tick - s.rem_born[n],
					"life": s.rem_life[n],
					"count": s.rem_count[n],
					"target": s.rem_target[n] if s.rem_kind[n] >= K.MARK else -1,
					"activate": _activate_of(w, n),
				}
			)
		)
	var standing := s.imprint_until >= w.tick
	return {"remnants": out, "imprint": standing, "imprint_at": s.imprint_at}


## The radius (m) of card `card`'s remnant cast (its hook child's burst; 0 without one).
static func cast_radius(w: World, card: StringName) -> float:
	var book := Modifiers.book(w)
	for key: String in book.remnant_hooks:
		var k: AttackHook = book.remnant_hooks[key]
		if k.id == card:
			return k.child.radius_m
	return 0.0
