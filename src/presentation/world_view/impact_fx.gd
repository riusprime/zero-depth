class_name ImpactFx
extends RefCounted
## v0.8.0 GF2 (owner O20: "the enemies, when hit by a bullet, should have particles where it hit and coming behind,
## so we have an impact, a clear impact of it"): every hit the player lands on an enemy throws an impact in the
## owner's effect atlases (VfxCore's pools: fx_spark_shapes, fx_debris_chunks, fx_smoke_puffs), tinted by the hit's
## element (none: the hero's blue-white): a flash and a few sparks back out of the hit point, and a spray out of the
## far side of the body along the hit's direction. A bolt's is the full one (with chunks and a puff of smoke); a
## slash's is smaller; any other hit (an area, an ability, a chain) a small flash and sparks only.
## Where it reads (EI-07, presentation only): HitFeel hands it each DAMAGE event the player owns (on_hit) and, after
## the events, the player's live bolts (track): a bolt's direction is its velocity at the last sync (a bolt fired
## and landed inside one tick: from the hit point into the body's centre); a melee or other hit's runs from the hero
## through the body. Its timing is the event's tick, drawn at the effects layer's frame time (VfxCore.now: sim
## ticks plus the interpolation fraction), so it pauses and replays with the sim; no Timer decides anything.
## Budget (PRESENTATION §7, the v0.8.0 PF budget): at most MAX_LIVE impacts live (the oldest goes); a hit within
## MERGE_M of a live impact that began within MERGE_TICKS is merged into it (it grows to the stronger, nothing new
## is drawn), so a burst of hits on one spot draws once; the FULL newest draw at the frame's density, the rest at
## THIN of it; every piece goes through VfxCore's pools and its frame cap (MAX_SPRITES). The Options "Effects
## density" scales the pieces (VfxCore.density, set by the attack forms' canvas every frame: low 0.25). Starting
## values.
## v0.8.0 GF3 (owner O22: the Blade gets the Gun's treatment): a slash's impact is its own: a cut flash drawn along the
## slash (the swing's tangent where it struck: the blade's way across the body; a thrust's along its aim) and sparks
## thrown along that tangent, not the bolt's spray; at SLASH strength (at least a bolt's: the 0.6 share is gone), the
## finisher's FINISHER_MULT bigger; the same budget, merging and pools. Its flinch (on_hit's return) is stronger than
## a bolt's (FLINCH_SLASH) and knocks the pose away from the swing (HitFeel, AvatarBase.flinch's knock).

const LIFE_TICKS := 18.0
const MAX_LIVE := 32
const FULL := 8
const THIN := 0.35
const MERGE_M := 0.45
const MERGE_TICKS := 3
## The kinds of hit and their strength (1: a bolt's full impact).
const BOLT := 0
const SLASH := 1
const OTHER := 2
const STRENGTH := [1.0, 1.1, 0.45]
## v0.8.0 GF3: the finisher's slash impact is this much bigger; a slash's flinch strength and knock (a bolt's: 1, 0).
const FINISHER_MULT := 1.3
const FLINCH_SLASH := 1.35
const KNOCK_SLASH := 0.8
const KNOCK_FINISHER := 1.0
## v0.8.0 GF3: a slash's sparks along its tangent at strength 1 and full density, and the cut's half-length (m).
const SLASH_SPARKS := 13
const CUT_HALF_M := 0.9
## v0.8.0 GF3: the fixed iso camera's direction on the sim plane (IsoRig: yaw 45 degrees). A slash's cut is drawn on
## the struck body's side between the blade's way in and the camera (CAM_SIDE of the way to the camera), so the body
## doesn't hide it.
const CAM := Vector2(0.70710678, -0.70710678)
const CAM_SIDE := 0.65
## v0.8.0 GF3: how far out (in body radii) the cut is drawn: the models stand a little outside their sim radius.
const CAM_OUT := 1.35
## A crit's impact is this much bigger.
const CRIT_MULT := 1.25
## Heights (m) a hit is drawn at: a bolt's flight height (SimPlane.CORE_HEIGHT), a slash's.
const BOLT_Y := SimPlane.CORE_HEIGHT
const SLASH_Y := 0.6
## The hero's blue-white (a hit with no element).
const HERO := Color(0.74, 0.88, 1.0)
## Pieces at strength 1 and full density.
const SPARKS := 6
const SPRAY := 8
const CHUNKS := 2

## Counts (tests and the probe): impacts added, merged into a live one, dropped past MAX_LIVE; pieces drawn in the
## last frame.
var added := 0
var merged := 0
var dropped := 0
var last_pieces := 0
## Live impacts: [hit point (Vector3), direction (Vector3, unit, flat), far side (Vector3), colour, start tick,
## strength, kind, seed].
var _live: Array = []
var _seed := 0
## The player's bolts at the last sync: id -> [velocity, spec key]; the frame before's while this one is built.
var _bolts := {}
## Spec key -> its impact colour, for one build (attack digest).
var _colors := {}
var _kinds := {}
var _digest := ""


## Live impacts (tests).
func live() -> int:
	return _live.size()


## The impact of DAMAGE event `e` (the player's, on an enemy): records it and returns [direction on the sim plane
## (away from the hit), strength, knock (0..1)] for the flinch. v0.8.0 GF3: a slash's direction leans along the
## swing (away from the blade's way), its strength FLINCH_SLASH and its knock KNOCK_SLASH (the finisher's more).
func on_hit(reader: WorldReader, e: SimEvent) -> Array:
	_check_build(reader)
	var idx := reader.actor_index(e.target_id)
	var centre := reader.actor_pos(idx) if idx >= 0 else e.pos
	var radius := reader.actor_radius(idx) if idx >= 0 else 0.4
	var bolt: Array = _bolts.get(e.source_id, [])
	var kind := OTHER
	if not bolt.is_empty() or e.tags & SimEvent.TAG_PROJECTILE:
		kind = BOLT
	elif e.tags & SimEvent.TAG_MELEE:
		kind = SLASH
	var dir := Vector2.ZERO
	if not bolt.is_empty():
		dir = (bolt[0] as Vector2).normalized()
	if dir == Vector2.ZERO and kind == BOLT:
		dir = (centre - e.pos).normalized()
	if dir == Vector2.ZERO:
		dir = (centre - reader.player_pos()).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var c := HERO
	var fx := &""
	if not bolt.is_empty():
		c = _key_color(reader, String(bolt[1]))
		fx = _key_kind(String(bolt[1]))
	elif kind == SLASH:
		c = _key_color(reader, "#melee", reader.step_attack_id())
	var crit := CRIT_MULT if e.tags & SimEvent.TAG_CRIT else 1.0
	var s: float = STRENGTH[kind] * crit
	var y := BOLT_Y if kind == BOLT else SLASH_Y
	var at := SimPlane.to_3d(e.pos, y)
	if kind != BOLT:  # a slash lands on the body's near side, not at the hero's blade tip
		at = SimPlane.to_3d(centre - dir * radius, y)
	var far := SimPlane.to_3d(centre + dir * radius, y)
	if kind != SLASH:
		add(at, SimPlane.to_3d(dir), far, c, e.tick, s, kind, fx)
		return [dir, s, 0.0]
	var fin := HitFeel.finisher_hit(reader, e)
	if fin:
		s *= FINISHER_MULT
	var tan := slash_tangent(reader.swing_motion(), dir)
	var face := (-dir).lerp(CAM, CAM_SIDE).normalized()
	at = SimPlane.to_3d(centre + face * radius * CAM_OUT, y)
	add(at, SimPlane.to_3d(tan), far, c, e.tick, s, kind)
	var away := (dir + tan * 0.6).normalized()
	return [away, FLINCH_SLASH * crit, KNOCK_FINISHER if fin else KNOCK_SLASH]


## v0.8.0 GF3: the way the blade crosses a body at `radial` (unit, hero -> body) for a swing's motion: a slash's
## tangent (right-to-left turns the sim angle up, left-to-right down; the spin turns up), a thrust's along its aim.
static func slash_tangent(motion: int, radial: Vector2) -> Vector2:
	match motion:
		WorldReader.MOTION_SLASH_LEFT_TO_RIGHT:
			return Vector2(radial.y, -radial.x)
		WorldReader.MOTION_THRUST:
			return radial
	return Vector2(-radial.y, radial.x)


## Records one impact (see on_hit): merged into a live one nearby that is still young, else added (the oldest goes
## past MAX_LIVE). False when merged.
func add(
	at: Vector3,
	dir: Vector3,
	far: Vector3,
	c: Color,
	tick: int,
	strength: float,
	kind: int,
	fx: StringName = &""
) -> bool:
	for imp: Array in _live:
		if (
			tick - int(imp[4]) <= MERGE_TICKS
			and tick >= int(imp[4])
			and (imp[0] as Vector3).distance_to(at) < MERGE_M
		):
			imp[5] = maxf(float(imp[5]), strength)
			imp[6] = mini(int(imp[6]), kind)
			merged += 1
			return false
	if _live.size() >= MAX_LIVE:
		_live.pop_front()
		dropped += 1
	_seed += 1
	_live.append([at, dir.normalized(), far, c, tick, strength, kind, _seed * 7919 + 17, fx])
	added += 1
	return true


## After the events of a sync: the player's live bolts (their direction and spec key) for the next sync's hits.
func track(reader: WorldReader) -> void:
	var now := {}
	for i in reader.projectile_count():
		if reader.projectile_team(i) != 0:
			continue
		now[reader.projectile_id(i)] = [reader.projectile_vel(i), reader.projectile_spec_key(i)]
	_bolts = now


func _check_build(reader: WorldReader) -> void:
	var d := reader.attack_digest()
	if d != _digest:
		_digest = d
		_colors.clear()
		_kinds.clear()


## The impact colour of a spec key (its first element's core; none: the hero's blue-white), cached for the build.
## `attack_id` given: the colour of that attack's spec (the Blade's step) under the cache key `key` + its id.
func _key_color(reader: WorldReader, key: String, attack_id: StringName = &"") -> Color:
	var k := key if attack_id == &"" else key + ":" + String(attack_id)
	if _colors.has(k):
		return _colors[k]
	var spec := reader.attack_spec(attack_id) if attack_id != &"" else reader.attack_spec_at(key)
	var els: Array = Array(spec.get("elements", PackedStringArray()))
	var c := HERO if els.is_empty() else AttackFormLooks.element_color(StringName(els[0]))
	if _colors.size() > 64:
		_colors.clear()
		_kinds.clear()
	_colors[k] = c
	# v0.9.0 VX V4: the first element's effects-layer kind, for the bolt's element extra.
	_kinds[k] = ElementLooks.kind(StringName(els[0])) if not els.is_empty() else &""
	return c


## v0.9.0 VX V4: the effects-layer kind of a spec key's first element (&"" for none), read with its colour.
func _key_kind(key: String) -> StringName:
	return _kinds.get(key, &"")


# --- Drawing (a VfxCore drawer: WorldViewRoot adds draw to the effects layer's drawers) ----------------------------
func draw(layer: VfxCore) -> void:
	var now := layer.now()
	var base := layer.density
	last_pieces = 0
	var keep: Array = []
	var shown := 0
	for k in range(_live.size() - 1, -1, -1):  # the newest first: the fresh hits keep their full look
		var imp: Array = _live[k]
		var age := now - float(imp[4])
		if age > LIFE_TICKS:
			continue
		keep.append(imp)
		if age < 0.0:
			continue
		var dn := base * (1.0 if shown < FULL else THIN)
		shown += 1
		last_pieces += _draw_one(layer, imp, clampf(age / LIFE_TICKS, 0.0, 1.0), dn)
	keep.reverse()
	_live = keep


## One impact at u (0..1) through its life, `dn` its density: the pieces it drew.
func _draw_one(layer: VfxCore, imp: Array, u: float, dn: float) -> int:
	var at: Vector3 = imp[0]
	var d: Vector3 = imp[1]
	var far: Vector3 = imp[2]
	var c: Color = imp[3]
	var s: float = imp[5]
	var kind: int = imp[6]
	var sd: int = imp[7]
	var side := Vector3.UP.cross(d).normalized()
	var hot := Color(c.lerp(Color.WHITE, 0.45) * 2.4, 1.0)
	var t := 1.0 - (1.0 - u) * (1.0 - u)  # out fast, slowing
	var n := 0
	if kind == SLASH:
		return _draw_slash(layer, imp, u, dn)
	# The flash where it hit.
	if u < 0.35:
		var f := 1.0 - u / 0.35
		if layer.sprite(&"spark", at, 0.8 * s * (0.8 + 0.6 * u), Color(hot, f), sd % 4, 0.0):
			n += 1
	# Sparks back out of the hit point (toward the shooter and to the sides).
	for j in maxi(1, int(round(SPARKS * s * dn))):
		var a := (VfxCore.h(sd, j) - 0.5) * 2.4
		var v := (
			(-d * 0.55 + side * sin(a) + Vector3(0, 0.25 + 0.6 * VfxCore.h(sd + 1, j), 0))
			. normalized()
		)
		var reach := s * (0.45 + 0.5 * VfxCore.h(sd + 2, j))
		var p := at + v * reach * t + Vector3(0, -0.5 * u * u, 0)
		var tail := at + v * reach * maxf(0.0, t - 0.18)
		if layer.streak(&"spark", tail, p, 0.08 * s, Color(hot, 1.0 - u), j % 4):
			n += 1
	if kind == OTHER:
		return n
	# The spray out of the far side, along the hit.
	for j in maxi(1, int(round(SPRAY * s * dn))):
		var p := spray_at(imp, j, u)
		var tail := spray_at(imp, j, maxf(0.0, u - 0.2))
		var w := 0.11 * s * (1.0 - 0.5 * u)
		if layer.streak(&"spark", tail, p, w, Color(hot, (1.0 - u) * (1.0 - u * 0.3)), (j + 1) % 4):
			n += 1
	if kind != BOLT:
		return n
	# A bolt also knocks a couple of chunks out of the far side and leaves a puff where it hit.
	var chunk := Color(c.lerp(Color(0.8, 0.8, 0.82), 0.6), clampf((1.0 - u) * 1.6, 0.0, 1.0))
	for j in int(round(CHUNKS * s * dn)):
		var spread := (VfxCore.h(sd + 6, j) - 0.5) * 1.1
		var v := (d + side * spread).normalized()
		var q := (
			far
			+ v * s * (0.6 + 0.6 * VfxCore.h(sd + 7, j)) * t
			+ Vector3(0, 0.9 * t - 1.2 * t * t, 0)
		)
		if layer.sprite(&"debris", q, 0.2 * s, chunk, (sd + j) % 4, u * 5.0):
			n += 1
	if dn >= 0.5:
		var puff := Color(
			Color(0.6, 0.6, 0.62).lerp(c, 0.25), 0.35 * (1.0 - u) * minf(1.0, u * 6.0)
		)
		if layer.sprite(
			&"smoke", at + Vector3(0, 0.25 * u, 0), (0.3 + 0.5 * u) * s, puff, sd % 4, sd * 0.1
		):
			n += 1
	# v0.9.0 VX V4: the element's own extra (Fire embers and smoke, a Lightning fork, Frost glints and shards, Venom a
	# splash, Bleed a splatter), for the FULL newest impacts only (inside MAX_LIVE and the merge); none at Low.
	var fx: StringName = imp[8] if imp.size() > 8 else &""
	if fx != &"" and dn >= layer.density:
		var before := layer.sprites_asked
		HeroFx.impact(layer, fx, at, d, u, sd, s * 0.8)
		n += layer.sprites_asked - before
	return n


## Where spray piece j of impact `imp` is at u (0..1) through its life: out of the far side along the hit, spread a
## little to the sides and up, dropping as it slows.
static func spray_at(imp: Array, j: int, u: float) -> Vector3:
	var d: Vector3 = imp[1]
	var far: Vector3 = imp[2]
	var s: float = imp[5]
	var sd: int = imp[7]
	var side := Vector3.UP.cross(d).normalized()
	var t := 1.0 - (1.0 - u) * (1.0 - u)
	var spread := (VfxCore.h(sd + 3, j) - 0.5) * 0.9
	var lift := 0.45 * VfxCore.h(sd + 4, j)
	var v := (d + side * spread + Vector3(0, lift, 0)).normalized()
	var reach := s * (1.0 + 1.2 * VfxCore.h(sd + 5, j))
	return far + v * reach * t + Vector3(0, -0.7 * u * u, 0)


## v0.8.0 GF3: one slash impact at u (0..1), `dn` its density: a cut flash along the slash (a bright streak drawn out
## across the body from the hit, then fading, over a hot spark), and sparks thrown on along the tangent (spread a
## little, lifted, falling), a couple of chips back off the body. The pieces it drew.
func _draw_slash(layer: VfxCore, imp: Array, u: float, dn: float) -> int:
	var at: Vector3 = imp[0]
	var tan: Vector3 = imp[1]
	var c: Color = imp[3]
	var s: float = imp[5]
	var sd: int = imp[7]
	var hot := Color(c.lerp(Color.WHITE, 0.5) * 2.6, 1.0)
	var n := 0
	# The cut: drawn out along the slash in its first moment, then fading where it lies.
	if u < 0.5:
		var f := 1.0 - u / 0.5
		var grow := minf(1.0, u / 0.12)
		var half := CUT_HALF_M * s * (0.4 + 0.6 * grow)
		var mid := at + tan * 0.15 * s
		if layer.streak(
			&"spark", mid - tan * half, mid + tan * half, 0.24 * s * f, Color(hot, f), 2
		):  # the round cell drawn out: a line (the diagonal cell 1 thins to nothing on a ribbon)
			n += 1
		if layer.sprite(&"spark", at, 1.3 * s * (0.8 + 0.5 * u), Color(hot, f), sd % 4, 0.0):
			n += 1
	# Sparks on along the blade's way.
	var t := 1.0 - (1.0 - u) * (1.0 - u)
	for j in maxi(1, int(round(SLASH_SPARKS * s * dn))):
		var p := slash_spark_at(imp, j, u)
		var tail := slash_spark_at(imp, j, maxf(0.0, u - 0.16))
		var w := 0.12 * s * (1.0 - 0.5 * u)
		if layer.streak(&"spark", tail, p, w, Color(hot, (1.0 - u) * (1.0 - u * 0.3)), j % 4):
			n += 1
	# A couple of chips knocked back off the body.
	var back := at - (imp[2] as Vector3)
	back.y = 0.0
	back = back.normalized() if back.length_squared() > 1e-6 else -tan
	var chip := Color(c.lerp(Color(0.85, 0.88, 0.92), 0.5), clampf((1.0 - u) * 1.6, 0.0, 1.0))
	for j in int(round(2.0 * s * dn)):
		var v := (back * 0.8 + tan * (VfxCore.h(sd + 9, j) - 0.3)).normalized()
		var q := at + v * s * 0.5 * t + Vector3(0, 0.6 * t - 1.0 * t * t, 0)
		if layer.sprite(&"debris", q, 0.12 * s, chip, (sd + j) % 4, u * 6.0):
			n += 1
	return n


## v0.8.0 GF3: where slash spark j of impact `imp` is at u (0..1): out of the hit point along the slash's tangent,
## spread a little to the sides and up, dropping as it slows.
static func slash_spark_at(imp: Array, j: int, u: float) -> Vector3:
	var at: Vector3 = imp[0]
	var tan: Vector3 = imp[1]
	var s: float = imp[5]
	var sd: int = imp[7]
	var side := Vector3.UP.cross(tan).normalized()
	var t := 1.0 - (1.0 - u) * (1.0 - u)
	var spread := (VfxCore.h(sd + 3, j) - 0.5) * 0.8
	var lift := 0.15 + 0.5 * VfxCore.h(sd + 4, j)
	var v := (tan + side * spread + Vector3(0, lift, 0)).normalized()
	var reach := s * (0.7 + 1.1 * VfxCore.h(sd + 5, j))
	return at + v * reach * t + Vector3(0, -0.6 * u * u, 0)
