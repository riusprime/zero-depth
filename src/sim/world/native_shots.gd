class_name NativeShots
extends RefCounted
## The projectile phase (World._projectile_hits) with its sweep run by the native side (World.native;
## native/src/zd_shots.cpp): each projectile's segment this tick against the walls and the bodies of the other team,
## the earliest contact first, a tie going to the wall and then to the lower body; Void and Wave shots meet walls
## only; a Mine disc holding is not swept. Three passes:
## 1. the steering, in GDScript (ProjectileMoves.steer for every projectile when any has a behaviour, then a Gravity
##    Node's bend), before the sweep instead of interleaved with the hits;
## 2. one native call: projectiles that meet nothing are advanced there (pos_x, pos_y and life come back as new
##    arrays), and the rest come back as a list of events, at most one a projectile, in ascending projectile order;
## 3. the events in that order, in GDScript: a Mine's pulse (GlaiveMods.hold), the end of range, or the contact run
##    through ProjectileContacts (the hit rules: damage, procs, pierce, bounce, the end hooks). A contact whose body
##    died earlier in this phase is swept again (sweep_one), so a dead body is never hit.
## The bodies are swept where they stood when the phase began, so a body pushed by an earlier hit of the same tick is
## met at its old place. Deterministic: the native side keeps nothing between calls.

## The events sweep_shots lists (ShotsScratch::HOLD, CONTACT, END).
const HOLD := 0
const CONTACT := 1
const END := 2


static func sweep(w: World) -> void:
	var pp := w.phase_probe
	var p := w.projectiles
	var n := p.size()
	if n == 0:
		return
	if pp != null:
		pp.begin(&"proj.steer")
	var pull := StarfallKinds.nodes(w) if not w.enemy_tables.is_empty() else PackedFloat32Array()
	if p.moves or not pull.is_empty():
		for i in n:
			var held := ProjectileMoves.steer(w, i)  # Orbit first, homing, the way back
			if not pull.is_empty() and not held:  # A Gravity Node bends it (after its form's steering)
				StarfallKinds.bend_projectile(w, i, pull)
	var skip := PackedByteArray()
	if not w.mx.gm_kind.is_empty():
		skip.resize(n)
		for i in n:
			skip[i] = 1 if GlaiveMods.held(w, i) else 0
	var through := _walls_only(w)
	if pp != null:
		pp.end(&"proj.steer")
		pp.begin(&"proj.sweep")
	NativeWorld.sync_walls(w)
	var count: int = w.native.sweep_shots(p, w.actors, skip, through)
	if pp != null:
		pp.end(&"proj.sweep")
	if count < 0:
		push_error("NativeShots: the native sweep refused the projectile columns")
		return
	var ev: PackedInt32Array = w.native.shot_events()
	var et: PackedFloat32Array = w.native.shot_t()
	var dead := PackedInt32Array()
	for e in count:
		var code := ev[e * 4]
		var i := ev[e * 4 + 1]
		if code == HOLD:
			GlaiveMods.hold(w, i)  # A Mine disc spins in place (no sweep), hitting
			continue
		var at := Vector2(p.pos_x[i], p.pos_y[i])
		if code == END:
			ProjectileContacts.range_end(w, i, at)
			dead.append(i)
			continue
		var actor := ev[e * 4 + 2]
		var wall := ev[e * 4 + 3]
		var t := et[e]
		if actor >= 0 and w.actors.dead[actor] == 1:  # Killed by an earlier hit this phase
			var again: PackedFloat32Array = w.native.sweep_one(
				p, w.actors, i, not through.is_empty() and through[i] == 1
			)
			t = again[0]
			actor = int(again[1])
			wall = int(again[2])
		if ProjectileContacts.apply(w, i, at, Vector2(p.vel_x[i], p.vel_y[i]), t, actor, wall):
			dead.append(i)
	if pp != null:
		pp.begin(&"proj.remove")
	p.remove_sorted(dead)
	if pp != null:
		pp.end(&"proj.remove")


## One byte a projectile, 1 for a Void or Wave shot (it passes through bodies; only walls end it), or empty when
## there is none. The answer depends on the projectile's spec only, so each spec is asked once.
static func _walls_only(w: World) -> PackedByteArray:
	var p := w.projectiles
	var out := PackedByteArray()
	var seen := {}
	for i in p.size():
		if p.team[i] != ActorStore.TEAM_PLAYER or i >= p.spec_key.size() or p.spec_key[i] == "":
			continue
		var key := p.spec_key[i]
		var hit: Variant = seen.get(key)
		if hit == null:
			hit = VoidShots.is_void_projectile(w, i) or WaveShots.is_wave_projectile(w, i)
			seen[key] = hit
		if hit:
			if out.is_empty():
				out.resize(p.size())
				out.fill(0)
			out[i] = 1
	return out
