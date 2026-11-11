extends RefCounted
## The frame probe's --twin (scripts/checks/frame_probe.gd, through frame_spans.gd): the proof that the batched enemies
## look as their nodes did. A second ActorViews (the twin) draws the same scene the old way (ActorViews.batching false:
## a node tree per enemy), synced on the same reader in the same frames, with its own HitFeel and ItemVisuals
## reading the same events (the flash, the flinch, the hold, the tints), both under the same camera. Just before every
## draw, after both views and their crowds have written this frame, it compares every batched enemy with its twin node:
## - the body: VatCrowd.instance_of on each side (the instance's transform, its colour: the hit flash and glow, its
##   custom data and drives: the pose);
## - the contact disc, the team ring, the dazed ring and the health bar: the batch's instance against the node's
##   interpolated global transform, and whether each shows;
## - the bar chunks drawn (BarChunks.drawn) and the bodies drawn (VatCrowd.drawn), each side.
## The report line gives what was compared and the largest differences. Probe-only; the twin doubles the drawing.

## Differences under these count as equal (float rounding between the two ways of reckoning a transform).
const EPS_POS := 0.0005
const EPS_BASIS := 0.0005
const EPS_COLOR := 0.0005

var twin: ActorViews
var _live: ActorViews
var _main: Node
var _frames := 0
var _bodies := 0
var _parts := 0
var _miss := {}  # what -> count
var _max := {}  # what -> largest difference
var _examples: PackedStringArray = []
var _bar_from := {}  # id -> the frame its bar showed from (shown on every frame since)
var _bar_last := {}


func setup(main: Node) -> void:
	_main = main
	var v: Node = main.get(&"view")
	_live = v.get(&"actors")
	twin = ActorViews.new()
	twin.name = "TwinActors"
	twin.batching = false
	twin.enemy_tint = _live.enemy_tint
	twin.outline_color = _live.outline_color
	twin.hero_look = _live.hero_look
	twin.hero_mood = _live.hero_mood
	twin.grounds = _live.grounds
	twin.cull = _live.cull
	v.add_child(twin)
	var feel := HitFeel.new(twin, v.get(&"rig"))
	feel.name = "TwinHitFeel"
	v.add_child(feel)
	var items := ItemVisuals.new(v.get(&"kit"), twin)
	items.name = "TwinItems"
	v.add_child(items)
	var drv: Node = main.get(&"driver")
	var reader: WorldReader = drv.get(&"reader")
	var sync := func() -> void:
		twin.sync(reader)
		feel.sync(reader)
		items.sync(reader)
	# Right after the views' own sync, before the HUD and the rest read the reader on the same signal
	var after: Array = []
	for c: Dictionary in drv.get_signal_connection_list(&"frame_ticked"):
		var cb: Callable = c["callable"]
		drv.disconnect(&"frame_ticked", cb)
		after.append(cb)
	var first: Callable = after.pop_front()
	drv.connect(&"frame_ticked", first)
	drv.connect(&"frame_ticked", sync)
	for cb: Callable in after:
		drv.connect(&"frame_ticked", cb)
	RenderingServer.frame_pre_draw.connect(_compare)


func _compare() -> void:
	if not is_instance_valid(twin) or _live.vat_crowd == null:
		return
	_frames += 1
	var ids: Array = Array(_live.batch.ids()) if _live.batch != null else []
	if ids.is_empty() and _live.vat_crowd != null:  # --ab=no_batch: node against node (the harness's own spread)
		ids = (_live.get(&"_actors") as Dictionary).keys()
	for id: int in ids:
		var a := _live.actor_node(id)
		var b := twin.actor_node(id)
		if a == null or not a.has_meta(&"enemy_avatar"):
			continue
		if b == null or not b.is_inside_tree():
			_note("twin_missing", 1.0, "id %d" % id)
			continue
		_body(id, a, b)
		if _live.batched_count() > 0:
			_furniture(id, b)
	_diff("bodies_drawn", absf(_live.vat_crowd.drawn - twin.vat_crowd.drawn), "")
	_diff("chunks_drawn", absf(_live.bar_chunks.drawn() - twin.bar_chunks.drawn()), "")


func _body(id: int, a: Node3D, b: Node3D) -> void:
	var ia: Dictionary = _live.vat_crowd.instance_of(a.get_meta(&"enemy_avatar"))
	var ib: Dictionary = twin.vat_crowd.instance_of(b.get_meta(&"enemy_avatar"))
	if ia.is_empty() != ib.is_empty():
		_note(
			"body_shown", 1.0, "id %d batch %s twin %s" % [id, not ia.is_empty(), not ib.is_empty()]
		)
		return
	if ia.is_empty():
		return
	_bodies += 1
	_xf("body", id, ia["xf"], ib["xf"])
	var ca: Color = ia["color"]
	var cb: Color = ib["color"]
	_diff(
		"body_color",
		Vector4(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b, ca.a - cb.a).length(),
		"id %d" % id
	)
	var da: PackedFloat32Array = ia["drives"]
	var db: PackedFloat32Array = ib["drives"]
	var dd := 0.0
	for k in mini(da.size(), db.size()):
		dd = maxf(dd, absf(da[k] - db[k]))
	var aa: AvatarBase = a.get_meta(&"enemy_avatar")
	var ab: AvatarBase = b.get_meta(&"enemy_avatar")
	_diff(
		"body_drives",
		dd,
		(
			"id %d t %.4f vs %.4f strike %s %s vs %s %s hold %s vs %s drives %s vs %s"
			% [
				id,
				aa.get(&"_t"),
				ab.get(&"_t"),
				aa.get(&"_strike_s"),
				aa.get(&"_strike_end_s"),
				ab.get(&"_strike_s"),
				ab.get(&"_strike_end_s"),
				aa.get(&"_hold"),
				ab.get(&"_hold"),
				da,
				db
			]
		)
	)


func _furniture(id: int, b: Node3D) -> void:
	var disc: MeshInstance3D = null
	var ring: MeshInstance3D = null
	var dazed: MeshInstance3D = null
	for c in b.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.mesh is CylinderMesh:
				disc = mi
			elif mi.mesh is TorusMesh and b.has_meta(&"dazed") and mi == b.get_meta(&"dazed"):
				dazed = mi
			elif mi.mesh is TorusMesh:
				ring = mi
	var bar: MeshInstance3D = (
		(b.get_meta(&"bar") as Node3D).get_child(0) if b.has_meta(&"bar") else null
	)
	for row: Array in [
		["disc", EnemyBatch.Part.DISC, disc],
		["ring", EnemyBatch.Part.RING, ring],
		["dazed", EnemyBatch.Part.DAZED, dazed],
		["bar", EnemyBatch.Part.BAR, bar],
	]:
		var node: MeshInstance3D = row[2]
		var mine: Array[Transform3D] = _live.batch.parts_of(id, row[1])
		var shows := node != null and node.is_visible_in_tree()
		if shows == mine.is_empty():
			_note(
				String(row[0]) + "_shown",
				1.0,
				"id %d batch %s twin %s" % [id, not mine.is_empty(), shows]
			)
			continue
		if not shows:
			continue
		_parts += 1
		var what: String = row[0]
		if what == "bar":  # A bar on its first frames shown, apart (the engine may hold a hidden node's old place)
			var since: int = _frames - int(_bar_from.get(id, _frames))
			if not _bar_from.has(id) or int(_bar_last.get(id, -9)) != _frames - 1:
				_bar_from[id] = _frames
				since = 0
			_bar_last[id] = _frames
			if since < 2:
				what = "bar_new"
		var m: Transform3D = mine[0]
		if what == "ring" or what == "dazed":  # Its flattening is in its mesh (EnemyBatch.flattened), not its basis
			var flat := EnemyBatch.RING_FLAT if what == "ring" else EnemyBatch.DAZED_FLAT
			m = Transform3D(m.basis * Basis.from_scale(flat), m.origin)
		_xf(what, id, m, node.get_global_transform_interpolated())


func _xf(what: String, id: int, a: Transform3D, b: Transform3D) -> void:
	_diff(
		what + "_pos", a.origin.distance_to(b.origin), "id %d %s vs %s" % [id, a.origin, b.origin]
	)
	var bd := maxf(
		maxf((a.basis.x - b.basis.x).length(), (a.basis.y - b.basis.y).length()),
		(a.basis.z - b.basis.z).length()
	)
	_diff(what + "_basis", bd, "id %d" % id)


func _diff(what: String, d: float, example: String) -> void:
	_max[what] = maxf(float(_max.get(what, 0.0)), d)
	var eps := EPS_POS
	if what.ends_with("_basis"):
		eps = EPS_BASIS
	elif what.ends_with("_color") or what.ends_with("_drives"):
		eps = EPS_COLOR
	elif what.ends_with("_drawn"):
		eps = 0.5
	if d > eps:
		_note(what, d, example)


func _note(what: String, d: float, example: String) -> void:
	_miss[what] = int(_miss.get(what, 0)) + 1
	_max[what] = maxf(float(_max.get(what, 0.0)), d)
	if int(_miss[what]) <= 2:  # The first two of each kind
		_examples.append("frame %d %s %.5f %s" % [_frames, what, d, example])


func report_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	(
		out
		. append(
			(
				"twin: %d frames compared, %d body instances, %d furniture instances against the twin's nodes"
				% [_frames, _bodies, _parts]
			)
		)
	)
	var keys: Array = _max.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k: String in keys:
		parts.append("%s max %.6f over %d" % [k, _max[k], int(_miss.get(k, 0))])
	out.append("twin differences (largest; frames over the threshold): " + ", ".join(parts))
	for e in _examples:
		out.append("  twin example: " + e)
	return out
