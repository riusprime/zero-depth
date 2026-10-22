class_name Lance
extends RefCounted
## v0.9.0 AF1 (owner Q7 "F5 Lance, F6 Scatter, F7 Glaive"; ATTACK_FORMS.md F5: "Hold to charge, release one piercing
## line shot; longer charge, more damage", "up to 1.2 s, ×1 → ×5 damage, pierces all", elements "all: along the
## line"; it replaces the Charge card, retired through data/wand/migration.tres): the Lance form, the Gun's shot as a
## charged line (AttackSpec.lance, set by the Lance card, data/modifiers/gun_lance.tres).
## - The charge: GunForms' hold (the Charge card's rule, World.mx.hold_t): while SHOOT is held and the shot is ready
##   the charge grows one tick a tick up to hold_ticks (1.2 s); unlike the Charge card it stays full until SHOOT is let
##   go (a full Lance waits for the release). Releasing fires one Lance at × 1000 + (hold_permille − 1000) × held /
##   hold_ticks per mille of the shot's damage (× 1 for a tap, × 5 at full). The Gun then waits its period (0.4 s;
##   attack speed at half its bonus, AttackRate.form_rate) before the next charge starts. A dash, a guard or a stun
##   while charging drops the charge (GunForms.hold, as the Charge card did).
## - The line: from the hero's edge along the aim, reach_m long (10.8 m, as far as an orb flies) and radius_m wide; a
##   wall stops it; it pierces every enemy on it (each takes one hit, nearest first). trace() is the one geometry: the
##   release's hits and the view's aim line (EI-07).
## - Elements along the line: each enemy hit is a full hit of the Lance's spec (its statuses feed, its On Hit and On
##   Kill hooks run), as a piercing bolt's would; its On End hooks run where the line ends. One release is one root.
## - Twin: its lanes (2 side by side at Lv 1–4, 3 fanned at Lv 5, GunForms.lanes), each at Twin's share (Attacks'
##   share rule); the lines past the primary at the secondary proc.
## - Caps: a Lance is no projectile; it never counts in the projectile caps (ShotCap) and launches none.
## - One LANCE event a line (the view's release flash, the sound): pos = the line's start, amount = its length (mm),
##   amount_applied = its angle (1/4096 turns), proc_pct = the charge (per mille of the shot's damage), effect_id = the
##   spec's key.
## Pure: integer maths and Collide's sweeps, no randomness, one clock.

## Twin's lines sit GunForms.TWIN_GAP_RADII of this apart (about 0.5 m, as the Laser's beams).
const LANE_RADIUS_M := 0.2


## `s` is the Lance (its shot charges and releases a line).
static func is_lance(s: AttackSpec) -> bool:
	return s != null and s.lance > 0


## The run's Gun shot is the Lance now.
static func active(w: World) -> bool:
	return PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w) and is_lance(Modifiers.bolt(w))


## 0..1: how far the Lance in hand has charged (0 when it isn't charging).
static func charge(w: World) -> float:
	return GunForms.charge_fraction(w) if active(w) else 0.0


## The lines of `spec` from `origin` along `angle` now (pure read): one per Twin lane, {from, to, hits (actor indices,
## nearest first), at (each hit's point), wall (it ended on a wall)}. The view draws the same (WorldReader.lance_lines).
static func trace(w: World, spec: AttackSpec, origin: Vector2, angle: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lanes := GunForms.lanes(spec, LANE_RADIUS_M)
	var turns := GunForms.lane_turns(spec)
	for li in lanes.size():
		var a := (angle + turns[li]) & 4095
		var dir := Kin.dir(a)
		var from := origin + dir * w.player.radius_m + Vector2(-dir.y, dir.x) * lanes[li]
		var line := _ray(w, spec, from, dir)
		line["angle"] = a
		out.append(line)
	return out


static func _ray(w: World, spec: AttackSpec, from: Vector2, dir: Vector2) -> Dictionary:
	var to := from + dir * spec.reach_m
	var r := spec.radius_m
	var wall := 1.0
	for k in w.walls_along(from, to, r):  # the grid's superset of the walls
		var s := Collide.sweep_vs_obb(from, to, r, w.walls[k])
		if s >= 0.0 and s < wall:
			wall = s
	var ts := PackedFloat32Array()
	var ids := PackedInt32Array()
	var a := w.actors
	for i in range(1, a.size()):  # every actor, as the Laser's beam (no grid before the tick's)
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
			continue
		var s := Collide.sweep_vs_circle(from, to, r, a.pos(i), a.radius[i])
		if s < 0.0 or s >= wall:
			continue
		var at := ts.size()  # nearest first; a tie keeps the lower index
		while at > 0 and ts[at - 1] > s:
			at -= 1
		ts.insert(at, s)
		ids.insert(at, i)
	var pts := PackedVector2Array()
	for s in ts:
		pts.append(from + (to - from) * s)
	return {
		"from": from, "to": from + (to - from) * wall, "hits": ids, "at": pts, "wall": wall < 1.0
	}


## One release of the Lance `spec` launched with `ctx` (Attacks._form; ctx.damage is already the charge's and Twin's
## share, ctx.size_permille the charge): every lane hits everything on it (the class doc). True if a hit landed.
static func fire(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	var lines := trace(w, spec, ctx.origin, ctx.angle)
	var centre := (lines.size() - 1) / 2  # the primary line: the first of two, the middle of three
	var root := ctx.root if ctx.root > 0 else w.take_root()
	var pid := w.actors.ids[0]
	var landed := false
	for li in lines.size():
		var l: Dictionary = lines[li]
		var from: Vector2 = l["from"]
		var to: Vector2 = l["to"]
		var e := w.emit_event(SimEvent.Kind.LANCE, pid, pid, pid, from)
		e.root_id = root
		e.amount = int(round((to - from).length() * 1000.0))
		e.amount_applied = int(l["angle"])
		e.proc_pct = ctx.size_permille
		e.effect_id = StringName(spec.key)
		var c := AttackContext.make(
			ctx.origin, int(l["angle"]), ctx.damage, root, ctx.tags, ctx.effect_id
		)
		c.base_damage = ctx.base_damage
		c.secondary = ctx.secondary or li != centre
		c.repeat = ctx.repeat
		c.depth = ctx.depth
		c.proc_pct = ctx.proc_pct
		var hits: PackedInt32Array = l["hits"]
		var pts: PackedVector2Array = l["at"]
		for k in hits.size():
			landed = Attacks.land(w, spec, c, hits[k], from, pts[k]) > 0 or landed
		Attacks.run_on_end(w, spec, c, to)
	return landed
