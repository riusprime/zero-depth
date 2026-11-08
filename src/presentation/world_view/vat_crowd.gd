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
## v0.10.5 W3-V4a (owner, 2026-11-06: VAT for every regular enemy): any avatar with a VatBake rig (a HordeAvatar's, or
## its own vat_rig(): the Charger and the Hatchling). The drives are VatBake.drives_of (the avatar's vat_drives(), or a
## horde avatar's four); a rig with more than four sends the rest in a per-look drive texture, one row per instance
## (written with the buffer, in the same order), and its lift is the avatar's vat_lift().
## Presentation only (EI-07): it reads the avatars, never the sim.

## The kinds a VAT crowd can draw (the pilot: the Swarmer, the most numerous horde kind: a pack of 8; v0.10.5 W3-V4a:
## the Charger and the Brood Mother's Hatchling).
## v0.10.5 W3-V4b: the other horde kinds (HordeVat).
## v0.10.5 W3-V4c: the Needle, Warden, Arc Caster and Bomb Drone (SoloVat.KINDS).
## v0.11.0 S4: the Hive Lens's Lens Drone.
const KINDS: Array[int] = [
	WorldReader.KIND_SWARMER,
	WorldReader.KIND_CHARGER,
	WorldReader.KIND_HATCHLING,
	WorldReader.KIND_SPLITTER,
	WorldReader.KIND_SPLITLING,
	WorldReader.KIND_SHIELD_BEARER,
	WorldReader.KIND_MENDER,
	WorldReader.KIND_MINE_LAYER,
	WorldReader.KIND_SNIPER,
	WorldReader.KIND_NEEDLE,
	WorldReader.KIND_WARDEN,
	WorldReader.KIND_ARC_CASTER,
	WorldReader.KIND_BOMB_DRONE,
	WorldReader.KIND_LENS_DRONE,
	WorldReader.KIND_SCRAP_HOUND,  # v0.11.0 O17a: the owner's model (SoloVat)
	WorldReader.KIND_ROCK_LURKER,  # v0.11.0 O17b: the owner's model (SoloVat)
	WorldReader.KIND_STONE_THROWER,  # v0.11.0 O17c: the owner's model (SoloVat)
	WorldReader.KIND_DUST_MITE,  # v0.11.0 O9: the horde critters (CritterBodies, on HordeVat's path)
	WorldReader.KIND_CAVE_BAT,
	WorldReader.KIND_EMBER_FLEA,
	WorldReader.KIND_ICE_CRAB,
	WorldReader.KIND_STAR_MOTE,
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
## The body sets by look key and the shadow sets by kind: {mmi, mm, entries [[root, facing, avatar]], buf, stride,
## pose, drawn; a rig with more than four drives: dbuf, dtex, mat (its drive texture's floats, the texture)}.
var _looks := {}
var _shadows := {}


## v0.10.5 W3-V4b: a horde kind drawn by the owner's model is baked from that model; without its file (EnemyModels)
## the code-built stand-in stays on the old path.
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
func add(root: Node3D, facing: Node3D, avatar: AvatarBase, outline: Color, shadow: bool) -> void:
	var kind: int = avatar.get(&"kind")
	var key := VatBake.look_key(kind, avatar.enemy_tint, avatar.role_glow, outline)
	if not _looks.has(key):
		var mesh := VatBake.mesh_for(kind, avatar.enemy_tint, avatar.role_glow, outline)
		var pose := VatBake.pose_for(kind)
		var mat := VatLooks.material(
			pose, outline, pose["outline_m"], bool(mesh.get_meta(&"two_sided", false))
		)
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
	var ref := VatBake.reference_of(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
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
## without a renderer): {xf, color, custom, drives (all of them: custom's four, then the drive texture's)}, or {} when
## it was not drawn.
func instance_of(avatar: Node3D) -> Dictionary:
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
				var drives := PackedFloat32Array(
					[buf[o + 16], buf[o + 17], buf[o + 18], buf[o + 19]]
				)
				if s.has("dbuf"):
					var dn: int = int((s["pose"] as Dictionary)["drive_texels"]) * 4
					var db: PackedFloat32Array = s["dbuf"]
					drives.append_array(db.slice(k * dn, k * dn + dn))
				return {
					"drives": drives,
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
	var pose: Dictionary = s["pose"]
	var dn := int(pose.get("drive_texels", 0)) * 4 if body else 0
	var dbuf := PackedFloat32Array()
	if dn > 0:
		dbuf = s["dbuf"]
		if dbuf.size() < mm.instance_count * dn:
			dbuf.resize(mm.instance_count * dn)
	var n := 0
	for e: Array in entries:
		if not _drawable(e):
			continue
		var avatar: AvatarBase = e[2]
		var root: Node3D = e[0]
		var xf: Transform3D = (
			inv
			* root.get_global_transform_interpolated()
			* (e[1] as Node3D).transform
			* avatar.transform
		)
		if body and avatar is HordeAvatar:  # v0.10.5 W3-V4b: the body's own moves (the Swarmer's: its lift)
			xf = xf * (avatar as HordeAvatar).vat_offset()
		elif body:
			xf = xf.translated_local(Vector3(0, float(avatar.call(&"vat_lift")), 0))
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
			var c := VatLooks.instance_color(avatar.hit_look(), float(avatar.call(&"glow_energy")))
			buf[o + 12] = c.r
			buf[o + 13] = c.g
			buf[o + 14] = c.b
			buf[o + 15] = c.a
			var d := VatBake.drives_of(avatar, pose)
			for k in 4:
				buf[o + 16 + k] = d[k] if k < d.size() else 0.0
			for k in dn:
				dbuf[n * dn + k] = d[4 + k] if 4 + k < d.size() else 0.0
		n += 1
	if n > 0:
		mm.buffer = buf
		if dn > 0:
			_upload_drives(s, dbuf, dn / 4, mm.instance_count)
	mm.visible_instance_count = n
	s["buf"] = buf  # (a packed array is copied on write: the set keeps the one written)
	if dn > 0:
		s["dbuf"] = dbuf
	s["drawn"] = n
	return n


## v0.10.5 W3-V4a: the drive texture of set `s` (`texels` wide, a row per instance of its capacity) from `dbuf`; a new
## texture (given to the material) when the capacity grew.
func _upload_drives(s: Dictionary, dbuf: PackedFloat32Array, texels: int, rows: int) -> void:
	var img := Image.create_from_data(
		texels, rows, false, Image.FORMAT_RGBAF, dbuf.slice(0, texels * rows * 4).to_byte_array()
	)
	var tex: ImageTexture = s.get("dtex")
	if tex != null and tex.get_height() == rows:
		tex.update(img)
		return
	tex = ImageTexture.create_from_image(img)
	s["dtex"] = tex
	VatLooks.set_drives(s["mat"], tex)


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
	var out := {
		"mmi": mmi, "mm": mm, "entries": [], "buf": buf, "stride": stride, "pose": pose, "drawn": 0
	}
	if body and int(pose.get("drive_texels", 0)) > 0:
		out["dbuf"] = PackedFloat32Array()
		out["mat"] = mat
		VatLooks.set_drives(mat, _zero_drives(int(pose["drive_texels"])))
	return out


## v0.10.5 W3-V4a: a drive texture of one still instance (every drive 0).
static func _zero_drives(texels: int) -> ImageTexture:
	var data := PackedFloat32Array()
	data.resize(texels * 4)
	return ImageTexture.create_from_image(
		Image.create_from_data(texels, 1, false, Image.FORMAT_RGBAF, data.to_byte_array())
	)


## v0.10.5 W3-V1 (ShaderWarmup): one still instance of `kind` in this look, so its shader variant compiles behind the
## loading cover (and its bake is made there).
static func warm_proxy(
	kind: int, tint: Color, role_glow: float, outline: Color
) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var mesh := VatBake.mesh_for(kind, tint, role_glow, outline)
	mm.mesh = mesh
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	mm.set_instance_color(0, VatLooks.instance_color(EnemyLooks.HIT_OFF, 1.5))
	mm.set_instance_custom_data(0, Color(0, 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "VatWarm"
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # set outside the physics step, like the crowd's
	mmi.multimesh = mm
	var pose := VatBake.pose_for(kind)
	var mat := VatLooks.material(
		pose, outline, pose["outline_m"], bool(mesh.get_meta(&"two_sided", false))
	)
	if int(pose["drive_texels"]) > 0:
		VatLooks.set_drives(mat, _zero_drives(int(pose["drive_texels"])))
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
