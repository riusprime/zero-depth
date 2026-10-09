class_name AttackFormView
extends Node3D
## v0.6.0 MX3 (docs/design/MODIFIER_ENGINE.md §4): the eight attack forms drawn from their final specs, in MultiMesh
## pools per form layer and per particle kind, under one per-frame budget. Presentation only (EI-07): it reads the
## sim through WorldReader and never writes; an effect's timing is sim ticks (its start tick and life), drawn at the
## frame's tick plus the physics interpolation fraction, so no Timer or tween decides anything.
##
## What draws what (AttackFormLooks composes the look; this lays it out):
## - ARC: a crescent of segments swept across the arc at body height, its core in the element colour and its outer
##   edge in the heat edge (the laser blade itself stays KitView's);
## - BOLT: a dart per shot on the pattern, with a tail of segments along its own path (so a homing shot leaves a
##   curved trail, a piercing one a long streak), a tether back to the hero for a returning one;
## - RING: an expanding circle, its flat fill ground-safe, its raised front in the heat edge; count = staggered rings;
## - BEAM: a core line with a wider edge glow, from the origin to its end (a chain jump: to the enemy hit);
## - ZONE: a lingering patch (bright rim, soft centre) with its rim ring, held for its life;
## - ORBITER: `count` bodies evenly round the hero, turning, each with a short arc trail;
## - LOB: a lit bomb arcing to its target over its ground circle (filling as it falls), then a landing flash;
## - BURST: an instant disc flash with a rim and a raised front.
## Particles (per element): sparks, crackle, shards, drip, smear, emitted from the form's points. A crit adds a
## white-hot flash; a bounce a flash at the bounce.
##
## Budget (PRESENTATION §7): every layer pool and particle pool has a fixed size; at most mesh_cap() form meshes and
## particle_cap() particles are drawn a frame, the live attacks first, then the newest effects (the oldest drop).
## The Options "Effects density" (ViewPrefs.effects_density: low / medium / high) scales the particles and the caps;
## a pattern's own copies (a halo's 12 darts) are never thinned below the cap.
##
## Live wiring (what the sim emits today): the Blade's arc when its step spec has an element or a weight; the
## player's bolts (element rim, particles and cues on each live projectile, a flash at each bounce); Overcharge's
## burst; a seeking beam's jump (Static Chain); crits. MX stage 2's runners (ring, zone, orbiter, lob) call spawn().

const DENSITIES: Array[String] = ["low", "medium", "high"]
const DENSITY_PARTICLES := {"low": 0.25, "medium": 0.55, "high": 1.0}
const DENSITY_MESH_CAP := {"low": 384, "medium": 640, "high": 1024}
## Starting values: within PRESENTATION §7's 2,000 live particles for the whole game.
const MAX_ATTACK_MESHES := 1024
const MAX_PARTICLES := 1200
const MAX_EFFECTS := 256
const POOL_CAP := 384
const PARTICLE_POOL_CAP := 600
const PARTICLE_KINDS: Array[StringName] = [&"sparks", &"crackle", &"shards", &"drip", &"smear"]
## Particles per effect (or per live bolt) at High, by form.
const PARTICLES: Array[int] = [14, 5, 26, 12, 20, 4, 6, 22]
## Heights: flat marks just over the floor, light at the body's height.
const GROUND_H := 0.07
const BODY_H := 0.45
const BOLT_H := SimPlane.CORE_HEIGHT
const ARC_SEGMENTS := 12
const TAIL_SEGMENTS := 4
const STREAK_SEGMENTS := 9
const ORBIT_TURN := 0.09
const HOME_TURN := 0.035
const RING_STAGGER := 4.0
const FLASH_TICKS := 8
## AttackSpec.Trigger numbers the hooks' reads carry (a test pins them).
const TRIGGER_ON_HIT := 0
const TRIGGER_ON_NTH := 2
const PLAYER_RADIUS := 0.35

## The layer pools: name → [mesh id, lit].
const LAYERS := {
	&"arc_core": [&"quad", false],
	&"arc_edge": [&"quad", false],
	&"bolt_core": [&"dart", false],
	&"bolt_edge": [&"quad", false],
	&"ring_fill": [&"ring", false],
	&"ring_front": [&"band", false],
	&"beam_core": [&"quad", false],
	&"beam_edge": [&"quad", false],
	&"zone_fill": [&"patch", false],
	&"zone_rim": [&"ring", false],
	&"orbiter_core": [&"dart", false],
	&"orbiter_edge": [&"quad", false],
	&"lob_body": [&"bomb", true],
	&"lob_glow": [&"spark", false],
	&"lob_ground": [&"ring", false],
	&"lob_fill": [&"patch", false],
	&"burst_fill": [&"disc", false],
	&"burst_rim": [&"ring", false],
	&"burst_front": [&"band", false],
	&"cue": [&"quad", false],
	&"flash": [&"disc", false],
}
const PARTICLE_MESH := {
	&"sparks": &"spark",
	&"crackle": &"shard",
	&"shards": &"shard",
	&"drip": &"spark",
	&"smear": &"quad"
}

var density := "high"
var pools := {}
var particle_pools := {}
## Live effects: {look, origin, angle, start, life, to, seed, own, kind, size, color}.
var _effects: Array[Dictionary] = []
## The player's live bolts that carry a layer this frame: {id, pos, vel, look, trail: PackedVector2Array}.
var _live: Array[Dictionary] = []
var _trails := {}
var _bounce_ticks := {}
var _tick := 0
var _tier := HeatLooks.TIER_COOL
var _seed := 0
var _mesh_left := 0
var _part_left := 0
var _drawn_meshes := 0
var _drawn_particles := 0
var _last_swing := 0
var _last_burst := -1
var _last_chain := -1
var _last_seq := 0
var _player := Vector2.ZERO
var _bolt_cache_sig := ""
var _bolt_look := {}


func _init() -> void:
	name = "AttackForms"
	for id: StringName in LAYERS:
		var l: Array = LAYERS[id]
		var mat: Material = AttackFormMeshes.lit() if l[1] else AttackFormMeshes.glow()
		var p := AttackFormPool.new(id, AttackFormMeshes.mesh(l[0]), mat, POOL_CAP)
		pools[id] = p
		add_child(p)
	for kind in PARTICLE_KINDS:
		var p := AttackFormPool.new(
			StringName("particles_%s" % kind),
			AttackFormMeshes.mesh(PARTICLE_MESH[kind]),
			AttackFormMeshes.glow(),
			PARTICLE_POOL_CAP
		)
		particle_pools[kind] = p
		add_child(p)


# --- Settings and budget --------------------------------------------------------------------------------------
func set_density(value: String) -> void:
	density = value if DENSITY_PARTICLES.has(value) else "high"


func particle_scale() -> float:
	return DENSITY_PARTICLES[density]


func mesh_cap() -> int:
	return mini(DENSITY_MESH_CAP[density], MAX_ATTACK_MESHES)


func particle_cap() -> int:
	return int(MAX_PARTICLES * particle_scale())


## How many form meshes and particles the last drawn frame showed.
func meshes_drawn() -> int:
	return _drawn_meshes


func particles_drawn() -> int:
	return _drawn_particles


func effect_count() -> int:
	return _effects.size()


func live_count() -> int:
	return _live.size()


func pool(id: StringName) -> AttackFormPool:
	return pools.get(id)


func particle_pool(kind: StringName) -> AttackFormPool:
	return particle_pools.get(kind)


# --- Spawning (constructed specs, the live wiring, MX stage 2's runners) ---------------------------------------
## Starts drawing `spec` (WorldReader.attack_spec's shape) from `origin` aimed at `angle` (radians, sim plane).
## `opts`: start (tick, default the last synced), tier (heat tier, default the hero's), crit, weight, to (a beam's
## end), own (the attacker's radius), and overrides of the look's sizes (half_angle, reach, radius, length, life).
## Returns the effect (its "look" is AttackFormLooks.compose's).
func spawn(
	spec: Dictionary, origin: Vector2, angle: float = 0.0, opts: Dictionary = {}
) -> Dictionary:
	var look := AttackFormLooks.compose(spec, int(opts.get("tier", _tier)), opts)
	for k: String in ["half_angle", "reach", "radius", "length", "life"]:
		if opts.has(k):
			look[k] = opts[k]
	var e := {
		"kind": &"form",
		"look": look,
		"origin": origin,
		"angle": angle,
		"start": float(opts.get("start", _tick)),
		"life": float(look["life"]),
		"to": opts.get("to", origin),
		"has_to": opts.has("to"),
		"own": float(opts.get("own", PLAYER_RADIUS)),
		"seed": _next_seed(),
	}
	_push(e)
	if bool(look["crit"]):
		flash(origin, AttackFormLooks.CRIT_FLASH, 0.9, float(e["start"]))
	return e


## A short flash of light at `at` (a crit's white-hot, a bounce's).
func flash(at: Vector2, c: Color, size: float, start: float = -1.0) -> void:
	_push(
		{
			"kind": &"flash",
			"origin": at,
			"color": c,
			"size": size,
			"start": float(_tick) if start < 0.0 else start,
			"life": float(FLASH_TICKS),
			"seed": _next_seed(),
		}
	)


func clear() -> void:
	_effects.clear()
	_live.clear()
	_trails.clear()
	_bounce_ticks.clear()


func _push(e: Dictionary) -> void:
	_effects.append(e)
	while _effects.size() > MAX_EFFECTS:
		_effects.pop_front()


func _next_seed() -> int:
	_seed += 1
	return _seed


# --- Live wiring ----------------------------------------------------------------------------------------------
func sync(reader: WorldReader) -> void:
	_tick = reader.tick()
	_tier = HeatLooks.tier_of(reader.heat_state())
	_player = reader.player_pos()
	set_density(ViewPrefs.effects_density)
	_sync_swing(reader)
	_sync_bolts(reader)
	_sync_burst(reader)
	_sync_chain(reader)
	_sync_crits(reader)


## A look adds something over the v0.5 blade or dart only with an element, a cue or a damage weight.
static func adds_layer(look: Dictionary) -> bool:
	return (
		not (look["particles"] as Array).is_empty()
		or not (look["cues"] as Array).is_empty()
		or absf(float(look["width"]) - 1.0) > 0.001
		or look["core"] != ThemePalette.color(&"player_core")
	)


func _sync_swing(reader: WorldReader) -> void:
	var t := reader.swing_tick()
	if t <= 0 or reader.player_dead():
		_last_swing = 0
		return
	var fresh := _last_swing == 0 or t < _last_swing
	_last_swing = t
	if not fresh:
		return
	var spec := reader.attack_spec(reader.step_attack_id())
	if spec.is_empty():
		return
	var look := AttackFormLooks.compose(spec, _tier)
	if not adds_layer(look):
		return
	var shape := reader.swing_shape()
	spawn(
		spec,
		_player,
		SimPlane.yaw_of(reader.swing_angle()),
		{
			"start": float(_tick - (t - 1)),
			"life": float(maxi(reader.swing_ticks(), 4)),
			"half_angle": TAU * float(shape[0]) / 4096.0,
			"reach": float(shape[1]),
			"own": float(shape[2]),
		}
	)


## The spec a live player projectile runs. MX1: every player projectile runs the Gun bolt's (MX stage 2 names each
## projectile's own spec; this is the one place to read it from).
func _bolt_spec(reader: WorldReader, _i: int) -> Dictionary:
	return reader.attack_spec(WorldReader.ATTACK_BOLT)


func _sync_bolts(reader: WorldReader) -> void:
	_live.clear()
	var sig := "%s|%d" % [reader.attack_digest(), _tier]
	if sig != _bolt_cache_sig:
		_bolt_cache_sig = sig
		var spec := _bolt_spec(reader, -1)
		_bolt_look = AttackFormLooks.compose(spec, _tier) if not spec.is_empty() else {}
	var seen := {}
	for i in reader.projectile_count():
		if reader.projectile_team(i) != 0 or reader.projectile_is_shard(i):
			continue
		if _bolt_look.is_empty() or not adds_layer(_bolt_look):
			continue
		var id := reader.projectile_id(i)
		seen[id] = true
		var p := reader.projectile_pos(i)
		var trail: PackedVector2Array = _trails.get(id, PackedVector2Array())
		if trail.is_empty() or trail[trail.size() - 1] != p:
			trail.append(p)
		while trail.size() > STREAK_SEGMENTS + 1:
			trail.remove_at(0)
		_trails[id] = trail
		_live.append(
			{
				"id": id,
				"pos": p,
				"vel": reader.projectile_vel(i),
				"look": _bolt_look,
				"trail": trail
			}
		)
		var bt := reader.projectile_bounce_tick(i)
		if bt >= 0 and _bounce_ticks.get(id, -1) != bt:
			flash(p, (_bolt_look["edge"] as Color).lerp(Color.WHITE, 0.5), 0.55)
		_bounce_ticks[id] = bt
	for d: Dictionary in [_trails, _bounce_ticks]:
		for id in d.keys():
			if not seen.has(id):
				d.erase(id)


## Overcharge's shockwave: the charged step's ON_NTH burst, drawn at the sim's radius.
func _sync_burst(reader: WorldReader) -> void:
	var oc := reader.overcharge_tick()
	if oc == _last_burst:
		return
	_last_burst = oc
	if oc < 0:
		return
	var child := hook_child(
		reader.attack_spec(reader.step_attack_id()), TRIGGER_ON_NTH, WorldReader.FORM_BURST
	)
	if child.is_empty():
		child = {"form": WorldReader.FORM_BURST}
	spawn(child, _player, 0.0, {"start": float(oc), "radius": reader.shockwave_radius_m()})


## A seeking beam's jump (Static Chain): from where it fired to the enemy it hit.
func _sync_chain(reader: WorldReader) -> void:
	var ct := reader.chain_tick()
	if ct == _last_chain:
		return
	_last_chain = ct
	if ct < 0:
		return
	var child := hook_child(
		reader.attack_spec(WorldReader.ATTACK_BOLT), TRIGGER_ON_HIT, WorldReader.FORM_BEAM
	)
	if child.is_empty():
		child = {"form": WorldReader.FORM_BEAM}
	var from := reader.chain_from()
	var to := reader.chain_to()
	spawn(child, from, (to - from).angle(), {"start": float(ct), "to": to})


func _sync_crits(reader: WorldReader) -> void:
	var player_id := reader.actor_id(0)
	var n := 0
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.DAMAGE or e.owner_id != player_id or e.target_id == player_id:
			continue
		if e.tags & SimEvent.TAG_DOT or (e.tags & SimEvent.TAG_CRIT) == 0 or n >= 8:
			continue
		n += 1
		flash(e.pos, AttackFormLooks.CRIT_FLASH, 0.8)


## The child spec of `spec`'s first hook on `trigger` whose child has `form` ({} if none).
static func hook_child(spec: Dictionary, trigger: int, form: int) -> Dictionary:
	for h: Dictionary in spec.get("hooks", []):
		var c: Dictionary = h.get("child", {})
		if int(h.get("trigger", -1)) == trigger and int(c.get("form", -1)) == form:
			return c
	return {}


# --- Drawing --------------------------------------------------------------------------------------------------
func _process(_delta: float) -> void:
	draw_at(float(_tick) + Engine.get_physics_interpolation_fraction())


## Lays every pool out for the frame at sim time `now` (ticks, fractional between ticks).
func draw_at(now: float) -> void:
	for p: AttackFormPool in pools.values():
		p.begin()
	for p: AttackFormPool in particle_pools.values():
		p.begin()
	_mesh_left = mesh_cap()
	_part_left = particle_cap()
	for b in _live:
		_draw_live_bolt(b, now)
	var keep: Array[Dictionary] = []
	for i in range(_effects.size() - 1, -1, -1):
		var e := _effects[i]
		var age := now - float(e["start"])
		if age > float(e["life"]) + 0.001:
			continue
		keep.append(e)
		if age < 0.0:
			continue
		if e["kind"] == &"flash":
			_draw_flash(e, age)
		else:
			_draw_form(e, age)
	keep.reverse()
	_effects = keep
	_drawn_meshes = mesh_cap() - _mesh_left
	_drawn_particles = particle_cap() - _part_left
	for p: AttackFormPool in pools.values():
		p.finish()
	for p: AttackFormPool in particle_pools.values():
		p.finish()


func _put(layer: StringName, xf: Transform3D, c: Color) -> bool:
	if _mesh_left <= 0:
		return false
	if not (pools[layer] as AttackFormPool).add(xf, c):
		return false
	_mesh_left -= 1
	return true


func _put_particle(kind: StringName, xf: Transform3D, c: Color) -> bool:
	if _part_left <= 0:
		return false
	if not (particle_pools[kind] as AttackFormPool).add(xf, c):
		return false
	_part_left -= 1
	return true


## A colour with its light multiplied by `energy` (over 1 feeds the glow) and alpha `a`.
static func lit_color(c: Color, a: float, energy: float) -> Color:
	return Color(c.r * energy, c.g * energy, c.b * energy, clampf(a, 0.0, 1.0))


## A flat piece at `p` turned to `yaw` (radians, sim angle), `sx` along it, `sz` across it, `sy` tall.
static func flat(p: Vector3, yaw: float, sx: float, sz: float, sy: float = 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sx, sy, sz)), p)


static func _dir(a: float) -> Vector2:
	return Vector2(cos(a), sin(a))


## A segment from `a` to `b` (3D) as a flat quad `width` wide.
static func segment(a: Vector3, b: Vector3, width: float) -> Transform3D:
	var d := b - a
	var yaw := atan2(-d.z, d.x)
	return flat((a + b) * 0.5, yaw, maxf(Vector2(d.x, d.z).length(), 0.001), width)


func _draw_form(e: Dictionary, age: float) -> void:
	var look: Dictionary = e["look"]
	match int(look["form"]):
		AttackFormLooks.ARC:
			_draw_arc(e, look, age)
		AttackFormLooks.BOLT:
			_draw_bolt(e, look, age)
		AttackFormLooks.RING:
			_draw_ring(e, look, age)
		AttackFormLooks.BEAM:
			_draw_beam(e, look, age)
		AttackFormLooks.ZONE:
			_draw_zone(e, look, age)
		AttackFormLooks.ORBITER:
			_draw_orbiter(e, look, age)
		AttackFormLooks.LOB:
			_draw_lob(e, look, age)
		AttackFormLooks.BURST:
			_draw_burst(e, look, age)


func _draw_arc(e: Dictionary, look: Dictionary, age: float) -> void:
	var life: float = e["life"]
	var sweep := clampf(age / maxf(life * 0.45, 1.0), 0.0, 1.0)
	var fade := clampf(1.0 - (age - life * 0.45) / maxf(life * 0.55, 1.0), 0.0, 1.0)
	var half: float = look["half_angle"]
	var own: float = e["own"]
	var r_out: float = own + float(look["reach"])
	var r_in := own + float(look["reach"]) * 0.45
	var r_mid := (r_in + r_out) * 0.5
	var thick: float = look["thick"]
	var energy: float = look["energy"]
	var seg_len := r_out * 2.0 * half / ARC_SEGMENTS * 1.15
	var points: Array[Vector3] = []
	for off: float in look["angles"]:
		var aim: float = float(e["angle"]) + off
		for k in ARC_SEGMENTS:
			var f := (k + 0.5) / ARC_SEGMENTS
			if f > sweep:
				break
			var a := aim - half + 2.0 * half * f
			var d := _dir(a)
			var head := 0.45 + 0.55 * (1.0 - clampf((sweep - f) * 2.0, 0.0, 1.0))
			var mid := SimPlane.to_3d(e["origin"] + d * r_mid, BODY_H)
			_put(
				&"arc_core",
				flat(mid, a, (r_out - r_in) * 0.8, seg_len),
				lit_color(look["core"], 0.5 * fade * head, energy)
			)
			var tip := SimPlane.to_3d(e["origin"] + d * (r_out - thick * 0.5), BODY_H)
			_put(
				&"arc_edge",
				flat(tip, a, thick, seg_len),
				lit_color(look["edge"], 0.85 * fade * head, energy)
			)
			points.append(tip)
	_emit(e, look, points, age, fade)


## A bolt's position `t` ticks after launch along copy direction `a0` (radians): straight, curving (home) or out and
## back (return).
func _bolt_at(e: Dictionary, look: Dictionary, a0: float, t: float, k: int) -> Vector2:
	var speed: float = look["speed"]
	var origin: Vector2 = e["origin"]
	var start := origin + _dir(a0) * float(e["own"])
	var cues: Array = look["cues"]
	if cues.has(&"curve"):
		var w := HOME_TURN * (1.0 if k % 2 == 0 else -1.0)
		var r := speed / w
		return start + Vector2(sin(a0 + w * t) - sin(a0), cos(a0) - cos(a0 + w * t)) * r
	var d := speed * t
	if cues.has(&"tether"):
		var half := float(e["life"]) * 0.5
		d = speed * (t if t < half else maxf(2.0 * half - t, 0.0))
	return start + _dir(a0) * d


func _draw_bolt(e: Dictionary, look: Dictionary, age: float) -> void:
	var fade := clampf((float(e["life"]) - age) / 4.0, 0.0, 1.0)
	var cues: Array = look["cues"]
	var segs := STREAK_SEGMENTS if cues.has(&"streak") else TAIL_SEGMENTS
	var points: Array[Vector3] = []
	var k := 0
	for off: float in look["angles"]:
		var a0: float = float(e["angle"]) + off
		var p := _bolt_at(e, look, a0, age, k)
		var prev := _bolt_at(e, look, a0, maxf(age - 0.5, 0.0), k)
		var heading := (p - prev).angle() if (p - prev).length() > 0.0001 else a0
		var at := SimPlane.to_3d(p, BOLT_H)
		var xf := Transform3D(
			(
				Basis(Vector3.UP, heading)
				* Basis.from_scale(Vector3(look["length"], look["thick"], look["thick"]))
			),
			at
		)
		_put(&"bolt_core", xf, lit_color(look["core"], fade, look["energy"]))
		_tail(e, look, a0, age, k, segs, fade)
		if cues.has(&"tether"):
			_put(
				&"cue",
				segment(SimPlane.to_3d(e["origin"], BOLT_H), at, 0.035),
				lit_color(look["edge"], 0.4 * fade, 1.4)
			)
		points.append(at)
		k += 1
	_emit(e, look, points, age, fade)


## The tail behind a constructed bolt: segments along its own path, fading to the back.
func _tail(
	e: Dictionary, look: Dictionary, a0: float, age: float, k: int, segs: int, fade: float
) -> void:
	var step := 1.5
	var w: float = float(look["thick"]) * 2.2
	for j in segs:
		var t0 := age - j * step
		var t1 := age - (j + 1) * step
		if t1 < 0.0:
			break
		var a := SimPlane.to_3d(_bolt_at(e, look, a0, t0, k), BOLT_H)
		var b := SimPlane.to_3d(_bolt_at(e, look, a0, t1, k), BOLT_H)
		var f := 1.0 - float(j) / segs
		_put(
			&"bolt_edge",
			segment(b, a, w * (0.5 + 0.5 * f)),
			lit_color(look["edge"], 0.6 * f * fade, look["energy"])
		)


func _draw_live_bolt(b: Dictionary, now: float) -> void:
	var look: Dictionary = b["look"]
	var trail: PackedVector2Array = b["trail"]
	var cues: Array = look["cues"]
	var segs := mini(trail.size() - 1, STREAK_SEGMENTS if cues.has(&"streak") else TAIL_SEGMENTS)
	var w: float = float(look["thick"]) * 2.2
	var n := trail.size()
	for j in segs:
		var a := SimPlane.to_3d(trail[n - 1 - j], BOLT_H)
		var c := SimPlane.to_3d(trail[n - 2 - j], BOLT_H)
		var f := 1.0 - float(j) / maxi(segs, 1)
		_put(
			&"bolt_edge",
			segment(c, a, w * (0.5 + 0.5 * f)),
			lit_color(look["edge"], 0.6 * f, look["energy"])
		)
	var at := SimPlane.to_3d(b["pos"], BOLT_H)
	# The v0.5 dart (ActorViews) is the core; the element rim glows round it.
	var heading := (b["vel"] as Vector2).angle()
	_put(
		&"bolt_core",
		Transform3D(
			(
				Basis(Vector3.UP, heading)
				* Basis.from_scale(
					Vector3(look["length"] * 1.25, look["thick"] * 1.8, look["thick"] * 1.8)
				)
			),
			at
		),
		lit_color(look["rim"], 0.45, look["energy"])
	)
	if cues.has(&"tether"):
		_put(
			&"cue",
			segment(SimPlane.to_3d(_player, BOLT_H), at, 0.035),
			lit_color(look["edge"], 0.4, 1.4)
		)
	var pts: Array[Vector3] = [at]
	_emit({"seed": int(b["id"]), "look": look}, look, pts, now, 1.0)


func _draw_ring(e: Dictionary, look: Dictionary, age: float) -> void:
	var count: int = look["count"]
	var life: float = e["life"]
	var each := maxf(life - RING_STAGGER * (count - 1), 4.0)
	var points: Array[Vector3] = []
	var fade_all := 1.0
	for k in count:
		var t := (age - RING_STAGGER * k) / each
		if t < 0.0 or t > 1.0:
			continue
		var r: float = float(look["radius"]) * (1.0 - (1.0 - t) * (1.0 - t))
		r = maxf(r, 0.05)
		var fade := 1.0 - t * t
		fade_all = fade
		var c := SimPlane.to_3d(e["origin"], GROUND_H)
		_put(
			&"ring_fill",
			Transform3D(Basis.from_scale(Vector3(r, 1, r)), c),
			lit_color(look["ground"], 0.55 * fade, look["energy"])
		)
		var h := 0.35 * float(look["width"])
		_put(
			&"ring_front",
			Transform3D(Basis.from_scale(Vector3(r, h, r)), c),
			lit_color(look["edge"], 0.75 * fade, look["energy"])
		)
		for j in 8:
			points.append(c + Vector3(cos(TAU * j / 8.0), 0.1, sin(TAU * j / 8.0)) * r)
	_emit(e, look, points, age, fade_all)


func _beam_end(e: Dictionary, look: Dictionary, off: float) -> Vector2:
	if bool(e.get("has_to", false)) and is_zero_approx(off):
		return e["to"]
	var origin: Vector2 = e["origin"]
	return origin + _dir(float(e["angle"]) + off) * (float(e["own"]) + float(look["length"]))


func _draw_beam(e: Dictionary, look: Dictionary, age: float) -> void:
	var t := age / maxf(float(e["life"]), 1.0)
	var fade := 1.0 - t * t
	var flicker := 0.8 + 0.2 * float((int(age) + int(e["seed"])) % 2)
	var points: Array[Vector3] = []
	for off: float in look["angles"]:
		var a := SimPlane.to_3d(e["origin"], BODY_H)
		var b := SimPlane.to_3d(_beam_end(e, look, off), BODY_H)
		var thick: float = look["thick"]
		_put(
			&"beam_core",
			segment(a, b, thick),
			lit_color(look["core"], fade * flicker, look["energy"])
		)
		_put(
			&"beam_edge",
			segment(a, b, thick * 2.8),
			lit_color(look["edge"], 0.45 * fade, look["energy"])
		)
		for j in 6:
			points.append(a.lerp(b, (j + 0.5) / 6.0))
	_emit(e, look, points, age, fade)


## Where copy `off` of a ground form sits: the origin for one copy, out along the pattern at its reach for more.
func _ground_at(e: Dictionary, look: Dictionary, off: float) -> Vector2:
	var origin: Vector2 = e["origin"]
	if int(look["count"]) <= 1:
		return origin
	return origin + _dir(float(e["angle"]) + off) * float(look["reach"])


func _draw_zone(e: Dictionary, look: Dictionary, age: float) -> void:
	var life: float = e["life"]
	var grow := clampf(age / 6.0, 0.0, 1.0)
	var fade := clampf((life - age) / maxf(life * 0.2, 1.0), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(age * 0.15 + float(e["seed"]))
	var points: Array[Vector3] = []
	for off: float in look["angles"]:
		var c := SimPlane.to_3d(_ground_at(e, look, off), GROUND_H)
		var r: float = float(look["radius"]) * (0.6 + 0.4 * grow)
		_put(
			&"zone_fill",
			Transform3D(Basis.from_scale(Vector3(r, 1, r)), c),
			lit_color(look["ground"], (0.28 + 0.08 * pulse) * fade, look["energy"])
		)
		_put(
			&"zone_rim",
			Transform3D(Basis.from_scale(Vector3(r, 1, r)), c + Vector3(0, 0.01, 0)),
			lit_color(look["ground_edge"], 0.7 * fade, look["energy"] * 1.4)
		)
		for j in 10:
			var h := _hash(int(e["seed"]), j)
			var rr := sqrt(_hash(int(e["seed"]) + 7, j)) * r * 0.9
			points.append(c + Vector3(cos(TAU * h), 0.05, sin(TAU * h)) * rr)
	_emit(e, look, points, age, fade)


func _draw_orbiter(e: Dictionary, look: Dictionary, age: float) -> void:
	var life: float = e["life"]
	var fade := clampf(minf(age / 4.0, (life - age) / 6.0), 0.0, 1.0)
	var n: int = look["count"]
	var orbit: float = look["reach"]
	var thick: float = look["thick"]
	var origin: Vector2 = e["origin"]
	var points: Array[Vector3] = []
	for k in n:
		var a: float = float(e["angle"]) + TAU * k / n + ORBIT_TURN * age
		var p := SimPlane.to_3d(origin + _dir(a) * orbit, BODY_H)
		var xf := Transform3D(
			(
				Basis(Vector3.UP, a + PI * 0.5)
				* Basis.from_scale(Vector3(thick * 2.4, thick * 0.45, thick * 0.9))
			),
			p
		)
		_put(&"orbiter_core", xf, lit_color(look["core"], fade, look["energy"]))
		for j in 3:
			var a0 := a - ORBIT_TURN * 2.0 * j
			var a1 := a - ORBIT_TURN * 2.0 * (j + 1)
			var f := 1.0 - j / 3.0
			_put(
				&"orbiter_edge",
				segment(
					SimPlane.to_3d(origin + _dir(a1) * orbit, BODY_H),
					SimPlane.to_3d(origin + _dir(a0) * orbit, BODY_H),
					thick * 0.9 * f
				),
				lit_color(look["edge"], 0.55 * f * fade, look["energy"])
			)
		points.append(p)
	_emit(e, look, points, age, fade)


func _draw_lob(e: Dictionary, look: Dictionary, age: float) -> void:
	var life: float = e["life"]
	var flight := life * 0.75
	var blast: float = look["radius"]
	var reach: float = look["reach"]
	var origin: Vector2 = e["origin"]
	var points: Array[Vector3] = []
	var fade := 1.0
	for off: float in look["angles"]:
		var target := origin + _dir(float(e["angle"]) + off) * reach
		var g := SimPlane.to_3d(target, GROUND_H)
		if age < flight:
			var s := age / flight
			var apex := 1.4 + reach * 0.12
			var p := SimPlane.to_3d(origin.lerp(target, s), BODY_H + 4.0 * apex * s * (1.0 - s))
			_put(
				&"lob_body",
				Transform3D(Basis.from_scale(Vector3.ONE * 0.34), p),
				Color(look["core"], 1.0).darkened(0.72)
			)
			_put(
				&"lob_glow",
				Transform3D(Basis.from_scale(Vector3.ONE * 0.12), p + Vector3(0, 0.17, 0)),
				lit_color(look["core"], 1.0, 3.0)
			)
			_put(
				&"lob_ground",
				Transform3D(Basis.from_scale(Vector3(blast, 1, blast)), g),
				lit_color(look["ground"], 0.3 + 0.6 * s, 1.2)
			)
			_put(
				&"lob_fill",
				Transform3D(Basis.from_scale(Vector3(blast * s, 1, blast * s)), g),
				lit_color(look["ground"], 0.18 * s, 1.0)
			)
			points.append(p)
		else:
			var u := clampf((age - flight) / maxf(life - flight, 1.0), 0.0, 1.0)
			fade = 1.0 - u
			var r := blast * (0.6 + 0.4 * u)
			_put(
				&"burst_fill",
				Transform3D(Basis.from_scale(Vector3(r, 1, r)), g),
				lit_color(look["ground"], 0.6 * fade, look["energy"])
			)
			_put(
				&"burst_front",
				Transform3D(Basis.from_scale(Vector3(r, 0.35 * float(look["width"]), r)), g),
				lit_color(look["edge"], 0.7 * fade, look["energy"])
			)
			for j in 8:
				points.append(g + Vector3(cos(TAU * j / 8.0), 0.1, sin(TAU * j / 8.0)) * r)
	_emit(e, look, points, age, fade)


func _draw_burst(e: Dictionary, look: Dictionary, age: float) -> void:
	var t := clampf(age / maxf(float(e["life"]), 1.0), 0.0, 1.0)
	var grow := 1.0 - (1.0 - t) * (1.0 - t)
	var fade := 1.0 - t
	var big_r: float = look["radius"]
	var points: Array[Vector3] = []
	for off: float in look["angles"]:
		var c := SimPlane.to_3d(_ground_at(e, look, off), GROUND_H)
		var r := big_r * (0.5 + 0.5 * grow)
		_put(
			&"burst_fill",
			Transform3D(Basis.from_scale(Vector3(r, 1, r)), c),
			lit_color(look["ground"], 0.65 * fade, look["energy"])
		)
		_put(
			&"burst_rim",
			Transform3D(Basis.from_scale(Vector3(big_r, 1, big_r)), c + Vector3(0, 0.01, 0)),
			lit_color(look["ground_edge"], 0.8 * fade, look["energy"])
		)
		_put(
			&"burst_front",
			Transform3D(Basis.from_scale(Vector3(r, 0.4 * float(look["width"]), r)), c),
			lit_color(look["edge"], 0.7 * fade, look["energy"])
		)
		for j in 10:
			points.append(c + Vector3(cos(TAU * j / 10.0), 0.1, sin(TAU * j / 10.0)) * r)
	_emit(e, look, points, age, fade)


func _draw_flash(e: Dictionary, age: float) -> void:
	var t := clampf(age / FLASH_TICKS, 0.0, 1.0)
	var s: float = float(e["size"]) * (1.0 - 0.6 * t)
	var p := SimPlane.to_3d(e["origin"], BOLT_H)
	_put(
		&"flash",
		Transform3D(Basis.from_scale(Vector3(s, 1, s)), p),
		lit_color(e["color"], 1.0 - t, 3.0)
	)
	var n := maxi(1, int(round(6 * particle_scale())))
	for j in n:
		var a := TAU * _hash(int(e["seed"]), j)
		var d := Vector3(cos(a), 0.6 * _hash(int(e["seed"]) + 3, j), sin(a)) * (0.2 + 0.7 * t)
		_put_particle(
			&"sparks",
			Transform3D(Basis.from_scale(Vector3.ONE * 0.05), p + d),
			lit_color(e["color"], 1.0 - t, 2.5)
		)


# --- Particles ------------------------------------------------------------------------------------------------
## A stable pseudo-random number in [0, 1) for (a, b): presentation only, the same every frame (no state).
static func _hash(a: int, b: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65536.0


## The element particles of effect `e` round `points` at `age`: each kind's share of the form's count (scaled by the
## density), each particle cycling over a short period from a point chosen by its hash.
func _emit(
	e: Dictionary, look: Dictionary, points: Array[Vector3], age: float, fade: float
) -> void:
	var parts: Array = look["particles"]
	if parts.is_empty() or points.is_empty() or fade <= 0.0:
		return
	var total := int(
		round(PARTICLES[int(look["form"])] * particle_scale() * maxf(1.0, points.size() / 4.0))
	)
	total = mini(total, 64)
	var sd: int = e["seed"]
	for pk: Array in parts:
		var kind: StringName = pk[0]
		var col: Color = pk[1]
		var n := maxi(1, int(ceil(total * float(pk[2]))))
		for j in n:
			var r1 := _hash(sd, j * 3 + 1)
			var r2 := _hash(sd, j * 3 + 2)
			var r3 := _hash(sd + 11, j)
			var period := 14.0 + 8.0 * r3
			var u := fposmod(age + r1 * period, period) / period
			var p: Vector3 = points[int(r2 * points.size()) % points.size()]
			if not _put_particle(
				kind,
				_particle_xf(kind, p, u, r1, r2, r3, age, j),
				_particle_color(kind, col, u, fade, age, j)
			):
				if _part_left <= 0:
					return
				break  # this kind's pool is full; the other kind may still have room


static func _particle_xf(
	kind: StringName, p: Vector3, u: float, r1: float, r2: float, r3: float, age: float, j: int
) -> Transform3D:
	var a := TAU * r1
	var out := Vector3(cos(a), 0, sin(a))
	match kind:
		&"sparks":
			var pos := (
				p
				+ out * u * 0.5 * (0.5 + r2)
				+ Vector3.UP * (u * 0.9 - u * u * 1.1) * (0.6 + r3 * 0.6)
			)
			return Transform3D(Basis.from_scale(Vector3.ONE * 0.05), pos)
		&"crackle":
			var step := floori(age / 3.0)
			var h := _hash(j * 31 + step, int(r1 * 1000.0))
			var pos := p + Vector3(cos(TAU * h), (h - 0.5) * 0.3, sin(TAU * h)) * 0.22
			var b := Basis.from_euler(Vector3(PI * h, TAU * r2, PI * 0.5 * (0.5 + r3)))
			return Transform3D(b * Basis.from_scale(Vector3(0.025, 0.32, 0.025)), pos)
		&"shards":
			var pos := p + out * u * 0.35 + Vector3.UP * (0.15 - u * 0.3)
			var b := Basis.from_euler(Vector3(r1 * TAU + u * 3.0, r2 * TAU, 0.6))
			return Transform3D(b * Basis.from_scale(Vector3(0.06, 0.17, 0.06)), pos)
		&"drip":
			var pos := p + out * 0.08 * r2 + Vector3.DOWN * u * 0.4
			return Transform3D(Basis.from_scale(Vector3(0.045, 0.09 * (1.0 + u), 0.045)), pos)
	# smear: a flat streak stretching as it fades
	return flat(p + out * 0.1 * u, a, 0.45 * (0.4 + u), 0.15)


static func _particle_color(
	kind: StringName, c: Color, u: float, fade: float, age: float, j: int
) -> Color:
	match kind:
		&"sparks":
			return lit_color(c, (1.0 - u) * fade, 2.4)
		&"crackle":
			var on := 1.0 if (floori(age / 3.0) + j) % 2 == 0 else 0.35
			return lit_color(c, on * fade, 2.8)
		&"shards":
			return lit_color(c, (1.0 - u) * fade, 1.7)
		&"drip":
			return lit_color(c, (1.0 - u * u) * fade, 1.4)
	return lit_color(c, 0.45 * (1.0 - u) * fade, 1.3)
