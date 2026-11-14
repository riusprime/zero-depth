class_name ProjectileContacts
extends RefCounted
## What projectile `i` does with its sweep's result this tick (World._projectile_hits, tick phase 6): a body it met
## takes the hit (a bomb bursts instead), with the bolt's procs and the card hooks, and a piercing or returning one
## goes on through; a wall it met bounces it (Ricochet Core, the Siege Engine's shells) or ends it; with no contact it
## flies on and ends at the end of its range. The GDScript sweep and the native one (NativeShots) both hand their
## contacts here, so the rules of a hit live in one place.


## Projectile `i` swept from `a` by `v`: the earliest contact at `best_t` (above 1: none) with body `best_actor` or
## wall `best_wall` (-1: not that one). True when the projectile ended (the caller removes it).
static func apply(
	w: World, i: int, a: Vector2, v: Vector2, best_t: float, best_actor: int, best_wall: int
) -> bool:
	var projectiles := w.projectiles
	var actors := w.actors
	var pp := w.phase_probe
	if best_t <= 1.0:
		if best_actor >= 0 and not Bomb.touches(w, i):  # A bomb's touch bursts it, no hit
			if pp != null:
				pp.begin(&"proj.damage")
			w.hit_spec = Attacks.projectile_spec(w, i)  # The bolt's own spec feeds
			w.hit_proc_permille = SecondaryProc.of_projectile(w, i)  # A secondary's
			if projectiles.owner[i] == actors.ids[0]:
				Matchups.arm(w, best_actor, w.hit_spec)  # The bolt's form and elements
			var got := Damage.hit(
				w,
				best_actor,
				projectiles.damage[i],
				projectiles.ids[i],
				projectiles.owner[i],
				projectiles.root_id[i],
				projectiles.tags[i],
				a,
				a + v * best_t,
				Attacks.projectile_effect(w.hit_spec, projectiles.tags[i]),  # A hook's names it
				Attacks.projectile_proc(w.hit_spec)  # A hook's (a trigger's child) 50, then 25
			)
			var crit_now := w.last_hit_crit  # This bolt's own hit (read before any proc hits again)
			w.hit_spec = null
			w.hit_proc_permille = 1000
			if pp != null:
				pp.end(&"proj.damage")
				pp.begin(&"proj.procs")
			if best_actor == 0 and w.player_dead() and w.killer_attack < 0:
				w.killer_attack = projectiles.cause_of(i)  # The recap names the shot's attack
			# Items: Frost Core and Static Chain react to the player's landed bolts.
			ItemProcs.on_bolt_hit(w, best_actor, i, got, a + v * best_t)
			BladeForms.hit_push_bolt(w, best_actor, i, got, a, crit_now)
			if pp != null:
				pp.end(&"proj.procs")
			LanceMods.on_hit(w, i, best_actor)  # Split spits its shards
			GlaiveMods.on_hit(w, i, best_actor)  # Split sheds its small discs
			SeekerMods.on_hit(w, i, best_actor)  # Pierce notes it, Ring, Split
			WispMods.on_hit(w, i, best_actor, a + v * best_t)  # A wisp's shot rings
			if Heat.pierce(w, i, best_actor, a):  # Heat: a Hot bolt goes on through one enemy.
				return false
			if ProjectileMoves.pierce(w, i, best_actor, a):  # Edge Rounds, Boomerang
				return false
		elif (
			best_wall >= 0
			and projectiles.bounces[i] > 0
			and BossRicochet.may_bounce(w, i, a + v * best_t, w.walls[best_wall])
		):
			# Items: Ricochet Core reflects the bolt off the wall instead of ending it. so do the
			# Siege Engine's shells, unless the way back would reach the player within 0.5 s.
			ItemEffects.bounce(w, i, a + v * best_t, w.walls[best_wall])
			BossRicochet.on_bounce(w, i)
			projectiles.life[i] -= 1
			if projectiles.life[i] <= 0:
				Attacks.on_projectile_end(w, i, a + v * best_t)
				return true
			return false
		if pp != null:
			pp.begin(&"proj.end")
		Attacks.on_projectile_end(w, i, a + v * best_t)  # ON_END, Flame Trail
		if not projectiles.cause.is_empty():  # A javelin sticks where it stopped
			BossSignatures.on_shot_end(w, i, a + v * best_t, best_actor >= 0)
		if pp != null:
			pp.end(&"proj.end")
		return true
	var b := a + v
	projectiles.pos_x[i] = b.x
	projectiles.pos_y[i] = b.y
	projectiles.life[i] -= 1
	if projectiles.life[i] <= 0:
		range_end(w, i, b)
		return true
	return false


## Projectile `i` flew to `b` and its life ran out there: its end hooks.
static func range_end(w: World, i: int, b: Vector2) -> void:
	var pp := w.phase_probe
	if pp != null:
		pp.begin(&"proj.end")
	Attacks.on_projectile_end(w, i, b)
	if not w.projectiles.cause.is_empty():  # At the end of its range
		BossSignatures.on_shot_end(w, i, b, false)
	if pp != null:
		pp.end(&"proj.end")
