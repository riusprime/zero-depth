class_name Bomb
extends RefCounted
## v0.9.0 BM (owner C §6.3: "The player launches bombs toward the aiming direction. Initial proposed cadence:
## approximately one bomb per second. Bombs explode on impact or according to a consistent, short detonation rule.
## Explosions damage enemies within a defined area. Elemental effects apply to the explosion where appropriate"; Q9
## "Straight, no Spread"; PLAN C51–C53; ATTACK_FORMS.md F3): the Bomb form, the Gun's shot as a thrown bomb
## (AttackSpec.blast_mm, set by the Bomb card, data/modifiers/gun_bomb.tres).
## - The throw: the Gun's bolt, straight along the aim, once a second (period 60 ticks; attack speed at half its bonus,
##   AttackRate.form_rate), 12 m/s for 8 m (its life), so a bomb ends on the first enemy it touches, on a wall, or 8 m
##   out. Its touch deals nothing (World's projectile pass skips the hit: touches()); where it ends it bursts (blast(),
##   from Attacks.on_projectile_end).
## - The blast: every enemy within blast_mm (2.2 m; the area stat scales it) takes the bomb's damage (4.5 × an orb hit:
##   the card multiplies the shot's damage) as one hit each, under the bomb's spec: its elements' statuses feed per
##   enemy (Engines.on_hit, as a projectile's hit), its On Hit and On Kill hooks run per enemy. Twin's bombs are its
##   lanes (2 at Lv 1–4, 3 at Lv 5), each at Twin's damage share, the extra ones at the secondary proc.
## - Overlap: blasts in one tick past WandTable.blast_merge_after (8) merge into one within their radius already set off
##   this tick (Attacks.merged_at, the existing budget). One BLAST event a blast (the views and the sound read it).
## - No other explosion (Q11): the bomb's blast is the only one.
## Pure: no randomness, no engine calls.


## `s` is a bomb (the Bomb form's shot).
static func is_bomb(s: AttackSpec) -> bool:
	return s != null and s.blast_mm > 0


## Player projectile `pi` is a bomb (its own spec is one).
static func touches(w: World, pi: int) -> bool:
	if w.projectiles.team[pi] != ActorStore.TEAM_PLAYER:
		return false
	var key := w.projectiles.spec_key[pi] if pi < w.projectiles.spec_key.size() else ""
	return key != "" and is_bomb(Attacks.projectile_spec(w, pi))


## The run's Gun shot is the Bomb now.
static func active(w: World) -> bool:
	return PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w) and is_bomb(Modifiers.bolt(w))


## The blast radius of `s` now (m): blast_mm, the area stat on it.
static func radius_m(w: World, s: AttackSpec) -> float:
	return Stats.area(w, s.blast_mm / 1000.0)


## Bomb projectile `pi` of `spec` ended at `at`: it bursts (the class doc). Returns the enemies its blast landed on
## (-1: merged into a blast already set off this tick).
static func blast(w: World, spec: AttackSpec, pi: int, at: Vector2) -> int:
	var r := radius_m(w, spec)
	if Attacks.merged_at(w, at, r):
		return -1
	var p := w.projectiles
	var pid := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.BLAST, pid, pid, pid, at)
	e.root_id = p.root_id[pi]
	e.amount = int(round(r * 1000.0))
	e.effect_id = StringName(spec.key)
	var tags := SimEvent.TAG_AREA | SimEvent.TAG_PROJECTILE
	var ctx := AttackContext.make(at, 0, p.damage[pi], p.root_id[pi], tags, &"")
	ctx.depth = spec.depth
	ctx.proc_pct = maxi(1, 100 >> spec.depth)
	ctx.secondary = (p.second_of(pi) & ProjectileStore.SECONDARY) != 0
	var landed := 0
	for i in w.enemies_near(at, r):
		if Attacks.land(w, spec, ctx, i, at, w.actors.pos(i)) > 0:
			landed += 1
	return landed
