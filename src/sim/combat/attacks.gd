class_name Attacks
extends RefCounted
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md §7; SIM_CONTRACTS §5b): the one entry point that runs an attack from
## its compiled spec. The weapon drivers keep their timing (PlayerKit: the combo's ticks, the shot period; PlayerSkill:
## the lunge), compute the damage with the runtime factors (the build's per mille, Overcharge, Momentum, Bulwark, the
## gamble shrine) and call launch(spec, ctx) at the moment the attack happens. The shape tests here are the ones the
## views' forecasts read too (EI-07).
##
## Forms with a runner in MX1: ARC (the Blade's steps, Lunge Cleave), BOLT (the Gun's shots, queued for phase 9),
## BURST (Overcharge's shockwave), BEAM (a seeking jump: Static Chain; a fan of rays: Scatter Blast). v0.6.0 MX2 adds
## the rest: LOB (a bomb in flight, landing life_ticks later as a blast of radius_m: Bomb Lobber), ZONE (a patch of
## radius_m for life_ticks that hits an enemy in it once every period_ticks, at most `count` a tick when count > 1:
## Arc Field, Flame Trail), RING (a ring growing to radius_m over life_ticks, hitting each enemy as its edge passes:
## Frost Nova) and ORBITER (blades circling the origin at reach_m: Orbit Blades drives its own each tick; a launched
## one sweeps once). Every player projectile carries its spec (ProjectileStore.spec_key: its hits, its statuses and
## its hooks are its own spec's, and ON_END runs where it ends); a bomb, a patch and a ring do too. The area stat
## scales the lingering forms' radii (LOB, ZONE, RING) when they launch.
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
const FEED_ORDER: Array[StringName] = [&"burn", &"shock", &"bleed", &"frost", &"slow", &"poison"]
## A bolt leaves the muzzle this far past the player's and its own edge.
const MUZZLE_GAP_M := 0.05


## Runs `spec` with `ctx`. Returns true if it landed a hit (a bolt: true once queued; its hits come in phase 9).
## v0.6.0 MX4: a WEAPON child launches the weapon's last attack; an EVERY_NTH hook's Nth launch is its child
## instead; a root weapon or Skill attack takes Ascension's charge; a seeking arc snaps to the nearest enemy; then the
## form runs, its ON_LAUNCH hooks fire from the origin, a root attack fires back (Rearguard) and repeats (Twin Cast;
## the Blade's combo steps repeat through their Twin Arc echo, ItemEffects).
static func launch(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	if not _count(w):
		return false
	if spec.form == AttackSpec.Form.WEAPON:
		return _weapon_copy(w, spec, ctx)
	if not spec.hooks.is_empty() and _replaced(w, spec, ctx):
		return true
	if ctx.depth == 0 and not ctx.repeat and not ctx.back:
		ModifierRuntime.on_root_launch(w, spec, ctx)
	if spec.homing > 0 and spec.form == AttackSpec.Form.ARC:
		ctx.angle = ProjectileMoves.snap_angle(w, ctx.origin, ctx.angle, arc_reach_m(w, spec) + 2.0)
	var landed := _form(w, spec, ctx)
	if not spec.hooks.is_empty():
		_run(w, spec, AttackSpec.Trigger.ON_LAUNCH, ctx, ctx.origin, -1, 0)
	if ctx.depth == 0 and not ctx.back and spec.back_permille > 0:
		_back(w, spec, ctx)
	if ctx.depth == 0 and not ctx.repeat and ctx.step < 0 and spec.repeat_delay_ticks > 0:
		ModifierRuntime.queue_repeat(w, spec, ctx)
	return landed


static func _form(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
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
		AttackSpec.Form.LOB:  # v0.6.0 MX2
			_lob(w, spec, ctx)
			return true
		AttackSpec.Form.ZONE:
			_zone(w, spec, ctx)
			return true
		AttackSpec.Form.RING:
			_ring(w, spec, ctx)
			return true
		AttackSpec.Form.ORBITER:
			return _orbiter(w, spec, ctx)
	return false


## v0.6.0 MX4: the weapon's last attack (the Blade's current combo step, or the Gun's shot) launched with `ctx`; a
## spec with directions = circle sends it all round (Meltdown Edge: an arc as a full circle, a shot as `count` bolts).
static func _weapon_copy(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	var root := Modifiers.weapon_attack(w)
	if root == null:
		return false
	var s := root
	if spec.directions == AttackSpec.DIR_CIRCLE:
		s = root.copy()
		s.key = root.key
		s.directions = AttackSpec.DIR_CIRCLE
		s.count = maxi(root.count, spec.count)
		SpecForms.settle(s)
	ctx.step = -1
	return launch(w, s, ctx)


## v0.6.0 MX4: an EVERY_NTH hook counts the spec's launches (ModifierRuntime.count); on its Nth the child launches
## instead (Bomb Rounds: every 5th shot is a bomb). True when it replaced this launch.
static func _replaced(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	for k in spec.hooks:
		if k.trigger != AttackSpec.Trigger.EVERY_NTH or k.every <= 0:
			continue
		var key := spec.key if spec.key != "" else String(spec.id)
		var n := ModifierRuntime.count(w, key + "#nth")
		if n % k.every != 0:
			return false
		run_hook(w, k, ctx, ctx.origin, -1)
		return true
	return false


## v0.6.0 MX4 (Rearguard): the same attack straight back at back_permille of its damage (an arc, a shot, a beam or
## a bomb; the round forms have no back).
static func _back(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	match spec.form:
		AttackSpec.Form.ARC, AttackSpec.Form.BOLT, AttackSpec.Form.BEAM, AttackSpec.Form.LOB:
			pass
		_:
			return
	var dmg := maxi(1, ctx.damage * spec.back_permille / 1000)
	var ang := (ctx.angle + SimTick.ANGLE_UNITS / 2) & 4095
	var c := AttackContext.make(ctx.origin, ang, dmg, ctx.root, ctx.tags, ctx.effect_id)
	c.base_damage = maxi(1, ctx.base_damage * spec.back_permille / 1000)
	c.step = ctx.step
	c.muzzle_m = ctx.muzzle_m
	c.back = true
	c.repeat = true
	if ctx.has_target:
		c.target = ctx.origin * 2.0 - ctx.target
		c.has_target = true
	launch(w, spec, c)


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


## A shot's bolt offsets (1/4096 turns): [0], or `count` bolts over the full fan `spread` centred on the aim;
## v0.6.0 MX4: with directions = circle, `count` bolts evenly all round; every offset turned by aim_offset.
static func shot_offsets(spec: AttackSpec) -> PackedInt32Array:
	var n := maxi(1, spec.count)
	var out := PackedInt32Array()
	if spec.directions == AttackSpec.DIR_CIRCLE:
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
	var offsets := shot_offsets(spec)
	if spec.has_tag(&"weapon"):
		offsets = Abilities.shot_offsets(w, offsets)  # Pulse Gun L5: twin bolts (the weapon's own shots)
	var gap := t.radius_m + spec.radius_m + MUZZLE_GAP_M if ctx.muzzle_m < 0.0 else ctx.muzzle_m
	for off in offsets:
		var dir := Kin.dir(ctx.angle + off)
		var muzzle := ctx.origin + dir * gap
		w.queue_projectile(
			w.actors.ids[0],
			ActorStore.TEAM_PLAYER,
			muzzle,
			dir * spec.speed,
			ctx.damage,
			spec.radius_m,
			maxi(1, spec.life_ticks),
			ctx.tags,
			spec.bounces,
			spec.key
		)


static func _burst(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	var a := w.actors
	var landed := false
	var hits := 0
	var r := ctx.radius_m if ctx.radius_m > 0.0 else spec.radius_m  # v0.6.0 MX4: Vent's, an echo's
	if spec.pull_m > 0.0:  # v0.6.0 MX4: Gravity Well
		ModifierRuntime.pull(w, ctx.origin, r, spec.pull_m)
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
			continue
		if not AttackShapes.disc_touches(ctx.origin, r, a.pos(i), a.radius[i]):
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
	if spec.chains > 0:  # v0.6.0 MX4: Storm Core jumps on, each enemy once
		got += _chain(w, spec, ctx, best)
	return got > 0


## v0.6.0 MX4: a seeking beam's further jumps from `first`, up to spec.chains, each to the nearest enemy not hit yet
## within reach_m of the last (ties: the lower index). Returns how many landed.
static func _chain(w: World, spec: AttackSpec, ctx: AttackContext, first: int) -> int:
	var a := w.actors
	var hit := PackedInt32Array([first])
	if ctx.exclude >= 0:
		hit.append(ctx.exclude)
	var from := a.pos(first)
	var landed := 0
	for n in spec.chains:
		var next := -1
		var nd := spec.reach_m
		for j in w.enemies_near(from, spec.reach_m):
			var d := Kin.length(a.pos(j) - from)
			if not hit.has(j) and d <= nd and (next < 0 or d < nd):
				next = j
				nd = d
		if next < 0:
			break
		hit.append(next)
		w.chain_from = from
		w.chain_to = a.pos(next)
		if _hit(w, next, ctx, from, a.pos(next)) > 0:
			landed += 1
			_landed(w, spec, ctx, next, a.pos(next), n + 2)
		from = a.pos(next)
	return landed


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


## v0.6.0 MX2: one hit of `spec` on actor `i` at `at` from `from` (an orbiter's touch, a patch's, a ring's, a bomb's
## blast): the hit under World.hit_spec (the engines read the spec's statuses), then what a landed hit sets off
## (statuses, ON_HIT / ON_KILL hooks). Returns the HP removed.
static func land(
	w: World, spec: AttackSpec, ctx: AttackContext, i: int, from: Vector2, at: Vector2
) -> int:
	var before := w.hit_spec
	w.hit_spec = spec
	var got := _hit(w, i, ctx, from, at)
	w.hit_spec = before
	if got > 0:
		_landed(w, spec, ctx, i, at, 1)
	return got


## The SimEvent tags a lingering spec's hits carry: area (an orbiter's: none, or melee for a hook's), plus
## TAG_ABILITY on an ability's (v0.5's ability hits: area | ability, the orbit blades' ability alone).
static func lingering_tags(spec: AttackSpec) -> int:
	var tags := SimEvent.TAG_AREA
	if spec.form == AttackSpec.Form.ORBITER:
		tags = 0 if spec.has_tag(&"ability") else SimEvent.TAG_MELEE
	return tags | (SimEvent.TAG_ABILITY if spec.has_tag(&"ability") else 0)


## The area stat on a lingering form's radius (a bomb, a patch, a ring), as v0.5's abilities had it.
static func area_radius(w: World, spec: AttackSpec) -> float:
	return Stats.area(w, spec.radius_m)


# --- v0.6.0 MX2: the lingering forms ----------------------------------------------------------------------
## A bomb from ctx.origin to ctx.target (or reach_m along ctx.angle), landing life_ticks later (Abilities lands it in
## phase 6 through land_lob).
static func _lob(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	var flight := spec.life_ticks if spec.life_ticks > 0 else Modifiers.HOOK_LOB_TICKS
	var r := area_radius(w, spec)
	if ctx.has_target or spec.count <= 1:
		var to := ctx.target if ctx.has_target else ctx.origin + Kin.dir(ctx.angle) * spec.reach_m
		Abilities.drop_bomb(w, to, ctx.origin, r, ctx.damage, flight, spec.key, ctx)
		return
	for k in spec.count:  # v0.6.0 MX4: `count` bombs evenly round (Cluster Payload's bomblets)
		var ang := (ctx.angle + k * SimTick.ANGLE_UNITS / spec.count) & 4095
		var to := ctx.origin + Kin.dir(ang) * spec.reach_m
		Abilities.drop_bomb(w, to, ctx.origin, r, ctx.damage, flight, spec.key, ctx)


## A bomb of `spec` landed at `at` (radius `r`, damage `dmg`, root `root`, hook level `depth` / `proc`): every enemy
## in the blast takes the hit (effect `effect`), then its ON_END hooks run from the blast.
static func land_lob(
	w: World,
	spec: AttackSpec,
	at: Vector2,
	r: float,
	dmg: int,
	root: int,
	depth: int,
	proc: int,
	effect: StringName
) -> void:
	var ctx := AttackContext.make(at, 0, dmg, root, lingering_tags(spec), effect)
	ctx.depth = depth
	ctx.proc_pct = proc
	for i in w.enemies_near(at, r):
		land(w, spec, ctx, i, at, w.actors.pos(i))
	_run(w, spec, AttackSpec.Trigger.ON_END, ctx, at, -1, 0)


## A patch at ctx.origin (ElementAbilities keeps it and burns what stands in it, phase 6).
static func _zone(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	var life := spec.life_ticks if spec.life_ticks > 0 else Modifiers.HOOK_ZONE_TICKS
	ElementAbilities.add_zone(w, ctx.origin, area_radius(w, spec), life, spec, ctx)


## A ring from ctx.origin (ModifierAbilities grows it, phase 6).
static func _ring(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	ModifierAbilities.add_ring(w, ctx.origin, area_radius(w, spec), spec, ctx)


## Blade k of an orbiter of `spec` around `center`, its first blade at angle `ang` (1/4096 turns), ring radius `r`.
static func orbiter_pos(spec: AttackSpec, center: Vector2, ang: int, r: float, k: int) -> Vector2:
	var n := maxi(1, spec.count)
	return center + Kin.dir((ang + k * SimTick.ANGLE_UNITS / n) & 4095) * r


## A launched orbiter (a hook's): one sweep of its blades around ctx.origin, each enemy hit once.
static func _orbiter(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	var a := w.actors
	var r := spec.reach_m if spec.reach_m > 0.0 else 1.5
	var br := spec.radius_m if spec.radius_m > 0.0 else Abilities.BLADE_R
	var landed := false
	for i in w.enemies_near(ctx.origin, r + br):
		for k in maxi(1, spec.count):
			var b := orbiter_pos(spec, ctx.origin, ctx.angle, r, k)
			if AttackShapes.disc_touches(b, br, a.pos(i), a.radius[i]):
				landed = land(w, spec, ctx, i, b, a.pos(i)) > 0 or landed
				break
	_run(w, spec, AttackSpec.Trigger.ON_END, ctx, ctx.origin, -1, 0)
	return landed


## A hit of `spec` landed on actor `i` at `at` (the `nth` landed hit of this launch): a weapon step's burn (Ember
## Edge, as before MX1), a hook attack's own statuses at its proc coefficient, then its ON_HIT and ON_KILL hooks.
static func _landed(
	w: World, spec: AttackSpec, ctx: AttackContext, i: int, at: Vector2, nth: int
) -> void:
	if spec.depth == 0 and spec.form == AttackSpec.Form.ARC and spec.has_status(&"burn"):
		if spec.has_tag(&"weapon"):
			ItemEffects.on_melee_hit(w, i, ctx.root, spec.stacks_of(&"burn"))
	if ctx.depth > 0 or (spec.has_tag(&"ability") and spec.form != AttackSpec.Form.BOLT):
		_feed(w, spec, ctx, i)  # v0.6.0 MX2: an ability's own attack (not a projectile) feeds here
	_run(w, spec, AttackSpec.Trigger.ON_HIT, ctx, at, i, nth)
	if w.actors.dead[i] == 1:
		_run(w, spec, AttackSpec.Trigger.ON_KILL, ctx, at, i, nth)


## A hook attack's own statuses: stacks × its proc coefficient (rounded down; none at 0), once per root per target
## and status. Root attacks feed through their sources instead (Engines.on_hit, ItemEffects.on_melee_hit,
## ItemProcs.on_bolt_hit), as before MX1; v0.6.0 MX2: so does every projectile (Engines reads World.hit_spec), while
## an ability's other attacks (a bomb, an orbiter, a patch, a ring) feed here, at proc 100 for the ability's own.
static func _feed(w: World, spec: AttackSpec, ctx: AttackContext, i: int) -> void:
	var a := w.actors
	for k in spec.status_ids.size():
		var n := spec.status_stacks[k] * ctx.proc_pct / 100
		var st := StringName(spec.status_ids[k])
		var code := CODE_HOOK_FEED + FEED_ORDER.find(st)
		if n <= 0 or a.dead[i] == 1:
			continue
		var every := spec.status_every[k]
		if every > 0 and not ModifierRuntime.every_hit(w, spec, st, every):
			continue  # v0.6.0 MX4: an inherited every-N status counts this form's own hits
		if not w.proc_ledger.try_mark(ctx.root, code, a.ids[i], w.tick):
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
			&"poison":  # v0.6.0 MX4
				Venom.add(w, i, n, ctx.root)


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


## v0.6.0 MX2: `spec`'s ON_END hooks from `at` (a ring that reached its radius).
static func run_on_end(w: World, spec: AttackSpec, ctx: AttackContext, at: Vector2) -> void:
	_run(w, spec, AttackSpec.Trigger.ON_END, ctx, at, -1, 0)


## v0.6.0 MX4: a moment's hooks on `trigger` from `at` (the dash's start and end, a walk step, a blink).
static func fire(w: World, spec: AttackSpec, trigger: int, ctx: AttackContext, at: Vector2) -> void:
	if spec != null:
		_run(w, spec, trigger, ctx, at, -1, 0)


## Launches hook `k`'s child from `at` under the guard (class doc). Returns true if it landed.
static func run_hook(
	w: World, k: AttackHook, parent: AttackContext, at: Vector2, exclude: int
) -> bool:
	if parent.depth + 1 > MAX_HOOK_DEPTH or k.child.depth > MAX_HOOK_DEPTH:
		return false
	if w.hook_chain.has(String(k.id)):
		return false
	if k.when == AttackHook.WHEN_OVERCLOCK and not Heat.overclocked(w):
		return false  # v0.6.0 MX4: Heat Sink Rounds
	var dmg := k.damage_for(parent.base_damage)
	if k.child.form == AttackSpec.Form.WEAPON and k.damage <= 0:  # v0.6.0 MX4: a share of the weapon's
		dmg = maxi(1, Modifiers.weapon_damage(w) * k.damage_permille / 1000)
	var c := parent.child(at, dmg, tags_of(k.child), k.child.effect_id)
	c.exclude = exclude
	if k.child.form == AttackSpec.Form.BOLT and exclude >= 0:  # v0.6.0 MX4: from past the enemy it hit
		c.muzzle_m = w.actors.radius[exclude] + k.child.radius_m + MUZZLE_GAP_M
	if k.delay_ticks > 0:  # v0.6.0 MX4: Long Shadow's afterimage waits
		ModifierRuntime.queue_hook(w, k, c)
		return false
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


## The spec player projectile `pi` runs (v0.6.0 MX2: its own, ProjectileStore.spec_key); a projectile without one (a
## Wingman volley, a Thorn Mantle bolt, a spec gone with a build change) reads the Gun bolt's, v0.5's rule. Null for
## an enemy's.
static func projectile_spec(w: World, pi: int) -> AttackSpec:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER:
		return null
	var key := p.spec_key[pi] if pi < p.spec_key.size() else ""
	if key != "":
		var s := Modifiers.book(w).find(key)
		if s != null:
			return s
	return Modifiers.bolt(w)


## A player projectile landed on actor `i` at `at` (World phase 9, ItemProcs.on_bolt_hit): its spec's ON_HIT hooks
## (v0.6.0 MX2: the projectile's own spec, and its ON_KILL hooks on a kill; MX1 read the Gun bolt's for every player
## projectile, v0.5's rule, which stays for a projectile without a spec). A hook with an `every` fires on every Nth
## landed bolt, counted once per landed bolt on World.chain_count, at most once per root (World.chain_root, set when
## it fires). A projectile's hook child launches one level below the projectile's spec.
static func on_projectile_hit(w: World, i: int, pi: int, at: Vector2) -> void:
	var spec := projectile_spec(w, pi)
	if spec == null:
		return
	var hooks := spec.hooks_on(AttackSpec.Trigger.ON_HIT)
	if w.actors.dead[i] == 1:
		hooks.append_array(spec.hooks_on(AttackSpec.Trigger.ON_KILL))
	if hooks.is_empty():
		return
	var root := w.projectiles.root_id[pi]
	var counted := false
	for k in hooks:
		if k.every > 0 and not counted:
			w.chain_count += 1
			counted = true
	var p := w.projectiles
	var ang := Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))  # v0.6.0 MX4: a hook's slash, split, way
	var ctx := AttackContext.make(at, ang, p.damage[pi], root, p.tags[pi], &"")
	ctx.depth = spec.depth
	ctx.proc_pct = maxi(1, 100 >> spec.depth)
	for k in hooks:
		if k.every > 0 and (w.chain_count % k.every != 0 or w.chain_root == root):
			continue
		run_hook(w, k, ctx, at, i)


## v0.6.0 MX2: player projectile `pi` ended at `at` (a hit that stopped it, a wall, its life): its spec's ON_END hooks
## from there, then what an ending projectile leaves (Flame Trail's fire).
static func on_projectile_end(w: World, pi: int, at: Vector2) -> void:
	if w.projectiles.team[pi] != ActorStore.TEAM_PLAYER:
		return
	var spec := projectile_spec(w, pi)
	if spec != null and not spec.hooks.is_empty():
		var p := w.projectiles
		var ang := Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))
		var ctx := AttackContext.make(at, ang, p.damage[pi], p.root_id[pi], p.tags[pi], &"")
		ctx.depth = spec.depth
		ctx.proc_pct = maxi(1, 100 >> spec.depth)
		_run(w, spec, AttackSpec.Trigger.ON_END, ctx, at, -1, 0)
	ModifierAbilities.on_projectile_end(w, at)


## The next landed bolt fires the bolt's first every-N ON_HIT hook (Static Chain's "ready" mark).
static func bolt_hook_ready(w: World) -> bool:
	for k in Modifiers.bolt(w).hooks_on(AttackSpec.Trigger.ON_HIT):
		if k.every > 0:
			return (w.chain_count + 1) % k.every == 0
	return false
