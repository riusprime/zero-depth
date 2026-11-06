class_name VatCrowd
extends Node3D
## v0.10.5 W3-V1 (owner, 2026-11-06: the enemy VAT pilot, ViewPrefs.enemy_vat): draws every VAT enemy of a kind and
## look as one MultiMesh (VatBake's merged body, VatLooks' material), instead of a node per piece. Each enemy keeps its
## actor node, facing node and avatar (HordeAvatar with `vat` on: no pieces): ActorViews, HitFeel and HitStop drive
## them as before (the sync, the flinch, the hold, the hit flash and tints through show_hit, the culling's
## set_process), and the avatar still runs its own clock and drives. Once a frame, after them (PROCESS_PRIORITY), this
## writes one instance per enemy:
## - its transform: the actor's interpolated place (get_global_transform_interpolated), its facing (and the Void's
##   lean), the avatar's own transform (the flinch's lean, squash and knock), then the body's lift (the idle bob and
##   the rise-in, HordeAvatar.vat_lift);
## - INSTANCE_CUSTOM: the windup raise, the strike swing, the crouch, the gait phase (the pose the shader samples);
## - COLOR: the hit flash or status tint (HordeAvatar.hit_look) and the accent's glow (VatLooks.instance_color).
## A hidden actor (an egg, a vanished one) or a freed one draws nothing. Its shadow (ViewPrefs.enemy_shadows "proxy")
## is one more MultiMesh per kind of the same rest-pose stand-in EnemyShadows gives a node enemy (SHADOWS_ONLY), at the
## avatar's transform (no lift), as the stand-in followed the avatar; "blob" keeps the blob node on the actor.
## Presentation only (EI-07): it reads the avatars, never the sim.

## The kinds a VAT crowd can draw (the pilot: the Swarmer, the most numerous horde kind: a pack of 8).
## v0.10.5 W3-V4b (owner, 2026-11-06: "can we apply it to the rest of the enemies"): the other horde kinds.
const KINDS: Array[int] = [
	WorldReader.KIND_SWARMER,
	WorldReader.KIND_SPLITTER,
	WorldReader.KIND_SPLITLING,
	WorldReader.KIND_SHIELD_BEARER,
	WorldReader.KIND_MENDER,
	WorldReader.KIND_MINE_LAYER,
	WorldReader.KIND_SNIPER,
]
## After every node's _process (the avatars' frame-time animation runs at 0).
const PROCESS_PRIORITY := 1000
const START_CAPACITY := 32
## The floats per instance: a 3x4 transform, then (body only) the colour and the custom data.
const BODY_STRIDE := 20
const SHADOW_STRIDE := 12
## The crowd's culling box (m from the origin each way): the GPU clips each instance; the CPU never culls the crowd.
const BOX_M := 500.0

## The instances drawn by the last frame (bodies, shadows; tests, probes).
var drawn := 0
var shadows_drawn := 0
## The body sets by look key and the shadow sets by kind: {mmi, mm, entries [[root, facing, avatar]], buf, stride}.
var _looks := {}
var _shadows := {}


## v0.10.5 W3-V4b: a kind drawn by the owner's model is baked from that model; without its file (EnemyModels) the
## code-built stand-in stays on the old path.
static func supports(kind: int) -> bool:
	if not KINDS.has(kind):
		return false
	var model := HordeAvatar.model_id(kind)
	return model == &"" or EnemyModels.has_model(model)


func _init() -> void:
	name = "VatCrowd"
	process_priority = PROCESS_PRIORITY
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Draws `avatar` (built with `vat` on, under `facing` under the actor `root`) in the look it was built with; with
## `shadow`, its proxy shadow too.
func add(root: Node3D, facing: Node3D, avatar: HordeAvatar, outline: Color, shadow: bool) -> void:
	var kind := avatar.kind
	var key := VatBake.look_key(kind, avatar.enemy_tint, avatar.role_glow, outline)
	if not _looks.has(key):
		var mesh := VatBake.mesh_for(kind, avatar.enemy_tint, avatar.role_glow, outline)
		var pose := VatBake.pose_for(kind)
		var mat := VatLooks.material(pose, outline, HordeAvatar.OUTLINE_M)
		_looks[key] = _new_set(mesh, mat, true, pose)
	(_looks[key]["entries"] as Array).append([root, facing, avatar])
	if shadow:
		if not _shadows.has(kind):
			var proxy := shadow_mesh(kind)
			if proxy == null:
				return
			_shadows[kind] = _new_set(proxy, null, false)
		(_shadows[kind]["entries"] as Array).append([root, facing, avatar])


## The rest-pose shadow stand-in of `kind` (EnemyShadows': the same mesh a node enemy casts with).
static func shadow_mesh(kind: int) -> ArrayMesh:
	var ref := VatBake.reference_avatar(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	var mesh := EnemyShadows.proxy_mesh(kind, ref)
	ref.free()
	return mesh


## The enemies this crowd draws (live or not yet dropped).
func count() -> int:
	var n := 0
	for s: Dictionary in _looks.values():
		n += (s["entries"] as Array).size()
	return n


## The looks it draws (tests: one MultiMesh per look).
func looks() -> int:
	return _looks.size()


## The MultiMeshInstance3D nodes (bodies first, then shadows; tests, the warm-up).
func instances() -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for s: Dictionary in _looks.values():
		out.append(s["mmi"])
	for s: Dictionary in _shadows.values():
		out.append(s["mmi"])
	return out


## The values `avatar`'s body instance was last drawn with (tests; read back from the buffer written, so it holds
## without a renderer): {xf, color, custom}, or {} when it was not drawn.
func instance_of(avatar: HordeAvatar) -> Dictionary:
	for s: Dictionary in _looks.values():
		var buf: PackedFloat32Array = s["buf"]
		var k := 0
		for e: Array in s["entries"]:
			if not _drawable(e):
				continue
			if e[2] == avatar:
				if k >= int(s["drawn"]):
					return {}
				var o := k * BODY_STRIDE
				return {
					"xf":
					Transform3D(
						Vector3(buf[o], buf[o + 4], buf[o + 8]),
						Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
						Vector3(buf[o + 2], buf[o + 6], buf[o + 10]),
						Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
					),
					"color": Color(buf[o + 12], buf[o + 13], buf[o + 14], buf[o + 15]),
					"custom": Vector4(buf[o + 16], buf[o + 17], buf[o + 18], buf[o + 19]),
				}
			k += 1
	return {}


func _process(_delta: float) -> void:
	drawn = 0
	shadows_drawn = 0
	for s: Dictionary in _looks.values():
		drawn += _write(s, true)
	for s: Dictionary in _shadows.values():
		shadows_drawn += _write(s, false)


## v0.10.5 W3-V1: one instance per drawable enemy of set `s`; returns how many.
func _write(s: Dictionary, body: bool) -> int:
	var entries: Array = s["entries"]
	var keep := 0
	for e: Array in entries:
		if _alive(e):
			entries[keep] = e
			keep += 1
	entries.resize(keep)
	var mm: MultiMesh = s["mm"]
	var stride: int = s["stride"]
	var buf: PackedFloat32Array = s["buf"]
	if keep > mm.instance_count:
		var cap := maxi(mm.instance_count, START_CAPACITY)
		while cap < keep:
			cap *= 2
		mm.instance_count = cap
		buf.resize(cap * stride)
	var inv := (s["mmi"] as Node3D).global_transform.affine_inverse()
	var n := 0
	for e: Array in entries:
		if not _drawable(e):
			continue
		var avatar: HordeAvatar = e[2]
		var root: Node3D = e[0]
		var xf: Transform3D = (
			inv
			* root.get_global_transform_interpolated()
			* (e[1] as Node3D).transform
			* avatar.transform
		)
		if body:  # v0.10.5 W3-V4b: the body's own moves (the Swarmer's: its lift)
			xf = xf * avatar.vat_offset()
		var o := n * stride
		var b := xf.basis
		buf[o] = b.x.x
		buf[o + 1] = b.y.x
		buf[o + 2] = b.z.x
		buf[o + 3] = xf.origin.x
		buf[o + 4] = b.x.y
		buf[o + 5] = b.y.y
		buf[o + 6] = b.z.y
		buf[o + 7] = xf.origin.y
		buf[o + 8] = b.x.z
		buf[o + 9] = b.y.z
		buf[o + 10] = b.z.z
		buf[o + 11] = xf.origin.z
		if body:
			var c := VatLooks.instance_color(avatar.hit_look(), avatar.glow_energy())
			buf[o + 12] = c.r
			buf[o + 13] = c.g
			buf[o + 14] = c.b
			buf[o + 15] = c.a
			var d := avatar.vat_drives(s["pose"])  # v0.10.5 W3-V4b: each kind's own
			buf[o + 16] = d.x
			buf[o + 17] = d.y
			buf[o + 18] = d.z
			buf[o + 19] = d.w
		n += 1
	if n > 0:
		mm.buffer = buf
	mm.visible_instance_count = n
	s["buf"] = buf  # (a packed array is copied on write: the set keeps the one written)
	s["drawn"] = n
	return n


static func _alive(e: Array) -> bool:
	var root: Variant = e[0]
	return (
		is_instance_valid(root)
		and not (root as Node).is_queued_for_deletion()
		and is_instance_valid(e[2])
	)


static func _drawable(e: Array) -> bool:
	return (e[2] as Node3D).is_visible_in_tree()


func _new_set(mesh: Mesh, mat: Material, body: bool, pose := {}) -> Dictionary:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = body
	mm.use_custom_data = body
	mm.mesh = mesh
	mm.custom_aabb = AABB(Vector3(-BOX_M, -BOX_M, -BOX_M), Vector3.ONE * BOX_M * 2.0)
	mm.instance_count = START_CAPACITY
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "VatBodies" if body else "VatShadows"
	mmi.multimesh = mm
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if mat != null:
		mmi.material_override = mat
	mmi.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if body
		else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	)
	add_child(mmi)
	var buf := PackedFloat32Array()
	var stride := BODY_STRIDE if body else SHADOW_STRIDE
	buf.resize(START_CAPACITY * stride)
	return {
		"mmi": mmi, "mm": mm, "entries": [], "buf": buf, "stride": stride, "pose": pose, "drawn": 0
	}


## v0.10.5 W3-V1 (ShaderWarmup): one still instance of `kind` in this look, so its shader variant compiles behind the
## loading cover (and its bake is made there).
static func warm_proxy(
	kind: int, tint: Color, role_glow: float, outline: Color
) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = VatBake.mesh_for(kind, tint, role_glow, outline)
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	mm.set_instance_color(0, VatLooks.instance_color(EnemyLooks.HIT_OFF, 1.5))
	mm.set_instance_custom_data(0, Color(0, 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "VatWarm"
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # set outside the physics step, like the crowd's
	mmi.multimesh = mm
	mmi.material_override = VatLooks.material(
		VatBake.pose_for(kind), outline, HordeAvatar.OUTLINE_M
	)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
