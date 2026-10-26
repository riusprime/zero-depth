class_name PlayerKit
extends RefCounted
## The player's attacks and utility (PLAN v0.1.0 Steps 2, 3, 7b). Melee and shooting have separate buttons
## (owner, 2026-10-07): PRIMARY = a swing, the next step of the combo (v0.3.0 L11: four distinct slashes, each its
## own SwingStep), along the character's facing (L29); SHOOT held = a bolt every shot_period_ticks along the aim.
## A run's build enables one of the two (PlayerBuild, L15).
## Blink teleports the way you're moving, through a wall when the far side is within range. Runs in tick phase 4;
## numbers from PlayerTable.
## v0.6.0 MX1: this is the weapons' driver (the combo's timing, the shot period); the swing and the shot themselves
## launch from the build's compiled specs (Modifiers, Attacks.launch).

const PRIMARY_SLOT := 0
const UTILITY_SLOT := 1
const BLINK_STEP_M := 0.1


## Guard is a held state (World.guarding); Blink spends a buffered press when it's ready.
## v0.4.0 BS: the utility is the forced loadout's or an owned Blink / Aegis ability (Abilities.utility); the
## ability's blink has its own range, cooldown, charges and a landing shock (Abilities).
static func advance_utility(w: World) -> void:
	Abilities.recharge_blink(w)
	if Abilities.utility(w) != PlayerTable.Utility.BLINK:
		w.input_buffer[UTILITY_SLOT] = 0
		return
	if (
		w.input_buffer[UTILITY_SLOT] == 0
		or not Abilities.blink_ready(w)
		or w.is_dashing()
		or PlayerSkill.busy(w)
		or Curses.stunned(w)
	):  # v0.6.0 CU: Brittle
		return
	w.input_buffer[UTILITY_SLOT] = 0
	w.blink_from = w.player_pos()
	w.actors.set_pos(0, blink_target(w))
	w.blink_tick = w.tick
	w.actors.invuln[0] = maxi(w.actors.invuln[0], Abilities.blink_iframes(w))
	Abilities.on_blink(w)  # v0.4.0 BS: the cooldown or a charge, and the landing shock.
	ItemProcs.on_blink(w)  # Items: Phase Strike.
	Curses.on_ability_use(w)  # v0.6.0 CU: Blood Price


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
	var steps := int(round(Abilities.blink_range_m(w) / BLINK_STEP_M))
	for k in range(steps, 0, -1):
		var at := from + dir * (BLINK_STEP_M * k)
		if (
			EnemyAi.clear_of_walls(w, at, t.radius_m)
			and w.nav.region_near(at) == home
			and w.blink_may_land(from, at)
		):
			return at
	return from


static func advance(w: World) -> void:
	Heat.advance(w)  # Overclock heat: the decay and the overheat stall run first.
	var t := w.player
	var can_attack := armed(w)
	ItemEffects.advance_echo(w)
	# Swing in progress: hit on its step's active tick, then end and open the combo window (none after the last
	# step: the combo starts over).
	if w.swing_t > 0:
		var cur := current_step(w)
		if w.swing_t == cur.active_tick:
			_resolve_swing(w)
		w.swing_t += 1
		if w.swing_t > cur.ticks:  # v0.8.0 SG: attack speed scales the whole swing (BladeForms.step)
			w.swing_t = 0
			w.combo_window = t.combo_window_ticks if w.combo_step < t.combo.size() - 1 else 0
	elif w.combo_window > 0:
		w.combo_window -= 1
	# A buffered press starts the next swing as soon as the current one ends.
	if not PlayerBuild.has_blade(w):
		w.input_buffer[PRIMARY_SLOT] = 0  # Builds: a Gun run's melee press does nothing (L15).
	if w.swing_t == 0 and can_attack and w.input_buffer[PRIMARY_SLOT] > 0:
		w.input_buffer[PRIMARY_SLOT] = 0
		w.combo_step = next_step(w)
		w.combo_window = 0
		w.swing_t = 1
		w.swing_angle = PlayerBuild.melee_angle(w)  # Builds: along the facing, not the aim (L29).
		w.swing_root = w.take_root()
		ItemEffects.on_swing_start(w)
		ItemProcs.on_swing_start(w)  # Items: Momentum.
		Engines.on_swing_start(w)  # Engines: Bulwark's guard charges.
		FireRhythm.on_swing(w)  # v0.8.0 MR (O91): Flurry's burst
	# Shooting: while held (and not swinging), a bolt every shot_period_ticks; the first one comes at once.
	if shooting(w) and can_attack and w.swing_t == 0:
		Heat.fire_tick(w)  # v0.9.5 HT: the primary attack is active (every form): heat fills by firing time
	if w.shot_cd > 0:
		w.shot_cd -= 1
	if GunForms.charging(w):  # v0.6.5 WN3: G13 Charge, hold to grow the shot, release to fire
		GunForms.hold(w, can_attack, func(pm: int) -> void: _fire_bolt(w, pm))
	# v0.9.5 FC4 (V9): a Void with Mine holds one void at a time (VoidMods.held)
	elif shooting(w) and can_attack and w.swing_t == 0 and w.shot_cd == 0 and not VoidMods.held(w):
		_fire_bolt(w)
		w.shot_cd = ItemEffects.shot_period_ticks(w)
	ItemProcs.advance_momentum(w)


## The hero may attack now: not guarding or dashing, not in the overheat stall (Heat), not stunned (v0.6.0 CU:
## Brittle), no skill committing (Kit, v0.3.5 K). v0.9.0 LZ: public, the Laser's beam reads it (Laser.firing).
static func armed(w: World) -> bool:
	var ok := not w.guarding() and not w.is_dashing() and Heat.can_attack(w)
	ok = ok and not Curses.stunned(w)
	return ok and not PlayerSkill.busy(w)


## SHOOT is held, alive, and the build has the gun (a Blade run never shoots, L15).
static func shooting(w: World) -> bool:
	return (
		(w.held_buttons & InputFrame.SHOOT) != 0 and not w.player_dead() and PlayerBuild.has_gun(w)
	)


## The step the current (or last) swing is: w.combo_step.
## v0.6.5 WN4: as its spec swings it (BladeForms.step: Thrust, Whirl, Heavy, Flurry, Lunge Step).
static func current_step(w: World) -> SwingStep:
	return BladeForms.step(w, w.combo_step)


## The step a press would start now: the next one while a swing runs or the combo window is open, else the first.
static func next_step(w: World) -> int:
	if w.swing_t > 0 or w.combo_window > 0:
		return (w.combo_step + 1) % w.player.combo.size()
	return 0


## The combo's last step (the finisher).
static func is_finisher(w: World, step: int) -> bool:
	return step == w.player.combo.size() - 1


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
	var spec := Modifiers.step(w, w.combo_step)
	var base := PlayerBuild.melee_damage(w, spec.damage)  # Builds: the Blade's damage factor (L16).
	var dmg := ItemProcs.momentum_damage(w, ItemEffects.swing_damage(w, base))
	dmg = Engines.charged_damage(w, dmg)  # Engines: Bulwark.
	dmg = Gamble.melee_damage(w, dmg)  # Gamble shrine (v0.3.0 L19).
	dmg = Curses.swing_damage(w, dmg)  # v0.6.0 CU: Heavy Hands' 4th hit
	dmg = BladeForms.counter_damage(w, spec, dmg)  # v0.6.5 WN4: Counter
	var landed := swing_arc(w, w.swing_angle, dmg, w.swing_root, &"")
	if landed:
		w.add_freeze(spec.hitstop_ticks)
	ItemEffects.after_swing(w, base, dmg)
	Abilities.after_swing(w, landed)  # v0.4.0 BS: Combo Sword L5's finisher shockwave.
	Engines.after_swing(w, landed)  # Engines: Slipstream.
	var tip := w.player.radius_m + Attacks.arc_reach_m(w, spec)
	ModifierAbilities.on_attack(w, w.player_pos() + Kin.dir(w.swing_angle) * tip)  # v0.6.0 MX2


## Launches combo step `step`'s spec (-1 = the current one) at `angle` for `dmg` from where the player is (melee;
## a spec that burns adds its burn on a landed hit). Used by the swing and by the Twin Arc echo (with its own step).
## Returns true if any hit landed.
static func swing_arc(
	w: World, angle: int, dmg: int, root: int, effect_id: StringName, step: int = -1
) -> bool:
	var s := step if step >= 0 else w.combo_step
	var ctx := AttackContext.make(w.player_pos(), angle, dmg, root, SimEvent.TAG_MELEE, effect_id)
	ctx.step = s
	if effect_id == ItemEffects.EFFECT_TWIN_ARC:  # v0.8.0 MR (O91): an echo is a repeat, at the secondary proc
		ctx.repeat = true
		ctx.secondary = true
	return Attacks.launch(w, Modifiers.step(w, s), ctx)


## One shot: the bolt spec launched along the aim (a Splinter fan, Ricochet's bounces: its spec's pattern and
## behaviour).
## v0.6.5 WN3: `charge` (per mille) sizes a charged shot (G13 Charge: its damage and its bolts' radius). v0.9.0 AF1b:
## the Lance's ball is sized by Lance.size_permille instead, and its release pushes the hero back (Lance.on_release).
static func _fire_bolt(w: World, charge: int = 1000) -> void:
	var spec := Modifiers.bolt(w)
	var dmg := PlayerBuild.bolt_damage(w, Attacks.bolt_base_damage(spec))  # Builds: the Gun's factor (L16).
	dmg = Gamble.shot_damage(w, dmg)  # Gamble shrine (v0.3.0 L19).
	dmg = Curses.shot_damage(w, dmg)  # v0.6.0 CU: Heavy Hands' every 4th shot
	AbilityCombos.on_shot(w)  # v0.4.0 AB: Wingman
	FireRhythm.on_shot(w)  # v0.8.0 MR (O91): Rapid Fire's ramp
	var tags := SimEvent.TAG_PROJECTILE | Heat.bolt_tags(w) | Abilities.bolt_tags(w)  # Hot, Pulse Gun L3
	var ctx := AttackContext.make(w.player_pos(), w.aim_angle, dmg, 0, tags, &"")
	if charge != 1000:
		ctx.damage = maxi(1, dmg * charge / 1000)
		ctx.base_damage = ctx.damage
		ctx.size_permille = charge
	var lance := Lance.is_lance(spec)
	if lance:  # v0.9.0 AF1b: the Lance's ball grows x 1 to x 2 while its damage grows x 1 to x 11.6
		ctx.size_permille = Lance.size_permille(spec, charge) * LanceMods.wide(w, spec) / 1000  # v0.9.5 FC4: Big Shot
		ctx.lance_full = LanceMods.is_full(spec, charge)
	Attacks.launch(w, spec, ctx)
	if lance:
		Lance.on_release(w, spec, charge, spec.radius_m * ctx.size_permille / 1000.0)
	ModifierAbilities.on_attack(w, ModifierAbilities.shot_end(w, ModifierAbilities.field_range(w)))
