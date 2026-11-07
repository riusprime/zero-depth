class_name Laser
extends RefCounted
## v0.9.0 LZ (owner C §6.2, Q8; PLAN C48–C50, C72; ATTACK_FORMS.md F2): the Laser form, the Gun's shot with
## AttackSpec.beam_hold, set by the Laser card (data/modifiers/gun_laser.tres).
## v0.11.0 O1 (owner, PLAN L1, L3b, L2; OWNER_QUESTIONS Q4–Q8, Q28: "a charged-feeling, lance-style attack … a 3 second
## cooldown … the same damage it'd do in 3 seconds of continuous beam"): the beam is now a lance.
## - Hold to fire: PlayerKit fires the Gun's shot every period_ticks while SHOOT is held (the first at once; no release
##   needed): period_seconds 3.0 (gun_laser.tres). Attack speed shortens the 3 s at half its bonus (Q4;
##   AttackRate.form_rate, rate_scale_permille 500).
## - Instant (Q7): the lance hits its whole path on the firing tick, from the hero's edge along the aim, reach_m long
##   (9 m), radius_m wide. It passes every enemy on its path (Q28: "Pierce everything, no card": spec.pierce is not
##   read); a wall stops it. trace() is the one geometry: the shot's hits and the record the view draws (EI-07;
##   LaserMods.record, WorldReader.beams).
## - Damage (Q4): one shot deals lance_ticks (30: 3 s of the old beam's 10 ticks a second) of the old beam's ticks, each
##   beam_permille of the shot's damage, times the Pattern's share per lance (Twin: 2 side by side at Lv 1–4, 3 fanned
##   at Lv 5, GunForms' lanes). An enemy takes a shot once per lance kind; crit rolls once per enemy hit.
## - Statuses (Q5: "3 hits worth"): each enemy hit is fed lance_feed (3) hits' worth of the lance's statuses
##   (AttackContext.feed_x, SecondaryProc.of_ctx); its hit hooks (Lightning's jump, a trigger's cast) fire once per
##   enemy hit. A kill runs its On Kill hooks.
## - Caps: a lance is no projectile. It never counts in the projectile caps (ShotCap) and launches none; what its hits
##   cast (a trigger's bolt) counts there as any other cast.
## - Falloff (v0.11.0 O1c, owner 2026-11-07): each enemy after the first on a path takes pierce_falloff_permille
##   (850: 15 % less) of the one before, never below pierce_floor_permille (400) of the first (falloff_next()).
##   Order is the path's (a path's `hits` run nearest first, legs in order; Ring, an area, is flat); each kind and lane
##   (Twin, Split, Backfire, Halo, Echo's strike) starts again at 1000.
##   Statuses are not scaled: every enemy is still fed lance_feed hits' worth.
## - The lance does not slow the hero (v0.11.0 O1c: move_permille is no longer set; move_factor() is 1).
## Pure: integer maths and Collide's sweeps, no randomness, one clock.

## Twin's lances sit GunForms.TWIN_GAP_RADII of this apart (about 0.5 m).
const LANE_RADIUS_M := 0.2
## "Every enemy on its path" (Q28): more than any room holds.
const ALL := 1 << 20
## A hit of Echo's strike (or a mine's) hits as this spec: no statuses, no hooks (made once, never written).
static var _bare: AttackSpec = null


static func _bare_spec() -> AttackSpec:
	if _bare == null:
		_bare = AttackSpec.new()
		_bare.id = &"laser_bare"
		_bare.form = AttackSpec.Form.BEAM
	return _bare


## `s` is the Laser form's shot.
static func held(s: AttackSpec) -> bool:
	return s != null and s.form == AttackSpec.Form.BEAM and s.beam_hold > 0


## The run's Gun shot is the Laser now.
static func active(w: World) -> bool:
	return PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w) and held(Modifiers.bolt(w))


## The Laser is held to fire now: SHOOT held, while the hero may attack (PlayerKit.armed) and isn't swinging.
static func firing(w: World) -> bool:
	return active(w) and PlayerKit.shooting(w) and PlayerKit.armed(w) and w.swing_t == 0


## The hero's move speed factor now: the Laser's move_permille while it is held to fire, else 1. The lance sets none
## (v0.11.0 O1c, owner: full speed while held), so this is 1; the hook stays for a spec that does.
static func move_factor(w: World) -> float:
	if not firing(w):
		return 1.0
	var pm := Modifiers.bolt(w).move_permille
	return pm / 1000.0 if pm > 0 else 1.0


## The `n`-th of a run of ticks at `pm` per mille is a feeding one (exact on average: pm of every 1000). The Void's
## aura reads it (VoidShots); the lance feeds on every shot.
static func feeds(n: int, pm: int) -> bool:
	return n * pm / 1000 != (n - 1) * pm / 1000


## The thousandths of damage one of the old beam's ticks dealt: the shot's `damage` × beam_permille × the lance's share.
static func milli_of(spec: AttackSpec, damage: int) -> int:
	var share := spec.share_permille if spec.share_permille > 0 else 1000
	return damage * maxi(0, spec.beam_permille) * share / 1000


## The whole damage of one lance whose old beam tick dealt `milli` thousandths: lance_ticks of them (at least 1).
static func shot_damage(w: World, milli: int) -> int:
	if milli <= 0:
		return 0
	return maxi(1, milli * LaserMods.param(w, "lance_ticks") / 1000)


## The share (per mille of the first hit) of the enemy after one that took `f`: pierce_falloff_permille of it, never
## below pierce_floor_permille (v0.11.0 O1c).
static func falloff_next(w: World, f: int) -> int:
	return maxi(
		LaserMods.param(w, "pierce_floor_permille"),
		f * LaserMods.param(w, "pierce_falloff_permille") / 1000
	)


## The lances of `spec` from `origin` along `angle` now (pure read): one per lane, {from, to, hits (actor indices,
## nearest first), at (each hit's point), wall (it ended on a wall)}. The shot hits these; LaserMods.record keeps them
## for the view (WorldReader.beams).
static func trace(w: World, spec: AttackSpec, origin: Vector2, angle: int) -> Array[Dictionary]:
	if LaserMods.mask(spec) != 0:  # v0.9.5 FC1: the cards that bend, fork and reflect the lance
		return LaserMods.plan(w, spec, origin, angle)
	var out: Array[Dictionary] = []
	var lanes := GunForms.lanes(spec, LANE_RADIUS_M)
	var turns := GunForms.lane_turns(spec)
	for li in lanes.size():
		var dir := Kin.dir((angle + turns[li]) & 4095)
		var from := origin + dir * w.player.radius_m + Vector2(-dir.y, dir.x) * lanes[li]
		var b := LaserMods.ray(w, from, dir, spec.reach_m, spec.radius_m, ALL, {})
		b["kind"] = LaserMods.K_MAIN
		b["lane"] = li
		b["share"] = 1000
		b["wmul"] = 1000
		b["end"] = true
		b["impact"] = bool(b["wall"])  # v0.11.0 O1: it passes its enemies; it ends on a wall or at its reach
		out.append(b)
	return out


## One hit of a lance (or Echo's strike, a mine's) on actor `i`: with `feed` the lance's statuses and hooks as the
## spec's, else a bare hit (a kill still runs its On Kill hooks). True if it landed.
static func hit(
	w: World, spec: AttackSpec, c: AttackContext, i: int, from: Vector2, at: Vector2, feed: bool
) -> bool:
	if feed:
		return Attacks.land(w, spec, c, i, from, at) > 0
	var before := w.strike_spec  # v0.10.5 O10: a bare hit is still the Laser's form (Matchups)
	w.strike_spec = spec
	var got := Attacks.land(w, _bare_spec(), c, i, from, at)
	w.strike_spec = before
	if got > 0 and w.actors.dead[i] == 1:
		Attacks.fire(w, spec, AttackSpec.Trigger.ON_KILL, c, at)
	return got > 0


## One lance of `spec` launched with `ctx` (Attacks._shared_form): every lane hits everything on its path (the class
## doc's damage and status rules). v0.9.5 FC1: a card-carrying lance is several paths (LaserMods.plan), each dealing its
## share of the shot, each kind hitting an enemy at most once; Big Shot's and Rapid Fire's damage, Echo's store.
## Returns true if a hit landed.
static func fire(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	var m := LaserMods.mask(spec)
	var milli := milli_of(spec, ctx.damage) * LaserMods.damage_permille(w, m) / 1000
	var dmg := shot_damage(w, milli)
	var base := maxi(1, shot_damage(w, milli_of(spec, ctx.base_damage)))
	var feed_x := maxi(1, LaserMods.param(w, "lance_feed"))
	var beams := trace(w, spec, ctx.origin, ctx.angle)
	var centre := (GunForms.lanes(spec, LANE_RADIUS_M).size() - 1) / 2  # the primary lance
	var root := w.take_root()
	var landed := false
	var seen := {}
	var rank := {}  # mark -> the next enemy's share, per mille
	for b in beams:
		var li := int(b["lane"])
		var kind: StringName = b["kind"]
		var share := int(b["share"])
		var part := dmg if share == 1000 else (maxi(1, dmg * share / 1000) if dmg > 0 else 0)
		var tags := ctx.tags | (SimEvent.TAG_AREA if kind == LaserMods.K_RING else 0)
		var c := AttackContext.make(ctx.origin, ctx.angle, part, root, tags, ctx.effect_id)
		c.base_damage = base if share == 1000 else maxi(1, base * share / 1000)
		c.secondary = ctx.secondary or li != centre or kind != LaserMods.K_MAIN
		c.repeat = ctx.repeat
		c.feed_x = feed_x
		var hits: PackedInt32Array = b["hits"]
		var pts: PackedVector2Array = b["at"]
		var mark := "%s%d" % [kind, li]
		for k in hits.size():
			if part <= 0:
				break
			var i := hits[k]
			if seen.has(mark + str(i)):  # a kind hits an enemy once a shot
				continue
			seen[mark + str(i)] = true
			if kind != LaserMods.K_RING:  # v0.11.0 O1c: each enemy down the path takes less (ring: an area, flat)
				var f: int = rank.get(mark, 1000)
				c.damage = maxi(1, part * f / 1000)
				rank[mark] = falloff_next(w, f)
			landed = hit(w, spec, c, i, b["from"], pts[k], true) or landed
		if kind == LaserMods.K_MAIN and bool(b["end"]):
			Attacks.run_on_end(w, spec, c, b["to"])
	if m != 0:
		LaserMods.after_shot(w, m, beams, dmg, milli)
	LaserMods.record(w, beams)
	return landed
