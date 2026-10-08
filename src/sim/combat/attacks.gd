class_name Attacks
extends RefCounted
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md §7; SIM_CONTRACTS §5b): the one entry point that runs an attack from
## its compiled spec. The weapon drivers keep their timing (PlayerKit: the combo's ticks, the shot period; PlayerSkill:
## the lunge), compute the damage with the runtime factors (the build's per mille, Overcharge, Momentum, Bulwark, the
## gamble shrine) and call launch(spec, ctx) at the moment the attack happens. The shape tests here are the ones the
## views' forecasts read too (EI-07).
##
## Forms with a runner in MX1: ARC (the Blade's steps, Lunge Cleave), BOLT (the Gun's shots, queued for phase 9),
## BURST (Overcharge's shockwave), BEAM (a seeking jump: Static Chain; a fan of rays: Scatter Blast). RING, ZONE,
## ORBITER and LOB come with the cards that use them (MX stage 2+); launching one does nothing.
##
## Hooks (AttackHook) recurse with the guard of the design's §2: a hook's child launches one level deeper, at most
## MAX_HOOK_DEPTH, with half its parent's proc coefficient (HIT.proc_pct 100 → 50 → 25); a hook never runs inside a
## chain it opened (ancestry, World.hook_chain); and at most MAX_LAUNCHES_PER_TICK launches run in one tick (then one
## LIMIT event, and the rest of the tick's launches are dropped). The engines' own guards (ProcLedger, Engines.begin)
## still hold for every status and payoff a hook's hits set off.

const MAX_HOOK_DEPTH := 2
const MAX_LAUNCHES_PER_TICK := 256
const EFFECT_LAUNCH_CAP := &"attack_launch_cap"
## ProcLedger codes for a hook attack's own status feeds (Engines' codes end at 40; appended, never renumbered).
const CODE_HOOK_FEED := 48
## The ledger code of each status a hook attack feeds: CODE_HOOK_FEED + its index here.
const FEED_ORDER: Array[StringName] = [&"burn", &"shock", &"bleed", &"frost", &"slow"]
## A bolt leaves the muzzle this far past the player's and its own edge.
const MUZZLE_GAP_M := 0.05


## Runs `spec` with `ctx`. Returns true if it landed a hit (a bolt: true once queued; its hits come in phase 9).
static func launch(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	if not _count(w):
		return false
	match spec.form:
		AttackSpec.Form.ARC:
			return _arc(w, spec, ctx)
		AttackSpec.Form.BOLT:
			_bolts(w, spec, ctx)
			return true
		AttackSpec.Form.BURST:
			return _burst(w, spec, ctx)
		AttackSpec.Form.BEAM:
			return _seek(w, spec, ctx) if spec.seek else _rays(w, spec, ctx)
	return false


## The per-tick launch cap. Over it: one LIMIT event (amount = the cap), then nothing more this tick.
static func _count(w: World) -> bool:
	if w.launch_tick != w.tick:
		w.launch_tick = w.tick
		w.launch_count = 0
	w.launch_count += 1
	if w.launch_count <= MAX_LAUNCHES_PER_TICK:
		return true
	if w.launch_count == MAX_LAUNCHES_PER_TICK + 1:
		var pid := w.actors.ids[0]
		var lim := w.emit_event(SimEvent.Kind.LIMIT, pid, pid, pid, w.player_pos())
		lim.effect_id = EFFECT_LAUNCH_CAP
		lim.amount = MAX_LAUNCHES_PER_TICK
		lim.ancestry = w.hook_chain.duplicate()
	return false


# --- Shapes (the hit and the views' forecasts) ------------------------------------------------------------
## An arc's reach: a weapon step's with its reach bonus (Long Edge), Combo Sword's level, the area stat and Hot's
## reach, in that order (v0.5's ItemEffects.swing_reach_m); a Skill's with the area stat only.
static func arc_reach_m(w: World, spec: AttackSpec) -> float:
	if not spec.has_tag(&"weapon"):
		return Stats.area(w, spec.reach_m)
	var reach := spec.reach_m * (1000 + spec.reach_bonus_permille) / 1000.0
	reach = Stats.area(w, reach * Abilities.reach_permille(w) / 1000.0)
	var hot := Heat.reach_permille(w)
	return reach if hot == 1000 else reach * hot / 1000.0


## True if a circle (p, r) touches `spec`'s arc from `center` facing `angle` (the player's own radius as its edge).
static func arc_touches(
	w: World, spec: AttackSpec, center: Vector2, angle: int, p: Vector2, r: float
) -> bool:
	return AttackShapes.arc_touches(
		center, w.player.radius_m, angle, spec.half_arc, arc_reach_m(w, spec), p, r
	)


## Where along ray `ang` from `center` (starting at the player's edge, reach_m long, radius_m wide) it first touches
## a circle (p, r): 0..1, or -1.
static func ray_touches(
	w: World, spec: AttackSpec, center: Vector2, ang: int, p: Vector2, r: float
) -> float:
	var dir := Kin.dir(ang)
	var from := center + dir * w.player.radius_m
	return Collide.sweep_vs_circle(from, from + dir * spec.reach_m, spec.radius_m, p, r)


## A shot's bolt offsets (1/4096 turns): [0], or `count` bolts over the full fan `spread` centred on the aim.
static func shot_offsets(spec: AttackSpec) -> PackedInt32Array:
	var n := maxi(1, spec.count)
	var out := PackedInt32Array()
	if n == 1:
		out.append(0)
		return out
	var half := spec.spread / 2
	for k in n:
		out.append(-half + 2 * half * k / (n - 1))
	return out


## Each bolt's base damage: the spec's, or its damage_permille share when the shot splits (at least 1).
static func bolt_base_damage(spec: AttackSpec) -> int:
	if spec.count <= 1:
		return spec.damage
	return maxi(1, spec.damage * spec.damage_permille / 1000)


# --- Runners ------------------------------------------------------------------------------------------------
static func _arc(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	var a := w.actors
	var landed := false
	var hits := 0
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
			continue
		if not arc_touches(w, spec, ctx.origin, ctx.angle, a.pos(i), a.radius[i]):
			continue
		var got := _hit(w, i, ctx, ctx.origin, a.pos(i))
		if got > 0:
			landed = true
			hits += 1
			_landed(w, spec, ctx, i, a.pos(i), hits)
	if not spec.hooks.is_empty():
		var tip := ctx.origin + Kin.dir(ctx.angle) * (w.player.radius_m + arc_reach_m(w, spec))
		_run(w, spec, AttackSpec.Trigger.ON_END, ctx, tip, -1, 0)
	return landed


static func _bolts(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	var t := w.player
	for off in Abilities.shot_offsets(w, shot_offsets(spec)):  # Pulse Gun L5: twin bolts
		var dir := Kin.dir(ctx.angle + off)
		var muzzle := ctx.origin + dir * (t.radius_m + spec.radius_m + MUZZLE_GAP_M)
		w.queue_projectile(
			w.actors.ids[0],
			ActorStore.TEAM_PLAYER,
			muzzle,
			dir * spec.speed,
			ctx.damage,
			spec.radius_m,
			spec.life_ticks,
			ctx.tags,
			spec.bounces
		)


static func _burst(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	var a := w.actors
	var landed := false
	var hits := 0
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
			continue
		if not AttackShapes.disc_touches(ctx.origin, spec.radius_m, a.pos(i), a.radius[i]):
			continue
		if _hit(w, i, ctx, ctx.origin, a.pos(i)) > 0:
			landed = true
			hits += 1
			_landed(w, spec, ctx, i, a.pos(i), hits)
	_run(w, spec, AttackSpec.Trigger.ON_END, ctx, ctx.origin, -1, 0)
	return landed


## A jump from ctx.origin to the nearest living enemy other than ctx.exclude within reach_m (ties: the lower index).
## It sets the jump the view draws (World.chain_*) and the root it fired in (World.chain_root).
static func _seek(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	var a := w.actors
	var best := -1
	var best_d := spec.reach_m
	for j in range(1, a.size()):
		if j == ctx.exclude or a.teams[j] == ActorStore.TEAM_PLAYER or a.dead[j] == 1:
			continue
		var d := Kin.length(a.pos(j) - ctx.origin)
		if d <= best_d and (best < 0 or d < best_d):
			best = j
			best_d = d
	if best < 0:
		return false
	w.chain_root = ctx.root
	w.chain_tick = w.tick
	w.chain_from = ctx.origin
	w.chain_to = a.pos(best)
	var got := _hit(w, best, ctx, ctx.origin, a.pos(best))
	if got > 0:
		_landed(w, spec, ctx, best, a.pos(best), 1)
	return got > 0


## A fan of `count` rays over `spread` toward ctx.angle, each stopping at the first wall or enemy within reach_m
## (Scatter Blast's pellets). ctx.on_ray gets each ray's end; a hit takes ctx.damage_fn's damage when set.
static func _rays(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	var a := w.actors
	var origin := ctx.origin
	var landed := false
	var hits := 0
	for ang in AttackShapes.pellet_angles(ctx.angle, spec.spread / 2, spec.count):
		var dir := Kin.dir(ang)
		var from := origin + dir * w.player.radius_m
		var to := from + dir * spec.reach_m
		var best := 2.0
		var target := -1
		for wall in w.walls:
			var s := Collide.sweep_vs_obb(from, to, spec.radius_m, wall)
			if s >= 0.0 and s < best:
				best = s
		for i in range(1, a.size()):
			if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
				continue
			var s := ray_touches(w, spec, origin, ang, a.pos(i), a.radius[i])
			if s >= 0.0 and s < best:
				best = s
				target = i
		var end := from + (to - from) * minf(best, 1.0)
		if ctx.on_ray.is_valid():
			ctx.on_ray.call(end)
		if target < 0:
			continue
		if ctx.damage_fn.is_valid():
			ctx.damage = ctx.damage_fn.call()
		var got := _hit(w, target, ctx, origin, end)
		if got > 0:
			landed = true
			hits += 1
			_landed(w, spec, ctx, target, end, hits)
			if a.dead[target] == 0 and ctx.on_landed.is_valid():
				ctx.on_landed.call(target)
	return landed


static func _hit(w: World, i: int, ctx: AttackContext, from: Vector2, at: Vector2) -> int:
	var pid := w.actors.ids[0]
	return Damage.hit(
		w, i, ctx.damage, pid, pid, ctx.root, ctx.tags, from, at, ctx.effect_id, ctx.proc_pct
	)


## A hit of `spec` landed on actor `i` at `at` (the `nth` landed hit of this launch): a weapon step's burn (Ember
## Edge, as before MX1), a hook attack's own statuses at its proc coefficient, then its ON_HIT and ON_KILL hooks.
static func _landed(
	w: World, spec: AttackSpec, ctx: AttackContext, i: int, at: Vector2, nth: int
) -> void:
	if spec.depth == 0 and spec.form == AttackSpec.Form.ARC and spec.has_status(&"burn"):
		if spec.has_tag(&"weapon"):
			ItemEffects.on_melee_hit(w, i, ctx.root, spec.stacks_of(&"burn"))
	if ctx.depth > 0:
		_feed(w, spec, ctx, i)
	_run(w, spec, AttackSpec.Trigger.ON_HIT, ctx, at, i, nth)
	if w.actors.dead[i] == 1:
		_run(w, spec, AttackSpec.Trigger.ON_KILL, ctx, at, i, nth)


## A hook attack's own statuses: stacks × its proc coefficient (rounded down; none at 0), once per root per target
## and status. Root attacks feed through their sources instead (Engines.on_hit, ItemEffects.on_melee_hit,
## ItemProcs.on_bolt_hit), as before MX1.
static func _feed(w: World, spec: AttackSpec, ctx: AttackContext, i: int) -> void:
	var a := w.actors
	for k in spec.status_ids.size():
		var n := spec.status_stacks[k] * ctx.proc_pct / 100
		var st := StringName(spec.status_ids[k])
		var code := CODE_HOOK_FEED + FEED_ORDER.find(st)
		if n <= 0 or a.dead[i] == 1 or not w.proc_ledger.try_mark(ctx.root, code, a.ids[i], w.tick):
			continue
		match st:
			&"burn":
				Engines.add_burn(w, i, n, ctx.root, spec.id)
			&"shock":
				Engines.add_shock(w, i, n, ctx.root)
			&"bleed":
				Engines.add_bleed(w, i, n, ctx.root)
			&"frost":
				Engines.add_frost(w, i, n, ctx.root, spec.id)
			&"slow":
				if w.item_mods.slow_ticks > 0:
					a.slow_t[i] = maxi(a.slow_t[i], w.item_mods.slow_ticks)


## Runs `spec`'s hooks on `trigger` from `at` (`exclude`: the actor just hit; `nth`: which landed hit of the launch,
## for an `every`; 0 for the triggers that aren't hits).
static func _run(
	w: World,
	spec: AttackSpec,
	trigger: int,
	ctx: AttackContext,
	at: Vector2,
	exclude: int,
	nth: int
) -> void:
	if spec.hooks.is_empty():
		return
	for k in spec.hooks_on(trigger):
		if k.every > 0 and nth > 0 and nth % k.every != 0:
			continue
		run_hook(w, k, ctx, at, exclude)


## Launches hook `k`'s child from `at` under the guard (class doc). Returns true if it landed.
static func run_hook(
	w: World, k: AttackHook, parent: AttackContext, at: Vector2, exclude: int
) -> bool:
	if parent.depth + 1 > MAX_HOOK_DEPTH or k.child.depth > MAX_HOOK_DEPTH:
		return false
	if w.hook_chain.has(String(k.id)):
		return false
	var c := parent.child(at, k.damage_for(parent.base_damage), tags_of(k.child), k.child.effect_id)
	c.exclude = exclude
	w.hook_chain.append(String(k.id))
	var landed := launch(w, k.child, c)
	w.hook_chain.remove_at(w.hook_chain.size() - 1)
	return landed


## The SimEvent tag bits a hook's child carries: a burst is area, a seeking beam a chain, an arc melee, a bolt or a
## ray a projectile.
static func tags_of(spec: AttackSpec) -> int:
	match spec.form:
		AttackSpec.Form.BURST:
			return SimEvent.TAG_AREA
		AttackSpec.Form.BEAM:
			return SimEvent.TAG_CHAIN if spec.seek else SimEvent.TAG_PROJECTILE
		AttackSpec.Form.ARC:
			return SimEvent.TAG_MELEE
	return SimEvent.TAG_PROJECTILE


# --- Moments the drivers report -----------------------------------------------------------------------------
## Combo step `step` (spec `spec`) resolved with base damage `base` and it is an Nth step: its ON_NTH hooks fire from
## the player (Overcharge's shockwave). Returns the first hook's damage (Resonance's share), 0 if none ran.
static func on_nth(w: World, spec: AttackSpec, base: int, root: int) -> int:
	var first := 0
	var ctx := AttackContext.make(
		w.player_pos(), w.swing_angle, base, root, SimEvent.TAG_MELEE, &""
	)
	for k in spec.hooks_on(AttackSpec.Trigger.ON_NTH):
		if first == 0:
			first = k.damage_for(base)
		run_hook(w, k, ctx, w.player_pos(), -1)
	return first


## A player projectile landed on actor `i` at `at` (World phase 9, ItemProcs.on_bolt_hit): the Gun bolt spec's ON_HIT
## hooks. MX1: a projectile doesn't carry its spec, so every player projectile reads the bolt's, which is v0.5's rule
## (Static Chain read every landed player bolt). A hook with an `every` fires on every Nth landed bolt, counted once
## per landed bolt on World.chain_count, at most once per root (World.chain_root, set when it fires).
static func on_projectile_hit(w: World, i: int, pi: int, at: Vector2) -> void:
	var spec := Modifiers.bolt(w)
	var hooks := spec.hooks_on(AttackSpec.Trigger.ON_HIT)
	if hooks.is_empty():
		return
	var root := w.projectiles.root_id[pi]
	var counted := false
	for k in hooks:
		if k.every > 0 and not counted:
			w.chain_count += 1
			counted = true
	var ctx := AttackContext.make(
		at, 0, w.projectiles.damage[pi], root, w.projectiles.tags[pi], &""
	)
	for k in hooks:
		if k.every > 0 and (w.chain_count % k.every != 0 or w.chain_root == root):
			continue
		run_hook(w, k, ctx, at, i)


## The next landed bolt fires the bolt's first every-N ON_HIT hook (Static Chain's "ready" mark).
static func bolt_hook_ready(w: World) -> bool:
	for k in Modifiers.bolt(w).hooks_on(AttackSpec.Trigger.ON_HIT):
		if k.every > 0:
			return (w.chain_count + 1) % k.every == 0
	return false
