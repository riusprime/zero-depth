class_name ShotCap
extends RefCounted
## v0.9.0 AS (owner Q13 "12 per attack": "At most 12 projectiles per attack (pattern × Twin × Split children); extra
## copies merge into bigger shots that keep the damage; a regression test fails above 40 projectiles a second for the
## worst legal build. Data values"; PLAN C36, C75, C76): the Gun's projectile caps (World.slot_table,
## data/wand/attack_slots.tres). A Gun run only (Q6: the forms and their cards are the Gun's); a lab world without the
## table, and a Blade run, launch as before.
## - Per attack (compile time, tree()): one attack's volley (its bolts × Twin's lanes, or its rings) times the volley
##   of each child it splits into (a hook's child, e.g. Split's shards, per shot of the parent) is at most
##   shots_per_attack_max. A volley past its share merges: fewer, bigger shots (merge(): the count falls, then Twin's
##   lanes; each shot's damage share grows so the volley's damage stays the same, and its radius grows with the copies
##   it took in, up to merge_radius_max_permille). A trigger's cast and a remnant's activation are attacks of their own.
## - Per second (run time, room()): the player projectiles a Gun run launches in any 60 ticks are at most
##   shots_per_second_max. The player's own shot (the first shot of a root volley: depth 0, not a repeat or the back
##   copy) always fires; it comes at most reserve() times a second (the Gun's fastest period now, Rapid Fire's ramp at
##   its top). Every other shot (a volley's extra copies, a child's, a repeat's, a trigger's cast) is an extra and
##   counts in World.shot_window; the extras of any 60 ticks stay within shots_per_second_max − reserve(). A volley
##   whose extras don't fit merges into the shots that do (Attacks._bolts, WandRings.launch: evenly picked, the damage
##   kept); a child volley with no room left is not launched.
## Pure: integer maths and sqrt only, no randomness, one clock.

const WINDOW := 60


## The shots one launch of `s` throws: its count × Twin's lanes for a bolt, its count for a ring; 1 for any other form.
static func shots(s: AttackSpec) -> int:
	match s.form:
		AttackSpec.Form.BOLT:
			return maxi(1, s.count) * (maxi(0, s.twin) + 1)
		AttackSpec.Form.RING:
			return maxi(1, s.count)
	return 1


## The per-attack cap of world `w` (0: none; a lab, a Blade run).
static func per_attack(w: World) -> int:
	var t := w.slot_table
	return t.shots_per_attack_max if t != null and AttackSlots.gun(w) else 0


## `s` and its children within `cap` shots per attack (class doc); `cap_root`: a new attack's whole cap (a trigger's
## cast, a remnant's activation). Compile time, in place.
static func tree(s: AttackSpec, cap: int, cap_root: int, radius_max_permille: int) -> void:
	if cap <= 0:
		return
	var n := shots(s)
	if n > cap:
		merge(s, cap, radius_max_permille)
		n = shots(s)
	for k in s.hooks:
		if k.child == null:
			continue
		if k.child.has_tag(WandCasts.TAG_CAST) or k.remnant != null:
			tree(k.child, cap_root, cap_root, radius_max_permille)
		else:
			tree(k.child, maxi(1, cap / n), cap_root, radius_max_permille)


## `s`'s volley merged into at most `cap` shots (class doc): the count first, then Twin's lanes; the damage share
## grows by the shots it took in, and the radius by their square root (at most `radius_max_permille` of its own).
static func merge(s: AttackSpec, cap: int, radius_max_permille: int) -> void:
	var n := shots(s)
	if n <= cap or (s.form != AttackSpec.Form.BOLT and s.form != AttackSpec.Form.RING):
		return
	var lanes := maxi(0, s.twin) + 1 if s.form == AttackSpec.Form.BOLT else 1
	if lanes > cap:
		s.twin = cap - 1
		s.count = 1
	else:
		s.count = maxi(1, cap / lanes)
	var after := shots(s)
	var share := s.share_permille if s.share_permille > 0 else 1000
	s.share_permille = (share * n + after / 2) / after
	s.radius_m = s.radius_m * grow_permille(n, after, radius_max_permille) / 1000.0


## A merged shot's radius, per mille of its own, for `n` shots merged into `k`: √(n / k), at most `most`.
static func grow_permille(n: int, k: int, most: int) -> int:
	if k <= 0 or n <= k:
		return 1000
	return mini(most, int(sqrt(float(n) / float(k)) * 1000.0))


# --- Per second ---------------------------------------------------------------------------------------------
## How many of a volley of `want` shots may launch now (class doc): all of them without the budget (a lab, a Blade
## run); else, for a `root` volley its first shot and the extras that fit, for any other only the extras that fit.
static func room(w: World, want: int, root: bool) -> int:
	var t := w.slot_table
	if t == null or want <= 0 or not AttackSlots.gun(w):
		return want
	_roll(w)
	var used := 0
	for v in w.shot_window:
		used += v
	var extras := want - 1 if root else want
	var k := mini(extras, maxi(0, t.shots_per_second_max - reserve(w) - used))
	return k + 1 if root else k


## The player's own shots a second at the most, now: 60 over the Gun's fastest period (its attack speed and Rapid
## Fire's ramp at its top, ItemEffects.shot_period_ticks' rule).
static func reserve(w: World) -> int:
	var spec := Modifiers.bolt(w)
	var base := maxi(1, spec.period_ticks)
	var r := AttackRate.rate(w, spec.rate_bonus_permille + maxi(0, spec.ramp_cap_permille))
	r = AttackRate.form_rate(spec, r)  # v0.9.0 LZ: ItemEffects.shot_period_ticks' rule
	var p := base
	if r != 1000:
		p = maxi(mini(base, AttackRate.MIN_SHOT_TICKS), AttackRate.scaled(base, r))
	p = maxi(1, p)
	return (WINDOW + p - 1) / p


## `n` extra shots launched now count against the budget (after room()).
static func spend(w: World, n: int) -> void:
	if w.slot_table == null or n <= 0 or not AttackSlots.gun(w):
		return
	_roll(w)
	w.shot_window[w.tick % WINDOW] += n


## The window moved on to this tick: the ticks since it was last written are emptied.
static func _roll(w: World) -> void:
	if w.shot_window.size() != WINDOW:
		w.shot_window = PackedInt32Array()
		w.shot_window.resize(WINDOW)
		w.shot_window_tick = w.tick - WINDOW
	var from := maxi(w.shot_window_tick + 1, w.tick - WINDOW + 1)
	for t in range(from, w.tick + 1):
		w.shot_window[t % WINDOW] = 0
	w.shot_window_tick = maxi(w.shot_window_tick, w.tick)


## The extra shots of the last second (the 60 ticks up to now), summed (tests, the views). Reads only.
static func last_second(w: World) -> int:
	if w.shot_window.size() != WINDOW:
		return 0
	var used := 0
	for t in range(
		maxi(w.tick - WINDOW + 1, w.shot_window_tick - WINDOW + 1), w.shot_window_tick + 1
	):
		used += w.shot_window[t % WINDOW]
	return used
