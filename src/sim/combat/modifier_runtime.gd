class_name ModifierRuntime
extends RefCounted
## v0.6.0 MX4 (docs/design/MODIFIER_ENGINE.md; SIM_CONTRACTS §8b): what the M-list's modifiers do in play that is
## not one launch of one spec, all read from the compiled specs (Modifiers) and kept in World.mx (ModifierState):
## - the launch queue: Twin Cast's repeats (a root attack again repeat_delay_ticks later at repeat_damage_permille,
##   from where the player is then) and a delayed hook's child (Long Shadow's afterimage), fired in tick phase 6 in
##   the order they were queued; a queued launch keeps its hook level and proc, and its hook id rides the ancestry
##   chain while it runs;
## - the every-N counters (an EVERY_NTH hook's launches; an inherited every-N status's hits on a form);
## - the moments: the dash's start (ON_LAUNCH, from where it starts) and end (ON_END, where it ends), and walking
##   (every Modifiers.MOVE_STEP_M walked, not dashing, the move spec's ON_LAUNCH hooks: Ember Trail); Phase Dash's
##   intangible dash (no bodies, no hits for the whole dash);
## - the body's rules: Ascension (after charge_ticks without a root attack, the next one deals × charge_permille),
##   Aether Shell (out of combat barrier_ticks, the next enemy hit is absorbed, and combat starts again) and
##   Resonance (each status on an enemy adds resonance_permille to the player's damage on it);
## - Gravity Well's pull.
## Every function draws no randomness (EI-05) and runs on the one clock.


## Counter `key` + 1, returned (an EVERY_NTH hook's launches; a form's hits for an every-N status).
static func count(w: World, key: String) -> int:
	var n := int(w.mx.counts.get(key, 0)) + 1
	w.mx.counts[key] = n
	return n


## An every-N status of `spec` (an inherited one on a bomb, an orbiter, a patch, a ring, a hook's attack) applies on
## this hit: every `every`-th landed hit of this form, counted per spec and status.
static func every_hit(w: World, spec: AttackSpec, status: StringName, every: int) -> bool:
	var key := "%s/%s" % [spec.key if spec.key != "" else String(spec.id), status]
	return count(w, key) % every == 0


# --- The launch queue ---------------------------------------------------------------------------------------------
## Twin Cast: root `spec` launched with `ctx` comes again repeat_delay_ticks later at repeat_damage_permille.
static func queue_repeat(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	var share := spec.repeat_damage_permille
	var c := AttackContext.make(
		ctx.origin, ctx.angle, maxi(1, ctx.damage * share / 1000), ctx.root, ctx.tags, ctx.effect_id
	)
	c.base_damage = maxi(1, ctx.base_damage * share / 1000)
	c.radius_m = ctx.radius_m
	c.muzzle_m = ctx.muzzle_m
	c.target = ctx.target
	c.has_target = ctx.has_target
	var flags := ModifierState.FLAG_REPEAT | ModifierState.FLAG_AT_PLAYER
	_queue(w, spec.key, w.tick + spec.repeat_delay_ticks, c, flags, "")


## A hook's child that waits (AttackHook.delay_ticks): `c` is its launch context, built when it triggered.
static func queue_hook(w: World, k: AttackHook, c: AttackContext) -> void:
	_queue(w, k.child.key, w.tick + k.delay_ticks, c, 0, String(k.id))


static func _queue(
	w: World, key: String, at_tick: int, c: AttackContext, flags: int, hook: String
) -> void:
	var s := w.mx
	s.q_key.append(key)
	s.q_tick.append(at_tick)
	s.q_pos.append(c.origin)
	s.q_angle.append(c.angle)
	s.q_damage.append(c.damage)
	s.q_base.append(c.base_damage)
	s.q_root.append(c.root)
	s.q_tags.append(c.tags)
	s.q_effect.append(String(c.effect_id))
	s.q_depth.append(c.depth)
	s.q_proc.append(c.proc_pct)
	s.q_flags.append(flags)
	s.q_hook.append(hook)
	s.q_radius.append(c.radius_m)
	s.q_muzzle.append(c.muzzle_m)


## Tick phase 6 (Abilities.advance): every queued launch whose tick has come, in queue order (one whose spec left
## the build with a build change is dropped); then the walk's trail.
static func advance(w: World) -> void:
	var s := w.mx
	var k := 0
	while k < s.q_key.size():
		if s.q_tick[k] > w.tick:
			k += 1
			continue
		var spec := Modifiers.book(w).find(s.q_key[k])
		var c := AttackContext.make(
			s.q_pos[k],
			s.q_angle[k],
			s.q_damage[k],
			s.q_root[k],
			s.q_tags[k],
			StringName(s.q_effect[k])
		)
		c.base_damage = s.q_base[k]
		c.depth = s.q_depth[k]
		c.proc_pct = s.q_proc[k]
		c.radius_m = s.q_radius[k]
		c.muzzle_m = s.q_muzzle[k]
		var flags := s.q_flags[k]
		var hook := s.q_hook[k]
		s.remove_at(k)
		if spec == null or w.player_dead():
			continue
		c.repeat = (flags & ModifierState.FLAG_REPEAT) != 0
		if flags & ModifierState.FLAG_AT_PLAYER:
			c.origin = w.player_pos()
		if hook != "":
			if w.hook_chain.has(hook):
				continue
			w.hook_chain.append(hook)
		Attacks.launch(w, spec, c)
		if hook != "":
			w.hook_chain.remove_at(w.hook_chain.size() - 1)
	_walk(w)


# --- The moments ----------------------------------------------------------------------------------------------------
## The dash just started (World phase 4): its ON_LAUNCH hooks from where it starts (Long Shadow).
static func on_dash_start(w: World) -> void:
	w.mx.dash_from = w.player_pos()
	_moment(w, Modifiers.dash(w), AttackSpec.Trigger.ON_LAUNCH, w.player_pos())


## The dash just ended: its ON_END hooks from where it ends (Phase Dash's shard burst).
static func on_dash_end(w: World) -> void:
	_moment(w, Modifiers.dash(w), AttackSpec.Trigger.ON_END, w.player_pos())


## A blink just left w.blink_from: the blink spec's hooks that don't wait (Afterimage's waiting echo is AbilityMods').
static func on_blink(w: World) -> void:
	var spec := Modifiers.blink(w)
	if spec == null or spec.hooks.is_empty():
		return
	var ctx := AttackContext.make(w.blink_from, w.aim_angle, 0, w.take_root(), 0, &"")
	for k in spec.hooks_on(AttackSpec.Trigger.ON_LAUNCH):
		if k.delay_ticks <= 0:
			Attacks.run_hook(w, k, ctx, w.blink_from, -1)


static func _moment(w: World, spec: AttackSpec, trigger: int, at: Vector2) -> void:
	if spec == null or spec.hooks_on(trigger).is_empty() or w.player_dead():
		return
	var ang := PlayerBuild.melee_angle(w) if PlayerBuild.has_blade(w) else w.aim_angle
	var ctx := AttackContext.make(at, ang, 0, w.take_root(), 0, &"")
	Attacks.fire(w, spec, trigger, ctx, at)


## Walking (not dashing, alive): every MOVE_STEP_M from the last drop, the move spec's ON_LAUNCH hooks fire where the
## player is (Ember Trail's burning crystals).
static func _walk(w: World) -> void:
	var spec := Modifiers.move(w)
	if spec == null or spec.hooks.is_empty() or w.player_dead():
		return
	var s := w.mx
	var p := w.player_pos()
	if not s.trail_on or w.is_dashing():
		s.trail_on = true
		s.trail_at = p
		return
	if Kin.length(p - s.trail_at) < Modifiers.MOVE_STEP_M:
		return
	s.trail_at = p
	s.trail_tick = w.tick
	_moment(w, spec, AttackSpec.Trigger.ON_LAUNCH, p)


## Phase Dash: the dash spec makes the dash intangible (the player passes through bodies and takes no hit).
static func intangible(w: World) -> bool:
	var d := Modifiers.dash(w)
	return d != null and d.intangible > 0


# --- The body's rules ----------------------------------------------------------------------------------------------
## A root attack (depth 0, not a repeat or a back copy) launches: Ascension's charge, for the weapon's and the Skill's.
static func on_root_launch(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	if not (spec.has_tag(&"weapon") or spec.has_tag(&"skill")):
		return
	var b := Modifiers.body(w)
	if b == null or b.charge_ticks <= 0:
		return
	if w.tick - w.mx.last_attack >= b.charge_ticks:
		ctx.damage = maxi(1, ctx.damage * b.charge_permille / 1000)
		ctx.base_damage = maxi(1, ctx.base_damage * b.charge_permille / 1000)
		w.mx.charge_tick = w.tick
	w.mx.last_attack = w.tick


## Ascension's next attack is charged now (the view's glow).
static func charged(w: World) -> bool:
	var b := Modifiers.body(w)
	return b != null and b.charge_ticks > 0 and w.tick - w.mx.last_attack >= b.charge_ticks


## Aether Shell is up now: out of combat (no damage dealt or taken) for barrier_ticks.
static func shell_up(w: World) -> bool:
	var b := Modifiers.body(w)
	return (
		b != null
		and b.barrier_ticks > 0
		and not w.player_dead()
		and w.tick - w.build_state.combat_tick >= b.barrier_ticks
	)


## An enemy hit on the player (Damage.hit, before it lands): with the shell up it is absorbed (the hit lands for 0,
## a STATUS_APPLY on the player names aether_shell) and combat starts again, so the shell waits barrier_ticks more.
static func absorb(w: World) -> bool:
	if not shell_up(w):
		return false
	w.mx.shell_tick = w.tick
	w.build_state.combat_tick = w.tick
	var pid := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, pid, pid, pid, w.player_pos())
	e.effect_id = &"aether_shell"
	return true


## Resonance: the player's attacker multiplier (per mille) on enemy `target`: + resonance_permille per status on it
## (burning, shocked, bleeding, chilled or frozen, slowed, poisoned).
static func resonance_mult(w: World, target: int, owner_id: int) -> int:
	if target == 0 or owner_id != w.actors.ids[0]:
		return 1000
	var b := Modifiers.body(w)
	if b == null or b.resonance_permille <= 0:
		return 1000
	var a := w.actors
	var n := 0
	for on: bool in [
		a.burn_stacks[target] > 0,
		a.shock_stacks[target] > 0,
		a.bleed_stacks[target] > 0,
		a.frost_stacks[target] > 0 or a.frozen_t[target] > 0,
		a.slow_t[target] > 0,
		a.poison_stacks[target] > 0,
	]:
		if on:
			n += 1
	return 1000 + n * b.resonance_permille


# --- Gravity Well ----------------------------------------------------------------------------------------------------
## Pulls every enemy (not a boss, not spawning in) touching the disc (`at`, `r`) up to `d` metres toward its centre,
## never past it. Walls push them out again in the next collision pass.
static func pull(w: World, at: Vector2, r: float, d: float) -> void:
	var a := w.actors
	for i in w.enemies_near(at, r):
		if a.invuln[i] > 0 or BossAi.is_boss_kind(a.kinds[i]):
			continue
		var to := at - a.pos(i)
		var dist := Kin.length(to)
		var step := minf(d, maxf(0.0, dist - a.radius[i]))
		if dist > 0.0 and step > 0.0:
			a.set_pos(i, a.pos(i) + to * (step / dist))


# --- Hash ---------------------------------------------------------------------------------------------------------
## The engine's state in play (Modifiers.hash_into: once the build has a modifier).
static func hash_into(w: World, h: StateHasher) -> void:
	if w.mx.touched():
		w.mx.hash_into(h)
	Venom.hash_into(w, h)
	ProjectileMoves.hash_into(w, h)
