class_name CritterCrowd
extends Node3D
## v0.11.0 O9c (owner Q16-c: "Batch now"): the horde critters drawn with no node each. A surge brings up to its
## alive_cap of one small kind at once; a node per critter (its actor root, facing, HordeAvatar with its own
## _process, bar and blob) cost ~40 us a frame each (O9b's breakdown), so ActorViews gives the critters to this crowd
## instead. Each sync (once a frame that ran a tick) it reads the WorldReader's columns straight (ids, kinds, places,
## facings, states, HP: no call per actor per field) into its own slot rows (packed arrays, a slot per live critter,
## swap-removed when one goes); each frame it poses every slot and writes one MultiMesh instance per critter:
## - the body: the same baked VAT mesh and material VatCrowd draws a critter with (VatBake.mesh_for, VatLooks), so the
##   look is the same (bodies, biome colours, the floor's cast and role glow); the instance transform is the place
##   (interpolated between the last two ticks, as the physics interpolation drew the node), the facing, then the
##   body's own move (CritterBodies.body_move_v: the bat's flight, the flea's hop, the crab's slide, the mote's float,
##   the idle bob, the rise-in's sink, as HordeAvatar._pose reckoned them); INSTANCE_CUSTOM.w the gait's phase
##   (CritterBodies.phase_at); COLOR the hit flash or status tint (set_hit, from ActorViews' flash and set_tint) and
##   the eye's glow (VatLooks.instance_color);
## - the shadow: ViewPrefs.enemy_shadows "proxy": VatCrowd.shadow_mesh (the same rest-pose stand-in, SHADOWS_ONLY) at
##   the place and facing; "blob": EnemyShadows' blob disc, flat under it;
## - the health bar, once it is hurt: a quad over its head, shrunk toward its centre by the HP left (no chunk trail).
## A critter has no flinch, hold or status rings (they need a node); its hit flash, damage numbers (events) and death
## spark (HitFeel, from the reader) are as before. Presentation only (EI-07): it reads, never writes.

## After the views' syncs and the other nodes' _process (as VatCrowd).
const PROCESS_PRIORITY := 1000
const START_CAPACITY := 64
const BODY_STRIDE := 20
const SHADOW_STRIDE := 12
## The crowd's culling box (m from the origin each way): the GPU clips each instance.
const BOX_M := 500.0
## The bar over a hurt critter (ActorViews' sizes).
const BAR_SIZE := Vector2(0.55, 0.07)
const BAR_LIFT_M := 0.55
## HordeAvatar's idle bob, walk pace and rise-in rates.
const WALK_FULL_MPS := 2.0
const FIRST := WorldReader.KIND_DUST_MITE
const LAST := WorldReader.KIND_STAR_MOTE

## The floor's look (ActorViews sets them before the first critter).
var enemy_tint := Color(0, 0, 0, 0)
var role_glow := 0.0
var outline := Color("#1A1A22")
## Altars an actor stands on (ActorViews.grounds).
var grounds: Array[AltarStage] = []
## The instances drawn by the last frame (bodies, shadows, bars; tests, probes).
var drawn := 0
var shadows_drawn := 0
var bars_drawn := 0

## The slots: one per live critter, in no order (a removed one's place takes the last).
var _ids := PackedInt32Array()
var _kind := PackedInt32Array()
var _x0 := PackedFloat32Array()  # the place at the tick before (the interpolation's start)
var _y0 := PackedFloat32Array()
var _x1 := PackedFloat32Array()  # the place at the latest tick
var _y1 := PackedFloat32Array()
var _yaw0 := PackedFloat32Array()
var _yaw1 := PackedFloat32Array()
var _spawning := PackedByteArray()
var _hp := PackedFloat32Array()  # the HP's share (1: full, no bar)
var _t := PackedFloat32Array()  # the frame-time clock since it came (the gait, the bob)
var _rise := PackedFloat32Array()
var _walk := PackedFloat32Array()
var _lx := PackedFloat32Array()  # where it was drawn last frame (its walk pace)
var _ly := PackedFloat32Array()
var _slide := PackedFloat32Array()  # the crab's slide (0..1 through it; < 0 none)
var _armed := PackedByteArray()
var _hit := PackedVector4Array()
var _seen := PackedInt32Array()
var _slot_of := {}
var _gen := 0
## Per kind: {body: [mmi, mm], shadow: [mmi, mm] or [], buf, sbuf}; and the one bar set.
var _sets := {}
var _bar_mm: MultiMesh
var _bar_buf := PackedFloat32Array()
var _shadow_mode := ""


static func takes(kind: int) -> bool:
	return kind >= FIRST and kind <= LAST


func _init() -> void:
	name = "CritterCrowd"
	process_priority = PROCESS_PRIORITY
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## The critters it draws (live, as of the last sync).
func count() -> int:
	return _ids.size()


func has(id: int) -> bool:
	return _slot_of.has(id)


## The critter ids it draws (tests).
func ids() -> PackedInt32Array:
	return _ids


## The hit flash or status tint (EnemyLooks.hit_value; HIT_OFF: none) critter `id` shows.
func set_hit(id: int, v: Vector4) -> void:
	var k: int = _slot_of.get(id, -1)
	if k >= 0:
		_hit[k] = v


## Reads the critters from `reader`'s columns (`latched`: the place a tick before on a frame that ran two or more).
## Returns how many slots went (critters gone since the last sync).
func sync(reader: WorldReader, latched: LatchedReader = null) -> int:
	_gen += 1
	var ids_c := reader.actor_ids_column()
	var kinds := reader.actor_kinds_column()
	var xs := reader.actor_pos_x_column()
	var ys := reader.actor_pos_y_column()
	var faces := reader.actor_facing_column()
	var states := reader.actor_state_column()
	var hps := reader.actor_hp_column()
	var maxes := reader.actor_max_hp_column()
	var spawn := WorldReader.STATE_SPAWN
	for i in range(1, ids_c.size()):
		var kind := kinds[i]
		if kind < FIRST or kind > LAST:
			continue
		var id := ids_c[i]
		var x := xs[i]
		var y := ys[i]
		var yaw := SimPlane.yaw_of(faces[i])
		var k: int = _slot_of.get(id, -1)
		if k < 0:
			k = _add(id, kind, x, y, yaw, states[i] == spawn, reader.actor_radius(i))
		else:
			var before: Variant = latched.actor_pos_before(i) if latched != null else null
			if before != null:
				_x0[k] = (before as Vector2).x
				_y0[k] = (before as Vector2).y
			else:
				_x0[k] = _x1[k]
				_y0[k] = _y1[k]
			_x1[k] = x
			_y1[k] = y
			_yaw0[k] = _yaw1[k]
			_yaw1[k] = yaw
		_spawning[k] = 1 if states[i] == spawn else 0
		_hp[k] = float(hps[i]) / maxf(1.0, maxes[i])
		_seen[k] = _gen
	var gone := 0
	var k := _ids.size() - 1
	while k >= 0:
		if _seen[k] != _gen:
			_remove(k)
			gone += 1
		k -= 1
	return gone


func _add(id: int, kind: int, x: float, y: float, yaw: float, spawning: bool, radius: float) -> int:
	_set_of(kind, radius)
	var k := _ids.size()
	_slot_of[id] = k
	_ids.append(id)
	_kind.append(kind)
	_x0.append(x)
	_y0.append(y)
	_x1.append(x)
	_y1.append(y)
	_yaw0.append(yaw)
	_yaw1.append(yaw)
	_spawning.append(1 if spawning else 0)
	_hp.append(1.0)
	_t.append(0.0)
	_rise.append(0.0 if spawning else 1.0)
	_walk.append(0.0)
	_lx.append(INF)
	_ly.append(INF)
	_slide.append(-1.0)
	_armed.append(0)
	_hit.append(EnemyLooks.HIT_OFF)
	_seen.append(_gen)
	return k


## Swap-removes slot `k` (the last slot takes its place).
func _remove(k: int) -> void:
	var last := _ids.size() - 1
	_slot_of.erase(_ids[k])
	if k != last:
		_ids[k] = _ids[last]
		_slot_of[_ids[k]] = k
		for col: StringName in [
			&"_kind",
			&"_x0",
			&"_y0",
			&"_x1",
			&"_y1",
			&"_yaw0",
			&"_yaw1",
			&"_spawning",
			&"_hp",
			&"_t",
			&"_rise",
			&"_walk",
			&"_lx",
			&"_ly",
			&"_slide",
			&"_armed",
			&"_hit",
			&"_seen"
		]:
			var arr: Variant = get(col)
			arr[k] = arr[last]
			set(col, arr)
	for col: StringName in [
		&"_ids",
		&"_kind",
		&"_x0",
		&"_y0",
		&"_x1",
		&"_y1",
		&"_yaw0",
		&"_yaw1",
		&"_spawning",
		&"_hp",
		&"_t",
		&"_rise",
		&"_walk",
		&"_lx",
		&"_ly",
		&"_slide",
		&"_armed",
		&"_hit",
		&"_seen"
	]:
		var arr: Variant = get(col)
		arr.resize(last)
		set(col, arr)


## The draw set of `kind` (made with its first critter, of body radius `radius`: its blob's size).
func _set_of(kind: int, radius: float) -> Dictionary:
	var s: Dictionary = _sets.get(kind, {})
	if not s.is_empty():
		return s
	_shadow_mode = ViewPrefs.enemy_shadows
	var mesh := VatBake.mesh_for(kind, enemy_tint, role_glow, outline)
	var pose := VatBake.pose_for(kind)
	var mat := VatLooks.material(pose, bool(mesh.get_meta(&"two_sided", false)))
	var off := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s["body"] = _new_mm(mesh, mat, true, "CritterBodies%d" % kind, off)
	s["buf"] = PackedFloat32Array()
	s["shadow"] = []
	s["sbuf"] = PackedFloat32Array()
	if _shadow_mode == "blob":
		var blob := EnemyShadows.blob_parts()
		s["shadow"] = _new_mm(blob[0], blob[1], false, "CritterBlobs%d" % kind, off)
		s["blob_scale"] = maxf(radius, 0.2) * EnemyShadows.BLOB_SCALE
	else:
		var proxy := VatCrowd.shadow_mesh(kind)
		if proxy != null:
			s["shadow"] = _new_mm(
				proxy,
				null,
				false,
				"CritterShadows%d" % kind,
				GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			)
	s["height"] = HordeAvatar.height_of(kind)
	_sets[kind] = s
	return s


func _new_mm(
	mesh: Mesh,
	mat: Material,
	body: bool,
	pname: String,
	cast: GeometryInstance3D.ShadowCastingSetting
) -> Array:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = body
	mm.use_custom_data = body
	mm.mesh = mesh
	mm.custom_aabb = AABB(Vector3(-BOX_M, -BOX_M, -BOX_M), Vector3.ONE * BOX_M * 2.0)
	mm.instance_count = START_CAPACITY
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = pname
	mmi.multimesh = mm
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if mat != null:
		mmi.material_override = mat
	mmi.cast_shadow = cast
	add_child(mmi)
	return [mmi, mm]


func _bar_set() -> MultiMesh:
	if _bar_mm != null:
		return _bar_mm
	var quad := QuadMesh.new()
	quad.size = BAR_SIZE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = ThemePalette.color(&"enemy_bar")
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	_bar_mm = _new_mm(quad, m, false, "CritterBars", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)[1]
	return _bar_mm


## The draw nodes (tests, the probe's A/B).
func instances() -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for c in get_children():
		if c is MultiMeshInstance3D:
			out.append(c)
	return out


func _process(delta: float) -> void:
	advance(delta)


## Poses every slot `delta` s on and writes the instances (the frame's draw).
func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	var f := 1.0
	if is_inside_tree() and get_tree().physics_interpolation:
		f = Engine.get_physics_interpolation_fraction()
	var calm := ViewPrefs.reduced_motion
	var inv := global_transform.affine_inverse() if is_inside_tree() else Transform3D.IDENTITY
	var n_all := _ids.size()
	drawn = 0
	shadows_drawn = 0
	bars_drawn = 0
	# The slots' frame-time state first (the clock, the rise-in, the crab's walk and slide).
	for k in n_all:
		_t[k] += dt
		var spawning := _spawning[k] == 1
		_rise[k] = move_toward(_rise[k], 0.0 if spawning else 1.0, dt * (6.0 if spawning else 2.5))
	var bars := 0
	for kind: int in _sets:
		var s: Dictionary = _sets[kind]
		var mm: MultiMesh = (s["body"] as Array)[1]
		var smm: MultiMesh = (
			null if (s["shadow"] as Array).is_empty() else (s["shadow"] as Array)[1]
		)
		var n := 0
		for k in n_all:
			if _kind[k] == kind:
				n += 1
		_fit(mm, n)
		if smm != null:
			_fit(smm, n)
		var buf: PackedFloat32Array = s["buf"]
		buf.resize(mm.instance_count * BODY_STRIDE)
		var sbuf: PackedFloat32Array = s["sbuf"]
		if smm != null:
			sbuf.resize(smm.instance_count * SHADOW_STRIDE)
		var h: float = s["height"]
		var blob := _shadow_mode == "blob"
		var bs: float = s.get("blob_scale", 1.0)
		var hz: float = CritterBodies.GAIT_HZ.get(kind, 1.0)
		var crab := kind == WorldReader.KIND_ICE_CRAB
		var j := 0
		for k in n_all:
			if _kind[k] != kind:
				continue
			var x := lerpf(_x0[k], _x1[k], f)
			var y := lerpf(_y0[k], _y1[k], f)
			var at := Vector3(x, 0.0, -y)
			for g in grounds:
				at.y = maxf(at.y, g.height_at(at))
			var t := _t[k]
			if crab:
				_crab_step(k, x, y, dt)
			_lx[k] = x
			_ly[k] = y
			var yb := Basis(Vector3.UP, lerp_angle(_yaw0[k], _yaw1[k], f))
			var mv := CritterBodies.body_move_v(kind, t, _slide[k], calm)
			var bob := 0.0 if calm else sin(t * HordeAvatar.BOB_RATE) * HordeAvatar.BOB_M
			var lift := bob - (1.0 - _rise[k]) * h
			var bp := Vector3(mv.x, lift + mv.y, 0.0)
			var xf := inv * Transform3D(yb * Basis(Vector3.BACK, mv.z), at + yb * bp)
			var o := j * BODY_STRIDE
			_put(buf, o, xf)
			var c := VatLooks.instance_color(_hit[k], 1.5 * lerpf(0.2, 1.0, _rise[k]))
			buf[o + 12] = c.r
			buf[o + 13] = c.g
			buf[o + 14] = c.b
			buf[o + 15] = c.a
			buf[o + 16] = 0.0
			buf[o + 17] = 0.0
			buf[o + 18] = 0.0
			buf[o + 19] = fposmod(t * hz, 1.0)
			if smm != null:
				var sx := (
					Transform3D(
						Basis.from_scale(Vector3.ONE * bs), at + Vector3(0, EnemyShadows.BLOB_Y, 0)
					)
					if blob
					else Transform3D(yb, at)
				)
				_put(sbuf, j * SHADOW_STRIDE, inv * sx)
			if _hp[k] < 1.0 and not _spawning[k] == 1:
				bars += 1
			j += 1
		if j > 0:
			mm.buffer = buf
			if smm != null:
				smm.buffer = sbuf
		mm.visible_instance_count = j
		if smm != null:
			smm.visible_instance_count = j
			shadows_drawn += j
		s["buf"] = buf
		s["sbuf"] = sbuf
		drawn += j
	_draw_bars(bars, f, inv)


## The bars over the hurt critters (none at full HP, none while it rises in).
func _draw_bars(bars: int, f: float, inv: Transform3D) -> void:
	if bars == 0:
		if _bar_mm != null:
			_bar_mm.visible_instance_count = 0
		return
	var mm := _bar_set()
	_fit(mm, bars)
	_bar_buf.resize(mm.instance_count * SHADOW_STRIDE)
	var j := 0
	for k in _ids.size():
		if _hp[k] >= 1.0 or _spawning[k] == 1:
			continue
		var h: float = (_sets[_kind[k]] as Dictionary)["height"]
		var at := Vector3(lerpf(_x0[k], _x1[k], f), h + BAR_LIFT_M, -lerpf(_y0[k], _y1[k], f))
		var frac := clampf(_hp[k], 0.02, 1.0)
		_put(
			_bar_buf,
			j * SHADOW_STRIDE,
			inv * Transform3D(Basis.from_scale(Vector3(frac, 1, 1)), at)
		)
		j += 1
	mm.buffer = _bar_buf
	mm.visible_instance_count = j
	bars_drawn = j


## The crab's walk pace from how far it was drawn since last frame, and its slide as it stops (HordeAvatar's).
func _crab_step(k: int, x: float, y: float, dt: float) -> void:
	if dt <= 0.0:
		return
	var speed := 0.0 if _lx[k] == INF else Vector2(x - _lx[k], y - _ly[k]).length() / dt
	_walk[k] = move_toward(_walk[k], clampf(speed / WALK_FULL_MPS, 0.0, 1.0), dt * 4.0)
	if _walk[k] > 0.6:
		_armed[k] = 1
	elif _armed[k] == 1 and _walk[k] < 0.25:
		_armed[k] = 0
		_slide[k] = 0.0
	if _slide[k] >= 0.0:
		_slide[k] += dt / CritterBodies.SLIDE_SECONDS
		if _slide[k] > 1.0:
			_slide[k] = -1.0


## Grows `mm` (doubling) to hold `n` instances.
static func _fit(mm: MultiMesh, n: int) -> void:
	if n <= mm.instance_count:
		return
	var cap := maxi(mm.instance_count, START_CAPACITY)
	while cap < n:
		cap *= 2
	mm.instance_count = cap


## A 3x4 transform into `buf` at `o` (MultiMesh's row-major layout).
static func _put(buf: PackedFloat32Array, o: int, xf: Transform3D) -> void:
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


## The values critter `id`'s body instance was last drawn with (tests; read back from the buffer written):
## {xf, color, custom}, or {} when it is not drawn.
func instance_of(id: int) -> Dictionary:
	var k: int = _slot_of.get(id, -1)
	if k < 0:
		return {}
	var kind := _kind[k]
	var j := 0
	for q in k:
		if _kind[q] == kind:
			j += 1
	var s: Dictionary = _sets[kind]
	var mm: MultiMesh = (s["body"] as Array)[1]
	if j >= mm.visible_instance_count:
		return {}
	var buf: PackedFloat32Array = s["buf"]
	var o := j * BODY_STRIDE
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
