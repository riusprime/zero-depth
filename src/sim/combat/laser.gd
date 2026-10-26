class_name Laser
extends RefCounted
## v0.9.0 LZ (owner C §6.2: "Holding the attack button continuously fires a laser in the aiming direction. Damage is
## applied through frequent ticks … Sustained contact should provide competitive, potentially higher single-target
## damage … The laser follows the player's aim as they move"; Q8; PLAN C48–C50, C72; ATTACK_FORMS.md F2): the Laser
## form, the Gun's shot as a held beam (AttackSpec.beam_hold, set by the Laser card, data/modifiers/gun_laser.tres).
## - Hold to fire: PlayerKit fires the Gun's shot every period_ticks while SHOOT is held (the first at once), so a held
##   beam deals a damage tick every period_ticks (6: 10 a second), each at the aim of that tick. Attack speed shortens
##   the period at half its bonus (AttackRate.form_rate, rate_scale_permille 500).
## - The beam: from the hero's edge along the aim, reach_m long (9 m), radius_m wide; a wall stops it; it stops at the
##   first enemy it touches, or with Pierce passes through `pierce` of them (hitting pierce + 1). trace() is the one
##   geometry: the tick's hits and the view's beam (EI-07).
## - Damage: each tick deals beam_permille of the shot's damage (data; see LASER_BOMB.md for the owner's numbers), times
##   the Pattern's share per beam (Twin: 2 beams side by side at Lv 1–4, 3 fanned at Lv 5, GunForms' lanes). Damage is
##   whole numbers, so a tick's share is dithered over the ticks (dealt()): exact on average, deterministic.
## - Elements per tick (the fair rule): the beam's statuses and its hit hooks (Lightning's jump, a trigger's cast,
##   Fire's burn) fire only on the "feeding" ticks, period_ticks / the Gun's own shot period of them (6 / 9: two ticks
##   in three), so a beam held on one enemy feeds it as many stacks a second as the orbs would; a beam past the first
##   (Twin's) feeds at the secondary proc, as a second orb does. A kill always runs its On Kill hooks.
## - Caps: a beam is no projectile. It never counts in the projectile caps (ShotCap) and launches none; what its feeding
##   ticks cast (a trigger's bolt) counts there as any other cast.
## - The hero moves at move_permille (750) while the beam fires (move_factor(), World's move step).
## Pure: integer maths and Collide's sweeps, no randomness, one clock.

## Twin's beams sit GunForms.TWIN_GAP_RADII of this apart (about 0.5 m).
const LANE_RADIUS_M := 0.2
## The beam's launch counter (ModifierRuntime.count): the feeding ticks and the damage dither read it.
const COUNT_KEY := "#beam"
## A tick that doesn't feed hits as this spec: no statuses, no hooks (made once, never written).
static var _bare: AttackSpec = null


static func _bare_spec() -> AttackSpec:
	if _bare == null:
		_bare = AttackSpec.new()
		_bare.id = &"laser_bare"
		_bare.form = AttackSpec.Form.BEAM
	return _bare


## `s` is a held beam (the Laser form).
static func held(s: AttackSpec) -> bool:
	return s != null and s.form == AttackSpec.Form.BEAM and s.beam_hold > 0


## The run's Gun shot is the Laser now.
static func active(w: World) -> bool:
	return PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w) and held(Modifiers.bolt(w))


## The beam is firing now: the Laser held with SHOOT, while the hero may attack (PlayerKit.armed) and isn't swinging.
static func firing(w: World) -> bool:
	return active(w) and PlayerKit.shooting(w) and PlayerKit.armed(w) and w.swing_t == 0


## The hero's move speed factor now: the Laser's move_permille while it fires, else 1.
static func move_factor(w: World) -> float:
	if not firing(w):
		return 1.0
	var pm := Modifiers.bolt(w).move_permille
	return pm / 1000.0 if pm > 0 else 1.0


## The share of the beam's ticks that feed statuses and hooks, per mille: its period over the Gun's own shot period
## (the class doc's fair rule), at most 1000.
static func feed_permille(w: World, spec: AttackSpec) -> int:
	var orb := maxi(1, w.player.shot_period_ticks)
	var period := LaserMods.rapid_period(w, spec, maxi(1, spec.period_ticks))  # v0.9.5 FC1: Rapid Fire's quicker tick
	return clampi(1000 * period / orb, 1, 1000)


## The `n`-th of a run of ticks at `pm` per mille is a feeding one (exact on average: pm of every 1000).
static func feeds(n: int, pm: int) -> bool:
	return n * pm / 1000 != (n - 1) * pm / 1000


## The whole damage the `n`-th tick deals when each deals `milli` thousandths on average (the dither).
static func dealt(n: int, milli: int) -> int:
	return n * milli / 1000 - (n - 1) * milli / 1000


## A beam's thousandths of damage per tick: the shot's `damage` × beam_permille × the beam's share.
static func milli_of(spec: AttackSpec, damage: int) -> int:
	var share := spec.share_permille if spec.share_permille > 0 else 1000
	return damage * maxi(0, spec.beam_permille) * share / 1000


## The beams of `spec` from `origin` along `angle` now (pure read): one per lane, {from, to, hits (actor indices,
## nearest first), at (each hit's point), wall (it ended on a wall)}. The view draws the same (WorldReader.beams).
static func trace(w: World, spec: AttackSpec, origin: Vector2, angle: int) -> Array[Dictionary]:
	if LaserMods.mask(spec) != 0:  # v0.9.5 FC1: the cards that bend, fork and reflect the beam
		return LaserMods.plan(w, spec, origin, angle)
	var out: Array[Dictionary] = []
	var lanes := GunForms.lanes(spec, LANE_RADIUS_M)
	var turns := GunForms.lane_turns(spec)
	var most := maxi(0, spec.pierce) + 1
	for li in lanes.size():
		var dir := Kin.dir((angle + turns[li]) & 4095)
		var from := origin + dir * w.player.radius_m + Vector2(-dir.y, dir.x) * lanes[li]
		var b := LaserMods.ray(w, from, dir, spec.reach_m, spec.radius_m, most, {})
		b["kind"] = LaserMods.K_MAIN
		b["lane"] = li
		b["share"] = 1000
		b["wmul"] = 1000
		b["end"] = true
		b["impact"] = b["hits"].size() > 0 or bool(b["wall"])
		out.append(b)
	return out


## One hit of a beam's tick (or Echo's, a mine's) on actor `i`: with `feed` the beam's statuses and hooks as the spec's,
## else a bare hit (a kill still runs its On Kill hooks). True if it landed.
static func hit(
	w: World, spec: AttackSpec, c: AttackContext, i: int, from: Vector2, at: Vector2, feed: bool
) -> bool:
	if feed:
		return Attacks.land(w, spec, c, i, from, at) > 0
	var got := Attacks.land(w, _bare_spec(), c, i, from, at)
	if got > 0 and w.actors.dead[i] == 1:
		Attacks.fire(w, spec, AttackSpec.Trigger.ON_KILL, c, at)
	return got > 0


## One damage tick of the held beam `spec` launched with `ctx` (Attacks._shared_form): every lane hits what it touches
## (the class doc's damage, feeding and kill rules). v0.9.5 FC1: a card-carrying beam is several beams (LaserMods.plan),
## each dealing its share of the tick, each kind hitting an enemy at most once; Big Shot's damage, Echo's and Mine's
## stores. Returns true if a hit landed.
static func fire(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	var key := (spec.key if spec.key != "" else String(spec.id)) + COUNT_KEY
	var n := ModifierRuntime.count(w, key)
	var m := LaserMods.mask(spec)
	var feed := feeds(n, feed_permille(w, spec))
	var milli := milli_of(spec, ctx.damage) * LaserMods.damage_permille(w, m) / 1000
	var dmg := dealt(n, milli)
	var base := maxi(1, milli_of(spec, ctx.base_damage) / 1000)
	var beams := trace(w, spec, ctx.origin, ctx.angle)
	var centre := (GunForms.lanes(spec, LANE_RADIUS_M).size() - 1) / 2  # the primary beam
	var root := w.take_root()
	var landed := false
	var seen := {}
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
		var hits: PackedInt32Array = b["hits"]
		var pts: PackedVector2Array = b["at"]
		var mark := "%s%d" % [kind, li]
		for k in hits.size():
			if part <= 0:
				break
			var i := hits[k]
			if seen.has(mark + str(i)):  # a kind hits an enemy once a tick
				continue
			seen[mark + str(i)] = true
			landed = hit(w, spec, c, i, b["from"], pts[k], feed) or landed
		if feed and kind == LaserMods.K_MAIN and bool(b["end"]):
			Attacks.run_on_end(w, spec, c, b["to"])
	if m != 0:
		LaserMods.after_tick(w, m, beams, dmg, milli)
	return landed
