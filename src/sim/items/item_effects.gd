class_name ItemEffects
extends RefCounted
## What the owned items do to the attacks (v0.2.0 PLAN, Items). Each effect still fires at most once per root chain
## per target, and burn ticks are DoT (DAMAGE with TAG_DOT, proc 0, no HIT).
## v0.6.0 MX1: the numbers come from the compiled specs (Modifiers; the items' modifiers rewrote them): the reach
## bonus, the shot period, the split, Overcharge's Nth step and shockwave, Twin Arc's repeat, the burn a step feeds.
## These functions keep their v0.5 names, so the views and the other systems read the same numbers as before.

## Walking within this distance of a pickup takes it.
const PICKUP_RADIUS_M := 0.8
## A dash hits enemies whose edge comes within this much of the player's edge along the dash.
const DASH_HIT_MARGIN_M := 0.1
## A bounced bolt is pushed this far off the wall so its next sweep starts clear.
const BOUNCE_CLEARANCE_M := 0.01
const EFFECT_TWIN_ARC := &"twin_arc"
const EFFECT_EMBER_EDGE := &"ember_edge"
const EFFECT_KINETIC_DASH := &"kinetic_dash"
const EFFECT_OVERCHARGE := &"overcharge"


## The reach of combo step `step` (-1 = the current one): its spec's (Long Edge's bonus in it), Combo Sword's level,
## area and Hot (Attacks.arc_reach_m). PlayerKit hits with it and WorldReader draws it (EI-07).
static func swing_reach_m(w: World, step: int = -1) -> float:
	var s := step if step >= 0 else w.combo_step
	return Attacks.arc_reach_m(w, Modifiers.step(w, s))


## Ticks between bolts while shooting: the bolt spec's period, with its rate bonus (Rapid Coil) applied (never under
## 2 ticks once shortened), then attack speed.
static func shot_period_ticks(w: World) -> int:
	var spec := Modifiers.bolt(w)
	var base := spec.period_ticks
	var bonus := spec.rate_bonus_permille
	if bonus <= 0:
		return Stats.period(w, base)  # v0.4.0 BS: attack speed
	return Stats.period(w, maxi(2, int(round(base * 1000.0 / (1000 + bonus)))))


## Damage of each bolt in a shot: the full bolt, or a Splinter share (rounded down, at least 1).
static func bolt_damage(w: World) -> int:
	return Attacks.bolt_base_damage(Modifiers.bolt(w))


## Angle offsets (1/4096 turns) of the bolts in one shot: [0], or a Splinter fan centred on the aim.
static func shot_offsets(w: World) -> PackedInt32Array:
	return Attacks.shot_offsets(Modifiers.bolt(w))


## Called when a swing starts (w.combo_step is already the new step): Overcharge marks every Nth swing of the
## combo, so with N = 4 and the four-slash combo it is always the finisher (v0.3.0 L11). swing_count still counts
## the swings started while it is owned.
static func on_swing_start(w: World) -> void:
	var every := Modifiers.step(w, w.combo_step).nth_every
	if every <= 0:
		w.swing_overcharged = false
		return
	w.swing_count += 1
	w.swing_overcharged = overcharged_step(w, w.combo_step)


## Overcharge charges combo step `step` (0-based): the Nth, 2Nth, ... swing of the combo.
static func overcharged_step(w: World, step: int) -> bool:
	var every := Modifiers.step(w, step).nth_every
	return every > 0 and (step + 1) % every == 0


## A press now would start an Overcharge swing.
static func overcharge_ready(w: World) -> bool:
	return overcharged_step(w, PlayerKit.next_step(w))


## A swing's damage with Overcharge applied.
static func swing_damage(w: World, base: int) -> int:
	if not w.swing_overcharged:
		return base
	return base * Modifiers.step(w, w.combo_step).nth_damage_permille / 1000


## After a swing resolves (`dmg` is what it dealt per target, `base` its combo damage): the step's ON_NTH hooks
## (Overcharge's shockwave, Attacks.on_nth), then schedule the step's repeat (Twin Arc's echo).
static func after_swing(w: World, base: int, dmg: int) -> void:
	var spec := Modifiers.step(w, w.combo_step)
	var wave := 0
	if w.swing_overcharged:
		w.overcharge_tick = w.tick
		wave = Attacks.on_nth(w, spec, base, w.swing_root)
	if spec.repeat_delay_ticks > 0:
		w.echo_t = spec.repeat_delay_ticks
		w.echo_angle = w.swing_angle
		w.echo_step = w.combo_step
		w.echo_root = w.swing_root
		w.echo_damage = maxi(1, dmg * spec.repeat_damage_permille / 1000)
		w.echo_overcharged = w.swing_overcharged  # Engines: Resonance.
		w.echo_wave = wave


## Resonance's shockwave (Engines.on_echo): `dmg` to every enemy touching the disc of Overcharge's shockwave
## (its ON_NTH burst's radius) around the player, at full proc (an engine payoff, not a hook).
static func shockwave(w: World, dmg: int, root: int, effect: StringName) -> void:
	var a := w.actors
	var center := w.player_pos()
	var radius := Modifiers.nth_burst_radius_m(w)
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
			continue
		if not AttackShapes.disc_touches(center, radius, a.pos(i), a.radius[i]):
			continue
		Damage.hit(w, i, dmg, a.ids[0], a.ids[0], root, SimEvent.TAG_AREA, center, a.pos(i), effect)


## Phase 4: counts down the pending Twin Arc echo and swings it (the same step's arc, re-tested from where the
## player is).
static func advance_echo(w: World) -> void:
	if w.echo_t <= 0:
		return
	w.echo_t -= 1
	if w.echo_t > 0:
		return
	w.echo_tick = w.tick
	PlayerKit.swing_arc(w, w.echo_angle, w.echo_damage, w.echo_root, EFFECT_TWIN_ARC, w.echo_step)
	Engines.on_echo(w, w.echo_root)  # Engines: Resonance.


## A weapon step's hit landed on actor `i` and its spec burns (Ember Edge's modifier, or the burn rider;
## Attacks._landed): `stacks` burn stacks, once per root chain per target.
static func on_melee_hit(w: World, i: int, root: int, stacks: int = 1) -> void:
	var m := w.item_mods
	var a := w.actors
	if m.burn_max_stacks <= 0 or a.dead[i] == 1 or a.burn_root[i] == root:
		return
	a.burn_root[i] = root
	if a.burn_stacks[i] == 0:
		a.burn_cd[i] = m.burn_period_ticks
	a.burn_stacks[i] = mini(a.burn_stacks[i] + stacks, m.burn_max_stacks)
	a.burn_t[i] = m.burn_duration_ticks
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[0], a.ids[0], a.ids[i], a.pos(i))
	e.root_id = root
	e.amount = a.burn_stacks[i]
	e.effect_id = EFFECT_EMBER_EDGE


## Phase 8: burns tick. Every period each burning actor takes burn_damage × stacks as DoT; when the burn runs
## out (each new stack refreshes it) all its stacks drop.
static func tick_burns(w: World) -> void:
	var a := w.actors
	var m := w.item_mods
	for i in a.size():
		if a.burn_stacks[i] == 0:
			continue
		a.burn_t[i] -= 1
		a.burn_cd[i] -= 1
		if a.burn_cd[i] <= 0:
			a.burn_cd[i] = m.burn_period_ticks
			Damage.tick_dot(
				w, i, m.burn_damage * a.burn_stacks[i], a.ids[0], a.ids[0], EFFECT_EMBER_EDGE
			)
		if a.burn_t[i] <= 0:
			a.burn_stacks[i] = 0
			a.burn_cd[i] = 0


## Phase 6: Kinetic Dash hits each enemy the dash swept through this tick, once per dash.
static func dash_hits(w: World, before: Vector2) -> void:
	var dmg := w.item_mods.dash_hit_damage
	if (dmg <= 0 and not Engines.dash_wants(w)) or not w.is_dashing() or w.player_dead():
		return
	var a := w.actors
	var now := w.player_pos()
	var r := a.radius[0] + DASH_HIT_MARGIN_M
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1 or w.dash_hit_ids.has(a.ids[i]):
			continue
		if Collide.sweep_vs_circle(before, now, r, a.pos(i), a.radius[i]) < 0.0:
			continue
		if w.dash_root == 0:
			w.dash_root = w.take_root()
		w.dash_hit_ids.append(a.ids[i])
		if dmg > 0:
			var got := Damage.hit(
				w,
				i,
				dmg,
				a.ids[0],
				a.ids[0],
				w.dash_root,
				SimEvent.TAG_DASH,
				before,
				a.pos(i),
				EFFECT_KINETIC_DASH
			)
			if got > 0:
				w.dash_hit_tick = w.tick
		Engines.on_dash_pass(w, i)  # Engines: bleed burst, Cold Snap, Shatter Dash.


## Ricochet Core: bolt `i` touched `wall` at `at`; reflect it off the touched face and spend a bounce.
static func bounce(w: World, i: int, at: Vector2, wall: Obb) -> void:
	var p := w.projectiles
	var v := Vector2(p.vel_x[i], p.vel_y[i])
	var n := wall_normal(at, p.radius[i], wall)
	v -= n * (2.0 * v.dot(n))
	var out := at + n * BOUNCE_CLEARANCE_M
	p.vel_x[i] = v.x
	p.vel_y[i] = v.y
	p.pos_x[i] = out.x
	p.pos_y[i] = out.y
	p.bounces[i] -= 1
	p.bounce_tick[i] = w.tick
	Engines.on_bounce(w, i)  # Engines: Shrapnel Storm.


## The outward normal of the face of `box` (grown by r) nearest to `at`: the axis with the smallest margin.
static func wall_normal(at: Vector2, r: float, box: Obb) -> Vector2:
	var d := at - box.center
	var lx := d.dot(box.axis_u)
	var ly := d.dot(box.axis_v)
	var mx := box.half.x + r - absf(lx)
	var my := box.half.y + r - absf(ly)
	if mx < my:
		return box.axis_u * (1.0 if lx >= 0.0 else -1.0)
	return box.axis_v * (1.0 if ly >= 0.0 else -1.0)


## Phase 9: the player takes every pickup within PICKUP_RADIUS_M (a PICKUP event each; amount = item index).
static func collect_pickups(w: World) -> void:
	if w.player_dead():
		return
	var p := w.pickups
	var at := w.player_pos()
	var i := 0
	while i < p.size():
		if Kin.length(p.pos(i) - at) > Stats.reach(w, PICKUP_RADIUS_M):  # v0.4.0: pickup range
			i += 1
			continue
		var idx := p.item[i]
		var e := w.emit_event(
			SimEvent.Kind.PICKUP, p.ids[i], w.actors.ids[0], w.actors.ids[0], p.pos(i)
		)
		e.amount = idx
		Offers.apply(w, idx)  # v0.6.0 MX2: a modifier with the six slots full asks for a swap
		p.remove_at(i)
		if BuildSlots.swapping(w):
			return  # one swap at a time: the next pickup waits for the next tick
