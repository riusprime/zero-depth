class_name WaveShots
extends RefCounted
## v0.9.0 AF3 (owner Q7 "F8 Seekers, F9 Wave, F10 Wisps"; ATTACK_FORMS.md F9: "A wide slow wave that rolls forward
## through everything", "3 m wide, 6 m/s, pierces, every 0.9 s", Twin and Backfire yes, the rest off, elements "all"):
## the Wave form, the Gun's shot as a wide band (AttackSpec.wave_mm, set by the Wave card,
## data/modifiers/gun_wave.tres). Not the Blade's Wave (the Echo Slash card, echo_slash): this one is the Gun's, id
## gun_wave, and carries no "wave" tag, so Split Wave never reads it.
## - The shot: the Gun's bolt, one every 0.9 s (attack speed at half its bonus, AttackRate.form_rate) at 6 m/s, as far
##   as an orb flies (10.8 m). It passes through enemies (World's projectile pass skips them, as the Void's); a wall or
##   the end of its flight ends it.
## - The band: wave_mm wide (3 m; the area stat scales it), centred on the shot and square to its flight, DEPTH_M deep.
##   Every enemy whose body the band rolls over takes the shot's hit once (Attacks.land: its elements, its On Hit and
##   On Kill hooks); the wait is per shot and enemy for the rest of the shot's flight (ModifierState.void_*, the
##   Void's per-shot waits: one list keyed by shot id), so a Twin's copies each hit and nothing is hit twice by one
##   wave. A wall between the shot and an enemy shields it (a band never hits round a corner).
## - Twin: its lanes at its share (2 side by side, 3 fanned at Lv 5); Backfire a wave behind. Caps: one projectile a
##   wave (ShotCap's 12 an attack and 40 a second hold).
## Pure (EI-02): float maths and Collide's sweeps, no randomness (EI-05), the one clock (EI-03).

## The band's depth along the flight (m): deep enough that nothing walking at it slips between two ticks.
const DEPTH_M := 0.5


## `s` is a Wave shot (the Wave form's).
static func is_wave(s: AttackSpec) -> bool:
	return s != null and s.wave_mm > 0


## Projectile `pi` is the player's Wave shot (its own spec is one).
static func is_wave_projectile(w: World, pi: int) -> bool:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER or pi >= p.spec_key.size() or p.spec_key[pi] == "":
		return false
	return is_wave(Attacks.projectile_spec(w, pi))


## The run's Gun shot is the Wave now.
static func active(w: World) -> bool:
	return PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w) and is_wave(Modifiers.bolt(w))


## Half the band's width of `s` now (m): wave_mm / 2, the area stat on it.
static func half_m(w: World, s: AttackSpec) -> float:
	return Stats.area(w, s.wave_mm / 2000.0)


## Tick phase 6 (ModifierRuntime.advance, after VoidShots.advance clears the waits that are over): each Wave shot's
## band hits what it rolls over.
static func advance(w: World) -> void:
	if w.player_dead() or not active(w):
		return
	for pi in _shots(w):
		_band(w, pi)


## The player's Wave shots now (projectile indices, ascending).
static func _shots(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for pi in w.projectiles.size():
		if is_wave_projectile(w, pi):
			out.append(pi)
	return out


static func _waiting(s: ModifierState, shot: int, foe: int) -> bool:
	for k in s.void_shot.size():
		if s.void_shot[k] == shot and s.void_foe[k] == foe:
			return true
	return false


## The enemies shot `pi`'s band covers now (actor indices, ascending; pure: the hit and the tests read it).
static func covered(w: World, pi: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var p := w.projectiles
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var speed := Kin.length(v)
	if speed <= 0.0:
		return out
	var dir := v / speed
	var at := Vector2(p.pos_x[pi], p.pos_y[pi])
	var half := half_m(w, Attacks.projectile_spec(w, pi))
	var a := w.actors
	for i in w.enemies_near(at, half + DEPTH_M):
		var off := a.pos(i) - at
		var along := off.dot(dir)
		var across := off.dot(Vector2(-dir.y, dir.x))
		var r := a.radius[i]
		if absf(along) > DEPTH_M * 0.5 + r or absf(across) > half + r:
			continue
		if _walled(w, at, a.pos(i)):
			continue
		out.append(i)
	return out


## A wall stands between `from` and `to`.
static func _walled(w: World, from: Vector2, to: Vector2) -> bool:
	for k in w.walls_along(from, to, 0.0):
		var s := Collide.sweep_vs_obb(from, to, 0.0, w.walls[k])
		if s >= 0.0 and s < 1.0:
			return true
	return false


## Shot `pi`'s band: every enemy under it that this shot hasn't hit takes its hit (the class doc).
static func _band(w: World, pi: int) -> void:
	var spec := Attacks.projectile_spec(w, pi)
	var p := w.projectiles
	var s := w.mx
	var at := Vector2(p.pos_x[pi], p.pos_y[pi])
	var sid := p.ids[pi]
	var ctx: AttackContext = null
	for i in covered(w, pi):
		var aid := w.actors.ids[i]
		if _waiting(s, sid, aid):
			continue
		s.void_shot.append(sid)
		s.void_foe.append(aid)
		s.void_next.append(w.tick + p.life[pi] + 2)  # gone with the shot (VoidShots.advance drops it)
		if ctx == null:
			var ang := Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi]))
			ctx = AttackContext.make(at, ang, p.damage[pi], w.take_root(), p.tags[pi], &"")
			ctx.depth = spec.depth
			ctx.proc_pct = maxi(1, 100 >> spec.depth)
			ctx.secondary = (p.second_of(pi) & ProjectileStore.SECONDARY) != 0
		Attacks.land(w, spec, ctx, i, at, w.actors.pos(i))


## The Wave shots in flight for the views: [{id, pos, dir, half (m), depth (m)}], in projectile order.
static func read(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not active(w):
		return out
	var p := w.projectiles
	for pi in _shots(w):
		var v := Vector2(p.vel_x[pi], p.vel_y[pi])
		var sp := Kin.length(v)
		(
			out
			. append(
				{
					"id": p.ids[pi],
					"pos": Vector2(p.pos_x[pi], p.pos_y[pi]),
					"dir": v / sp if sp > 0.0 else Vector2.RIGHT,
					"half": half_m(w, Attacks.projectile_spec(w, pi)),
					"depth": DEPTH_M,
				}
			)
		)
	return out
