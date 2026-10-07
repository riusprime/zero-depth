class_name ItemEffects
extends RefCounted
## What the owned items do to the attacks (v0.2.0 PLAN, Items). Plain modifiers for now: the full
## Trigger → Condition → Payoff queue (SIM_CONTRACTS §8) arrives with the engine work. Each effect still fires at
## most once per root chain per target, and burn ticks are DoT (DAMAGE with TAG_DOT, proc 0, no HIT).

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


## The swing's reach with Long Edge applied. PlayerKit hits with it and WorldReader draws it (EI-07).
static func swing_reach_m(w: World) -> float:
	return w.player.swing_reach_m * (1000 + w.item_mods.reach_bonus_permille) / 1000.0


## Ticks between bolts while shooting, with Rapid Coil applied (never under 2 ticks once shortened).
static func shot_period_ticks(w: World) -> int:
	var base := w.player.shot_period_ticks
	var bonus := w.item_mods.fire_rate_bonus_permille
	if bonus <= 0:
		return base
	return maxi(2, int(round(base * 1000.0 / (1000 + bonus))))


## Damage of each bolt in a shot: the full bolt, or a Splinter share (rounded down, at least 1).
static func bolt_damage(w: World) -> int:
	var m := w.item_mods
	if m.split_count <= 1:
		return w.player.bolt_damage
	return maxi(1, w.player.bolt_damage * m.split_damage_permille / 1000)


## Angle offsets (1/4096 turns) of the bolts in one shot: [0], or a Splinter fan centred on the aim.
static func shot_offsets(w: World) -> PackedInt32Array:
	var m := w.item_mods
	var n := maxi(1, m.split_count)
	var out := PackedInt32Array()
	if n == 1:
		out.append(0)
		return out
	var half := m.split_spread / 2
	for k in n:
		out.append(-half + 2 * half * k / (n - 1))
	return out


## Called when a swing starts: counts swings toward Overcharge and marks this one if it's the Nth.
static func on_swing_start(w: World) -> void:
	var every := w.item_mods.overcharge_every
	if every <= 0:
		w.swing_overcharged = false
		return
	w.swing_count += 1
	w.swing_overcharged = w.swing_count % every == 0


## The next swing will be an Overcharge swing.
static func overcharge_ready(w: World) -> bool:
	var every := w.item_mods.overcharge_every
	return every > 0 and (w.swing_count + 1) % every == 0


## A swing's damage with Overcharge applied.
static func swing_damage(w: World, base: int) -> int:
	if not w.swing_overcharged:
		return base
	return base * w.item_mods.overcharge_mult_permille / 1000


## After a swing resolves (`dmg` is what it dealt per target, `base` its combo damage): the Overcharge shockwave,
## then schedule the Twin Arc echo.
static func after_swing(w: World, base: int, dmg: int) -> void:
	var m := w.item_mods
	if w.swing_overcharged:
		w.overcharge_tick = w.tick
		var wave := maxi(1, base * m.shockwave_damage_permille / 1000)
		var a := w.actors
		var center := w.player_pos()
		for i in range(1, a.size()):
			if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
				continue
			if not AttackShapes.disc_touches(center, m.shockwave_radius_m, a.pos(i), a.radius[i]):
				continue
			Damage.hit(
				w,
				i,
				wave,
				a.ids[0],
				a.ids[0],
				w.swing_root,
				SimEvent.TAG_AREA,
				center,
				a.pos(i),
				EFFECT_OVERCHARGE
			)
	if m.echo_delay_ticks > 0:
		w.echo_t = m.echo_delay_ticks
		w.echo_angle = w.swing_angle
		w.echo_root = w.swing_root
		w.echo_damage = maxi(1, dmg * m.echo_damage_permille / 1000)


## Phase 4: counts down the pending Twin Arc echo and swings it (same arc, re-tested from where the player is).
static func advance_echo(w: World) -> void:
	if w.echo_t <= 0:
		return
	w.echo_t -= 1
	if w.echo_t > 0:
		return
	w.echo_tick = w.tick
	PlayerKit.swing_arc(w, w.echo_angle, w.echo_damage, w.echo_root, EFFECT_TWIN_ARC)


## A melee hit landed on actor `i`: Ember Edge adds a burn stack, once per root chain per target.
static func on_melee_hit(w: World, i: int, root: int) -> void:
	var m := w.item_mods
	var a := w.actors
	if m.burn_max_stacks <= 0 or a.dead[i] == 1 or a.burn_root[i] == root:
		return
	a.burn_root[i] = root
	if a.burn_stacks[i] == 0:
		a.burn_cd[i] = m.burn_period_ticks
	a.burn_stacks[i] = mini(a.burn_stacks[i] + 1, m.burn_max_stacks)
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
	if dmg <= 0 or not w.is_dashing() or w.player_dead():
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
		if Kin.length(p.pos(i) - at) > PICKUP_RADIUS_M:
			i += 1
			continue
		var idx := p.item[i]
		var e := w.emit_event(
			SimEvent.Kind.PICKUP, p.ids[i], w.actors.ids[0], w.actors.ids[0], p.pos(i)
		)
		e.amount = idx
		w.add_item(idx)
		p.remove_at(i)
