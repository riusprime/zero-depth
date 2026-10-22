class_name BlackHoles
extends RefCounted
## v0.8.0 P2 (owner O24: "Change Void so shots have a chance to spawn a small black hole lasting 2 seconds,
## attracting nearby enemies and dealing damage"; replaces v0.6.0 MX4's pull on every hit, ModifierRuntime.pull).
## A spec with AttackSpec.hole_permille (the Void card's, rising with its level) leaves a black hole with that chance:
## - where a projectile of it ends (the hit that stopped it, a wall, the end of its flight; Attacks.on_projectile_end),
##   and where a slash of it first lands (Attacks._arc); one draw on the `ability` stream per shot or landing slash,
##   only for a spec that has a chance (a build without Void draws nothing);
## - it stands WandTable.hole_ticks (2 s), at most WandTable.hole_max (3) at once: a new one past the cap replaces the
##   oldest;
## - each tick it draws every enemy within hole_pull_radius_m toward its centre by hole_pull_step_m (never past it; not
##   a boss, nor an enemy still spawning in; walls push them out again in the collision pass, so a small step never
##   carries one through a wall);
## - every hole_period_ticks it pulses: each enemy within hole_radius_m takes hole_damage_permille of the shot's damage
##   (at least 1) as a damage-over-time tick (Damage.tick_dot: TAG_DOT, proc 0, so it never sets off a hit's cards;
##   EI-06), effect EFFECT.
## State in World.mx (ModifierState.hole_*), copied by WorldSnapshot and hashed while a hole stands. Pure (EI-02): the
## one draw is a named stream's (EI-05), the clock is World.tick (EI-03).

const EFFECT := &"void_hole"
## A pull stops this far (m) from the centre, so the enemies it gathers aren't stacked on one point.
const CORE_GAP_M := 0.3
## The wand's numbers in a lab world without World.wand_table: WandTable's defaults (they mirror data/wand/wand.tres).
static var _defaults := WandTable.new()


## Shot `spec` (damage `dmg`) ended or landed at `at`: with its chance, a black hole opens there.
static func roll(w: World, spec: AttackSpec, at: Vector2, dmg: int) -> void:
	if spec == null or spec.hole_permille <= 0 or w.player_dead():
		return
	if not w.rng_ability.chance_permille(spec.hole_permille):
		return
	var pulse := maxi(1, (dmg * spec.hole_damage_permille + 500) / 1000)
	open(w, at, pulse)


## Opens a black hole at `at` whose pulses deal `pulse` (the oldest goes past the cap).
static func open(w: World, at: Vector2, pulse: int) -> void:
	var s := w.mx
	var t := table(w)
	while s.hole_pos.size() >= maxi(1, t.hole_max):
		_remove(s, 0)
	s.hole_pos.append(at)
	s.hole_from.append(w.tick)
	s.hole_dmg.append(pulse)


## The wand's numbers (World.wand_table, or the defaults in a lab world).
static func table(w: World) -> WandTable:
	return w.wand_table if w.wand_table != null else _defaults


## Tick phase 6 (ModifierRuntime.advance): holes past their life close, then each (oldest first) pulls and pulses.
static func advance(w: World) -> void:
	var s := w.mx
	if s.hole_pos.is_empty():
		return
	var t := table(w)
	for k in range(s.hole_pos.size() - 1, -1, -1):
		if w.tick - s.hole_from[k] >= t.hole_ticks:
			_remove(s, k)
	if w.player_dead():
		return
	var a := w.actors
	var pid := a.ids[0]
	for k in s.hole_pos.size():
		var at := s.hole_pos[k]
		for i in w.enemies_near(at, t.hole_pull_radius_m):
			if a.invuln[i] > 0 or BossAi.is_boss_kind(a.kinds[i]):
				continue
			var to := at - a.pos(i)
			var dist := Kin.length(to)
			var step := minf(t.hole_pull_step_m, maxf(0.0, dist - CORE_GAP_M))
			if dist > 0.0 and step > 0.0:
				a.set_pos(i, a.pos(i) + to * (step / dist))
		var age := w.tick - s.hole_from[k]
		if age <= 0 or age % maxi(1, t.hole_period_ticks) != 0:
			continue
		for i in w.enemies_near(at, t.hole_radius_m):
			if a.dead[i] == 0:
				Damage.tick_dot(w, i, s.hole_dmg[k], pid, pid, EFFECT)


static func _remove(s: ModifierState, k: int) -> void:
	s.hole_pos.remove_at(k)
	s.hole_from.remove_at(k)
	s.hole_dmg.remove_at(k)


## The holes for the views (WorldReader.black_holes): [{pos, age (ticks), life (ticks), radius, pull_radius}], oldest
## first.
static func read(w: World) -> Array:
	var s := w.mx
	var out := []
	if s.hole_pos.is_empty():
		return out
	var t := table(w)
	for k in s.hole_pos.size():
		(
			out
			. append(
				{
					"pos": s.hole_pos[k],
					"from": s.hole_from[k],
					"age": w.tick - s.hole_from[k],
					"life": t.hole_ticks,
					"radius": t.hole_radius_m,
					"pull_radius": t.hole_pull_radius_m,
				}
			)
		)
	return out
