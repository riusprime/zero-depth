class_name SoloVat
extends RefCounted
## v0.10.5 W3-V4c (owner, 2026-11-06: "can we apply it to the rest of the enemies and test it?"): VAT for the
## stand-alone enemies (the Needle, the Warden, the Arc Caster, the Bomb Drone; v0.11.0 S4: the Lens Drone): their
## reference and VAT avatars, the looks of their own StandardMaterial3D pieces, and the rig they declare (VatBake's,
## see its class notes).
##
## Their rigs are one-number joints. Each avatar's pose code works out a few plain numbers (an angle, a height, a
## scale: its RAW drives, the avatar's _vd) and writes its nodes from them; each joint of its rig is one of those
## nodes' transforms made of one number (a turn about one axis, a slide, a stretch; the Needle's lean: one turn from
## two), so the joints composed up a chain are the nodes' own transforms for any mix of the numbers, and only each
## grid's sampling is approximate (a slide or a stretch is linear: exact on two samples). A drive is sent as 0..1 over
## its [lo, hi] (a loop wrapped); a drive no grid reads (a second glow: the Needle's muzzle) is sent as it is.
## A drive spec: [lo, hi, loop]. A grid: [[drive, samples], ...] (1 to 3 axes). A joint: [grid, parent, frame, make]:
## make(values) -> Transform3D from the raw values of its grid's axes, in order.
##
## Pieces: an avatar's body plates (AvatarBase.body_materials: the hit flash, the tints, the role glow ActorViews
## gives them, read from the reference avatar after ActorViews' own tint_greys / role_glow) are VatBake's mode 0; its
## other lit glowing pieces are accents (mode 1) glowing at the instance's glow_energy() or at the drive their
## material names (meta GLOW: drive + 1); an unshaded piece (the Warden's cracks, the Arc Caster's crystal, the Bomb
## Drone's fuse) draws its albedo as is (the CUSTOM2.w flag: no light, no flash). A node with meta LIVE (and what
## hangs from it) is not baked: the VAT avatar keeps it as a node (the drones' ground disc, the Warden's dust ring).
## Presentation only (EI-07).

## The kinds drawn this way (VatCrowd.KINDS lists them).
const KINDS: Array[int] = [
	WorldReader.KIND_NEEDLE,
	WorldReader.KIND_WARDEN,
	WorldReader.KIND_ARC_CASTER,
	WorldReader.KIND_BOMB_DRONE,
	WorldReader.KIND_LENS_DRONE,
	WorldReader.KIND_SCRAP_HOUND,  # v0.11.0 O17a
	WorldReader.KIND_ROCK_LURKER,  # v0.11.0 O17b
	WorldReader.KIND_STONE_THROWER,  # v0.11.0 O17c: on the owner's model
	WorldReader.KIND_CINDER_PRIEST,  # v0.11.0 O17d: the owner's model, animated in code
	WorldReader.KIND_KILN_BEETLE,  # v0.11.0 O17e
]
## Metas: a piece material's look (its role: &"plate", &"accent", &"unshaded"), an accent's glow drive (+ 1), a node
## kept live.
const LOOK := &"zd_look"
const GLOW := &"zd_glow"
const LIVE := &"zd_live"


static func is_solo(kind: int) -> bool:
	return KINDS.has(kind)


static func _new(kind: int) -> AvatarBase:
	match kind:
		WorldReader.KIND_NEEDLE:
			return NeedleAvatar.new()
		WorldReader.KIND_WARDEN:
			return WardenAvatar.new()
		WorldReader.KIND_ARC_CASTER:
			return ArcCasterAvatar.new()
		WorldReader.KIND_BOMB_DRONE:
			return BombDroneAvatar.new()
		WorldReader.KIND_LENS_DRONE:
			return LensDroneAvatar.new()
		WorldReader.KIND_SCRAP_HOUND:  # v0.11.0 O17a
			return ScrapHoundAvatar.new()
		WorldReader.KIND_ROCK_LURKER:  # v0.11.0 O17b
			return RockLurkerAvatar.new()
		WorldReader.KIND_STONE_THROWER:
			return StoneThrowerAvatar.new()
		WorldReader.KIND_CINDER_PRIEST:
			return CinderPriestAvatar.new()
		WorldReader.KIND_KILN_BEETLE:  # v0.11.0 O17e
			return KilnBeetleAvatar.new()
	return null


## A reference avatar of `kind` with its pieces (not in the tree; the caller frees it), its body plates in the look
## ActorViews gives a fresh enemy (tint_greys under the biome's cast `tint`, role_glow at `role_glow`), each piece
## material marked with its role (LOOK).
static func reference_of(kind: int, tint: Color, role_glow: float, outline: Color) -> AvatarBase:
	var a := _new(kind)
	a.setup(outline, &"outline")
	a.set_process(false)
	a.set_meta(&"mats", a.body_materials)
	ActorViews.tint_greys(a, tint)
	ActorViews.lift_model(a, kind)  # v0.11.0 F2
	ActorViews.role_glow(a, kind, role_glow)
	for m in a.body_materials:
		m.set_meta(LOOK, &"plate")
	_mark(a)
	return a


static func _mark(n: Node) -> void:
	for c in n.get_children():
		var mi := c as MeshInstance3D
		if mi != null:
			var ms: Array = [mi.material_override]
			if mi.mesh != null:  # v0.11.0 S4: the Lens Drone model's pieces carry theirs per surface
				for k in mi.mesh.get_surface_count():
					ms.append(mi.get_surface_override_material(k))
			for mat: Variant in ms:
				var m := mat as StandardMaterial3D
				if m != null and not m.has_meta(LOOK):
					var unshaded := m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
					m.set_meta(LOOK, &"unshaded" if unshaded else &"accent")
		_mark(c)


## A VAT avatar of `kind` (no pieces; tools, tests; not in the tree; the caller frees it).
static func vat_avatar_of(kind: int, outline: Color) -> AvatarBase:
	var a := _new(kind)
	a.set(&"vat", true)
	a.setup(outline, &"outline")
	return a


## VatBake.surface_look for a marked StandardMaterial3D piece: [albedo (linear) + mode, emission (linear; a plate's
## times its rest energy) + outline, two-sided, glow source, unshaded, vertex colours].
static func surface_look(m: StandardMaterial3D) -> Array:
	var role: StringName = m.get_meta(LOOK)
	var a := m.albedo_color.srgb_to_linear()
	var e := m.emission.srgb_to_linear() if m.emission_enabled else Color.BLACK
	var k := m.emission_energy_multiplier if role == &"plate" else 1.0
	var outline := 1.0 if m.stencil_mode == BaseMaterial3D.STENCIL_MODE_OUTLINE else 0.0
	return [
		[a.r, a.g, a.b, 0.0 if role == &"plate" else 1.0],
		[e.r * k, e.g * k, e.b * k, outline],
		m.cull_mode == BaseMaterial3D.CULL_DISABLED,
		float(m.get_meta(GLOW, 0)),
		1.0 if role == &"unshaded" else 0.0,
		m.vertex_color_use_as_albedo,
	]


## The rig (VatBake's) of `avatar` from its drive specs, grids and joints (see the class notes).
static func rig(
	key: String, drives: Array, grids: Array, joints: Array, outline_m: float, scaled: bool
) -> Dictionary:
	var gs: Array = []
	for g: Array in grids:
		var axes: Array = []
		for ax: Array in g:
			axes.append([ax[0], ax[1], bool((drives[ax[0]] as Array)[2])])
		gs.append(axes)
	var js: Array = []
	for j: Array in joints:
		js.append({"grid": j[0], "parent": j[1], "frame": j[2]})
	return {
		"key": key,
		"drives": drives.size(),
		"grids": gs,
		"joints": js,
		"row":
		func(g: int, d: PackedFloat64Array) -> Array: return _row(drives, grids, joints, g, d),
		"scaled": scaled,
		"outline_m": outline_m,
	}


static func _row(
	drives: Array, grids: Array, joints: Array, g: int, d: PackedFloat64Array
) -> Array:
	var vals: Array = []
	for ax: Array in grids[g]:
		var spec: Array = drives[ax[0]]
		vals.append(lerpf(spec[0], spec[1], d[ax[0]]))
	var out: Array = []
	for j: Array in joints:
		if j[0] == g:
			out.append((j[3] as Callable).call(vals))
	return out


## The drives VatCrowd sends for the raw numbers `raw` (each 0..1 over its spec's [lo, hi], a loop wrapped; a drive
## whose spec spans nothing as it is).
static func normalized(raw: PackedFloat32Array, drives: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(drives.size())
	for i in drives.size():
		var spec: Array = drives[i]
		var lo: float = spec[0]
		var span: float = float(spec[1]) - lo
		var v: float = raw[i] if i < raw.size() else 0.0
		if is_zero_approx(span):
			out[i] = v
			continue
		var u := (v - lo) / span
		out[i] = u - floor(u) if bool(spec[2]) else u
	return out


## The transform of `node` in the frame of its ancestor `top` (the nodes between, as the tree composes them).
static func between(top: Node, node: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n := node
	while n != top and n != null:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Elementary transforms: a slide, a stretch.
static func at(p: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, p)


static func stretch(s: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(s), Vector3.ZERO)


## A joint's make (see the class notes): `pre` x a turn about `axis` by k x its value x `post`.
static func turn(
	axis: Vector3, k := 1.0, pre := Transform3D.IDENTITY, post := Transform3D.IDENTITY
) -> Callable:
	var f := func(v: Array) -> Transform3D:
		return pre * Transform3D(Basis(axis, k * float(v[0])), Vector3.ZERO) * post
	return f


## A joint's make: `pre` x a slide to base + dir x its value x `post`.
static func slide(
	dir: Vector3, base := Vector3.ZERO, pre := Transform3D.IDENTITY, post := Transform3D.IDENTITY
) -> Callable:
	var f := func(v: Array) -> Transform3D:
		return pre * Transform3D(Basis.IDENTITY, base + dir * float(v[0])) * post
	return f


## A joint's make: `pre` x a stretch by base + per x its value.
static func stretch_by(base: Vector3, per: Vector3, pre := Transform3D.IDENTITY) -> Callable:
	var f := func(v: Array) -> Transform3D:
		return pre * Transform3D(Basis.from_scale(base + per * float(v[0])), Vector3.ZERO)
	return f


## VatBake.pose_error: a random state of `a` from `ranges` ({private var: [lo, hi]}, or [values...] to pick from),
## posed (`pose`: the avatar's own pose call) and returned.
static func sample(
	a: Object, rng: RandomNumberGenerator, ranges: Dictionary, pose: Callable
) -> Dictionary:
	var s := {}
	for k: String in ranges:
		var r: Variant = ranges[k]
		if r is Array and (r as Array).size() == 2 and not ((r as Array)[0] is int):
			s[k] = lerpf((r as Array)[0], (r as Array)[1], rng.randf())
		elif r is Array:
			s[k] = (r as Array)[rng.randi() % (r as Array).size()]
		else:
			s[k] = r
	apply(a, s, pose)
	return s


## Poses `a` in state `s` (sample's).
static func apply(a: Object, s: Dictionary, pose: Callable) -> void:
	for k: String in s:
		a.set(k, s[k])
	pose.call()
