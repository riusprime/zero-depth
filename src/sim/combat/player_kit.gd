class_name PlayerKit
extends RefCounted
## The player's attacks and utility (PLAN v0.1.0 Steps 2, 3, 7b). Melee and shooting have separate buttons
## (owner, 2026-10-07): PRIMARY = a swing, the next step of the combo (v0.3.0 L11: four distinct slashes, each its
## own SwingStep); SHOOT held = a bolt every shot_period_ticks.
## Blink teleports the way you're moving, through a wall when the far side is within range. Runs in tick phase 4;
## numbers from PlayerTable.

const PRIMARY_SLOT := 0
const UTILITY_SLOT := 1
const BLINK_STEP_M := 0.1


## Guard is a held state (World.guarding); Blink spends a buffered press when it's ready.
static func advance_utility(w: World) -> void:
	if w.blink_cd > 0:
		w.blink_cd -= 1
	var t := w.player
	if t.utility != PlayerTable.Utility.BLINK:
		w.input_buffer[UTILITY_SLOT] = 0
		return
	if w.input_buffer[UTILITY_SLOT] == 0 or w.blink_cd > 0 or w.is_dashing():
		return
	w.input_buffer[UTILITY_SLOT] = 0
	w.blink_from = w.player_pos()
	w.actors.set_pos(0, blink_target(w))
	w.blink_cd = t.blink_cooldown_ticks
	w.blink_tick = w.tick
	w.actors.invuln[0] = maxi(w.actors.invuln[0], t.blink_iframe_ticks)
	ItemProcs.on_blink(w)  # Items: Phase Strike.


## The way a blink (or a dash) goes: the move direction, or the aim when standing still.
static func move_or_aim(w: World) -> Vector2:
	var mv := Vector2(w.move_intent.x, w.move_intent.y)
	return Kin.dir(Kin.angle_of(mv)) if mv != Vector2.ZERO else Kin.dir(w.aim_angle)


## Where a blink lands (owner, 2026-10-07: "a teleport, allowing you to go through walls"; v0.3.0 L1: "By thickness
## vs range"). It goes up to blink_range_m along move_or_aim, and it passes through a wall only when a free spot
## beyond the wall lies within that range; otherwise it ends at the last free spot before the wall. A spot is free
## when the player's circle touches no wall (the sealed gate's footprint included) and it lies in the NavField
## region the player walks in, so a blink never ends inside a wall, in the void outside the floor, or in a pocket
## you can't walk to; it may end in another room, but never across the boss room's boundary except through its
## open door (v0.3.0 B, World.blink_may_land). So thin cover is crossed at almost any distance and a thick wall
## only from close up. Samples every BLINK_STEP_M from the far end back: the farthest free one wins (none: stay).
static func blink_target(w: World) -> Vector2:
	var t := w.player
	var from := w.player_pos()
	var dir := move_or_aim(w)
	var home := w.nav.region_near(from)
	var steps := int(round(t.blink_range_m / BLINK_STEP_M))
	for k in range(steps, 0, -1):
		var at := from + dir * (BLINK_STEP_M * k)
		if (
			_clear(w, at, t.radius_m)
			and w.nav.region_near(at) == home
			and w.blink_may_land(from, at)
		):
			return at
	return from


static func _clear(w: World, at: Vector2, r: float) -> bool:
	for wall in w.walls:
		if Collide.circle_vs_obb(at, r, wall) != Vector2.ZERO:
			return false
	return true


static func advance(w: World) -> void:
	var t := w.player
	var can_attack := not w.guarding() and not w.is_dashing()
	ItemEffects.advance_echo(w)
	# Swing in progress: hit on its step's active tick, then end and open the combo window (none after the last
	# step: the combo starts over).
	if w.swing_t > 0:
		var cur := current_step(w)
		if w.swing_t == cur.active_tick:
			_resolve_swing(w)
		w.swing_t += 1
		if w.swing_t > cur.ticks:
			w.swing_t = 0
			w.combo_window = t.combo_window_ticks if w.combo_step < t.combo.size() - 1 else 0
	elif w.combo_window > 0:
		w.combo_window -= 1
	# A buffered press starts the next swing as soon as the current one ends.
	if w.swing_t == 0 and can_attack and w.input_buffer[PRIMARY_SLOT] > 0:
		w.input_buffer[PRIMARY_SLOT] = 0
		w.combo_step = next_step(w)
		w.combo_window = 0
		w.swing_t = 1
		w.swing_angle = w.aim_angle
		w.swing_root = w.take_root()
		ItemEffects.on_swing_start(w)
		ItemProcs.on_swing_start(w)  # Items: Momentum.
	# Shooting: while held (and not swinging), a bolt every shot_period_ticks; the first one comes at once.
	if w.shot_cd > 0:
		w.shot_cd -= 1
	if shooting(w) and can_attack and w.swing_t == 0 and w.shot_cd == 0:
		_fire_bolt(w)
		w.shot_cd = ItemEffects.shot_period_ticks(w)
	ItemProcs.advance_momentum(w)


static func shooting(w: World) -> bool:
	return (w.held_buttons & InputFrame.SHOOT) != 0 and not w.player_dead()


## The step the current (or last) swing is: w.combo_step.
static func current_step(w: World) -> SwingStep:
	return w.player.combo[w.combo_step]


## The step a press would start now: the next one while a swing runs or the combo window is open, else the first.
static func next_step(w: World) -> int:
	if w.swing_t > 0 or w.combo_window > 0:
		return (w.combo_step + 1) % w.player.combo.size()
	return 0


## The combo's last step (the finisher).
static func is_finisher(w: World, step: int) -> bool:
	return step == w.player.combo.size() - 1


static func swing_hits(w: World, i: int) -> bool:
	return arc_hits(w, i, w.swing_angle)


## True if the arc of combo step `step` (-1 = the current one) at `angle` touches actor i. The reach includes Long
## Edge (ItemEffects.swing_reach_m), the same numbers WorldReader.swing_shape draws (EI-07).
static func arc_hits(w: World, i: int, angle: int, step: int = -1) -> bool:
	var t := w.player
	var s := step if step >= 0 else w.combo_step
	return AttackShapes.arc_touches(
		w.player_pos(),
		t.radius_m,
		angle,
		t.combo[s].half_arc,
		ItemEffects.swing_reach_m(w, s),
		w.actors.pos(i),
		w.actors.radius[i]
	)


## The lunge for this tick (phase 5): the current step's lunge_m spread over the ticks before its hit, along the
## swing angle. Zero when no swing is running or the step doesn't lunge.
static func lunge_offset(w: World) -> Vector2:
	if w.swing_t <= 0:
		return Vector2.ZERO
	var s := current_step(w)
	if s.lunge_m <= 0.0 or w.swing_t > s.lunge_ticks():
		return Vector2.ZERO
	return Kin.dir(w.swing_angle) * (s.lunge_m / s.lunge_ticks())


static func _resolve_swing(w: World) -> void:
	var s := current_step(w)
	var base := s.damage
	var dmg := ItemProcs.momentum_damage(w, ItemEffects.swing_damage(w, base))
	if swing_arc(w, w.swing_angle, dmg, w.swing_root, &""):
		w.add_freeze(s.hitstop_ticks)
	ItemEffects.after_swing(w, base, dmg)


## Hits every enemy in the arc of combo step `step` (-1 = the current one) at `angle` for `dmg` (melee; Ember Edge
## burns on a landed hit). Used by the swing and by the Twin Arc echo (with its own step). Returns true if any hit
## landed.
static func swing_arc(
	w: World, angle: int, dmg: int, root: int, effect_id: StringName, step: int = -1
) -> bool:
	var a := w.actors
	var landed := false
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
			continue
		if not arc_hits(w, i, angle, step):
			continue
		var got := Damage.hit(
			w,
			i,
			dmg,
			a.ids[0],
			a.ids[0],
			root,
			SimEvent.TAG_MELEE,
			w.player_pos(),
			a.pos(i),
			effect_id
		)
		if got > 0:
			landed = true
			ItemEffects.on_melee_hit(w, i, root)
	return landed


## One shot: a bolt along the aim, or a Splinter fan (ItemEffects.shot_offsets); Ricochet Core adds bounces.
static func _fire_bolt(w: World) -> void:
	var t := w.player
	var dmg := ItemEffects.bolt_damage(w)
	for off in ItemEffects.shot_offsets(w):
		var dir := Kin.dir(w.aim_angle + off)
		var muzzle := w.player_pos() + dir * (t.radius_m + t.bolt_radius_m + 0.05)
		w.queue_projectile(
			w.actors.ids[0],
			ActorStore.TEAM_PLAYER,
			muzzle,
			dir * t.bolt_speed,
			dmg,
			t.bolt_radius_m,
			t.bolt_life_ticks,
			SimEvent.TAG_PROJECTILE,
			w.item_mods.bounces
		)
