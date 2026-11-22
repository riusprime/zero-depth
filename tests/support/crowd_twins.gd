class_name CrowdTwins
extends RefCounted
## The native crowd tests' comparison of two views of one world (tests/unit/native/test_native_crowd*.gd): a view
## stepped by hand with its batch native or not, one frame of it, and what each drew (the furniture's sets and columns,
## every VAT set's instances and drives), with the first difference between two, shortly.

const DT := 1.0 / 60.0


## What a write left: each set's instances (count x 12 floats), and the slot columns it reckons.
static func taken(b: EnemyBatch) -> Dictionary:
	var sets: Array = []
	for s: Array in b.get(&"_sets"):
		var mm: MultiMesh = s[2]
		var n := mm.visible_instance_count
		var buf: PackedFloat32Array = s[3]
		sets.append([mm.instance_count, n, buf.slice(0, n * EnemyBatch.STRIDE)])
	var out := {"sets": sets, "drawn": b.drawn.duplicate()}
	for col: StringName in [&"_px", &"_py", &"_pz", &"_sx", &"_s0", &"_s1", &"_bo"]:
		out[col] = b.get(col).duplicate()
	return out


static func first_difference(a: Dictionary, b: Dictionary) -> String:
	for col: StringName in [&"_px", &"_py", &"_pz", &"_sx", &"_s0", &"_s1", &"_bo"]:
		if a[col] != b[col]:
			return "column %s %s" % [col, at(a[col], b[col])]
	if a["drawn"] != b["drawn"]:
		return "drawn %s vs %s" % [a["drawn"], b["drawn"]]
	var sa: Array = a["sets"]
	var sb: Array = b["sets"]
	for j in sa.size():
		for q in 3:
			if sa[j][q] != sb[j][q]:
				return "set %d field %d %s" % [j, q, at(sa[j][q], sb[j][q])]
	return ""


## Where two values first differ (an array's first index), shortly.
static func at(a: Variant, b: Variant) -> String:
	if typeof(a) != typeof(b) or not (a is PackedFloat32Array or a is PackedVector3Array):
		return "%s vs %s" % [a, b]
	if a.size() != b.size():
		return "sizes %d vs %d" % [a.size(), b.size()]
	for k in a.size():
		if a[k] != b[k]:
			return "at %d: %s vs %s" % [k, var_to_str(a[k]), var_to_str(b[k])]
	return "alike"


## A view of `w` stepped by hand (its batch, crowd and flash clock), its batch native or not (`native`).
static func hand_views(t: GutTest, w: World, native: bool) -> ActorViews:
	var views: ActorViews = t.add_child_autofree(ActorViews.new())
	views.set_process(false)
	var was := EnemyBatch.native
	EnemyBatch.native = native  # (its batch is made by this first sync)
	views.sync(WorldReader.new(w))
	EnemyBatch.native = was
	views.batch.native_override = native
	views.batch.set_process(false)
	views.vat_crowd.set_process(false)
	return views


static func frame(views: ActorViews) -> void:
	views._process(DT)
	views.bar_chunks.advance(DT)
	views.batch.advance(DT)
	views.vat_crowd._process(DT)


## Every VAT set's instances (count, capacity, the floats drawn, the drive floats drawn) by look, and the furniture.
static func drawn(views: ActorViews) -> Dictionary:
	var out := {"furniture": taken(views.batch)}
	var crowd := views.vat_crowd
	for group: StringName in [&"_looks", &"_shadows"]:
		var sets: Dictionary = crowd.get(group)
		for key: Variant in sets:
			var s: Dictionary = sets[key]
			var mm: MultiMesh = s["mm"]
			var n := mm.visible_instance_count
			var stride: int = s["stride"]
			var row := [mm.instance_count, n, (s["buf"] as PackedFloat32Array).slice(0, n * stride)]
			var dn := int((s["pose"] as Dictionary).get("drive_texels", 0)) * 4
			if s.has("dbuf") and dn > 0:
				row.append((s["dbuf"] as PackedFloat32Array).slice(0, n * dn))
			out["%s %s" % [group, key]] = row
	return out


static func drawn_difference(a: Dictionary, b: Dictionary) -> String:
	var fd := first_difference(a["furniture"], b["furniture"])
	if fd != "":
		return "furniture " + fd
	if a.keys() != b.keys():
		return "sets %s vs %s" % [a.keys(), b.keys()]
	for key: String in a:
		if key == "furniture":
			continue
		for q in (a[key] as Array).size():
			if a[key][q] != b[key][q]:
				return "%s field %d %s" % [key, q, at(a[key][q], b[key][q])]
	return ""


## Every batched enemy's avatar in both views (the same id).
static func both(a: ActorViews, b: ActorViews, id: int) -> Array:
	var na := a.actor_node(id)
	var nb := b.actor_node(id)
	if na == null or nb == null or not na.has_meta(&"enemy_avatar"):
		return []
	return [na.get_meta(&"enemy_avatar"), nb.get_meta(&"enemy_avatar")]
