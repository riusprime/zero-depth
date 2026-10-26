class_name WardenAvatar
extends AvatarBase
## The Warden (owner, v0.2.0 L17; docs/art/enemies_visual_reference.png, the third creature): a hulking grey rock
## golem. A long faceted red shell covers its head and back, with a dark visor frame and a glowing red slot at the
## front; big boulder shoulders, heavy forearm rocks and fists that hang almost to the ground; a dark chest under the
## shell and two short stumpy legs on lighter stone feet. No shield: the Warden takes less damage from the front and
## more from the back, so the front reads armoured (fists, chest) and the shell's back is split by glowing cracks,
## the weak spot. Presentation only (EI-07): sync() reads the sim through WorldReader once per tick, advance()
## animates in frame time, and nothing here feeds back into the sim.
## +X is the front and +Z the right in every local frame; the node sits at the actor's feet under ActorViews' facing.
## v0.8.0 TG (owner O4, Q3): its slam disc is no longer drawn on the ground; the windup reads from the body (AvatarBase
## "tell"): the fists climb overhead, the knees bend into a crouch that deepens with the windup's progress, and the
## visor brightens and flashes just before the slam.
## v0.8.0 P1 (owner O25: "The large enemy also needs a visible ground-smash animation"; O26): a full overhead slam. The
## fists climb overhead and the chest heaves back by STRIKE_RAISE_BY of the windup (AvatarBase.strike_raise) and hold
## there, trembling, to the hit tick; then they come down hard in STRIKE_SNAP_S, the chest pitching forward and the
## knees dropping, the fists land at the front and stay down through the first part of the recovery, and a dust ring
## runs out over the slam's circle (its radius from the telegraph) from the impact. The red circle itself is back on
## the ground (TelegraphViews; EnemyAi.telegraph "ground": true).

## Hips (leg pivots) and the chest pivot above them, in metres from the ground.
const HIP_Y := 0.3
## Shoulder pivots, in the chest frame: behind the middle, high, wide.
const SHOULDER := Vector3(-0.08, 0.52, 0.5)
## Walking speed the gait is tuned for (the Warden's 1.6 m/s) and the stride (metres per full two-step cycle).
const WALK_SPEED := 1.6
const STRIDE := 0.95
## Faster than this between two ticks is a teleport (a new floor), not motion.
const TELEPORT_SPEED := 30.0
## Shoulder angles (radians about the side axis; + swings the arm forward and up): fists overhead in the windup,
## down on the ground at the front corners in the slam (the arms also swing out, so the iso camera sees the fists
## land beside the shell, not under it).
const ARM_UP := 2.75
const ARM_SLAM := 0.25
## v0.8.0 P1: the chest's heave back at the top of the raise and its pitch forward in the slam (radians), and how far
## the hips drop when the fists land (metres).
const RAISE_LEAN := 0.24
const SLAM_PITCH := 0.42
const SLAM_DROP := 0.12
## v0.8.0 P1: the dust ring: it runs from DUST_START of the slam's radius to its full radius over DUST_SECONDS from the
## impact, fading out; its band is DUST_BAND of the radius wide. Its colour is neutral dust, not a reserved role.
const DUST_SECONDS := 0.45
const DUST_START := 0.3
const DUST_BAND := 0.22
const DUST_ALPHA := 0.9
const DUST_COLOR := Color("#F4EEE2")
const DUST_SEGMENTS := 40
## The slam's radius when no telegraph gave one (data/enemies/warden.tres, slam radius_m).
const SLAM_RADIUS := 2.4
## Recovery is the attack's 0.667 s (data/enemies/warden.tres, a starting value); the fists rise over its end.
const RECOVER_TICKS := 40
## Seconds to rise out of the ground once the spawn-in ends.
const RISE_SECONDS := 0.45
const OUTLINE_M := 0.02

## Colours sampled from the reference sheet (lit facets read lighter in game light). Each facet of the shell and the
## rocks is tinted a little lighter or darker (vertex colours), so the planes stay distinct under any light.
## v0.8.0 EC: the shell (body), the visor frame (trim), the rocks (grey) and the visor (eye) come from EnemyPalettes.
const FACET_TINT := 0.16
const FIST_COLOR := Color("#68564F")
const CHEST_COLOR := Color("#2A2D33")
const LEG_COLOR := Color("#3B383B")
const FOOT_COLOR := Color("#705D55")
## The weak spot's glow: hotter than the shell, so the back reads as the place to hit.
const CRACK_COLOR := Color("#FF8A3C")

## The shell's rings, back to front: x (chest frame), half-width, half-height, centre height. The back is a flat,
## lower plate (the weak spot); the shell is longest over the back, as in the sheet's side view.
const SHELL_RINGS := [
	[-0.42, 0.27, 0.22, 0.53],
	[-0.3, 0.34, 0.27, 0.56],
	[0.0, 0.37, 0.29, 0.57],
	[0.24, 0.36, 0.3, 0.58],
	[0.36, 0.3, 0.3, 0.58],
]
## The front edge is notched up around the visor frame: the bottom pair of the last two rings rises to these
## heights (unit section y), as on the sheet's front view.
const SHELL_NOTCH := [-0.8, -0.25]

## The shell's cross-section as unit points (z, y), round from the top centre through the right: a ridge on top,
## sloped shoulders, near-vertical sides, and a bottom that narrows in to the visor.
const SHELL_SECTION := [
	Vector2(0.0, 1.08),
	Vector2(0.62, 0.84),
	Vector2(0.98, 0.42),
	Vector2(0.9, -0.55),
	Vector2(0.62, -1.0),
	Vector2(0.3, -1.0),
	Vector2(-0.3, -1.0),
	Vector2(-0.62, -1.0),
	Vector2(-0.9, -0.55),
	Vector2(-0.98, 0.42),
	Vector2(-0.62, 0.84),
]

## Body meshes, built once and shared by every Warden.
static var _meshes := {}

## Parts, read by tests and by ActorViews (flash materials).
var shell: MeshInstance3D
var visor: MeshInstance3D
var weak_spot: Node3D
var arms: Array[Node3D] = []
var fists: Array[Node3D] = []
var legs: Array[Node3D] = []
## v0.8.0 P1: the impact's dust ring (hidden between slams).
var dust: MeshInstance3D

var _body := Node3D.new()
var _chest := Node3D.new()
var _elbows: Array[Node3D] = []
var _visor_mat := StandardMaterial3D.new()
var _crack_mat := StandardMaterial3D.new()
var _technique := &"outline"
var _outline := Color.BLACK
# Sim state from the last sync.
var _state := WorldReader.STATE_MOVE
var _state_ticks := 0
var _windup := 0.0
# Smoothed animation state.
var _speed := 0.0
var _walk := 0.0
var _phase := 0.0
var _raise := 0.0
var _slam := 0.0
var _rise := 1.0
var _shake := 0.0
# v0.8.0 P1: the slam's radius (the telegraph's, read in the windup), and seconds since the impact (-1: no dust).
var _slam_r := SLAM_RADIUS
var _dust_t := -1.0
var _dust_mat := StandardMaterial3D.new()


## Builds the model (rim outline only; no X-ray silhouette since v0.9.5 PF1).
func setup(outline_color: Color, technique: StringName = &"outline") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_outline = outline_color
	_technique = technique
	add_child(_body)
	_chest.position.y = HIP_Y
	_body.add_child(_chest)
	_piece(_chest, &"pelvis", Vector3(0.0, 0.02, 0), Vector3(0.42, 0.2, 0.44), CHEST_COLOR, 3)
	_piece(_chest, &"chest", Vector3(0.02, 0.2, 0), Vector3(0.56, 0.42, 0.54), CHEST_COLOR, 4)
	shell = _piece(_chest, &"shell", Vector3.ZERO, Vector3.ONE, _color(&"body"), 0)
	_build_visor()
	_build_weak_spot()
	for side in [-1.0, 1.0]:
		_build_arm(side)
		_build_leg(side)
	_build_dust()
	_pose(0.0)


## Reads actor i's state after a sim tick.
func sync(reader: WorldReader, i: int) -> void:
	var tg := reader.telegraph(i)
	apply_state(
		{
			"tick": reader.tick(),
			"pos": reader.actor_pos(i),
			"state": reader.actor_state(i),
			"windup": float(tg.get("progress", 0)) / 1000.0,
			"radius": float(tg.get("radius", _slam_r)),
		}
	)


## The same as sync(), from plain values (tests drive the avatar with this): tick, pos, state (a WorldReader
## STATE_*), windup (0..1, the telegraph's progress), radius (optional: the slam's, from the telegraph).
func apply_state(s: Dictionary) -> void:
	var tick: int = s["tick"]
	var pos: Vector2 = s["pos"]
	var state: int = s["state"]
	var dt_ticks := tick - _last_tick
	if _fresh or state != _state:
		_state_ticks = 0
	elif dt_ticks > 0:
		_state_ticks += dt_ticks
	_track_motion(tick, pos, TELEPORT_SPEED)
	_state = state
	_windup = clampf(s.get("windup", 0.0), 0.0, 1.0)
	if state == WorldReader.STATE_WINDUP and s.has("radius"):
		_slam_r = maxf(float(s["radius"]), 0.5)
	strike_note(state)  # v0.8.0 P1: the hit tick starts the slam's downswing
	if _fresh:
		_fresh = false
		_rise = 0.0 if state == WorldReader.STATE_SPAWN else 1.0
		_pose(0.0)


## Advances the animation by `delta` seconds of frame time.
func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or shell == null:
		return
	_t += dt
	_speed = lerpf(_speed, _vel.length(), _rate(10.0, dt))
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt / RISE_SECONDS)
	# v0.8.0 P1: Windup: the fists climb overhead by STRIKE_RAISE_BY of its progress and hold there, trembling.
	# The hit tick: they come down hard (strike_swing's snap). Recover: they stay on the ground, then rise back.
	var was_snapping := strike_snapping()
	strike_advance(dt)
	var winding := _state == WorldReader.STATE_WINDUP
	_raise = strike_raised(winding, _windup, move_toward(_raise, 0.0, dt * 6.0))
	var hold := 0.0
	if _state == WorldReader.STATE_RECOVER:
		hold = 1.0 - smoothstep(0.35, 1.0, float(_state_ticks) / RECOVER_TICKS)
	var swing := strike_swing()
	if strike_snapping():
		_slam = maxf(swing, _slam)
	elif swing > 0.0 or hold > 0.0:
		_slam = maxf(swing, hold)
	else:
		_slam = lerpf(_slam, 0.0, _rate(6.0, dt))
	if was_snapping and not strike_snapping():
		_shake = 1.0  # the impact
		_dust_t = 0.0
	_shake = move_toward(_shake, 0.0, dt * 4.0)
	_advance_dust(dt)
	_pose(dt)


## 0..1: how far the fists are raised overhead (the windup pose).
func raise_amount() -> float:
	return _raise


## 0..1: how far the fists are slammed down (the attack and its recovery).
func slam_amount() -> float:
	return _slam


## v0.8.0 TG: 0..1 how deep the windup crouch is (from the windup's progress).
func crouch_amount() -> float:
	return tell_crouch(_windup) if _state == WorldReader.STATE_WINDUP else 0.0


## The visor's current glow (emission energy).
func visor_energy() -> float:
	return _visor_mat.emission_energy_multiplier


## The fists' mean height above the feet, in this node's frame.
func fist_height() -> float:
	var sum := 0.0
	for f in fists:
		sum += (global_transform.affine_inverse() * f.global_position).y
	return sum / maxf(1.0, fists.size())


func _pose(dt: float) -> void:
	var busy := maxf(_raise, _slam)
	var walk_target := 0.0 if busy > 0.3 else clampf(_speed / WALK_SPEED, 0.0, 1.0)
	_walk = lerpf(_walk, walk_target, _rate(6.0, dt))
	_phase += _speed * dt * TAU / STRIDE * (1.0 - busy)
	var s := sin(_phase)
	# Heavy breathing at rest; a rolling, lumbering sway when walking.
	var breath := sin(_t * 1.7) * (1.0 - _walk) * (1.0 - busy)
	var bob := absf(s) * 0.03 * _walk
	# v0.8.0 TG: the windup's knees-bent crouch (no disc on the ground any more), deepening with its progress.
	var calm := ViewPrefs.reduced_motion
	var tell_c := crouch_amount()
	var crouch := _raise * 0.03 + _slam * SLAM_DROP + tell_c * 0.07
	var hip := HIP_Y + bob + breath * 0.008 - crouch
	# Spawn-in: up out of the ground, leaning back as it comes.
	var sink := 1.0 - _rise
	sink = sink * sink * (3.0 - 2.0 * sink)
	_body.position = Vector3(0, -1.35 * sink, 0)
	_body.rotation = Vector3(s * 0.06 * _walk, 0, -0.25 * sink)
	var tremble := 0.0 if calm else sin(_t * 47.0) * 0.012 * _raise * smoothstep(0.6, 1.0, _windup)
	_chest.position = Vector3(tremble - tell_c * 0.05, hip, 0)
	# The chest leans back to heave the fists up, then pitches forward into the slam.
	var lean := 0.06 * _walk + _raise * RAISE_LEAN - _slam * SLAM_PITCH - _shake * 0.05
	_chest.rotation = Vector3(-s * 0.05 * _walk, cos(_phase) * 0.06 * _walk, lean)
	_chest.scale = Vector3(1.0, 1.0 + breath * 0.012, 1.0 + breath * 0.01)
	var winding := _state == WorldReader.STATE_WINDUP
	var tell := tell_glow(_windup, _t, calm) if winding else 1.0
	_visor_mat.emission_energy_multiplier = (2.4 + 4.0 * _raise) * tell + 2.0 * _shake
	_crack_mat.emission_energy_multiplier = 1.8 + 0.5 * sin(_t * 3.4) + 1.5 * _raise
	for k in arms.size():
		var side := -1.0 if k == 0 else 1.0
		# Walking: the arms swing against the legs; idle: they hang, a little forward.
		var hang := 0.12 + side * s * 0.28 * _walk + breath * 0.02
		var swing := lerpf(lerpf(hang, ARM_UP, _raise), ARM_SLAM, _slam)
		# Raised, they come in over the head so the fists meet; slammed, they swing out to the front corners.
		var roll := -side * (_raise * 0.42 + _slam * 0.4)
		arms[k].rotation = Vector3(roll, 0, swing)
		_elbows[k].rotation = Vector3(0, 0, _raise * 0.7 + 0.12 * (1.0 - busy) - _slam * 0.1)
		arms[k].position = SHOULDER * Vector3(1, 1, side) + Vector3(0, breath * 0.01, 0)
	for k in legs.size():
		var sgn := -1.0 if k == 0 else 1.0
		legs[k].rotation = Vector3(0, 0, s * 0.42 * _walk * sgn)
		legs[k].position = Vector3(0, hip, sgn * 0.19)


## v0.8.0 P1: 0..1 how far the impact's dust ring has run (-1: none showing).
func dust_amount() -> float:
	return clampf(_dust_t / DUST_SECONDS, 0.0, 1.0) if _dust_t >= 0.0 else -1.0


## v0.8.0 P1: the slam's radius the dust ring runs out to (the telegraph's).
func slam_radius() -> float:
	return _slam_r


func _advance_dust(dt: float) -> void:
	if _dust_t < 0.0:
		dust.visible = false
		return
	_dust_t += dt
	var u := _dust_t / DUST_SECONDS
	if u >= 1.0:
		_dust_t = -1.0
		dust.visible = false
		return
	var ease := 1.0 - (1.0 - u) * (1.0 - u)
	var r := _slam_r * lerpf(DUST_START, 1.0, ease)
	dust.visible = true
	dust.scale = Vector3(r, 1.0, r)
	var c := DUST_COLOR
	c.a = DUST_ALPHA * (1.0 - u) * (1.0 - u * 0.5)
	_dust_mat.albedo_color = c


## v0.8.0 P1: the dust ring: a flat band (unit outer radius) just above the floor, unshaded and see-through, laid flat
## on the ground under the Warden (the node's own frame: its facing doesn't matter for a ring).
func _build_dust() -> void:
	dust = MeshInstance3D.new()
	dust.name = "SlamDust"
	dust.mesh = _dust_mesh()
	# v0.8.0 TX2: the owner's dust ring (fx_dust_ring's first cell) on a flat quad, its ragged ring at the same unit
	# radius (it sits at BossStrikeShapes.DUST_RING_R of the quad's side), tinted the same neutral dust.
	var tex := BossStrikeMeshes.texture("fx_dust_ring")
	if tex != null:
		var q := PlaneMesh.new()
		q.size = Vector2.ONE / BossStrikeShapes.DUST_RING_R
		dust.mesh = q
		_dust_mat.albedo_texture = tex
		_dust_mat.uv1_scale = Vector3(0.5, 0.5, 1.0)
	_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dust_mat.albedo_color = Color(DUST_COLOR, 0.0)
	dust.material_override = _dust_mat
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.position = Vector3(0, 0.05, 0)
	dust.visible = false
	add_child(dust)


static func _dust_mesh() -> ArrayMesh:
	var m: Mesh = _meshes.get(&"dust")
	if m != null:
		return m as ArrayMesh
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var inner := 1.0 - DUST_BAND
	for k in DUST_SEGMENTS:
		var a0 := TAU * k / DUST_SEGMENTS
		var a1 := TAU * (k + 1) / DUST_SEGMENTS
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		verts.append_array([o0, o1 * inner, o0 * inner, o0, o1, o1 * inner])
		for j in 6:
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[&"dust"] = out
	return out


func _build_visor() -> void:
	_piece(
		_chest, &"visor_frame", Vector3(0.39, 0.37, 0), Vector3(0.1, 0.28, 0.17), _color(&"trim"), 0
	)
	visor = MeshInstance3D.new()
	var vb := BoxMesh.new()
	vb.size = Vector3(0.02, 0.17, 0.075)
	visor.mesh = vb
	_visor_mat.albedo_color = _color(&"eye")
	_visor_mat.emission_enabled = true
	_visor_mat.emission = _color(&"eye")
	_visor_mat.emission_energy_multiplier = 2.4
	write_stencil(_visor_mat)
	visor.material_override = _visor_mat
	visor.position = Vector3(0.445, 0.37, 0)
	visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chest.add_child(visor)


## The weak spot: glowing cracks across the shell's flat back plate and a hot core showing through the split.
func _build_weak_spot() -> void:
	weak_spot = Node3D.new()
	weak_spot.name = "WeakSpot"
	weak_spot.position = Vector3(_shell_x(0) - 0.004, _shell_cy(0), 0)
	weak_spot.scale = Vector3(1, 1.15, 1.3)
	_chest.add_child(weak_spot)
	_crack_mat.albedo_color = CRACK_COLOR
	_crack_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_crack_mat.emission_enabled = true
	_crack_mat.emission = CRACK_COLOR
	_crack_mat.emission_energy_multiplier = 1.8
	write_stencil(_crack_mat)
	var cracks := MeshInstance3D.new()
	cracks.mesh = _crack_mesh()
	cracks.material_override = _crack_mat
	cracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weak_spot.add_child(cracks)


func _build_arm(side: float) -> void:
	var tag := "r" if side > 0 else "l"
	var arm := Node3D.new()
	arm.name = "Arm_" + tag
	_chest.add_child(arm)
	_piece(
		arm, &"shoulder", Vector3(0, 0, side * 0.01), Vector3(0.36, 0.38, 0.34), _color(&"grey"), 11
	)
	var elbow := Node3D.new()
	elbow.position = Vector3(0.0, -0.17, side * 0.03)
	arm.add_child(elbow)
	_piece(
		elbow,
		&"forearm",
		Vector3(0.1, -0.19, side * 0.04),
		Vector3(0.46, 0.4, 0.5),
		_color(&"grey"),
		23
	)
	var fist := Node3D.new()
	fist.name = "Fist_" + tag
	fist.position = Vector3(0.16, -0.5, -side * 0.01)
	elbow.add_child(fist)
	_piece(fist, &"fist", Vector3.ZERO, Vector3(0.38, 0.31, 0.4), FIST_COLOR, 37)
	arms.append(arm)
	_elbows.append(elbow)
	fists.append(fist)


func _build_leg(side: float) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, HIP_Y, side * 0.19)
	_body.add_child(pivot)
	_piece(pivot, &"leg", Vector3(0, -0.12, 0), Vector3(0.2, 0.22, 0.19), LEG_COLOR, 5)
	_piece(pivot, &"foot", Vector3(0.03, -0.245, 0), Vector3(0.29, 0.11, 0.25), FOOT_COLOR, 7)
	legs.append(pivot)


## v0.8.0 EC: the Warden's colour in `slot` under the active palette.
static func _color(slot: StringName) -> Color:
	return EnemyPalettes.color(WorldReader.KIND_WARDEN, slot)


## One body piece: a faceted rock (or the shell) with an outline, its X-ray twin, and its material in
## body_materials. Meshes are built once and shared by every Warden (the facets never change).
func _piece(
	parent: Node3D, key: StringName, at: Vector3, size: Vector3, c: Color, salt: int
) -> MeshInstance3D:
	var mesh: Mesh = _meshes.get(key)
	if mesh == null:
		if key == &"shell":
			mesh = _shell_mesh()
		elif key == &"visor_frame":
			mesh = _box(size)
		else:
			mesh = _rock(size, salt)
		_meshes[key] = mesh
	return _outlined(
		parent,
		mesh,
		at,
		c,
		_outline,
		ThemePalette.color(&"enemy_body"),
		_technique,
		OUTLINE_M,
		key != &"visor_frame",
		String(key).capitalize().replace(" ", "")
	)


# --- meshes -----------------------------------------------------------------------------------------------------


func _shell_x(k: int) -> float:
	return SHELL_RINGS[k][0]


func _shell_cy(k: int) -> float:
	return SHELL_RINGS[k][3]


static func _shell_mesh() -> ArrayMesh:
	var rings: Array = []
	for k in SHELL_RINGS.size():
		var r: Array = SHELL_RINGS[k]
		var ring: Array[Vector3] = []
		for j in SHELL_SECTION.size():
			var p: Vector2 = SHELL_SECTION[j]
			if k >= SHELL_RINGS.size() - 2 and (j == 5 or j == 6):
				p.y = SHELL_NOTCH[k - (SHELL_RINGS.size() - 2)]
			# A small fixed wobble breaks the rings into uneven facets, as on the sheet.
			var w := 1.0 + (_noise(k * 31 + j * 7) - 0.5) * 0.08 * float(k > 0 and k < 4)
			ring.append(Vector3(r[0], r[3] + p.y * r[2] * w, p.x * r[1] * w))
		rings.append(ring)
	var tris := []
	var n := SHELL_SECTION.size()
	for k in rings.size() - 1:
		var a: Array[Vector3] = rings[k]
		var b: Array[Vector3] = rings[k + 1]
		for j in n:
			var j2 := (j + 1) % n
			if (j + k) % 2 == 0:
				tris.append([a[j], a[j2], b[j2]])
				tris.append([a[j], b[j2], b[j]])
			else:
				tris.append([a[j], a[j2], b[j]])
				tris.append([a[j2], b[j2], b[j]])
	# The back plate and the front face: fans round a centre point.
	var back: Array[Vector3] = rings[0]
	var front: Array[Vector3] = rings[rings.size() - 1]
	var bc := Vector3(SHELL_RINGS[0][0], SHELL_RINGS[0][3], 0)
	var fc := Vector3(SHELL_RINGS[4][0] + 0.06, SHELL_RINGS[4][3] + 0.08, 0)
	for j in n:
		var j2 := (j + 1) % n
		tris.append([bc, back[j], back[j2]])
		tris.append([fc, front[j], front[j2]])
	return _mesh_from(tris, Vector3(-0.03, 0.56, 0), 3)


## A chunky faceted boulder of the given size: a six-sided block with big near-vertical sides and bevelled top and
## bottom rings closed by flat-ish caps, each vertex nudged by a fixed wobble from `salt` so the faces break unevenly.
static func _rock(size: Vector3, salt: int) -> ArrayMesh:
	const SIDES := 6
	# [height, radius, turn (in half steps)] from the bottom cap up.
	var levels := [[-0.5, 0.6, 1], [-0.3, 1.0, 0], [0.28, 1.0, 0], [0.5, 0.62, 1]]
	var rings: Array = []
	for k in levels.size():
		var ring: Array[Vector3] = []
		for j in SIDES:
			var h := salt * 97 + k * 13 + j * 5
			var turn: int = levels[k][2]
			var ang := TAU * (float(j) + 0.5 * turn) / SIDES + (_noise(h) - 0.5) * 0.3
			var rad: float = levels[k][1] * (0.9 + _noise(h + 1) * 0.16)
			var y: float = levels[k][0] + (_noise(h + 2) - 0.5) * 0.1
			ring.append(
				Vector3(cos(ang) * rad * 0.5 * size.x, y * size.y, sin(ang) * rad * 0.5 * size.z)
			)
		rings.append(ring)
	var tris := []
	for k in rings.size() - 1:
		var a: Array[Vector3] = rings[k]
		var b: Array[Vector3] = rings[k + 1]
		for j in SIDES:
			var j2 := (j + 1) % SIDES
			if levels[k][2] == levels[k + 1][2]:
				tris.append([a[j], a[j2], b[j2]])
				tris.append([a[j], b[j2], b[j]])
			elif levels[k][2] == 1:
				tris.append([a[j], b[j2], b[j]])
				tris.append([a[j], a[(j + 1) % SIDES], b[j2]])
			else:
				tris.append([a[j], a[j2], b[j]])
				tris.append([a[j2], b[j2], b[j]])
	var bottom: Array[Vector3] = rings[0]
	var top: Array[Vector3] = rings[rings.size() - 1]
	var bc := Vector3(0, -0.52 * size.y, 0)
	var tc := Vector3((_noise(salt) - 0.5) * 0.1 * size.x, 0.53 * size.y, 0)
	for j in SIDES:
		var j2 := (j + 1) % SIDES
		tris.append([bc, bottom[j], bottom[j2]])
		tris.append([tc, top[j], top[j2]])
	return _mesh_from(tris, Vector3.ZERO, salt)


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## The glowing cracks on the back plate (plane x = 0 of the weak-spot node, facing -X): a jagged split down the
## middle with branches, as thin flat strips.
static func _crack_mesh() -> ArrayMesh:
	var lines := [
		[
			Vector2(0.0, 0.17),
			Vector2(0.03, 0.08),
			Vector2(-0.02, -0.01),
			Vector2(0.025, -0.1),
			Vector2(-0.01, -0.18)
		],
		[Vector2(-0.02, -0.01), Vector2(-0.1, 0.04), Vector2(-0.16, 0.0)],
		[Vector2(0.025, -0.1), Vector2(0.11, -0.07), Vector2(0.17, -0.12)],
		[Vector2(0.03, 0.08), Vector2(0.1, 0.13)],
	]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for k in lines.size():
		var line: Array = lines[k]
		var w := 0.034 if k == 0 else 0.022
		for j in line.size() - 1:
			var a: Vector2 = line[j]
			var b: Vector2 = line[j + 1]
			var d := (b - a).normalized()
			var nrm := Vector2(-d.y, d.x) * w * 0.5
			var p := [a + nrm, a - nrm, b - nrm, b + nrm]
			var q: Array[Vector3] = []
			for v: Vector2 in p:
				q.append(Vector3(0, v.y, v.x))
			for t in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
				_tri(verts, normals, t[0], t[1], t[2], Vector3(1, 0, 0))
	# The core: a small diamond where the main split widens.
	var c := Vector2(-0.0, -0.01)
	var dm: Array[Vector3] = [
		Vector3(0, c.y + 0.05, c.x),
		Vector3(0, c.y, c.x + 0.035),
		Vector3(0, c.y - 0.05, c.x),
		Vector3(0, c.y, c.x - 0.035)
	]
	_tri(verts, normals, dm[0], dm[1], dm[2], Vector3(1, 0, 0))
	_tri(verts, normals, dm[0], dm[2], dm[3], Vector3(1, 0, 0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## A fixed pseudo-random value in [0, 1) from an integer (an integer hash; no RNG, the same every run).
static func _noise(n: int) -> float:
	var h := (n * 374761393 + 668265263) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	return float(h & 0xFFFF) / 65536.0


## Flat-shaded triangles facing away from `centre`, each facet tinted by a fixed amount from `salt` (FACET_TINT)
## and the downward ones shaded, so neighbouring planes read apart as on the sheet.
static func _mesh_from(tris: Array, centre: Vector3, salt: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for k in tris.size():
		var t: Array = tris[k]
		_tri(verts, normals, t[0], t[1], t[2], centre)
		var n := normals[normals.size() - 1]
		var v := 1.0 + (_noise(salt * 131 + k * 17) - 0.5) * 2.0 * FACET_TINT
		v *= lerpf(1.0, 0.72, clampf(-n.y, 0.0, 1.0))
		var c := Color(v, v, v)
		colors.append_array([c, c, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
