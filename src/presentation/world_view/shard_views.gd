class_name ShardViews
extends Node3D
## Shard gems: when a kill pays shards (a SHARDS event), up to MAX_PER_KILL small violet crystals burst
## from the body, hang for a moment, then fly into the player and vanish. Cosmetic and in frame time: the sim
## already counted the shards. Jitter comes from a presentation RNG seeded per event, so shots look the same.
## Each gem is an outlined faceted shard (ShardMesh) lit by the scene with its
## own violet emission, instead of a flat unshaded crystal. The chest's price gem keeps shared_material().
## The flying gems are instances of two multimeshes (the crystals and their outline shells), so a burst of many
## payouts at once builds no node: one draw per half, the gems' places written once a frame.
## A normal kill's shards lie on
## the floor in the sim (ShardDrops); each drop is a small glowing cluster of the same gems on the ground (more gems
## for a bigger drop, DROP_GEMS_MAX at most), turning slowly. When the hero takes one (it leaves the reader with a
## pickup SHARDS event at its spot) the cluster is pulled into the hero over PULL_S and vanishes; a drop that left by
## merging (the floor's cap) just goes. The pickup's SHARDS event bursts nothing. Instant payouts (boss, chests,
## events) still burst and fly as before.
## A drop is an instance too: each cluster shape has a crystal batch and an outline batch, and every drop's glow
## sprite is an instance of one more batch, so a drop that lands builds no node and adds nothing to the tree. The
## shapes' meshes are built once a session, before the first fight (warm_shapes(), a floor load's jobs).

const COLOR := Color("#B48CFF")
const MAX_PER_KILL := 8
const MAX_ALIVE := 64
const BURST_S := 0.28
const SPEED := 13.0
const HEIGHT := 0.8
const PULL_S := 0.15
const DROP_GEMS_MAX := 4
const DROP_HEIGHT := 0.34
const DROP_SPREAD := 0.26
## How many shapes a drop of one size is drawn from. Building and baking a cluster is script work on every vertex,
## so each size and shape is built once a session and every drop of it is an instance of its meshes. A drop still
## turns by its own number.
const DROP_SHAPES := 16
## The drop sizes: two gems up to DROP_GEMS_MAX.
const DROP_SIZES := DROP_GEMS_MAX - 1
## Drops drawn at once (the floor's cap, ShardDrops.MAX_ON_FLOOR, plus the ones being pulled), and in one shape.
const DROP_CAP := 64
## The drops' turn about the vertical, radians a second.
const DROP_SPIN := 0.8
## A flying gem's outline shell margin (its share of the gem's size).
const GEM_OUTLINE := 0.2
## Round a drop's place: its crystals' reach, metres (their shadow batch is bounded by its drops, not by the room).
const DROP_REACH := 0.6
const ROOM_BOX := AABB(Vector3(-512, -8, -512), Vector3(1024, 64, 1024))

static var _material: StandardMaterial3D
static var _mesh: ArrayMesh
static var _gem_material: StandardMaterial3D
## The drop shapes' meshes by shape index ((gems - 2) * DROP_SHAPES + shape): [crystal, outline shell], empty until
## built. Meshes only (no node), shared by every view of the session.
static var _shape_meshes: Array[Array] = []
static var _shapes_made := 0
## Every drop's glow sprite: ShardMesh.glow's quad and material.
static var _glow_mesh: Mesh
static var _glow_mat: Material

var _last_seq := 0
var _target := Vector3.ZERO
## The flying gems by slot (a slot keeps its gem for the whole flight), a column each: place, velocity, age (s),
## turn about the vertical (rad), and whether the slot holds a gem.
var _g_pos := PackedVector3Array()
var _g_vel := PackedVector3Array()
var _g_age := PackedFloat64Array()
var _g_turn := PackedFloat32Array()
var _g_live := PackedByteArray()
## The slots burst since the gems last stepped (their interpolation starts at that step).
var _fresh := PackedInt32Array()
## The gems' crystals and outline shells (made at the first burst).
var _crystals: MultiMeshInstance3D
var _outlines: MultiMeshInstance3D
## The drops the last sync laid out (their places never change: a merge only grows the amount).
var _drop_seqs := PackedInt32Array()
var _drop_amounts := PackedInt32Array()
## The drops on the floor by sequence number (each its glow slot), and the pulled ones (their glow slots).
var _drops := {}
var _pulled := PackedInt32Array()
## The drops' batches: a crystal and an outline shell batch per shape, and every drop's glow in one.
var _shape_batches: Array[Array] = []
var _glows: MultiMeshInstance3D
## Per shape: which of its slots hold a drop, how many instances its batches draw, and its crystals' bounds.
var _shape_used: Array[PackedByteArray] = []
var _shape_shown := PackedInt32Array()
var _shape_box: Array[AABB] = []
## The drops by glow slot, a column each: 0 free, 1 on the floor, 2 pulled; its shape and its slot in the shape's
## batches; its gem count; its place; its turn (32-bit, as a node's rotation keeps it); seconds pulled; and whether
## it is drawn yet (its first place starts its interpolation, as a node entering the tree did).
var _d_live := PackedByteArray()
var _d_shape := PackedInt32Array()
var _d_slot := PackedInt32Array()
var _d_n := PackedInt32Array()
var _d_pos := PackedVector3Array()
var _d_turn := PackedFloat32Array()
var _d_age := PackedFloat64Array()
var _d_fresh := PackedByteArray()


## The gem material, shared with the price tag on chests (emission on from creation).
static func shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = COLOR
		_material.emission_enabled = true
		_material.emission = COLOR
		_material.emission_energy_multiplier = 2.4
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _material


## The flying gems' material: the shard look (lit, toned facets, emission on from creation).
static func gem_material() -> StandardMaterial3D:
	if _gem_material == null:
		_gem_material = ShardMesh.crystal_material(COLOR, 1.6)
	return _gem_material


## Builds the drop shapes not built yet: of `gems` gems (2 to DROP_GEMS_MAX), or every size when 0. A floor's
## load runs it a size a job, behind the cover; later loads find them built.
static func warm_shapes(gems: int = 0) -> void:
	if _shape_meshes.is_empty():
		_shape_meshes.resize(DROP_SIZES * DROP_SHAPES)
	for i in DROP_SIZES * DROP_SHAPES:
		if _shape_meshes[i].is_empty() and (gems == 0 or 2 + i / DROP_SHAPES == gems):
			_build_shape(i)


## The drop shapes built this session (tests read it).
static func shapes_built() -> int:
	return _shapes_made


## The crystal and outline meshes a drop of `n` gems numbered `seq` is drawn with (its shape built if it is not).
static func drop_meshes(n: int, seq: int) -> Array[Mesh]:
	var i := _shape_of(n, seq)
	warm_shapes(n)
	return [_shape_meshes[i][0], _shape_meshes[i][1]]


static func _shape_of(n: int, seq: int) -> int:
	return (n - 2) * DROP_SHAPES + seq % DROP_SHAPES


## One shape: the cluster baked to a crystal mesh (the gem material, casting a shadow) and an outline shell mesh.
static func _build_shape(i: int) -> void:
	var t0 := PerfMarks.start()
	var made := ShardMesh.baked(
		ShardMesh.cluster(
			gem_material(), 2 + i / DROP_SHAPES, DROP_HEIGHT, DROP_SPREAD, 1 + i % DROP_SHAPES
		)
	)
	var pair: Array[Mesh] = [null, null]
	for mi: MeshInstance3D in made.get_children():
		pair[0 if mi.material_override == gem_material() else 1] = mi.mesh
	made.free()
	_shape_meshes[i] = pair
	_shapes_made += 1
	PerfMarks.add(&"shards.shape_baked", t0)


func _init() -> void:
	name = "Shards"


## The drops' batches made (and the shapes built, when no load did): a floor's view runs it at its build, so the
## first drop of a fight builds nothing. Called again, it does nothing.
func prepare() -> void:
	if _glows != null:
		return
	warm_shapes()
	if _glow_mesh == null:
		var g := ShardMesh.glow(COLOR, 0.9, 0.4)
		_glow_mesh = g.mesh
		_glow_mat = g.material_override
		g.free()
	_glows = _drop_batch(_glow_mesh, _glow_mat, false)
	_glows.name = "DropGlows"
	for i in _shape_meshes.size():
		var pair: Array[MultiMeshInstance3D] = [
			_drop_batch(_shape_meshes[i][0], gem_material(), true),
			_drop_batch(_shape_meshes[i][1], ShardMesh.outline_material(), false)
		]
		pair[0].name = "DropCrystals%d" % i
		pair[1].name = "DropOutlines%d" % i
		if i > 0:  # One shape's pair is enough for the load's warm-up: the rest draw the same looks
			for mmi in pair:
				mmi.set_meta(ShaderWarmup.SKIP_META, true)
		_shape_batches.append(pair)
		var used := PackedByteArray()
		used.resize(DROP_CAP)
		_shape_used.append(used)
		_shape_box.append(AABB())
	_shape_shown.resize(_shape_meshes.size())
	_d_live.resize(DROP_CAP)
	_d_shape.resize(DROP_CAP)
	_d_slot.resize(DROP_CAP)
	_d_n.resize(DROP_CAP)
	_d_pos.resize(DROP_CAP)
	_d_turn.resize(DROP_CAP)
	_d_age.resize(DROP_CAP)
	_d_fresh.resize(DROP_CAP)


## One drop batch: DROP_CAP instances of `mesh` in `mat`, none drawn yet. The crystals cast a shadow as a drop's
## crystal did; their bounds follow their drops (so the sun's shadow is fitted as before), the rest span the room.
func _drop_batch(mesh: Mesh, mat: Material, shadow: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = DROP_CAP
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	if shadow:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = ROOM_BOX
	mmi.visible = false
	add_child(mmi)
	return mmi


func sync(reader: WorldReader) -> void:
	_target = SimPlane.to_3d(reader.player_pos()) + Vector3(0, HEIGHT, 0)
	var taken := PackedVector2Array()
	var t0 := PerfMarks.start()
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.SHARDS and e.effect_id == WorldReader.SHARD_PICKUP_EFFECT:
			taken.append(e.pos)
		elif e.kind == SimEvent.Kind.SHARDS:
			_burst(e.pos, mini(e.amount, MAX_PER_KILL), reader.seed_value() * 31 + e.seq)
	PerfMarks.add(&"shards.events", t0)
	t0 = PerfMarks.start()
	_sync_drops(reader, taken)
	PerfMarks.add(&"shards.drops", t0)


## Shard drops lying on the floor (tests read it).
func drop_count() -> int:
	return _drops.size()


## Drops being pulled into the hero (tests read it).
func pulled_count() -> int:
	return _pulled.size()


## Every drop batch: the glows, then each shape's crystals and outline shells (empty before prepare(); tests read
## them).
func drop_batches() -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	if _glows != null:
		out.append(_glows)
	for pair: Array in _shape_batches:
		out.append_array(pair)
	return out


## Where drop `seq` on the floor is drawn: [its crystals' multimesh, its slot there, its outlines' multimesh (the
## same slot), the glows' multimesh, its glow slot]; empty when no such drop lies there (tests read it).
func drop_instance(seq: int) -> Array:
	if not _drops.has(seq):
		return []
	var g: int = _drops[seq]
	var pair: Array = _shape_batches[_d_shape[g]]
	return [
		(pair[0] as MultiMeshInstance3D).multimesh,
		_d_slot[g],
		(pair[1] as MultiMeshInstance3D).multimesh,
		_glows.multimesh,
		g,
	]


func _sync_drops(reader: WorldReader, taken: PackedVector2Array) -> void:
	var seqs := reader.shard_drop_seqs()
	var amounts := reader.shard_drop_amounts()
	if taken.is_empty() and seqs == _drop_seqs and amounts == _drop_amounts:
		return  # The same drops as the last sync, none taken: nothing to lay out
	_drop_seqs = seqs.duplicate()
	_drop_amounts = amounts.duplicate()
	prepare()
	var at := reader.shard_drops()
	var live := {}
	for k in seqs.size():
		live[seqs[k]] = true
		var n := clampi(2 + amounts[k] / 4, 2, DROP_GEMS_MAX)
		var g: int = _drops.get(seqs[k], -1)
		if g >= 0 and _d_n[g] != n:  # a merge made it bigger: a new cluster with more gems
			_free_drop(g)
			_drops.erase(seqs[k])
			g = -1
		if g < 0:
			var t0 := PerfMarks.start()
			g = _place_drop(seqs[k], n)
			PerfMarks.add(&"shards.drop_made", t0)
			if g < 0:
				continue  # More drops than the batches hold: this one is not drawn
			_drops[seqs[k]] = g
		_d_pos[g] = SimPlane.to_3d(at[k])
	for seq: int in _drops.keys():
		if live.has(seq):
			continue
		var g: int = _drops[seq]
		_drops.erase(seq)
		if _was_taken(_d_pos[g], taken):
			_d_live[g] = 2
			_d_age[g] = 0.0
			_pulled.append(g)
		else:
			_free_drop(g)
	_draw_drops()


## A new drop of `n` gems numbered `seq`: a glow slot and a slot in its shape's batches, turned by its number.
## -1 when the batches are full.
func _place_drop(seq: int, n: int) -> int:
	var g := _d_live.find(0)
	var shape := _shape_of(n, seq)
	var slot := _shape_used[shape].find(0)
	if g < 0 or slot < 0:
		return -1
	_shape_used[shape][slot] = 1
	_d_live[g] = 1
	_d_shape[g] = shape
	_d_slot[g] = slot
	_d_n[g] = n
	_d_turn[g] = float(seq % 7)
	_d_age[g] = 0.0
	_d_fresh[g] = 1
	return g


## A drop gone: its instances drawn at zero size at once (not shrinking through the interpolation), its slots free.
func _free_drop(g: int) -> void:
	var pair: Array = _shape_batches[_d_shape[g]]
	var slot := _d_slot[g]
	var none := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for k in 2:
		var mm := (pair[k] as MultiMeshInstance3D).multimesh
		mm.set_instance_transform(slot, none)
		mm.reset_instance_physics_interpolation(slot)
	_glows.multimesh.set_instance_transform(g, none)
	_glows.multimesh.reset_instance_physics_interpolation(g)
	_shape_used[_d_shape[g]][slot] = 0
	_d_live[g] = 0


## The transform the drop in glow slot `g` is drawn with now: its batches' instances get exactly this (tests read
## it: a headless run keeps no instance data to read back).
func drawn_transform(g: int) -> Transform3D:
	var b := Basis.from_euler(Vector3(0, _d_turn[g], 0))
	if _d_live[g] != 2:
		return Transform3D(b, _d_pos[g])
	var t := minf(1.0, _d_age[g] / PULL_S)
	return Transform3D(b.scaled(Vector3.ONE * (1.0 - 0.6 * t)), _d_pos[g].lerp(_target, t * t))


## Writes every drop into its batches in one pass: a drop on the floor at its place with its turn; a pulled one on
## its way into the hero (its place eased toward the hero over PULL_S, shrinking to 0.4), its turn kept. The crystal,
## its outline shell and its glow share the transform, as the pieces of one drop node did (the glow is a billboard,
## so it shows neither the turn nor the shrink). Each shape's batches draw up to their last slot in use.
func _draw_drops() -> void:
	if _glows == null:
		return
	var top := PackedInt32Array()
	top.resize(_shape_batches.size())
	var glow_top := 0
	for i in _shape_box.size():
		_shape_box[i] = AABB()
	for g in DROP_CAP:
		if _d_live[g] == 0:
			continue
		var xf := drawn_transform(g)
		var reach := AABB(_d_pos[g], Vector3.ZERO)
		if _d_live[g] == 2:
			reach = reach.expand(_target)
		var shape := _d_shape[g]
		var slot := _d_slot[g]
		var pair: Array = _shape_batches[shape]
		var crystals := (pair[0] as MultiMeshInstance3D).multimesh
		var outlines := (pair[1] as MultiMeshInstance3D).multimesh
		crystals.set_instance_transform(slot, xf)
		outlines.set_instance_transform(slot, xf)
		_glows.multimesh.set_instance_transform(g, xf)
		if _d_fresh[g] == 1:  # A new drop starts where it lands, as a node entering the tree did
			_d_fresh[g] = 0
			crystals.reset_instance_physics_interpolation(slot)
			outlines.reset_instance_physics_interpolation(slot)
			_glows.multimesh.reset_instance_physics_interpolation(g)
		top[shape] = maxi(top[shape], slot + 1)
		glow_top = g + 1
		reach = reach.grow(DROP_REACH)
		var box := _shape_box[shape]
		_shape_box[shape] = reach if box.size == Vector3.ZERO else box.merge(reach)
	_show(_glows, glow_top)
	for i in top.size():
		if top[i] == _shape_shown[i] and top[i] == 0:
			continue
		var pair: Array = _shape_batches[i]
		var crystals: MultiMeshInstance3D = pair[0]
		if top[i] > 0 and crystals.custom_aabb != _shape_box[i]:
			crystals.custom_aabb = _shape_box[i]
		_show(crystals, top[i])
		_show(pair[1], top[i])
		_shape_shown[i] = top[i]


static func _show(mmi: MultiMeshInstance3D, n: int) -> void:
	if mmi.multimesh.visible_instance_count != n:
		mmi.multimesh.visible_instance_count = n
	if mmi.visible != (n > 0):
		mmi.visible = n > 0


static func _was_taken(at: Vector3, taken: PackedVector2Array) -> bool:
	for p in taken:
		if SimPlane.to_3d(p).distance_to(at) < 0.05:
			return true
	return false


## Gems in flight (tests read it).
func count() -> int:
	return _g_live.count(1)


## The gems' crystal and outline batches (null before the first burst; tests read them). A slot past count() may be
## an empty one (drawn at zero size) until the gems after it land.
func gem_batches() -> Array[MultiMeshInstance3D]:
	return [_crystals, _outlines]


func _burst(at: Vector2, n: int, salt: int) -> void:
	if _mesh == null:
		_mesh = ShardMesh.shard(4, 0.1, 0.18, 0.15, 51)
	if _crystals == null:
		_crystals = _batch(gem_material())
		_crystals.name = "GemCrystals"
		_outlines = _batch(ShardMesh.outline_material())
		_outlines.name = "GemOutlines"
		_g_pos.resize(MAX_ALIVE)
		_g_vel.resize(MAX_ALIVE)
		_g_age.resize(MAX_ALIVE)
		_g_turn.resize(MAX_ALIVE)
		_g_live.resize(MAX_ALIVE)
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var origin := SimPlane.to_3d(at) + Vector3(0, HEIGHT, 0)
	for k in n:
		var slot := _g_live.find(0)
		if slot < 0:
			break
		var a := TAU * (k + rng.randf() * 0.6) / maxf(1.0, n)
		var v := Vector3(cos(a), 1.2 + rng.randf(), sin(a)) * (2.2 + rng.randf() * 1.6)
		_g_pos[slot] = origin
		_g_vel[slot] = v
		_g_age[slot] = 0.0
		_g_turn[slot] = 0.0
		_g_live[slot] = 1
		_fresh.append(slot)
	_draw_gems(false)


## One half of the gems: MAX_ALIVE instances of the shard mesh in `mat`, unshadowed, drawn wherever they fly. The
## instances move in the physics interpolation as the gems' nodes did (each slot keeps its gem for its flight).
func _batch(mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	mm.instance_count = MAX_ALIVE
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The gems are in world space, spread over the room: never cull the batch by its first instance's box.
	mmi.custom_aabb = AABB(Vector3(-512, -8, -512), Vector3(1024, 64, 1024))
	mmi.visible = false
	add_child(mmi)
	return mmi


## Writes every flying gem into both batches: the crystal turned about the vertical, its shell the same grown by
## the outline's margin (ShardMesh.outlined's shell, centred on the gem). The batches draw up to the last live slot;
## an empty slot below it is drawn at zero size. `moved`: after the gems' step (the frame's _process).
func _draw_gems(moved: bool) -> void:
	if _crystals == null:
		return
	var n := _g_live.rfind(1) + 1
	var grow := Basis.from_scale(Vector3.ONE * (1.0 + GEM_OUTLINE))
	for k in n:
		if _g_live[k] == 0:
			continue
		var b := Basis(Vector3.UP, _g_turn[k])
		_crystals.multimesh.set_instance_transform(k, Transform3D(b, _g_pos[k]))
		_outlines.multimesh.set_instance_transform(k, Transform3D(b * grow, _g_pos[k]))
	if moved:  # A new gem starts where its first step put it, as a node entering the tree did
		for slot in _fresh:
			_crystals.multimesh.reset_instance_physics_interpolation(slot)
			_outlines.multimesh.reset_instance_physics_interpolation(slot)
		_fresh.clear()
	for mmi: MultiMeshInstance3D in [_crystals, _outlines]:
		if mmi.multimesh.visible_instance_count != n:
			mmi.multimesh.visible_instance_count = n
		if mmi.visible != (n > 0):
			mmi.visible = n > 0


## A gem that reached the hero: gone at once (its slot drawn at zero size, not shrinking through the interpolation).
func _land(slot: int) -> void:
	_g_live[slot] = 0
	for mmi: MultiMeshInstance3D in [_crystals, _outlines]:
		mmi.multimesh.set_instance_transform(
			slot, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		)
		mmi.multimesh.reset_instance_physics_interpolation(slot)


func _process(delta: float) -> void:
	_process_drops(delta)
	if _crystals == null or not _g_live.has(1):
		return
	for i in _g_live.size():
		if _g_live[i] == 0:
			continue
		var age := _g_age[i] + delta
		_g_age[i] = age
		if age < BURST_S:
			_g_vel[i] *= maxf(0.0, 1.0 - delta * 5.0)
			_g_pos[i] += _g_vel[i] * delta
		else:
			var to := _target - _g_pos[i]
			var step := SPEED * delta * minf(1.0, (age - BURST_S) * 4.0 + 0.3)
			if to.length() <= maxf(step, 0.15):
				_land(i)
				continue
			_g_pos[i] += to.normalized() * step
		_g_turn[i] += delta * 9.0
	_draw_gems(true)


## The drops' slow turn and the pulled ones' way into the hero, written to their batches; nothing on a frame with no
## drop. A pulled drop's instances go once PULL_S is over.
func _process_drops(delta: float) -> void:
	if _drops.is_empty() and _pulled.is_empty():
		return
	var t0 := PerfMarks.start()
	for g: int in _drops.values():
		_d_turn[g] += delta * DROP_SPIN
	var i := 0
	while i < _pulled.size():
		var g := _pulled[i]
		_d_age[g] += delta
		if minf(1.0, _d_age[g] / PULL_S) >= 1.0:
			_free_drop(g)
			_pulled.remove_at(i)
			continue
		i += 1
	_draw_drops()
	PerfMarks.add(&"shards.drops_drawn", t0)
