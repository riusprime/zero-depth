class_name RuneExplosion
extends RefCounted
## v0.9.5 FC0 (owner: "The shotgun form, the scatter has to go, we are gonna be replacing it with rune explosion, a
## violet explosion that comes out of the player as an energy kind like shield that grown, just like a mage from world
## of warcraft"; FORM_COMBOS.md R0, R1): the Rune Explosion form, the Gun's shot as a ring of runes bursting from the
## hero (AttackSpec.rune_mm, set by the Rune Explosion card, data/modifiers/gun_rune_explosion.tres). It replaces the
## Scatter form (retired through data/wand/migration.tres).
## - The burst: every period (1.1 s; attack speed at half its bonus, AttackRate.form_rate) while the hero attacks, a
##   ring centred on the hero (it follows them each tick) grows linearly from 0 to its radius (3.5 m; the area stat
##   scales it) over rune_ticks (21 = 0.35 s), then lingers FADE_TICKS for the view's fade (no hits).
## - The hits: each enemy is hit once per burst, the tick the edge reaches it (edge >= centre distance - the enemy's
##   radius), as one Attacks.land hit under the spec (its elements' statuses, On Hit and On Kill hooks). The damage is
##   the shot's (3.75 x an orb hit, the card multiplies it; 3.0 before the FC0 DPS check). Tags are area (no heat,
##   Heat.NOT_ATTACK) and projectile (the Damage stat and crit apply as for the Bomb).
## - The shove: a hit enemy slides PUSH_M outward along the hero-to-enemy line over PUSH_TICKS (bosses ignore it, as
##   they do the Blade's and Scatter Blast's); the next collision pass keeps it out of walls.
## - Twin (R1): `twin` more bursts follow the first, every TWIN_GAP_TICKS (0.2 s), each TWIN_SIZE_PERMILLE (70 %) of
##   the radius and share_permille (Twin's 70 %) of the damage: Lv 1-2 one extra burst, Lv 3 two.
## - Caps: at most LIVE_MAX bursts alive per hero (a burst past it is dropped). A burst is no projectile, so it never
##   counts in ShotCap's 40 a second (the Laser's rule; one burst a 1.1 s is far under it).
## State: ModifierState.rune_* (hashed and saved only while a burst lives).
## Pure (EI-02): integer maths, Kin's length, no randomness (EI-05), the one clock (EI-03).

const LIVE_MAX := 3
## The view's fade after the growth ends (0.15 s); the sim keeps the burst this long, hitting nothing.
const FADE_TICKS := 9
const TWIN_GAP_TICKS := 12
const TWIN_SIZE_PERMILLE := 700
## The shove: metres and ticks.
const PUSH_M := 0.4
const PUSH_TICKS := 6


## `s` is a Rune Explosion (the form's shot).
static func is_rune(s: AttackSpec) -> bool:
	return s != null and s.rune_mm > 0


## The run's Gun shot is the Rune Explosion now.
static func active(w: World) -> bool:
	return PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w) and is_rune(Modifiers.bolt(w))


## The full radius of `s` now (m): rune_mm, the area stat on it.
static func radius_m(w: World, s: AttackSpec) -> float:
	return Stats.area(w, RuneMods.radius_mm(w, s) / 1000.0)  # v0.9.5 FC5: Big Shot, Rapid Fire


## The edge radius (m) of a burst of full radius `radius` at `age` ticks of its `grow` growth ticks: linear, in whole
## millimetres.
static func edge_m(radius: float, age: int, grow: int) -> float:
	var full := roundi(radius * 1000.0)
	return float(full * clampi(age, 0, grow) / maxi(1, grow)) / 1000.0


## Called by Attacks._shared_form with the whole shot (before the share): queue the first burst and Twin's.
static func fire(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	var s := w.mx
	var r := radius_m(w, spec)
	var extra_share := spec.share_permille if spec.share_permille > 0 else TWIN_SIZE_PERMILLE
	var base := RuneMods.damage(w, spec, ctx.damage)  # v0.9.5 FC5: Big Shot's x1.6, Rapid Fire's x0.7
	var aim := RuneMods.target(w, spec, w.player_pos())  # v0.9.5 FC5: Homing's centre
	var fixed: bool = aim["fixed"]
	var at: Vector2 = aim["at"]
	var queued := false
	var first := -1
	for k in maxi(0, spec.twin) + 1:
		if s.rune_uid.size() >= LIVE_MAX:
			break
		var dmg := base
		var rad := r
		if k > 0:
			dmg = maxi(1, (base * extra_share + 500) / 1000)
			rad = r * TWIN_SIZE_PERMILLE / 1000.0
		if k == 0:
			first = s.rune_next
		if fixed:
			RuneMods.note_burst(s, s.rune_next, at, RuneMods.F_FIXED)
		s.rune_uid.append(s.rune_next)
		s.rune_next += 1
		s.rune_key.append(spec.key)
		s.rune_born.append(w.tick + k * TWIN_GAP_TICKS)
		s.rune_radius.append(rad)
		s.rune_damage.append(dmg)
		s.rune_root.append(ctx.root if ctx.root != 0 and k == 0 else w.take_root())
		queued = true
	if first >= 0:
		RuneMods.on_cast(w, spec, at, base, r)  # Echo's glyph, Mine's trap
	return queued


## Tick phase 6 (ModifierRuntime.advance): the shoves step, each burst whose edge grows hits what it reaches, the
## bursts that are over leave.
static func advance(w: World) -> void:
	var s := w.mx
	if s.rune_uid.is_empty() and s.rune_push_id.is_empty():
		return
	_advance_push(w)
	if w.player_dead():
		_clear(s)
		return
	var hero := w.player_pos()
	var k := 0
	while k < s.rune_uid.size():
		var spec := Modifiers.book(w).find(s.rune_key[k])
		var age := w.tick - s.rune_born[k]
		if spec == null or age >= maxi(1, spec.rune_ticks) + FADE_TICKS:
			_drop(s, k)
			continue
		if age >= 0 and age <= spec.rune_ticks:
			var centre := RuneMods.centre_of(s, s.rune_uid[k], hero)  # v0.9.5 FC5: Homing, Echo, Mine fix it
			_hit(w, spec, k, centre, edge_m(s.rune_radius[k], age, spec.rune_ticks))
			if age == spec.rune_ticks:
				RuneMods.on_full(w, spec, s.rune_uid[k], centre, s.rune_radius[k], s.rune_damage[k])
		k += 1


static func _hit(w: World, spec: AttackSpec, k: int, centre: Vector2, edge: float) -> void:
	var s := w.mx
	var uid := s.rune_uid[k]
	var tags := SimEvent.TAG_AREA | SimEvent.TAG_PROJECTILE
	var ctx := AttackContext.make(centre, 0, s.rune_damage[k], s.rune_root[k], tags, &"")
	ctx.depth = spec.depth
	ctx.proc_pct = maxi(1, 100 >> spec.depth)
	for i in w.enemies_near(centre, edge):
		var aid := w.actors.ids[i]
		if _hit_before(s, uid, aid):
			continue
		s.rune_hit_uid.append(uid)
		s.rune_hit_foe.append(aid)
		var pos := w.actors.pos(i)
		if Attacks.land(w, spec, ctx, i, centre, pos) > 0:
			_shove(w, i, centre)
			RuneMods.on_hit(w, spec, uid, s.rune_damage[k], i, centre, pos)  # v0.9.5 FC5: Split


static func _hit_before(s: ModifierState, uid: int, aid: int) -> bool:
	for j in s.rune_hit_uid.size():
		if s.rune_hit_uid[j] == uid and s.rune_hit_foe[j] == aid:
			return true
	return false


static func _shove(w: World, i: int, from: Vector2) -> void:
	var a := w.actors
	var s := w.mx
	if a.dead[i] == 1 or BossAi.is_boss_kind(a.kinds[i]) or s.rune_push_id.has(a.ids[i]):
		return
	var away := a.pos(i) - from
	var len := Kin.length(away)
	s.rune_push_id.append(a.ids[i])
	s.rune_push_dir.append(away / len if len > 0.0 else Kin.dir(w.aim_angle))
	s.rune_push_left.append(PUSH_TICKS)


static func _advance_push(w: World) -> void:
	var s := w.mx
	var step := PUSH_M / PUSH_TICKS
	for j in range(s.rune_push_id.size() - 1, -1, -1):
		var i := w.actors.index_of(s.rune_push_id[j])
		if i > 0 and w.actors.dead[i] == 0:
			w.actors.set_pos(i, w.actors.pos(i) + s.rune_push_dir[j] * step)
			s.rune_push_left[j] -= 1
		else:
			s.rune_push_left[j] = 0
		if s.rune_push_left[j] <= 0:
			s.rune_push_id.remove_at(j)
			s.rune_push_dir.remove_at(j)
			s.rune_push_left.remove_at(j)


static func _drop(s: ModifierState, k: int) -> void:
	var uid := s.rune_uid[k]
	RuneMods.forget(s, uid)
	for j in range(s.rune_hit_uid.size() - 1, -1, -1):
		if s.rune_hit_uid[j] == uid:
			s.rune_hit_uid.remove_at(j)
			s.rune_hit_foe.remove_at(j)
	s.rune_uid.remove_at(k)
	s.rune_key.remove_at(k)
	s.rune_born.remove_at(k)
	s.rune_radius.remove_at(k)
	s.rune_damage.remove_at(k)
	s.rune_root.remove_at(k)


static func _clear(s: ModifierState) -> void:
	RuneMods.clear(s)
	s.rune_uid.clear()
	s.rune_key.clear()
	s.rune_born.clear()
	s.rune_radius.clear()
	s.rune_damage.clear()
	s.rune_root.clear()
	s.rune_hit_uid.clear()
	s.rune_hit_foe.clear()
	s.rune_push_id.clear()
	s.rune_push_dir.clear()
	s.rune_push_left.clear()


## The bursts for the views: [{uid, pos (the hero), radius (full, m), edge (m now), age, grow, fade, hits (actor ids)}],
## oldest first; a burst still waiting for its start tick is left out.
static func read(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := w.mx
	for k in s.rune_uid.size():
		var spec := Modifiers.book(w).find(s.rune_key[k])
		var age := w.tick - s.rune_born[k] - 1  # the age advance() last ran with (the tick counter has stepped on)
		if spec == null or age < 0:
			continue
		var hits := PackedInt32Array()
		for j in s.rune_hit_uid.size():
			if s.rune_hit_uid[j] == s.rune_uid[k]:
				hits.append(s.rune_hit_foe[j])
		(
			out
			. append(
				{
					"uid": s.rune_uid[k],
					"pos": RuneMods.centre_of(s, s.rune_uid[k], w.player_pos()),
					"radius": s.rune_radius[k],
					"edge": edge_m(s.rune_radius[k], age, spec.rune_ticks),
					"age": age,
					"grow": spec.rune_ticks,
					"fade": FADE_TICKS,
					"hits": hits,
				}
			)
		)
	return out
