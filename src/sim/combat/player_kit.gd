class_name PlayerKit
extends RefCounted
## The player's attacks and utility (PLAN v0.1.0 Steps 2, 3, 7b). Melee and shooting have separate buttons
## (owner, 2026-10-07): PRIMARY = a swing (a 3-hit combo); SHOOT held = a bolt every shot_period_ticks.
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
## you can't walk to; it may end in another room. So thin cover is crossed at almost any distance and a thick wall
## only from close up. Samples every BLINK_STEP_M from the far end back: the farthest free one wins (none: stay).
static func blink_target(w: World) -> Vector2:
	var t := w.player
	var from := w.player_pos()
	var dir := move_or_aim(w)
	var home := w.nav.region_near(from)
	var steps := int(round(t.blink_range_m / BLINK_STEP_M))
	for k in range(steps, 0, -1):
		var at := from + dir * (BLINK_STEP_M * k)
		if _clear(w, at, t.radius_m) and w.nav.region_near(at) == home:
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
	# Swing in progress: hit on its active tick, then end and open the combo window.
	if w.swing_t > 0:
		if w.swing_t == t.swing_active_tick:
			_resolve_swing(w)
		w.swing_t += 1
		if w.swing_t > t.swing_ticks:
			w.swing_t = 0
			w.combo_window = t.combo_window_ticks
	elif w.combo_window > 0:
		w.combo_window -= 1
	# A buffered press starts the next swing as soon as the current one ends.
	if w.swing_t == 0 and can_attack and w.input_buffer[PRIMARY_SLOT] > 0:
		w.input_buffer[PRIMARY_SLOT] = 0
		w.combo_step = (w.combo_step + 1) % t.swing_damage.size() if w.combo_window > 0 else 0
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


static func swing_hits(w: World, i: int) -> bool:
	return arc_hits(w, i, w.swing_angle)


## True if a swing arc at `angle` touches actor i. The reach includes Long Edge (ItemEffects.swing_reach_m), the
## same number WorldReader.swing_shape draws.
static func arc_hits(w: World, i: int, angle: int) -> bool:
	var t := w.player
	return AttackShapes.arc_touches(
		w.player_pos(),
		t.radius_m,
		angle,
		t.swing_half_arc,
		ItemEffects.swing_reach_m(w),
		w.actors.pos(i),
		w.actors.radius[i]
	)


static func _resolve_swing(w: World) -> void:
	var base: int = w.player.swing_damage[w.combo_step]
	var dmg := ItemProcs.momentum_damage(w, ItemEffects.swing_damage(w, base))
	if swing_arc(w, w.swing_angle, dmg, w.swing_root, &""):
		w.add_freeze(w.player.swing_hitstop_ticks)
	ItemEffects.after_swing(w, base, dmg)


## Hits every enemy in the swing arc at `angle` for `dmg` (melee; Ember Edge burns on a landed hit). Used by the
## swing and by the Twin Arc echo. Returns true if any hit landed.
static func swing_arc(w: World, angle: int, dmg: int, root: int, effect_id: StringName) -> bool:
	var a := w.actors
	var landed := false
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1 or not arc_hits(w, i, angle):
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
