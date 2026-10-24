class_name EpicRobeView
extends Node3D
## v0.9.0 MP2 (owner, PLAN "Owner decisions" MP2: "the epic robe that appears with a ??? and it rsembles the hollow
## crown one, we might have to change the model a bit and not only color, then another 250 that is like the hollow
## drown but divine with a halo on the head"; "The Fallen's dark look (Recommended)"; "put very high effort on doing
## the next one so it looks great buddy (by code) and you also made it with physics"): the two epic robes' pieces,
## built in code on the hero (PlayerAvatar keeps its hood, legs and rune; the poncho keeps simulating under the robe,
## which is drawn in its place).
## - The cloth (both robes): a long, heavy outer cloak open at the front, hung from the shoulders, its upper ring
##   riding just outside the poncho's own hem springs and its hem a second ring of damped springs (the poncho's
##   physics, tuned heavier: softer, slower, more inertia, a longer swing), and a shoulder mantle over the seam.
##   Layered: flat-shaded cloth in vertex-coloured bands (lighter at the shoulders, darker to the hem, a darker
##   inside), a velvet rim, a fresnel sheen shell over it, and a glowing trim along every edge.
##   - "fallen" (The Fallen's dark look): near-black, the hem torn into jagged points and slits, the mantle in
##     pointed lappets, a faint violet ember along the torn edges; a dark spiked crown over the hood (black metal,
##     a red-violet gem), red-violet eyes glowing in the hood's shadow (the blue visor hidden: owner, 2026-10-24, "if
##     it has the red eyes it should not have the blue square"), the plain shots violet (ElementLooks), dark smoke wisps
##     trailing from the hem while moving.
##   - "divine" (its radiant twin): white and gold, the hem and mantle in rounded scallops with gold trim; a gold
##     crown of rays with white-hot gems and its own light; a halo floating over the head (a gold band, a bright core
##     ring above it, a soft glow, beads that show its slow turn, motes circling it, a warm light); gold light
##     trailing from the hem while moving.
## Effects: the trails are one fixed-size MultiMesh pool each (TRAIL_CAP puffs at High, half at Medium; one draw);
## Effects density Low keeps every shape (cloth, crown, eyes, halo rings and glow) and drops the trails, the motes and
## the lights. Reduced motion stills the halo's turn and bob, the motes and the eyes' flicker, and the trail puffs
## stop drifting. No piece uses the enemy red or the hostile yellow on the cloth (tests/unit/presentation/
## test_epic_robes.gd); the divine robe keeps the blue visor. Presentation only (EI-07): it reads the avatar.

const STYLES: Array[StringName] = [&"fallen", &"divine"]
## The robe's columns, all round from the front (cloak-frame angles, +Z the right); BACK is the back's middle.
const COLUMNS := 16
const BACK := 8
## The mantle's columns, all round.
const MANTLE_COLUMNS := 12
## The robe's waist (its A-line's half-widths front-back and side to side, metres) and the hem's flare out from it.
const WAIST := Vector2(0.27, 0.31)
const FLARE := 0.05
## The hem's springs: the poncho's (PlayerAvatar.SPRING_K, SPRING_C, INERTIA, MAX_OFFSET), tuned heavier.
const HEM_K := 62.0
const HEM_C := 5.2
const HEM_INERTIA := 0.5
const HEM_DRAG := 1.25
const HEM_MAX := 0.3
## The hem's length below the upper ring: the back hangs longest.
const HEM_BACK := 0.31
const HEM_FRONT := 0.19
const TRIM_W := 0.04
## The trails: puffs in the pool at High (Medium half, Low none), spawned per second while moving.
const TRAIL_CAP := 40
const TRAIL_RATE := 55.0
const MOTES := 10
## The halo over the head (hood frame), and its turn (radians a second).
const HALO_AT := Vector3(-0.03, 0.42, 0.0)
const HALO_SPIN := 0.5
## The jagged hem of the fallen robe: each tooth between two hem points (> 0: a point that much lower; < 0: a slit
## torn up that fraction toward the upper ring), and each hem point's own length change.
const TEETH := [
	0.06, 0.09, -0.3, 0.12, 0.04, -0.45, 0.1, 0.07, 0.13, -0.3, 0.09, 0.05, -0.42, 0.11, 0.07, 0.08
]
const JITTER := [
	0.0,
	0.02,
	-0.02,
	0.04,
	0.01,
	-0.03,
	0.05,
	0.02,
	0.04,
	-0.02,
	0.03,
	0.0,
	-0.03,
	0.02,
	0.01,
	-0.02
]

const LOOKS := {
	&"fallen":
	{
		"hi": Color("#2C2634"),
		"mid": Color("#1A161F"),
		"lo": Color("#0E0B12"),
		"in": Color("#09070C"),
		"trim": Color("#7A34C4"),
		"trim_hot": Color("#B57CFF"),
		"sheen": Color("#5B3594"),
		"metal": Color("#1D1923"),
		"gem": Color("#C23C9E"),
		"eye": Color("#D040A8"),
		"trail": Color("#4E3B68"),
	},
	&"divine":
	{
		"hi": Color("#FFFDF8"),
		"mid": Color("#F1EBDF"),
		"lo": Color("#E6D6B2"),
		"in": Color("#D9C9A5"),
		"trim": Color("#D9A23C"),
		"trim_hot": Color("#FFF1CF"),
		"sheen": Color("#E0B04A"),
		"metal": Color("#D9A441"),
		"gem": Color("#FFF6DE"),
		"eye": Color("#FFF6DE"),
		"trail": Color("#FFE2A0"),
	},
}

var style := &""
var avatar: PlayerAvatar
## The pieces (tests read them): the cloth and its layers, the head's pieces (under `head`, which follows the hood).
var cape: MeshInstance3D
var sheen: MeshInstance3D
var trim: MeshInstance3D
var head := Node3D.new()
var crown: MeshInstance3D
var gems: MeshInstance3D
var eyes: MeshInstance3D
var eye_glow: Array[MeshInstance3D] = []
var halo: Node3D
var halo_motes: MultiMeshInstance3D
var light: OmniLight3D
var trail: MultiMeshInstance3D
var trail_cap := 0
## The fresnel sheen laid over the avatar's own hood (freed with this view: dispose()).
var hood_sheen: MeshInstance3D
var _look := {}
var _mesh := ArrayMesh.new()
var _trim_mesh := ArrayMesh.new()
var _trim_mat: ShaderMaterial
var _hem_pos: Array[Vector3] = []
var _hem_vel: Array[Vector3] = []
var _hem_target: Array[Vector3] = []
var _mid: Array[Vector3] = []
var _top: Array[Vector3] = []
var _xf := Transform3D.IDENTITY
var _fresh := true
var _prev_vel := Vector3.ZERO
var _t := 0.0
var _emit := 0.0
var _emit_k := 0
var _p_pos := PackedVector3Array()
var _p_age := PackedFloat32Array()
var _p_seed := PackedFloat32Array()


## Builds `p_style`'s pieces on `p_avatar` (outlined and X-rayed like its body: `outline`, `technique`).
func build(
	p_avatar: PlayerAvatar, p_style: StringName, outline: Color, technique: StringName
) -> void:
	name = "EpicRobe"
	avatar = p_avatar
	style = p_style
	_look = LOOKS.get(style, LOOKS[&"fallen"])
	var team := ThemePalette.color(&"player_core")
	for _j in COLUMNS:
		_hem_pos.append(Vector3.ZERO)
		_hem_vel.append(Vector3.ZERO)
		_hem_target.append(Vector3.ZERO)
		_mid.append(Vector3.ZERO)
		_top.append(Vector3.ZERO)
	# The cloth: outlined, X-rayed and hit-flashed with the body (the avatar's pieces), a velvet rim on it.
	cape = avatar._outlined(
		self, _mesh, Vector3.ZERO, Color.WHITE, outline, team, technique, 0.014, true, "Cape"
	)
	var cm := cape.material_override as StandardMaterial3D
	cm.vertex_color_is_srgb = true
	cm.roughness = 0.9
	cm.rim_enabled = true
	cm.rim = 0.55 if style == &"fallen" else 0.35
	cm.rim_tint = 0.6
	cape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if style == &"divine":  # radiant: a soft warm-white light of its own (the hit flash comes back to it)
		cm.set_meta(&"rest", [Color("#FFF2D6"), 0.16])
		cm.emission = Color("#FFF2D6")
		cm.emission_energy_multiplier = 0.16
	sheen = EpicRobeParts.shell(
		"Sheen", _mesh, _look["sheen"], 0.55 if style == &"fallen" else 0.4, 3.0
	)
	add_child(sheen)
	trim = MeshInstance3D.new()
	trim.name = "Trim"
	trim.mesh = _trim_mesh
	_trim_mat = EpicRobeParts.material(&"glow", EpicRobeParts.GLOW_SHADER)
	_trim_mat.set_shader_parameter(&"energy", 1.1 if style == &"fallen" else 1.6)
	trim.material_override = _trim_mat
	trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trim)
	# The poncho stays in the physics (the robe's waist rides its springs) but this robe is drawn in its place.
	avatar.cloak.visible = false
	# The owner (2026-10-24): "if it has the red eyes it should not have the blue square": The Fallen's eyes are its
	# only face; the hero's blue visor comes back with any other robe (PlayerAvatar._set_epic).
	avatar.visor.visible = style != &"fallen"
	head.name = "Head"
	add_child(head)
	var shell := avatar.hood.get_child(0) as MeshInstance3D
	if shell != null:
		hood_sheen = EpicRobeParts.shell(
			"HoodSheen", shell.mesh, _look["sheen"], 0.6 if style == &"fallen" else 0.35, 2.5
		)
		shell.add_child(hood_sheen)
	_build_crown(outline, team, technique)
	if style == &"fallen":
		_build_eyes()
	else:
		_build_halo()
	_build_extras()
	_follow_head()
	_step_cloth(0.0)
	_rebuild()


## Called before this view is freed: the sheen it laid on the hood goes too.
func dispose() -> void:
	if hood_sheen != null and is_instance_valid(hood_sheen):
		hood_sheen.get_parent().remove_child(hood_sheen)
		hood_sheen.free()
	hood_sheen = null


## Frame time: the cloth's springs, the head's pieces, the halo, the trail.
func advance(dt: float) -> void:
	if avatar == null:
		return
	_t += dt
	_follow_head()
	_step_cloth(dt)
	_rebuild()
	var calm := ViewPrefs.reduced_motion
	if halo != null:
		halo.position = HALO_AT + Vector3(0, 0.0 if calm else sin(_t * 1.6) * 0.014, 0)
		if not calm:
			halo.rotate_object_local(Vector3.UP, HALO_SPIN * dt)
		_place_motes(calm)
	for g in eye_glow:
		var f := 1.0 if calm else 0.9 + 0.1 * sin(_t * 7.3 + g.position.z * 40.0)
		g.scale = Vector3.ONE * f
	_trim_mat.set_shader_parameter(&"pulse", 1.0 if calm else 0.88 + 0.12 * sin(_t * 2.4))
	_advance_trail(dt, calm)


## The pieces built (tests): their node names.
func pieces() -> Array[String]:
	var out: Array[String] = []
	for n: Node in [cape, sheen, trim, crown, gems, eyes, halo, halo_motes, light, trail]:
		if n != null:
			out.append(String(n.name))
	return out


## The hem's spring points (avatar frame; a copy).
func hem() -> Array[Vector3]:
	return _hem_pos.duplicate()


## The hem springs' largest distance from their rest targets (0 once the robe has settled).
func hem_offset() -> float:
	var worst := 0.0
	for j in _hem_pos.size():
		worst = maxf(worst, _hem_pos[j].distance_to(_hem_target[j]))
	return worst


## Puffs alive in the trail.
func trail_alive() -> int:
	return _p_pos.size()


# --- the cloth ------------------------------------------------------------------------------------------------------


func _angle(j: int) -> float:
	return TAU * float(j) / float(COLUMNS)


## The poncho's hem at cloak-frame angle `a` (its 8 springs, front first, round through the right).
static func _poncho_at(ring: Array, a: float) -> Vector3:
	var f := fposmod(a, TAU) / (TAU / 8.0)
	var k := int(floor(f)) % 8
	return (ring[k] as Vector3).lerp(ring[(k + 1) % 8], f - floor(f))


func _step_cloth(dt: float) -> void:
	var d := avatar.cloth_drive()
	var xf: Transform3D = d[0]
	var ring: Array = d[1]
	var vel: Vector3 = d[2]
	var dash: float = d[3]
	var slump: float = d[4]
	_xf = xf
	var up := xf.basis.y.normalized()
	var speed := Vector2(vel.x, vel.z).length()
	var swing := 0.03 + 0.03 * clampf(speed / PlayerAvatar.WALK_SPEED, 0.0, 1.0) + 0.2 * dash
	for j in COLUMNS:
		var a := _angle(j)
		var dir := Vector3(cos(a), 0, sin(a))
		# The neckline: round the shoulders under the hood's rim, dipping to a shallow V at the throat.
		var front := maxf(0.0, dir.x)
		var ty := 0.405 - 0.02 * dir.x - 0.13 * front * front * front * front
		_top[j] = xf * Vector3(dir.x * 0.19, ty * (1.0 - 0.35 * slump), dir.z * 0.215)
		# The waist ring takes the poncho's own hem springs' motion (pulled in toward the body: the robe's waist),
		# never inside an A-line round the hips.
		var p := _poncho_at(ring, a)
		var rel := p - xf.origin
		var h := rel.dot(up)
		var radial := rel - up * h
		var out_dir := radial.normalized() if radial.length() > 0.01 else xf.basis * dir
		var line := 1.0 / sqrt(pow(dir.x / WAIST.x, 2.0) + pow(dir.z / WAIST.y, 2.0))
		var rr := maxf(radial.length() * 0.7, line * (1.0 + 0.35 * slump))
		_mid[j] = xf.origin + up * (h + 0.02) + out_dir * rr
		var hang := lerpf(HEM_BACK, HEM_FRONT, (1.0 + dir.x) * 0.5)
		if style == &"fallen":
			hang += float(JITTER[j])
		hang *= 1.0 - 0.55 * slump
		_hem_target[j] = _mid[j] + out_dir * (FLARE + swing) - up * hang
	if _fresh or dt <= 0.0:
		if _fresh:
			for j in COLUMNS:
				_hem_pos[j] = _hem_target[j]
				_hem_vel[j] = Vector3.ZERO
		_fresh = false
		_prev_vel = vel
		return
	var accel := ((vel - _prev_vel) / dt).limit_length(80.0)
	_prev_vel = vel
	var n := ceili(dt / PlayerAvatar.SUB_STEP)
	var step := dt / n
	var push := -accel * HEM_INERTIA - vel * HEM_DRAG * (1.0 + dash)
	for _i in n:
		for j in COLUMNS:
			var acc := (_hem_target[j] - _hem_pos[j]) * HEM_K - _hem_vel[j] * HEM_C + push
			_hem_vel[j] += acc * step
			_hem_pos[j] += _hem_vel[j] * step
			var off := _hem_pos[j] - _hem_target[j]
			if off.length() > HEM_MAX:
				_hem_pos[j] = _hem_target[j] + off.limit_length(HEM_MAX)
				_hem_vel[j] *= 0.5


## The hem as drawn: each spring point lifted as a pendulum swung out (the poncho's rule) and kept off the floor.
func _hem_drawn(j: int) -> Vector3:
	var p := _hem_pos[j]
	var off := p - _hem_target[j]
	p.y += Vector2(off.x, off.z).length_squared() * 1.2
	p.y = maxf(p.y, 0.025)
	return p


## The tooth between hem points j and the next: fallen a jagged point or a slit torn up; divine a scallop's rise.
func _tooth(j: int, a: Vector3, b: Vector3) -> Vector3:
	var k := (j + 1) % COLUMNS
	var base := (a + b) * 0.5
	var mid := (_mid[j] + _mid[k]) * 0.5
	if style != &"fallen":
		return base.lerp(mid, 0.12)
	var v: float = TEETH[j]
	if v < 0.0:
		return base.lerp(mid, -v)
	var down := (base - mid).normalized()
	var p := base + down * v
	p.y = maxf(p.y, 0.02)
	return p


func _rebuild() -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var tv := PackedVector3Array()
	var tc := PackedColorArray()
	var hems: Array[Vector3] = []
	for j in COLUMNS:
		hems.append(_hem_drawn(j))
	var hi: Color = _look["hi"]
	var mid_c: Color = _look["mid"]
	var lo: Color = _look["lo"]
	var centre := Vector3.ZERO
	for p in _top:
		centre += p
	centre /= COLUMNS
	var neck := _xf.basis.y.normalized()
	for j in COLUMNS:
		var k := (j + 1) % COLUMNS
		var t0 := _top[j]
		var t1 := _top[k]
		var m0 := _mid[j]
		var m1 := _mid[k]
		var h0 := hems[j]
		var h1 := hems[k]
		var tooth := _tooth(j, h0, h1)
		var torn := style == &"fallen" and float(TEETH[j]) < 0.0
		var tooth_c := lo.lerp(mid_c, 0.5) if torn else lo
		_face(verts, normals, colors, [t0, t1, m1], [hi, hi, mid_c])
		_face(verts, normals, colors, [t0, m1, m0], [hi, mid_c, mid_c])
		_face(verts, normals, colors, [m0, m1, tooth], [mid_c, mid_c, tooth_c])
		_face(verts, normals, colors, [m0, tooth, h0], [mid_c, tooth_c, lo])
		_face(verts, normals, colors, [m1, h1, tooth], [mid_c, lo, tooth_c])
		# The glowing trim along the hem: h0 -> tooth -> h1.
		var mm := (m0 + m1) * 0.5
		_trim_edge(tv, tc, h0, tooth, m0, mm)
		_trim_edge(tv, tc, tooth, h1, mm, m1)
		# A dark collar across the neckline (both ways), as the poncho's: no lit inside shows past the hood.
		verts.append_array([centre, t0, t1, centre, t1, t0])
		normals.append_array([neck, neck, neck, -neck, -neck, -neck])
		for _n in 6:
			colors.append(PlayerAvatar.NECK_SHADE)
	# The seam down the front, where the robe's two panels meet.
	var side := _xf.basis.z.normalized() * 0.05
	_trim_edge(tv, tc, _top[0], _mid[0], _top[0] + side, _mid[0] + side)
	_trim_edge(tv, tc, _mid[0], hems[0], _mid[0] + side, hems[0] + side)
	_mantle(verts, normals, colors, tv, tc)
	_commit(_mesh, verts, normals, colors)
	_commit(_trim_mesh, tv, PackedVector3Array(), tc)
	_place_rune()


## The affinity's rune on the robe's back (the poncho under it is hidden): flat on the back column's facet, below the
## mantle, a little out from the cloth (the poncho's rule, PlayerAvatar._place_back_rune).
func _place_rune() -> void:
	var runes := avatar.runes
	if runes == null:
		return
	var top := _top[BACK]
	var low := _mid[BACK]
	var down := low - top
	if down.length_squared() < 0.0001:
		return
	down = down.normalized()
	var n := down.cross(_xf.basis.z.normalized()).normalized()
	runes.back.transform = Transform3D(Basis.looking_at(-n, -down), top.lerp(low, 0.62) + n * 0.016)


## The shoulder mantle: a short layer over the shoulders, rigid on them; fallen in pointed lappets (none at the back's
## middle, where the rune sits), divine in rounded scallops.
func _mantle(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	tv: PackedVector3Array,
	tc: PackedColorArray
) -> void:
	var slump := avatar.slump_amount()
	var tops: Array[Vector3] = []
	var bots: Array[Vector3] = []
	for j in MANTLE_COLUMNS:
		var a := TAU * float(j) / float(MANTLE_COLUMNS)
		var dir := Vector3(cos(a), 0, sin(a))
		var front := maxf(0.0, dir.x)
		var y := (0.42 - 0.02 * dir.x - 0.1 * front * front * front * front) * (1.0 - 0.35 * slump)
		tops.append(_xf * Vector3(dir.x * 0.205, y, dir.z * 0.232))
		var point := 0.07 if style == &"fallen" and j % 2 == 1 else 0.0
		var r := 0.3 + point * 0.35
		var by := (0.26 - point - 0.02 * dir.x - 0.06 * front) * (1.0 - 0.5 * slump)
		bots.append(_xf * Vector3(dir.x * r, by, dir.z * (r + 0.04)))
	var hi: Color = _look["hi"]
	var mid_c: Color = _look["mid"]
	for j in MANTLE_COLUMNS:
		var k := (j + 1) % MANTLE_COLUMNS
		var t0 := tops[j]
		var t1 := tops[k]
		var b0 := bots[j]
		var b1 := bots[k]
		var notch := (b0 + b1) * 0.5
		notch = notch.lerp((t0 + t1) * 0.5, 0.26 if style == &"fallen" else 0.12)
		_face(verts, normals, colors, [t0, t1, notch], [hi, hi, mid_c])
		_face(verts, normals, colors, [t0, notch, b0], [hi, mid_c, mid_c])
		_face(verts, normals, colors, [t1, b1, notch], [hi, mid_c, mid_c])
		_trim_edge(tv, tc, b0, notch, t0, (t0 + t1) * 0.5)
		_trim_edge(tv, tc, notch, b1, (t0 + t1) * 0.5, t1)


## One cloth facet, both sides: the outside in its bands (`cols`), the inside a centimetre in, in the inside colour.
func _face(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	t: Array,
	cols: Array
) -> void:
	var a: Vector3 = t[0]
	var b: Vector3 = t[1]
	var c: Vector3 = t[2]
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	var avg := (a + b + c) / 3.0
	var axis := Vector3(0, avg.y, 0)
	var ca: Color = cols[0]
	var cb: Color = cols[1]
	var cc: Color = cols[2]
	if n.dot(avg - axis) < 0.0:
		var tmp := b
		b = c
		c = tmp
		var tc := cb
		cb = cc
		cc = tc
		n = -n
	n = n.normalized()
	verts.append_array([a, c, b])
	normals.append_array([n, n, n])
	colors.append_array([ca, cc, cb])
	var off := -n * 0.01
	var inside: Color = _look["in"]
	verts.append_array([a + off, b + off, c + off])
	normals.append_array([-n, -n, -n])
	colors.append_array([inside, inside.lerp(ca, 0.25), inside])


## The trim's glowing band along edge a -> b, fading toward the cloth's inner points ia, ib (linear colours: hot at
## the edge, the trim's colour fading out), a few millimetres out from the cloth.
func _trim_edge(
	tv: PackedVector3Array, tc: PackedColorArray, a: Vector3, b: Vector3, ia: Vector3, ib: Vector3
) -> void:
	var qa := a + (ia - a).normalized() * TRIM_W
	var qb := b + (ib - b).normalized() * TRIM_W
	var out := Vector3(a.x + b.x, 0, a.z + b.z).normalized() * 0.006
	var hot := (_look["trim_hot"] as Color).srgb_to_linear()
	var base := (_look["trim"] as Color).srgb_to_linear()
	var fade := Color(base, 0.0)
	tv.append_array([a + out, b + out, qb + out, a + out, qb + out, qa + out])
	tc.append_array([hot, hot, fade, hot, fade, fade])


static func _commit(
	mesh: ArrayMesh, v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray
) -> void:
	mesh.clear_surfaces()
	if v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	if not n.is_empty():
		arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


# --- the head: crown, eyes, halo ------------------------------------------------------------------------------------


## `head` takes the hood's pose in the avatar's frame each frame, so the crown, eyes and halo ride the hood.
func _follow_head() -> void:
	var hood := avatar.hood
	if hood == null:
		return
	var t := hood.transform
	var n := hood.get_parent() as Node3D
	while n != null and n != avatar:
		t = n.transform * t
		n = n.get_parent() as Node3D
	head.transform = t


func _build_crown(outline: Color, team: Color, technique: StringName) -> void:
	var fallen := style == &"fallen"
	crown = avatar._outlined(
		head,
		EpicRobeParts.crown_mesh(fallen),
		Vector3.ZERO,
		_look["metal"],
		outline,
		team,
		technique,
		0.008,
		false,
		"Crown"
	)
	var m := crown.material_override as StandardMaterial3D
	m.metallic = 0.7 if fallen else 0.6
	m.roughness = 0.38 if fallen else 0.3
	m.rim_enabled = true
	m.rim = 0.4
	m.rim_tint = 0.2
	# Its rest glow (ActorViews' hit flash comes back to it): a faint violet in the black metal, the gold's own light.
	var rest := [_look["trim"], 0.12] if fallen else [Color("#E8B04A"), 0.45]
	m.set_meta(&"rest", rest)
	m.emission = rest[0]
	m.emission_energy_multiplier = rest[1]
	crown.add_child(
		EpicRobeParts.shell("CrownSheen", crown.mesh, _look["sheen"], 0.7 if fallen else 0.5, 2.0)
	)
	gems = MeshInstance3D.new()
	gems.name = "Gems"
	gems.mesh = EpicRobeParts.gem_mesh(fallen)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = _look["gem"]
	gm.emission_enabled = true
	gm.emission = _look["gem"]
	gm.emission_energy_multiplier = 2.2 if fallen else 3.0
	AvatarBase.write_stencil(gm)
	gems.material_override = gm
	gems.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(gems)


## The Fallen's eyes: two slanted slits in the hood's shadow (its only face: the visor is hidden), each with a glow.
func _build_eyes() -> void:
	var c: Color = _look["eye"]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var x := PlayerAvatar.FACE_X + 0.009
	for side in [-1.0, 1.0]:
		var zc: float = side * 0.052
		# A slanted diamond slit: its inner end lower (a frown), 6.5 cm across, 3 cm tall at its widest.
		var inner := Vector3(x, 0.07, zc - side * 0.033)
		var outer := Vector3(x, 0.102, zc + side * 0.033)
		var top := Vector3(x, 0.106, zc - side * 0.004)
		var bot := Vector3(x, 0.073, zc + side * 0.004)
		var front := Vector3(x + 0.005, 0.088, zc)
		var behind := Vector3(-1, 0.088, zc)
		AvatarBase._tri(verts, normals, inner, top, front, behind)
		AvatarBase._tri(verts, normals, top, outer, front, behind)
		AvatarBase._tri(verts, normals, outer, bot, front, behind)
		AvatarBase._tri(verts, normals, bot, inner, front, behind)
		var g := EpicRobeParts.glow_quad("EyeGlow", c, 0.17)
		g.position = Vector3(x + 0.012, 0.088, zc)
		head.add_child(g)
		eye_glow.append(g)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	eyes = MeshInstance3D.new()
	eyes.name = "Eyes"
	eyes.mesh = m
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = c.lightened(0.35)
	em.emission_enabled = true
	em.emission = c
	em.emission_energy_multiplier = 2.6
	AvatarBase.write_stencil(em)
	eyes.material_override = em
	eyes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(eyes)


## The divine halo over the head: a gold band, a bright core ring above it, beads round it that show its turn, a soft
## glow under them (the motes and a warm light from Medium up: _build_extras).
func _build_halo() -> void:
	halo = Node3D.new()
	halo.name = "Halo"
	halo.position = HALO_AT
	halo.rotation = Vector3(0, 0, 0.12)  # tipped back a little, over the hood's forward tilt
	head.add_child(halo)
	var band := MeshInstance3D.new()
	band.name = "HaloBand"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.19
	tm.outer_radius = 0.228
	tm.rings = 48
	tm.ring_segments = 8
	band.mesh = tm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("#D9A23C")
	bm.metallic = 1.0
	bm.roughness = 0.22
	bm.emission_enabled = true
	bm.emission = Color("#D9A23C")
	bm.emission_energy_multiplier = 0.9
	bm.rim_enabled = true
	bm.rim = 0.6
	AvatarBase.write_stencil(bm)
	band.material_override = bm
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.add_child(band)
	var core := MeshInstance3D.new()
	core.name = "HaloCore"
	var cm := TorusMesh.new()
	cm.inner_radius = 0.2
	cm.outer_radius = 0.213
	cm.rings = 48
	cm.ring_segments = 6
	core.mesh = cm
	var km := StandardMaterial3D.new()
	km.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	km.albedo_color = Color("#FFF6E0")
	km.emission_enabled = true
	km.emission = Color("#FFF3D6")
	km.emission_energy_multiplier = 4.0
	AvatarBase.write_stencil(km)
	core.material_override = km
	core.position.y = 0.02
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.add_child(core)
	var beads := MeshInstance3D.new()
	beads.name = "HaloBeads"
	beads.mesh = EpicRobeParts.bead_mesh(8, 0.209, 0.022)
	beads.material_override = km
	beads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.add_child(beads)
	var glow := MeshInstance3D.new()
	glow.name = "HaloGlow"
	var q := QuadMesh.new()
	q.size = Vector2(0.84, 0.84)
	q.orientation = PlaneMesh.FACE_Y
	glow.mesh = q
	var gm := (
		EpicRobeParts.material(&"ring", EpicRobeParts.RING_SHADER).duplicate() as ShaderMaterial
	)
	gm.set_shader_parameter(&"tint", Color("#FFD98A"))
	gm.set_shader_parameter(&"ring", 0.25)
	gm.set_shader_parameter(&"width", 0.07)
	gm.set_shader_parameter(&"strength", 1.1)
	glow.material_override = gm
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.add_child(glow)


# --- effects: density-gated ------------------------------------------------------------------------------------------


## Effects density: the trail pool, the halo's motes and the lights from Medium up (Low keeps every shape).
func _build_extras() -> void:
	var dens := ViewPrefs.effects_density
	if dens == "low":
		trail_cap = 0
		return
	trail_cap = TRAIL_CAP if dens == "high" else TRAIL_CAP / 2
	trail = MultiMeshInstance3D.new()
	trail.name = "Trail"
	trail.top_level = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = trail_cap
	mm.visible_instance_count = 0
	var q := QuadMesh.new()
	var fallen := style == &"fallen"
	q.size = Vector2.ONE
	q.material = EpicRobeParts.sprite_material(fallen)
	mm.mesh = q
	trail.multimesh = mm
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)
	light = OmniLight3D.new()
	light.name = "Light"
	light.shadow_enabled = false
	if fallen:
		light.light_color = _look["eye"]
		light.light_energy = 0.25
		light.omni_range = 0.7
		light.position = Vector3(PlayerAvatar.FACE_X + 0.12, 0.08, 0)
	else:
		light.light_color = Color("#FFE0A0")
		light.light_energy = 0.7
		light.omni_range = 1.8
		light.position = HALO_AT + Vector3(0, 0.05, 0)
	head.add_child(light)
	if halo != null:
		halo_motes = MultiMeshInstance3D.new()
		halo_motes.name = "HaloMotes"
		var hm := MultiMesh.new()
		hm.transform_format = MultiMesh.TRANSFORM_3D
		hm.use_colors = true
		hm.instance_count = MOTES if dens == "high" else MOTES / 2
		var mq := QuadMesh.new()
		mq.size = Vector2.ONE
		mq.material = EpicRobeParts.sprite_material(false)
		hm.mesh = mq
		halo_motes.multimesh = hm
		halo_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.add_child(halo_motes)
		_place_motes(ViewPrefs.reduced_motion)


## The motes circle the halo, bobbing (reduced motion: they hold still where they are).
func _place_motes(calm: bool) -> void:
	if halo_motes == null:
		return
	var mm := halo_motes.multimesh
	var t := 0.0 if calm else _t
	for i in mm.instance_count:
		var a := TAU * i / mm.instance_count + t * 0.7
		var r := 0.235 + 0.035 * sin(i * 1.7 + t * 1.3)
		var y := 0.03 + 0.035 * sin(i * 2.3 + t * 2.0)
		var s := 0.035 + 0.015 * sin(i * 3.1 + t * 3.0)
		mm.set_instance_transform(
			i, Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(cos(a) * r, y, sin(a) * r))
		)
		mm.set_instance_color(i, Color(1.0, 0.93, 0.75, 0.85))


## The trail: puffs spawned at the hem while the hero moves (at most trail_cap alive: the pool's frame cap), each
## living TRAIL_LIFE; fallen dark smoke that swells and rises, divine gold light that shrinks and drifts up.
func _advance_trail(dt: float, calm: bool) -> void:
	if trail == null:
		return
	var life := 1.2 if style == &"fallen" else 0.8
	var k := 0
	while k < _p_pos.size():
		_p_age[k] += dt
		if _p_age[k] >= life:
			_p_pos.remove_at(k)
			_p_age.remove_at(k)
			_p_seed.remove_at(k)
			continue
		if not calm:
			_p_pos[k] += Vector3(0, (0.22 if style == &"fallen" else 0.38) * dt, 0)
		k += 1
	var d := avatar.cloth_drive()
	var vel: Vector3 = d[2]
	var dash: float = d[3]
	var speed := Vector2(vel.x, vel.z).length()
	if speed > 1.0 or dash > 0.1:
		_emit += dt * TRAIL_RATE * float(trail_cap) / TRAIL_CAP * clampf(speed / 5.0, 0.5, 1.6)
	else:
		_emit = 0.0
	var to_world := avatar.global_transform if avatar.is_inside_tree() else avatar.transform
	while _emit >= 1.0:
		_emit -= 1.0
		if _p_pos.size() >= trail_cap:
			continue
		_emit_k = (_emit_k + 7) % COLUMNS
		var seed := fposmod(
			sin(float(_p_seed.size() + _emit_k) * 12.9898 + _t * 3.7) * 43758.5453, 1.0
		)
		var at := _hem_drawn(_emit_k).lerp(_mid[_emit_k], 0.15 + 0.2 * seed)
		_p_pos.append(to_world * at)
		_p_age.append(0.0)
		_p_seed.append(seed)
	var mm := trail.multimesh
	var base: Color = _look["trail"]
	for i in _p_pos.size():
		var u := _p_age[i] / life
		var s := 0.0
		var c := base
		if style == &"fallen":
			s = lerpf(0.24, 0.6, u) * (0.8 + 0.4 * _p_seed[i])
			c.a = 0.8 * sin(PI * minf(1.0, u * 1.25)) * (1.0 - u * 0.4)
		else:
			s = lerpf(0.11, 0.04, u) * (0.7 + 0.6 * _p_seed[i])
			c = base.lerp(Color("#FFF8E8"), _p_seed[i])
			c.a = 1.0 - u
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), _p_pos[i]))
		mm.set_instance_color(i, c)
	mm.visible_instance_count = _p_pos.size()
