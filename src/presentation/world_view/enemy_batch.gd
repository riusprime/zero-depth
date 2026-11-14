# gdlint: disable=max-public-methods
class_name EnemyBatch
extends Node3D
## The enemies drawn with no node of theirs in the tree. A node per enemy (its root, contact disc, team ring, dazed
## ring and health bar, each moved, notified and drawn by the engine every frame) was the largest cost of a horde frame
## (docs/roadmap/v0.11.1/evidence/PERF_NATIVE.md: taking them out of the tree gave back 6 to 9 ms), so ActorViews gives
## the enemies of KINDS (drawn by the VAT crowd) to this batch instead:
## - each keeps its root, facing and avatar as plain objects outside the tree (they hold the avatar's frame-time pose,
##   the flinch, the hold and the hit look, which ActorViews, HitFeel and HitStop drive as before; actor_node(id) is
##   that root); the batch runs each avatar's frame step while the camera could show it, as the tree ran its _process;
## - the places it is drawn at are reckoned here as the engine drew its nodes (measured against a view of nodes by the
##   frame probe's --twin, scripts/checks/batch_twin.gd): its contact disc, team ring, dazed ring, health bar and blob
##   between its last two syncs by the physics interpolation's fraction (origin), the bar's fill interpolated the same
##   way; its body (VatCrowd) and bar chunk at body_origin; at the latest place when it is far off screen;
## - the disc, ring, dazed ring, bar and blob are instances of one MultiMesh per mesh (the same meshes and materials
##   ActorParts gives a node enemy), all written in one pass a frame into packed buffers and uploaded once a set;
## - HitFeel's bar chunk reads the bar's place from here (BarChunks.locate); status marks hang from an anchor node made
##   only for an enemy that shows one (anchor()).
## A killed enemy's instances go the same frame, unless its body falls (its avatar's die()): then its disc and ring stay
## until the fall ends, as the node's did, and its bar and blob go at once. Presentation only (EI-07): it reads what
## ActorViews gives it, never the sim. write_furniture() takes the slot columns and fills the buffers: with the native
## library loaded and `native` on, one call to its ZdCrowd does it (the same numbers: tests/unit/native/
## test_native_crowd.gd), and GDScript only hands each set's buffer to its MultiMesh; else the GDScript pass below.

## The set kinds.
enum Part { DISC, RING, DAZED, BAR, BLOB }

## The kinds batched: the VAT crowd's horde kinds and the Charger and Hatchling, whose avatars need nothing of the tree.
## The other VAT kinds (the solo models: Needle, Warden, the drones, the owner's models) still read the tree in their
## frame step or death (global transforms, timers), so they keep their node.
const KINDS: Array[int] = [
	WorldReader.KIND_SWARMER,
	WorldReader.KIND_SPLITTER,
	WorldReader.KIND_SPLITLING,
	WorldReader.KIND_SHIELD_BEARER,
	WorldReader.KIND_MENDER,
	WorldReader.KIND_MINE_LAYER,
	WorldReader.KIND_SNIPER,
	WorldReader.KIND_CHARGER,
	WorldReader.KIND_HATCHLING,
]
## After the views' sync and the other nodes' _process, before VatCrowd (which draws the bodies at these places).
const PROCESS_PRIORITY := VatCrowd.PROCESS_PRIORITY - 1
const START_CAPACITY := 64
const STRIDE := 12
## The sets' culling box (m from the origin each way): the GPU clips each instance.
const BOX_M := 500.0
## The furniture's offsets over the feet and flattening (ActorParts' nodes).
const DISC_Y := 0.006
const RING_Y := 0.02
const RING_FLAT := Vector3(1, 0.08, 1)
const DAZED_FLAT := Vector3(1, 0.15, 1)
## The native writer's class (native/src/zd_crowd.h).
const NATIVE_CLASS := &"ZdCrowd"

## Whether the furniture is written by the native library's ZdCrowd (on by default; the frame probe's
## --ab=no_native_crowd and the equality tests turn it off to run the GDScript writer, the reference). The GDScript
## pass also runs whenever the class is missing.
static var native := true

## This batch's own native switch (null: the shared `native`; the equality test runs a GDScript batch beside a native
## one on the same frames).
var native_override: Variant = null
## How many slots have gone (VatCrowd drops its dead entries only when this moved).
var removed := 0
## The avatars' state as packed rows, synced, stepped and drawn by ZdCrowd while the native writer runs and every
## batched avatar has a native class (BatchAvatars).
var avatars := BatchAvatars.new()

## The view whose shared parts, bar chunks and look it draws with (ActorViews sets it).
var views: ActorViews
## Instances written by the last frame, by Part (tests, probes).
var drawn: PackedInt32Array = [0, 0, 0, 0, 0]
## The process frame of the last sync (place, add): a node read during that frame was at its last sync but one's place.
var synced_frame := -1

## The slots: one per batched enemy (live, or falling after its death), in no order (a removed one's place takes the
## last). Places are in the actors' view's space.
var _ids := PackedInt32Array()
var _roots: Array[Node3D] = []
var _avatars: Array[AvatarBase] = []
var _x0 := PackedFloat32Array()  # the place at the tick before the latest (the interpolation's start)
var _y0 := PackedFloat32Array()
var _z0 := PackedFloat32Array()
var _x1 := PackedFloat32Array()  # the place at the latest tick
var _y1 := PackedFloat32Array()
var _z1 := PackedFloat32Array()
var _interp := PackedByteArray()  # 1: drawn between the two (the camera could show it); 0: at the latest
var _live := PackedByteArray()  # 1: in the sim; 0: its body falls (disc and ring stay, bar and blob gone)
var _bar_on := PackedByteArray()
var _dazed_on := PackedByteArray()
var _blob_on := PackedByteArray()
var _bar_y := PackedFloat32Array()
var _dazed_y := PackedFloat32Array()  # < 0: no dazed ring
var _blob_s := PackedFloat32Array()  # the blob's size (0: no blob)
var _disc := PackedInt32Array()  # its disc's set and its ring's set (by radius)
var _ring := PackedInt32Array()
var _slot_of := {}
## Anchor nodes in the tree by id (status marks), made on demand.
var _anchors := {}
## The draw sets: [Part, MultiMeshInstance3D, MultiMesh, buffer]; by key ([Part, radius] or Part).
var _sets: Array = []
var _set_of := {}
## The pass's scratch: each slot's drawn place this frame.
var _px := PackedFloat32Array()
var _py := PackedFloat32Array()
var _pz := PackedFloat32Array()
## Each slot's bar fill as drawn, the fill written last frame, and the one at the last physics tick: the engine
## interpolated a node bar's pivot scale between the last two (sx = lerp(s0, the fill now, fraction)).
var _sx := PackedFloat32Array()
var _s0 := PackedFloat32Array()
var _s1 := PackedFloat32Array()
## The process frame each slot came in: the tree first runs a node's _process the frame after it is added.
var _born := PackedInt32Array()
## Each slot's facing node, and where VatCrowd draws its body this frame (body_at; INF: hidden).
var _facings: Array[Node3D] = []
var _bo := PackedVector3Array()
var _bo_fresh := false  # _bo written since the last change (a sync, a slot come or gone)
var _phys_seen := -1
## The native writer's inputs kept as columns, written on events instead of read off each enemy every frame: its bar
## trail's fill (BarChunks.fill_to; 1 without a trail) and whether its root, facing and avatar all show (each sync).
var _fill := PackedFloat64Array()
var _shown := PackedByteArray()
## Slots whose body falls (their root is freed when the fall ends: the frame's drop looks only while there are any).
var _falls := 0
var _crowd: RefCounted


func _init() -> void:
	name = "EnemyBatch"
	process_priority = PROCESS_PRIORITY
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## The roots outside the tree go with the batch (they are no child of anything: a floor's view freed would leave them).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for r in _roots:
			if is_instance_valid(r):
				r.free()


static func takes(kind: int) -> bool:
	return KINDS.has(kind)


## The roots of the enemies batched (live, or falling after their death): plain objects outside the tree, on purpose
## (WorldViewRoot.idle_pool_nodes counts them out of the orphans).
func roots() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for r in _roots:
		if is_instance_valid(r):  # (a freed one waits for the next frame's drop)
			out.append(r)
	return out


func has(id: int) -> bool:
	return _slot_of.has(id)


## The ids batched (tests, the probe's twin).
func ids() -> PackedInt32Array:
	return _ids


## Starts drawing enemy `id` (its detached `root` at `at`, `avatar` its model), of contact radius `radius`: its bar at
## `bar_y`, its dazed ring at `dazed_y` (< 0: none), a blob shadow when `blob`.
func add(
	id: int,
	root: Node3D,
	avatar: AvatarBase,
	at: Vector3,
	radius: float,
	heights: Vector2,
	blob: bool
) -> void:
	var k := _ids.size()
	_slot_of[id] = k
	_ids.append(id)
	_roots.append(root)
	_avatars.append(avatar)
	_facings.append(root.get_meta(&"facing"))
	_x0.append(at.x)
	_y0.append(at.y)
	_z0.append(at.z)
	_x1.append(at.x)
	_y1.append(at.y)
	_z1.append(at.z)
	_interp.append(1)
	_live.append(1)
	_bar_on.append(0)
	_dazed_on.append(0)
	_blob_on.append(1 if blob else 0)
	_bar_y.append(heights.x)
	_dazed_y.append(heights.y)
	_blob_s.append(maxf(radius, 0.2) * EnemyShadows.BLOB_SCALE if blob else 0.0)
	_px.append(at.x)
	_py.append(at.y)
	_pz.append(at.z)
	_sx.append(1.0)
	_s0.append(1.0)
	_s1.append(1.0)
	_born.append(Engine.get_process_frames())
	_bo.append(Vector3.INF)
	_fill.append(1.0)
	_shown.append(1 if root.visible and _facings[k].visible and avatar.visible else 0)
	_disc.append(_set_index(Part.DISC, radius))
	_ring.append(_set_index(Part.RING, radius))
	_set_index(Part.BAR, 0.0)  # The sets it can show in later (made now: the pass walks the sets made)
	if heights.y >= 0.0:
		_set_index(Part.DAZED, 0.0)
	if blob:
		_set_index(Part.BLOB, 0.0)
	avatar.detached = true
	avatars.add(id, avatar, _facings[k], root.get_meta(&"vat_sets", Vector2i(-1, -1)))
	_bo_fresh = false
	synced_frame = Engine.get_process_frames()


## Enemy `id` stands at `at` after this sync: it is drawn between its place at the last sync and this one, as the
## engine drew its node (the twin probe, scripts/checks/batch_twin.gd, measured it: setting a node to the tick before
## the latest and resetting its interpolation in the same frame, ActorViews._start_from_tick_before, leaves its previous
## place at the last sync's). `before` (a Vector3, or null) only moves its anchor the way a node is moved.
func place(id: int, at: Vector3, before: Variant) -> void:
	_bo_fresh = false
	var k: int = _slot_of[id]
	synced_frame = Engine.get_process_frames()
	_x0[k] = _x1[k]
	_y0[k] = _y1[k]
	_z0[k] = _z1[k]
	_x1[k] = at.x
	_y1[k] = at.y
	_z1[k] = at.z
	if _anchors.has(id):
		_place_anchor(_anchors[id], at, before)


## Whether `id` is drawn between its last two ticks (on screen); turning it on starts it at its latest place.
func set_interpolated(id: int, on: bool) -> void:
	var k: int = _slot_of[id]
	if on and _interp[k] == 0:
		_x0[k] = _x1[k]
		_y0[k] = _y1[k]
		_z0[k] = _z1[k]
	_interp[k] = 1 if on else 0


## Its bar, dazed ring and blob show (`bar`, `dazed`, `blob`) after this sync.
func show_parts(id: int, bar: bool, dazed: bool, blob: bool) -> void:
	_bo_fresh = false
	var k: int = _slot_of[id]
	_bar_on[k] = 1 if bar else 0
	_dazed_on[k] = 1 if dazed and _dazed_y[k] >= 0.0 else 0
	_blob_on[k] = 1 if blob and _blob_s[k] > 0.0 else 0


## A batched enemy's sync (ActorViews.sync calls it): _update_actor's rules for its kinds (the facing, the avatar's
## sync, the bar once hurt and not rising in, the dazed ring while it recovers, the blob with the body, an egg
## hidden), its numbers from the columns read once this sync (`cols`: facing, state, HP, max HP).
func update(id: int, reader: WorldReader, i: int, parts: Array, cols: Array) -> void:
	var facing: Node3D = parts[0]
	var yaw := SimPlane.yaw_of((cols[0] as PackedInt32Array)[i])
	if yaw != parts[7]:  # Write only what changed
		facing.rotation = Vector3(0, yaw, 0)
		parts[7] = yaw
	var state: int = (cols[1] as PackedInt32Array)[i]
	var hp: int = (cols[2] as PackedInt32Array)[i]
	var max_hp: int = (cols[3] as PackedInt32Array)[i]
	var bar := state != WorldReader.STATE_SPAWN and hp < max_hp
	if bar:  # Its chunk and refill (the batch scales the bar to the trail's fill)
		views.bar_chunks.feed(id, null, clampf(float(hp) / maxf(1.0, max_hp), 0.0, 1.0))
	var shown := reader.actor_egg_permille(i) < 0  # Still an egg: BossSignatureViews draws it
	if facing.visible != shown:
		facing.visible = shown
	var avatar: Node3D = parts[5]
	var k: int = _slot_of[id]
	var t_en := PerfMarks.start()
	if _avatars_native():  # Its inputs, applied with every other batched enemy's in one call (flush_avatars)
		avatars.facing_moved(k, facing, false)
		avatars.note_sync(k, reader, i)
	else:
		avatar.call(&"sync", reader, i)
	PerfMarks.add(&"actors.enemy_sync", t_en)
	show_parts(id, bar and shown, state == WorldReader.STATE_RECOVER, shown and avatar.visible)
	_shown[k] = 1 if shown and avatar.visible and (_roots[k] as Node3D).visible else 0


## The end of the views' sync: the batched avatars' syncs noted this sync, applied natively in one call.
func flush_avatars() -> void:
	if _avatars_native():
		avatars.flush(_crowd, avatars.frame_columns(_x1, _y1, _z1))


## Whether enemy `id`'s avatar runs its frame step (its set_process, as ActorViews' culling turns it).
func set_processing(id: int, on: bool) -> void:
	var k: int = _slot_of.get(id, -1)
	if k < 0:
		return
	_avatars[k].set_process(on)
	avatars.set_processing(k, on)


## ActorViews' catch-up as enemy `id` comes on screen: four 0.05 s steps of its avatar after its sync.
func warm(id: int) -> void:
	var k: int = _slot_of.get(id, -1)
	if k < 0:
		return
	if _avatars_native():
		avatars.warm(k)
		return
	for q in 4:
		_avatars[k].advance(0.05)


## The Void leaned enemy `id`'s facing (its whole transform is read from now on).
func facing_leaned(id: int) -> void:
	var k: int = _slot_of.get(id, -1)
	if k >= 0:
		avatars.facing_moved(k, _facings[k], true)


## VatCrowd: its sets `sets` ([index, body, period, drive floats, capacity] each) written natively from the avatars'
## rows (by set: [count, capacity, buffer, drive buffer]), or [] when the avatars run in GDScript.
func write_bodies(sets: Array) -> Array:
	if not _avatars_native():
		return []
	if not _bo_fresh:  # (the body places are this frame's furniture pass's)
		write_furniture()
	return avatars.write_bodies(_crowd, avatars.frame_columns(_x1, _y1, _z1), _bo, sets)


## Whether the avatars' rows hold their state now (the native writer on and every avatar covered), turning them on
## or off to match.
func _avatars_native() -> bool:
	var want := _native_on() and avatars.all_native()
	avatars.set_on(want)
	return want


## BarChunks.fill_to: enemy `id`'s bar trail shows fill `f` now (1 once its trail is gone).
func set_fill(id: int, f: float) -> void:
	var k: int = _slot_of.get(id, -1)
	if k >= 0:
		_fill[k] = f


## A batched enemy left the sim: its body falls a moment where its avatar has a death (its disc and ring stay with
## it, as its node's did; its bar and blob go), else its instances go now.
func drop(id: int, node: Node3D) -> void:
	var av: Variant = node.get_meta(&"enemy_avatar")
	if (av as Object).has_method(&"die") and is_inside_tree() and av.die():
		set_processing(id, true)
		release(id, true)
		get_tree().create_timer(av.DEATH_SECONDS).timeout.connect(node.queue_free)
		return
	release(id, false)
	let_go(node)


## Frees a batched enemy's root its owner lets go of: now, as it is in no tree (a queued free of an object outside the
## tree waits for the end of the frame, and one whose view goes first in that frame is never freed); a root in the
## tree (the path without the batch) is queued as before.
static func let_go(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	if node.is_inside_tree():
		node.queue_free()
	else:
		node.free()


## Enemy `id` left the sim: its slot goes now, or (`falls`) stays without its bar and blob until its root is freed.
func release(id: int, falls: bool) -> void:
	_bo_fresh = false
	var k: int = _slot_of.get(id, -1)
	if k < 0:
		return
	if falls:
		if _live[k] == 1:
			_falls += 1
		_live[k] = 0
		_bar_on[k] = 0
		_blob_on[k] = 0
		_x0[k] = _x1[k]  # It stays where it fell (no sync moves it again)
		_y0[k] = _y1[k]
		_z0[k] = _z1[k]
		return
	_remove(k)


## Where enemy `id` is drawn now (the actors' view's space), as the physics interpolation drew its node.
func origin(id: int) -> Vector3:
	var k: int = _slot_of.get(id, -1)
	if k < 0:
		return Vector3.INF
	var f := _fraction() if _interp[k] == 1 else 1.0
	return Vector3(lerpf(_x0[k], _x1[k], f), lerpf(_y0[k], _y1[k], f), lerpf(_z0[k], _z1[k], f))


## Where VatCrowd draws enemy `id`'s body, and BarChunks its bar's chunk: its place at the last sync but one (the
## interpolation's start, x0), as both read a node's interpolated place during the frame and the engine gave them that
## (the twin probe, batch_twin.gd, measured it); its latest place when it is not interpolated (far off screen). The
## disc, ring and bar themselves are drawn at the interpolated place (origin), as the engine drew those nodes.
func body_at(id: int) -> Vector3:
	var k: int = _slot_of.get(id, -1)
	if k < 0:
		return Vector3.INF
	if _bo_fresh:  # (the frame's pass wrote it; a test or the first frame reckons it here)
		return _bo[k]
	var shown := (_roots[k] as Node3D).visible and _facings[k].visible and _avatars[k].visible
	return _body_origin(k) if shown else Vector3.INF


## body_at's place for slot `k` (shown or not).
func _body_origin(k: int) -> Vector3:
	if _interp[k] == 0 or not _interpolating():
		return Vector3(_x1[k], _y1[k], _z1[k])
	if synced_frame == Engine.get_process_frames():  # (on a frame with no tick, the interpolated place)
		return Vector3(_x0[k], _y0[k], _z0[k])
	var f := _fraction()
	return Vector3(lerpf(_x0[k], _x1[k], f), lerpf(_y0[k], _y1[k], f), lerpf(_z0[k], _z1[k], f))


## BarChunks.locate: where `id`'s bar's chunk goes (_body_origin's place, at the bar's height), or Vector3.INF while
## its bar is hidden.
func bar_point(id: int) -> Vector3:
	var k: int = _slot_of.get(id, -1)
	if k < 0 or _bar_on[k] == 0:
		return Vector3.INF
	return _body_origin(k) + Vector3(0, _bar_y[k], 0)


## A node in the tree that follows enemy `id` as its root did (moved on each sync, physics-interpolated), for what must
## hang from one (status marks); made the first time it is asked for, freed with the enemy. Null for one not batched.
func anchor(id: int) -> Node3D:
	var k: int = _slot_of.get(id, -1)
	if k < 0:
		return null
	var a: Node3D = _anchors.get(id)
	if a == null:
		a = Node3D.new()
		a.name = "Anchor%d" % id
		a.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON  # (the batch's own is off)
		a.set_meta(&"bar_y", _bar_y[k])
		a.position = Vector3(_x1[k], _y1[k], _z1[k])
		add_child(a)
		a.reset_physics_interpolation()
		_anchors[id] = a
	return a


static func _place_anchor(a: Node3D, at: Vector3, before: Variant) -> void:
	if before != null and not a.position.is_equal_approx(before as Vector3):
		a.position = before as Vector3
		a.reset_physics_interpolation()
	a.position = at


func _remove(k: int) -> void:
	_bo_fresh = false
	removed += 1
	avatars.remove(k)
	var id := _ids[k]
	if _live[k] == 0:
		_falls -= 1
	_slot_of.erase(id)
	if _anchors.has(id):
		(_anchors[id] as Node).queue_free()
		_anchors.erase(id)
	var last := _ids.size() - 1
	if k != last:
		_ids[k] = _ids[last]
		_slot_of[_ids[k]] = k
		_roots[k] = _roots[last]
		_avatars[k] = _avatars[last]
		_facings[k] = _facings[last]
	_roots.resize(last)
	_avatars.resize(last)
	_facings.resize(last)
	_ids.resize(last)
	for col: StringName in [
		&"_x0",
		&"_y0",
		&"_z0",
		&"_x1",
		&"_y1",
		&"_z1",
		&"_interp",
		&"_live",
		&"_bar_on",
		&"_dazed_on",
		&"_blob_on",
		&"_bar_y",
		&"_dazed_y",
		&"_blob_s",
		&"_disc",
		&"_ring",
		&"_px",
		&"_py",
		&"_pz",
		&"_sx",
		&"_s0",
		&"_s1",
		&"_born",
		&"_bo",
		&"_fill",
		&"_shown",
	]:
		var arr: Variant = get(col)
		if k != last:
			arr[k] = arr[last]
		arr.resize(last)
		set(col, arr)


## The physics interpolation's fraction this frame (1 with the interpolation off).
func _fraction() -> float:
	return Engine.get_physics_interpolation_fraction() if _interpolating() else 1.0


## Whether the physics interpolation is on (off: every node was drawn at its latest place).
func _interpolating() -> bool:
	return is_inside_tree() and get_tree().physics_interpolation


func _process(delta: float) -> void:
	advance(delta)


## The frame: drops the slots whose fall ended, runs every avatar's frame step the camera could show (as the tree
## ran its _process), then writes the furniture.
func advance(delta: float) -> void:
	var k := _ids.size() - 1
	if _falls == 0 and _native_on():  # (only a falling body's root is freed while its slot stays)
		k = -1
	while k >= 0:
		var r: Node3D = _roots[k]
		if not is_instance_valid(r) or r.is_queued_for_deletion():
			_remove(k)
		k -= 1
	var t_av := PerfMarks.start()
	if _avatars_native():  # Every avatar's step in one native call
		avatars.step(_crowd, avatars.frame_columns(_x1, _y1, _z1), _born, delta)
	else:
		var frame := Engine.get_process_frames()
		for j in _avatars.size():
			var a: AvatarBase = _avatars[j]
			if a.is_processing() and _born[j] != frame:
				a._process(delta)  # (as the tree ran it, from the frame after it came)
	PerfMarks.add(&"batch.avatars", t_av)  # The avatars' frame step (the tree ran it before)
	var t_wr := PerfMarks.start()
	write_furniture()
	PerfMarks.add(&"batch.write", t_wr)


## Whether the native writer runs (its class loaded and `native` on, or this batch's override), made the first time.
func _native_on() -> bool:
	if not (native if native_override == null else bool(native_override)):
		return false
	if _crowd == null:
		if not ClassDB.class_exists(NATIVE_CLASS):
			return false
		_crowd = ClassDB.instantiate(NATIVE_CLASS)
	return true


## Every slot's disc, ring, dazed ring, bar and blob into its set's buffer (one pass a set over the slot columns, the
## places reckoned once), then one upload a set: natively when it can (`script` forces the GDScript pass: tests).
func write_furniture(script := false) -> void:
	if not script and _native_on():
		_write_native()
		return
	var f := _fraction()
	var interp_on := _interpolating()
	var synced_now := synced_frame == Engine.get_process_frames()
	var n := _ids.size()
	var ticked := Engine.get_physics_frames() != _phys_seen  # A tick since the last write
	_phys_seen = Engine.get_physics_frames()
	var chunks: BarChunks = views.bar_chunks if views != null else null
	for k in n:
		var ff := f if _interp[k] == 1 else 1.0
		_px[k] = lerpf(_x0[k], _x1[k], ff)
		_py[k] = lerpf(_y0[k], _y1[k], ff)
		_pz[k] = lerpf(_z0[k], _z1[k], ff)
		# The bar's fill: BarChunks' trail, as it scaled a node bar's pivot, interpolated as the engine did
		var t: HealthBarTrail = chunks.trail_of(_ids[k]) if chunks != null else null
		var now := maxf(t.fill, 0.001) if t != null else 1.0
		if _bar_on[k] == 0:
			_s0[k] = now
		elif ticked:
			_s0[k] = _s1[k]
		_s1[k] = now
		_sx[k] = lerpf(_s0[k], now, ff)
		# Where VatCrowd draws its body this frame (INF: hidden), reckoned here once (VatCrowd.body_at)
		var shown := (_roots[k] as Node3D).visible and _facings[k].visible and _avatars[k].visible
		if not shown:
			_bo[k] = Vector3.INF
		elif _interp[k] == 0 or not interp_on:
			_bo[k] = Vector3(_x1[k], _y1[k], _z1[k])
		elif synced_now:
			_bo[k] = Vector3(_x0[k], _y0[k], _z0[k])
		else:  # (a frame with no tick: the interpolated place)
			_bo[k] = Vector3(_px[k], _py[k], _pz[k])
	for p in drawn.size():
		drawn[p] = 0
	for j in _sets.size():
		var s: Array = _sets[j]
		var part: int = s[0]
		var mm: MultiMesh = s[2]
		var buf: PackedFloat32Array = s[3]
		s[3] = PackedFloat32Array()  # The pass holds the only reference (no copy on each write)
		var c := 0
		for k in n:
			var sx := 1.0
			var sy := 1.0
			var sz := 1.0
			var y := _py[k]
			match part:
				Part.DISC:
					if _disc[k] != j:
						continue
					y += DISC_Y
				Part.RING:
					if _ring[k] != j:
						continue
					y += RING_Y
				Part.DAZED:
					if _dazed_on[k] == 0:
						continue
					y += _dazed_y[k]
				Part.BAR:
					if _bar_on[k] == 0:
						continue
					y += _bar_y[k]
					sx = _sx[k]
				_:
					if _blob_on[k] == 0:
						continue
					y += EnemyShadows.BLOB_Y
					sx = _blob_s[k]
					sy = sx
					sz = sx
			if c >= mm.instance_count:
				var cap := maxi(mm.instance_count, START_CAPACITY)
				while cap <= c:
					cap *= 2
				mm.instance_count = cap
				buf.resize(cap * STRIDE)
			var o := c * STRIDE
			buf[o] = sx
			buf[o + 1] = 0.0
			buf[o + 2] = 0.0
			buf[o + 3] = _px[k]
			buf[o + 4] = 0.0
			buf[o + 5] = sy
			buf[o + 6] = 0.0
			buf[o + 7] = y
			buf[o + 8] = 0.0
			buf[o + 9] = 0.0
			buf[o + 10] = sz
			buf[o + 11] = _pz[k]
			c += 1
		if c > 0:
			mm.buffer = buf
		mm.visible_instance_count = c
		s[3] = buf
		drawn[part] += c
	_bo_fresh = true


## write_furniture's pass in the native library (ZdCrowd.write_furniture: the same numbers from the same columns), then
## one upload a set: O(sets) here, whatever the number of enemies.
func _write_native() -> void:
	var ticked := Engine.get_physics_frames() != _phys_seen  # A tick since the last write
	_phys_seen = Engine.get_physics_frames()
	var set_parts := PackedInt32Array()
	var caps := PackedInt32Array()
	for s: Array in _sets:
		set_parts.append(s[0])
		caps.append((s[2] as MultiMesh).instance_count)
	var r: Array = (
		_crowd
		. call(
			&"write_furniture",
			[
				_x0,
				_y0,
				_z0,
				_x1,
				_y1,
				_z1,
				_interp,
				_bar_on,
				_dazed_on,
				_blob_on,
				_shown,
				_bar_y,
				_dazed_y,
				_blob_s,
				_disc,
				_ring,
				_fill,
				_s0,
				_s1,
			],
			set_parts,
			caps,
			_fraction(),
			_interpolating(),
			synced_frame == Engine.get_process_frames(),
			ticked,
			PackedFloat64Array([DISC_Y, RING_Y, EnemyShadows.BLOB_Y])
		)
	)
	_px = r[0]
	_py = r[1]
	_pz = r[2]
	_sx = r[3]
	_s0 = r[4]
	_s1 = r[5]
	_bo = r[6]
	var counts: PackedInt32Array = r[7]
	var got_caps: PackedInt32Array = r[8]
	var bufs: Array = r[9]
	for p in drawn.size():
		drawn[p] = 0
	for j in _sets.size():
		var s: Array = _sets[j]
		var mm: MultiMesh = s[2]
		var c := counts[j]
		if got_caps[j] != mm.instance_count:
			mm.instance_count = got_caps[j]
		if c > 0:
			mm.buffer = bufs[j]
		mm.visible_instance_count = c
		s[3] = bufs[j]
		drawn[s[0]] += c
	_bo_fresh = true


## The set drawing `part` for actor radius `radius` (the disc and ring are sized by it; one set for the others), made
## the first time with ActorParts' mesh and material for it.
func _set_index(part: int, radius: float) -> int:
	var key := [part, radius] if part == Part.DISC or part == Part.RING else [part]
	var j: int = _set_of.get(key, -1)
	if j >= 0:
		return j
	var parts := views.shared_parts
	var mesh: Mesh
	var mat: Material
	match part:
		Part.DISC:
			mesh = parts.disc_mesh(radius)
			mat = parts.disc_material(views.outline_color)
		Part.RING:
			mesh = flattened(parts.ring_mesh(radius), RING_FLAT)
			mat = parts.ring_material(ThemePalette.color(&"enemy_body"))
		Part.DAZED:
			mesh = flattened(parts.dazed_mesh(), DAZED_FLAT)
			mat = parts.dazed_material()
		Part.BAR:
			mesh = parts.bar_mesh()
			mat = parts.bar_material(ThemePalette.color(&"enemy_bar"))
		_:
			var blob := EnemyShadows.blob_parts()
			mesh = blob[0]
			mat = blob[1]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.custom_aabb = AABB(Vector3(-BOX_M, -BOX_M, -BOX_M), Vector3.ONE * BOX_M * 2.0)
	mm.instance_count = START_CAPACITY
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Batch%s" % Part.keys()[part].capitalize()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(mmi)
	var buf := PackedFloat32Array()
	buf.resize(START_CAPACITY * STRIDE)
	j = _sets.size()
	_sets.append([part, mmi, mm, buf])
	_set_of[key] = j
	return j


## The draw nodes (tests, the probe).
func instances() -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for s: Array in _sets:
		out.append(s[1])
	return out


## The instances of `part` drawn for enemy `id` last frame, read back from the buffers written (tests): each a
## Transform3D; [] when none.
func parts_of(id: int, part: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var k: int = _slot_of.get(id, -1)
	if k < 0:
		return out
	for j in _sets.size():
		var s: Array = _sets[j]
		if s[0] != part:
			continue
		var c := 0
		for q in _ids.size():
			var shows := false
			match part:
				Part.DISC:
					shows = _disc[q] == j
				Part.RING:
					shows = _ring[q] == j
				Part.DAZED:
					shows = _dazed_on[q] == 1
				Part.BAR:
					shows = _bar_on[q] == 1
				_:
					shows = _blob_on[q] == 1
			if not shows:
				continue
			if q == k and c < (s[2] as MultiMesh).visible_instance_count:
				var b: PackedFloat32Array = s[3]
				var o := c * STRIDE
				out.append(
					Transform3D(
						Vector3(b[o], b[o + 4], b[o + 8]),
						Vector3(b[o + 1], b[o + 5], b[o + 9]),
						Vector3(b[o + 2], b[o + 6], b[o + 10]),
						Vector3(b[o + 3], b[o + 7], b[o + 11])
					)
				)
			c += 1
	return out


## A copy of `mesh` flattened by `flat`: its vertices scaled, its normals by the inverse transpose and its tangents as
## directions, as the engine shades a node scaled so. A MultiMesh instance's normals take its basis as it is, so a ring
## drawn as an instance scaled by `flat` was outlined by the ink pass where its node was not (seen in the before/after
## shots); the flattening is baked here and the instance is not scaled.
static func flattened(mesh: Mesh, flat: Vector3) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k in v.size():
		v[k] = v[k] * flat
	arrays[Mesh.ARRAY_VERTEX] = v
	var inv := Vector3(1.0 / flat.x, 1.0 / flat.y, 1.0 / flat.z)
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for k in n.size():
		n[k] = (n[k] * inv).normalized()
	arrays[Mesh.ARRAY_NORMAL] = n
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var t: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for k in range(0, t.size(), 4):
			var d := (Vector3(t[k], t[k + 1], t[k + 2]) * flat).normalized()
			t[k] = d.x
			t[k + 1] = d.y
			t[k + 2] = d.z
		arrays[Mesh.ARRAY_TANGENT] = t
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
