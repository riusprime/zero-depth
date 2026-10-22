class_name AvatarBase
extends Node3D
## What the stand-alone creature avatars share (audit P-1): the player's and the Charger, Warden, Needle, Arc Caster,
## Bomb Drone and horde models. The bosses have their own base (BossAvatar) and parts library (BossParts).
## Presentation only (EI-07): each avatar's sync() reads the sim through WorldReader once per tick, advance() animates
## in frame time, and nothing here feeds back into the sim. Each avatar keeps its own advance() and pose.

## Faster than this many ticks between two syncs is a gap, not motion (the velocity is dropped).
const MOTION_GAP_TICKS := 30
## v0.8.0 TG: the windup tell (tell_crouch / tell_glow): the crouch is full by this share of the windup, the flash
## runs from TELL_FLASH_FROM to the strike, the extra glow (a multiple of the accent's rest energy) at the end of
## the climb and at the flash, and the flash's flicker rate (none with reduced motion). Starting values.
const TELL_CROUCH_BY := 0.6
const TELL_FLASH_FROM := 0.8
const TELL_GLOW_CLIMB := 1.5
const TELL_GLOW_FLASH := 2.5
const TELL_FLICKER_HZ := 9.0
## v0.8.0 GF2 (owner O20: "the enemy should flinch. That doesn't mean to move"): a hit's flinch, a pose recoil away
## from the hit drawn on this node only (the sim body never moves): FLINCH_SECONDS long, the lean back (radians) and
## the squash (the share the body shortens; it widens by half that) at full strength, peaking at FLINCH_PEAK of the
## way and snapping back with a small overshoot (FLINCH_SNAP). A new hit restarts it only once the last one has run
## FLINCH_RETRIGGER_S, so steady fire keeps it twitching instead of holding it bent. Reduced motion: FLINCH_CALM of
## it. Starting values.
const FLINCH_SECONDS := 0.2
const FLINCH_LEAN := 0.3
const FLINCH_SQUASH := 0.16
const FLINCH_PEAK := 0.25
const FLINCH_SNAP := 0.18
const FLINCH_RETRIGGER_S := 0.12
const FLINCH_CALM := 0.4
## v0.8.0 GF3 (owner O22): a Blade hit also knocks the pose away from the swing by up to FLINCH_KNOCK_M (metres, at
## the flinch's peak and strength 1; the node only, back to rest exactly). Starting value.
const FLINCH_KNOCK_M := 0.09
## v0.8.0 P1 (owner O26: "Their arm movements don't communicate attacks properly"): every melee enemy's strike reads
## in two beats. The strike pose (claws, fists, shield, mandibles drawn back or up) is fully raised by STRIKE_RAISE_BY
## of the windup's progress (the sim's telegraph progress, not a timer) and held there to the hit; at the hit tick (the
## sim's ACTIVE state, first seen by a sync) the strike snaps out over STRIKE_SNAP_S, accelerating, stays out while the
## attack is active and STRIKE_HOLD_S after, then eases back over STRIKE_BACK_S. Frame time only animates the motion
## the sim's state started; nothing here decides anything. Starting values.
const STRIKE_RAISE_BY := 0.35
const STRIKE_SNAP_S := 0.07
const STRIKE_HOLD_S := 0.12
const STRIKE_BACK_S := 0.35

## The outlined body materials (ActorViews flashes them on a hit).
var body_materials: Array[StandardMaterial3D] = []
## v0.8.0 HR (O89): for an avatar on EnemyLooks' shared materials (the horde kinds, the Charger and Hatchling): the
## biome's cast on the grey parts (ActorViews.enemy_tint) and the role glow's energy (ActorViews.role_glow_energy;
## 0: none), set by ActorViews before setup(): they pick the shared body materials (they were applied to the avatar's
## own materials after it was built: ActorViews.tint_greys / role_glow). Its pieces carrying a body plate (the hit
## flash goes to them, show_hit) and the HIT last set on them.
var enemy_tint := Color(0, 0, 0, 0)
var role_glow := 0.0
var _hit_pieces: Array[GeometryInstance3D] = []
var _hit := EnemyLooks.HIT_OFF
# Sim state from the last sync.
var _fresh := true
var _last_tick := -1
var _last_pos := Vector2.ZERO
var _vel := Vector2.ZERO
# Frame time since the model was built (seconds).
var _t := 0.0
# v0.8.0 GF2: the flinch running (seconds into it; FLINCH_SECONDS or more: none), its strength, the push's direction
# on the sim plane (away from the hit), and this node's own transform at rest (a Hatchling is built at two thirds).
var _flinch_t := FLINCH_SECONDS
var _flinch_s := 0.0
var _flinch_dir := Vector2.RIGHT
var _rest_xf := Transform3D.IDENTITY
## v0.8.0 GF3: the knock of the flinch running (metres at its peak; 0: none, a bolt's).
var _flinch_knock := 0.0
## v0.8.0 GF3 (owner O22, the Blade's hit-stop): frame seconds the pose is held still for (HitStop): the frame time
## that falls inside it is dropped, the rest of that frame runs on, so the pose resumes where it stopped (no pop).
var _hold := 0.0
## v0.8.0 P1: the strike running: frame seconds since the hit tick was seen (-1: none), and how many of them it had
## run when the attack left ACTIVE (-1 while still active).
var _strike_s := -1.0
var _strike_end_s := -1.0


func _process(delta: float) -> void:
	var dt := consume_hold(delta)
	if dt <= 0.0:
		return
	advance(dt)
	advance_flinch(dt)


## v0.8.0 GF3: holds the pose still for `seconds` of frame time (the longer of this and a hold already running; never
## stacked). A flinch running jumps to its peak first, so the hold shows the impact pose. Presentation only.
func hold(seconds: float) -> void:
	_hold = maxf(_hold, seconds)
	if flinching() and _flinch_t < FLINCH_PEAK * FLINCH_SECONDS:
		_flinch_t = FLINCH_PEAK * FLINCH_SECONDS
		advance_flinch(0.0)


func holding() -> bool:
	return _hold > 0.0


## v0.8.0 GF3: the share of `delta` left once a hold has taken its part (the hold counts down by what it took).
func consume_hold(delta: float) -> float:
	if _hold <= 0.0:
		return delta
	var used := minf(_hold, maxf(delta, 0.0))
	_hold -= used
	return delta - used


## v0.8.0 GF2: a hit pushes the body's pose away along `away` (sim plane, the hit's direction) at `strength` (1: a
## bolt). False when the last flinch is too young to restart (FLINCH_RETRIGGER_S).
## v0.8.0 GF3: `knock` (0..1, a Blade hit's) also shifts the pose away by up to FLINCH_KNOCK_M.
func flinch(away: Vector2, strength: float = 1.0, knock: float = 0.0) -> bool:
	if flinching() and _flinch_t < FLINCH_RETRIGGER_S:
		return false
	if not flinching():
		_rest_xf = transform
	var calm := FLINCH_CALM if ViewPrefs.reduced_motion else 1.0
	_flinch_t = 0.0
	_flinch_s = clampf(strength, 0.0, 1.5) * calm
	_flinch_knock = clampf(knock, 0.0, 1.0) * FLINCH_KNOCK_M * calm
	_flinch_dir = away.normalized() if away.length_squared() > 1e-6 else Vector2.RIGHT
	return true


## v0.8.0 GF3: how far the pose is knocked away now (metres).
func knock_amount() -> float:
	return maxf(flinch_envelope(_flinch_t / FLINCH_SECONDS), 0.0) * _flinch_knock


func flinching() -> bool:
	return _flinch_t < FLINCH_SECONDS


## 0..1 (a little under 0 in the snap back): the flinch's envelope now, times its strength.
func flinch_amount() -> float:
	return flinch_envelope(_flinch_t / FLINCH_SECONDS) * _flinch_s


## The flinch's shape over its life u (0..1): out fast to 1 at FLINCH_PEAK, back past 0 by FLINCH_SNAP, settled at 1.
static func flinch_envelope(u: float) -> float:
	if u <= 0.0 or u >= 1.0:
		return 0.0
	if u < FLINCH_PEAK:
		var a := u / FLINCH_PEAK
		return 1.0 - (1.0 - a) * (1.0 - a)
	var b := (u - FLINCH_PEAK) / (1.0 - FLINCH_PEAK)
	return (1.0 - b) * (1.0 - b) * (1.0 - b) - FLINCH_SNAP * sin(PI * b) * (1.0 - b)


## Steps the flinch by `delta` seconds of frame time and poses this node: a lean away from the hit about the pivot
## (_flinch_pivot), a squash; at rest the node's own transform comes back exactly.
func advance_flinch(delta: float) -> void:
	if not flinching():
		return
	_flinch_t += clampf(delta, 0.0, 0.05)
	if not flinching():
		transform = _rest_xf
		return
	var k := flinch_amount()
	var yaw := (get_parent() as Node3D).rotation.y if get_parent() is Node3D else 0.0
	var d := (
		Basis(Vector3.UP, yaw + _rest_xf.basis.get_euler().y).inverse()
		* SimPlane.to_3d(_flinch_dir)
	)
	var axis := Vector3.UP.cross(d).normalized()
	var squash := Vector3(
		1.0 + 0.5 * FLINCH_SQUASH * k, 1.0 - FLINCH_SQUASH * k, 1.0 + 0.5 * FLINCH_SQUASH * k
	)
	var b := Basis(axis, FLINCH_LEAN * k) * Basis.from_scale(squash)
	var p := Vector3(0, _flinch_pivot(), 0)
	transform = _rest_xf * Transform3D(b, p - b * p + d * knock_amount())


## The point the flinch leans about, metres above the feet in this node's frame (a hovering body leans about itself).
func _flinch_pivot() -> float:
	return 0.0


## Advances the animation by `delta` seconds of frame time (each avatar its own).
func advance(_delta: float) -> void:
	pass


## v0.8.0 P1: 0..1 how far the strike pose is raised at windup progress p: full by STRIKE_RAISE_BY, then held.
static func strike_raise(p: float) -> float:
	return smoothstep(0.0, STRIKE_RAISE_BY, clampf(p, 0.0, 1.0))


## v0.8.0 P1: notes the sim state each sync: the first sync in ACTIVE starts the strike, leaving ACTIVE ends its
## active part (the hold and the ease back follow).
func strike_note(state: int) -> void:
	if state == WorldReader.STATE_ACTIVE:
		if _strike_s < 0.0 or _strike_end_s >= 0.0:
			_strike_s = 0.0
			_strike_end_s = -1.0
	elif _strike_s >= 0.0 and _strike_end_s < 0.0:
		_strike_end_s = _strike_s


## v0.8.0 P1: runs the strike's motion by `dt` seconds of frame time.
func strike_advance(dt: float) -> void:
	if _strike_s < 0.0:
		return
	_strike_s += dt
	var after := _strike_s - maxf(STRIKE_SNAP_S, _strike_end_s)
	if _strike_end_s >= 0.0 and after > STRIKE_HOLD_S + STRIKE_BACK_S:
		_strike_s = -1.0
		_strike_end_s = -1.0


## v0.8.0 P1: 0..1 how far the strike is out now: accelerating out over STRIKE_SNAP_S from the hit tick, out while
## the attack is active and STRIKE_HOLD_S after, then back over STRIKE_BACK_S.
func strike_swing() -> float:
	if _strike_s < 0.0:
		return 0.0
	if _strike_s < STRIKE_SNAP_S:
		var u := _strike_s / STRIKE_SNAP_S
		return u * u
	if _strike_end_s < 0.0:
		return 1.0
	var after := _strike_s - maxf(STRIKE_SNAP_S, _strike_end_s)
	if after <= STRIKE_HOLD_S:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (after - STRIKE_HOLD_S) / STRIKE_BACK_S)


## v0.8.0 P1: whether the strike is still snapping out (its first STRIKE_SNAP_S).
func strike_snapping() -> bool:
	return _strike_s >= 0.0 and _strike_s < STRIKE_SNAP_S


## v0.8.0 P1: the raised pose's share now: from the windup's progress while it winds up (`winding`), falling to 0 as
## the strike snaps out, 0 while it is out, and `rest` (the avatar's own eased value) otherwise.
func strike_raised(winding: bool, p: float, rest: float) -> float:
	if winding:
		return strike_raise(p)
	if strike_snapping():
		return minf(rest, 1.0 - _strike_s / STRIKE_SNAP_S)
	return rest if _strike_s < 0.0 else 0.0


## v0.8.0 TG (owner O4, Q3): the melee kinds, the Sniper and the Needle draw no ground mark while they wind up, so
## their bodies carry the read. From the windup's progress p (0..1, WorldReader.telegraph()["progress"] / 1000, the
## same number the old ground fill grew with): a crouch / draw-back that deepens over the first TELL_CROUCH_BY of the
## windup, and an eye / visor / muzzle glow that climbs with p and flashes from TELL_FLASH_FROM until the strike. The
## direction reads from the body itself: the sim holds an enemy's facing through its windup (EnemyAi), and
## ActorViews turns the model to it, unsmoothed. Reduced motion (ViewPrefs.reduced_motion): no flicker, the flash
## is a steady step up; the crouch is a slow pose and stays. Starting values: TELL_* above.


## 0..1: how deep the windup crouch is at progress p.
static func tell_crouch(p: float) -> float:
	return smoothstep(0.0, TELL_CROUCH_BY, clampf(p, 0.0, 1.0))


## Whether progress p is in the flash just before the strike.
static func tell_flashing(p: float) -> bool:
	return p >= TELL_FLASH_FROM and p <= 1.0


## The accent glow's multiplier at progress p (1 at rest), `t` the frame-time clock, `calm` reduced motion.
static func tell_glow(p: float, t: float, calm: bool) -> float:
	var q := clampf(p, 0.0, 1.0)
	var g := 1.0 + TELL_GLOW_CLIMB * smoothstep(0.0, TELL_FLASH_FROM, q)
	if tell_flashing(q):
		var flicker := 1.0 if calm else 0.75 + 0.25 * cos(t * TAU * TELL_FLICKER_HZ)
		g += TELL_GLOW_FLASH * flicker
	return g


## The windup progress (0..1) of actor i as the view reads it: its telegraph's progress while it winds up, else 0.
static func windup_progress(reader: WorldReader, i: int) -> float:
	if reader.actor_state(i) != WorldReader.STATE_WINDUP:
		return 0.0
	return float(reader.telegraph(i).get("progress", 0)) / 1000.0


## The share of the way to a target an exponential ease covers in `dt` at `per_second`.
func _rate(per_second: float, dt: float) -> float:
	return 1.0 - exp(-per_second * dt)


## The velocity (m/s) from the last sync's position to `pos` at `tick`: zero after a teleport (faster than
## `teleport_speed`), a long gap or a rewind; then remembers this tick and position.
func _track_motion(tick: int, pos: Vector2, teleport_speed: float) -> void:
	if not _fresh and tick > _last_tick:
		var v := (pos - _last_pos) * (60.0 / float(tick - _last_tick))
		_vel = (
			v
			if v.length() <= teleport_speed and tick - _last_tick <= MOTION_GAP_TICKS
			else Vector2.ZERO
		)
	elif tick < _last_tick:
		_vel = Vector2.ZERO
	_last_tick = tick
	_last_pos = pos


## One outlined, flashable body piece under `parent` (its material in body_materials), and with technique "xray"
## its silhouette in the team colour through walls. Unlike BossParts.piece, the vertex colours are not the albedo
## unless asked. v0.8.0 HR (O89): the silhouette is a pass of the piece's own material (EnemyLooks.xray, shared per
## team colour, shrunk as the twin was), no longer a second MeshInstance3D with its own material.
func _outlined(
	parent: Node3D,
	mesh: Mesh,
	at: Vector3,
	c: Color,
	outline: Color,
	team: Color,
	technique: StringName,
	outline_m: float,
	vertex_colors := false,
	piece_name := ""
) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	if not piece_name.is_empty():
		piece.name = piece_name
	piece.mesh = mesh
	piece.position = at
	var mat := outline_material(c, outline, outline_m)
	if vertex_colors:
		mat.vertex_color_use_as_albedo = true
	piece.material_override = mat
	parent.add_child(piece)
	body_materials.append(ActorViews.flashable(mat))
	if technique == &"xray":
		EnemyLooks.chain_xray(mat, EnemyLooks.xray(team, EnemyLooks.XRAY_SHRINK, 0.0))
	return piece


## v0.8.0 HR: the hit flash or a status tint (`on`: `c` at `energy` instead of the rest glow; off: the rest glow), on
## every body piece of this avatar (its shared materials' HIT); nothing is set when it is already showing
## (ActorViews._set_flash calls it).
func show_hit(on: bool, c: Color = Color.WHITE, energy: float = 0.0) -> void:
	var v := EnemyLooks.hit_value(on, c, energy)
	if v == _hit:
		return
	_hit = v
	for piece in _hit_pieces:
		piece.set_instance_shader_parameter(EnemyLooks.HIT, v)


## v0.8.0 HR: the HIT now on the body pieces (tests: Vector4 rgb the linear emission x energy, w 1 = shown).
func hit_look() -> Vector4:
	return _hit


## v0.8.0 HR: this avatar's body pieces on shared materials (tests).
func hit_pieces() -> Array[GeometryInstance3D]:
	return _hit_pieces


## v0.8.0 HR: the shared body materials this avatar draws with, each once, in build order (tests, tools).
func body_looks() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for piece in _hit_pieces:
		var mi := piece as MeshInstance3D
		var mats: Array[Material] = [mi.material_override]
		for k in mi.get_surface_override_material_count():
			mats.append(mi.get_surface_override_material(k))
		for m in mats:
			if EnemyLooks.is_body(m) and not out.has(m):
				out.append(m)
	return out


## v0.8.0 HR: the shared body material (EnemyLooks.body) for a plate of `p_kind` in colour `c` (times `tex` when
## given), outlined in `outline` `outline_m` thick, then `xray_pass`; `two_sided`: drawn from both sides. The biome's
## cast pulls a grey plate toward enemy_tint and a role-coloured one rests at role_glow of its own colour, as
## ActorViews.tint_greys and role_glow did to the avatar's own materials.
func shared_body(
	p_kind: int,
	c: Color,
	tex: Texture2D,
	outline: Color,
	outline_m: float,
	xray_pass: Material,
	two_sided := false
) -> ShaderMaterial:
	var albedo := ActorViews.grey_tinted(c, enemy_tint)
	var rest: Array = ActorViews.NO_GLOW
	if role_glow > 0.0 and EnemyPalettes.KIND_IDS.has(p_kind) and ActorViews.role_glows(albedo):
		rest = [Color(albedo, 1.0), role_glow]
	return EnemyLooks.body(albedo, tex, rest[0], rest[1], outline, outline_m, xray_pass, two_sided)


## An opaque body material with the stencil outline.
static func outline_material(c: Color, outline: Color, outline_m: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 1.0
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	mat.stencil_color = outline
	mat.stencil_outline_thickness = outline_m
	return mat


## A body piece's X-ray twin: the same mesh a little smaller, drawn in the team colour where walls hide it (the
## Charger's merged body still uses it; _outlined chains EnemyLooks.xray onto the piece's material instead).
static func xray_twin(
	parent: Node3D, mesh: Mesh, c: Color, team: Color, at: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var ghost := MeshInstance3D.new()
	ghost.mesh = mesh
	var gm := StandardMaterial3D.new()
	gm.albedo_color = c
	gm.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
	gm.stencil_color = Color(team, 0.85)
	ghost.material_override = gm
	ghost.position = at
	ghost.scale = Vector3.ONE * 0.96
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ghost)
	return ghost


## A face, visor or glow marks the stencil like the body pieces do, so the X-ray twins behind it stay hidden.
static func write_stencil(m: StandardMaterial3D) -> void:
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	m.stencil_reference = 1


## Appends one flat-shaded triangle facing away from `centre` (Godot's front faces wind clockwise).
static func _tri(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	centre: Vector3
) -> void:
	var n := (b - a).cross(c - a)
	if n.dot((a + b + c) / 3.0 - centre) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = n.normalized()
	verts.append_array([a, c, b])
	normals.append_array([n, n, n])


## Flat-shaded triangles of a solid around `centre`, each turned to face away from it (Godot's front faces wind
## clockwise); degenerate ones are dropped.
static func flat_mesh(tris: Array, centre: Vector3) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for t: Array in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue
		if n.dot((a + b + c) / 3.0 - centre) < 0.0:
			var tmp := b
			b = c
			c = tmp
			n = -n
		n = n.normalized()
		verts.append_array([a, c, b])
		normals.append_array([n, n, n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
