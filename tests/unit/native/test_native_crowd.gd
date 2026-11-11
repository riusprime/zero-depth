extends GutTest
## The batched enemies' furniture written by the native library (ZdCrowd, EnemyBatch.native): the same buffers as the
## GDScript pass for a seeded crowd frame after frame (places, bar fills, body places, every set's instances, bit for
## bit), the events reaching the buffers on their frame (a spawn, a kill, a hurt bar, a dazed Charger), and the
## GDScript pass taken without the library or with the switch off.

const SW := ActorStore.Kind.SWARMER
const SN := ActorStore.Kind.SNIPER
const SB := ActorStore.Kind.SHIELD_BEARER
const CH := ActorStore.Kind.CHARGER
const MD := ActorStore.Kind.MENDER
const DT := 1.0 / 60.0
const FRAMES := 300
const KINDS_ALL := [
	ActorStore.Kind.SWARMER,
	ActorStore.Kind.SPLITTER,
	ActorStore.Kind.SPLITLING,
	ActorStore.Kind.SHIELD_BEARER,
	ActorStore.Kind.MENDER,
	ActorStore.Kind.MINE_LAYER,
	ActorStore.Kind.SNIPER,
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.HATCHLING,
]

var _vat := false
var _native := true


func before_each() -> void:
	_vat = ViewPrefs.enemy_vat
	_native = EnemyBatch.native
	ViewPrefs.enemy_vat = true
	EnemyBatch.native = true


func after_each() -> void:
	ViewPrefs.enemy_vat = _vat
	EnemyBatch.native = _native


func _views(w: World) -> ActorViews:
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(WorldReader.new(w))
	return views


func _ripen(w: World) -> void:
	for t in w.tuning.spawn_in_ticks + 1:
		w.step(InputFrame.new())


## What a write left: each set's instances (count x 12 floats), and the slot columns it reckons.
func _taken(b: EnemyBatch) -> Dictionary:
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


func _first_difference(a: Dictionary, b: Dictionary) -> String:
	for col: StringName in [&"_px", &"_py", &"_pz", &"_sx", &"_s0", &"_s1", &"_bo"]:
		if a[col] != b[col]:
			return "column %s %s" % [col, _at(a[col], b[col])]
	if a["drawn"] != b["drawn"]:
		return "drawn %s vs %s" % [a["drawn"], b["drawn"]]
	var sa: Array = a["sets"]
	var sb: Array = b["sets"]
	for j in sa.size():
		for q in 3:
			if sa[j][q] != sb[j][q]:
				return "set %d field %d %s" % [j, q, _at(sa[j][q], sb[j][q])]
	return ""


## Where two values first differ (an array's first index), shortly.
static func _at(a: Variant, b: Variant) -> String:
	if typeof(a) != typeof(b) or not (a is PackedFloat32Array or a is PackedVector3Array):
		return "%s vs %s" % [a, b]
	if a.size() != b.size():
		return "sizes %d vs %d" % [a.size(), b.size()]
	for k in a.size():
		if a[k] != b[k]:
			return "at %d: %s vs %s" % [k, var_to_str(a[k]), var_to_str(b[k])]
	return "alike"


func test_the_native_writer_gives_the_script_writer_s_buffers() -> void:
	if not ClassDB.class_exists(EnemyBatch.NATIVE_CLASS):
		pending("the native library is not loaded")
		return
	var w := CombatLab.world()
	var kinds := [SW, SW, SW, SN, SB, CH, MD]
	for k in 40:
		w.add_enemy(kinds[k % kinds.size()], Vector2(-12.0 + (k % 8) * 3.0, -6.0 + (k / 8) * 3.0))
	var views := _views(w)
	var b := views.batch
	var compared := 0
	var bars := 0
	var hp_rng := RandomNumberGenerator.new()
	hp_rng.seed = 5505
	for f in FRAMES:
		for t in [0, 1, 1, 2][f % 4]:  # Frames with no tick, one and two (the interpolation's cases)
			w.step(InputFrame.new())
		if f % 7 == 3:  # Hurt someone (the bar, its fill and its chunk)
			var i := hp_rng.randi_range(0, w.actors.size() - 1)
			if w.actors.teams[i] != 0 and w.actors.hp[i] > 1:
				w.actors.hp[i] = maxi(1, w.actors.hp[i] - maxi(1, w.actors.max_hp[i] / 5))
		if f == 150:  # A kill or two (a code body goes, an owner's model falls)
			for i in w.actors.size():
				if w.actors.teams[i] != 0 and w.actors.kinds[i] in [SN, SB]:
					w.actors.hp[i] = 0
					var at := w.actors.pos(i)
					Damage.hit(w, i, 1 << 20, 0, 0, w.take_root(), 0, at, at)
					break
		if f % 2 == 0:
			views.sync(WorldReader.new(w))
		await get_tree().process_frame  # A real frame: the fraction and the physics frames move on
		views.bar_chunks.advance(DT)
		var s0: PackedFloat32Array = b.get(&"_s0")
		var s1: PackedFloat32Array = b.get(&"_s1")
		var seen: int = b.get(&"_phys_seen")
		var caps := PackedInt32Array()
		for s: Array in b.get(&"_sets"):
			caps.append((s[2] as MultiMesh).instance_count)
		b.write_furniture()
		var native := _taken(b)
		b.set(&"_s0", s0)  # The same inputs again for the GDScript pass
		b.set(&"_s1", s1)
		b.set(&"_phys_seen", seen)
		var sets: Array = b.get(&"_sets")
		for j in sets.size():
			(sets[j][2] as MultiMesh).instance_count = caps[j]
		b.write_furniture(true)
		var script := _taken(b)
		var diff := _first_difference(native, script)
		if diff != "":
			fail_test("frame %d: %s" % [f, diff])
			return
		compared += 1
		bars += b.drawn[EnemyBatch.Part.BAR]
	assert_eq(compared, FRAMES, "every frame alike")
	assert_gt(bars, 0, "bars were drawn and compared")
	assert_gt(b.ids().size(), 30, "a crowd")


func test_events_reach_the_buffers_on_their_frame() -> void:
	if not ClassDB.class_exists(EnemyBatch.NATIVE_CLASS):
		pending("the native library is not loaded")
		return
	var fti := get_tree().physics_interpolation
	get_tree().physics_interpolation = false  # Each drawn at its latest tick
	var w := CombatLab.world()
	var sniper := w.add_enemy(SN, Vector2(2.0, 2.0))
	var charger := w.add_enemy(CH, Vector2(-3.0, 1.0))
	var views := _views(w)
	_ripen(w)
	views.sync(WorldReader.new(w))
	views.batch.advance(DT)
	assert_not_null(views.batch.get(&"_crowd"), "the native writer runs")
	assert_eq(views.batch.drawn[EnemyBatch.Part.DISC], 2, "two discs")
	# A spawn: its disc and ring the frame of the sync that brings it
	var swarmer := w.add_enemy(SW, Vector2(4.0, -1.0))
	views.sync(WorldReader.new(w))
	views.batch.advance(DT)
	var disc: Array[Transform3D] = views.batch.parts_of(swarmer, EnemyBatch.Part.DISC)
	assert_eq(disc.size(), 1, "the new one's disc")
	assert_almost_eq(disc[0].origin.x, SimPlane.to_3d(Vector2(4.0, -1.0)).x, 1e-5, "where it came")
	# A hurt bar: shown the frame its HP drops, at the trail's fill
	var i := w.actors.index_of(sniper)
	w.actors.hp[i] = w.actors.max_hp[i] / 2
	views.sync(WorldReader.new(w))
	views.bar_chunks.advance(DT)
	views.batch.advance(DT)
	var bar: Array[Transform3D] = views.batch.parts_of(sniper, EnemyBatch.Part.BAR)
	assert_eq(bar.size(), 1, "its bar")
	assert_almost_eq(
		bar[0].basis.x.x, maxf(views.bar_chunks.trail_of(sniper).fill, 0.001), 1e-6, "its fill"
	)
	# The hit flash: the body's colour the frame after the hit (VatCrowd writes it from the avatar)
	views.flash(charger)
	views.batch.advance(DT)
	views.vat_crowd._process(DT)
	var body: Dictionary = views.vat_crowd.instance_of(
		views.actor_node(charger).get_meta(&"enemy_avatar")
	)
	assert_lt((body["color"] as Color).a, 0.0, "the Charger flashes")
	# A dazed Charger: its ring over its head the frame it recovers
	var c := w.actors.index_of(charger)
	w.actors.state[c] = WorldReader.STATE_RECOVER
	views.sync(WorldReader.new(w))
	views.batch.advance(DT)
	var dazed: Array[Transform3D] = views.batch.parts_of(charger, EnemyBatch.Part.DAZED)
	assert_eq(dazed.size(), 1, "its dazed ring")
	var dy: float = views.actor_node(charger).get_meta(&"dazed_y")
	assert_almost_eq(dazed[0].origin.y, dy, 1e-5, "over its head")
	# A kill: a code body's instances go the frame of the sync that misses it
	var at := w.actors.pos(i)
	Damage.hit(w, i, 1 << 20, 0, 0, w.take_root(), 0, at, at)
	for t in 120:
		if w.actors.index_of(sniper) < 0:
			break
		w.step(InputFrame.new())
	views.sync(WorldReader.new(w))
	views.batch.advance(DT)
	assert_true(views.batch.parts_of(sniper, EnemyBatch.Part.DISC).is_empty(), "no disc")
	assert_true(views.batch.parts_of(sniper, EnemyBatch.Part.BAR).is_empty(), "no bar")
	assert_eq(views.batch.drawn[EnemyBatch.Part.DISC], 2, "the other two stay")
	get_tree().physics_interpolation = fti


func test_the_script_pass_is_taken_without_the_library_or_with_the_switch_off() -> void:
	var w := CombatLab.world()
	var id := w.add_enemy(SW, Vector2(1.0, 1.0))
	EnemyBatch.native = false
	var off := _views(w)
	off.batch.advance(DT)
	assert_null(off.batch.get(&"_crowd"), "switched off: no native writer")
	assert_eq(off.batch.parts_of(id, EnemyBatch.Part.DISC).size(), 1, "the GDScript pass drew it")
	EnemyBatch.native = true
	var on := _views(w)
	on.batch.advance(DT)
	assert_eq(
		on.batch.get(&"_crowd") != null,
		ClassDB.class_exists(EnemyBatch.NATIVE_CLASS),
		"the native writer only with the library"
	)
	assert_eq(on.batch.parts_of(id, EnemyBatch.Part.DISC).size(), 1, "drawn either way")


# --- The avatars: their sync, frame step and body instances (BatchAvatars, ZdCrowd's avatar calls) -------------------


## A view of `w` stepped by hand (its batch, crowd and flash clock), its batch native or not (`native`).
func _hand_views(w: World, native: bool) -> ActorViews:
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	var was := EnemyBatch.native
	EnemyBatch.native = native  # (its batch is made by this first sync)
	views.sync(WorldReader.new(w))
	EnemyBatch.native = was
	views.batch.native_override = native
	views.batch.set_process(false)
	views.vat_crowd.set_process(false)
	return views


func _frame(views: ActorViews) -> void:
	views._process(DT)
	views.bar_chunks.advance(DT)
	views.batch.advance(DT)
	views.vat_crowd._process(DT)


## Every VAT set's instances (count, capacity, the floats drawn, the drive floats drawn) by look, and the furniture.
func _drawn(views: ActorViews) -> Dictionary:
	var out := {"furniture": _taken(views.batch)}
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


func _drawn_difference(a: Dictionary, b: Dictionary) -> String:
	var fd := _first_difference(a["furniture"], b["furniture"])
	if fd != "":
		return "furniture " + fd
	if a.keys() != b.keys():
		return "sets %s vs %s" % [a.keys(), b.keys()]
	for key: String in a:
		if key == "furniture":
			continue
		for q in (a[key] as Array).size():
			if a[key][q] != b[key][q]:
				return "%s field %d %s" % [key, q, _at(a[key][q], b[key][q])]
	return ""


## Every batched enemy's avatar in both views (the same id).
func _both(a: ActorViews, b: ActorViews, id: int) -> Array:
	var na := a.actor_node(id)
	var nb := b.actor_node(id)
	if na == null or nb == null or not na.has_meta(&"enemy_avatar"):
		return []
	return [na.get_meta(&"enemy_avatar"), nb.get_meta(&"enemy_avatar")]


func test_the_native_avatars_draw_the_script_avatars_bodies() -> void:
	if not ClassDB.class_exists(EnemyBatch.NATIVE_CLASS):
		pending("the native library is not loaded")
		return
	var calm_was := ViewPrefs.reduced_motion
	var w := CombatLab.world()
	for k in 45:  # Every batched kind, a few far out (they come on screen: the catch-up steps)
		var far := 30.0 if k % 9 == 4 else 0.0
		w.add_enemy(
			KINDS_ALL[k % KINDS_ALL.size()],
			Vector2(-12.0 + (k % 9) * 3.0 + far, -7.0 + (k / 9) * 3.0)
		)
	var a := _hand_views(w, true)
	var b := _hand_views(w, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5506
	var compared := 0
	var flinched := 0
	var held := 0
	var dazed := 0
	var fell := 0
	for f in FRAMES:
		ViewPrefs.reduced_motion = f >= 200 and f < 230  # A stretch of reduced motion (calm)
		for t in [0, 1, 1, 2][f % 4]:  # Frames with no tick, one and two
			w.step(InputFrame.new())
		if f % 7 == 3:  # Hurt someone (the bar; a Mender heals it)
			var i := rng.randi_range(0, w.actors.size() - 1)
			if w.actors.teams[i] != 0 and w.actors.hp[i] > 1:
				w.actors.hp[i] = maxi(1, w.actors.hp[i] - maxi(1, w.actors.max_hp[i] / 5))
		if f == 100:  # Spawns
			for kind: int in [SW, CH, ActorStore.Kind.SPLITTER]:
				w.add_enemy(kind, Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0)))
		if f == 120:  # A dazed Charger
			for i in w.actors.size():
				if w.actors.kinds[i] == CH:
					w.actors.state[i] = WorldReader.STATE_RECOVER
					dazed += 1
					break
		if f == 150 or f == 240:  # Kills: a code body goes, an owner's model falls
			for i in w.actors.size():
				if (
					w.actors.teams[i] != 0
					and w.actors.kinds[i] in [SN, SB, ActorStore.Kind.SPLITTER]
				):
					fell += 1 if w.actors.kinds[i] != SN else 0
					var at := w.actors.pos(i)
					Damage.hit(w, i, 1 << 20, 0, 0, w.take_root(), 0, at, at)
					break
		if f % 2 == 0:
			a.sync(WorldReader.new(w))
			b.sync(WorldReader.new(w))
		if f % 3 == 1:  # Hits: the flash, a flinch (a Blade's knock now and then), a hold, a tint
			var ids := a.batch.ids()
			if ids.size() > 0:
				var id := ids[rng.randi_range(0, ids.size() - 1)]
				var away := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
				var knock := 1.0 if f % 6 == 1 else 0.0
				var pair := _both(a, b, id)
				for v: ActorViews in [a, b]:
					v.flash(id)
				if not pair.is_empty():
					var fa: bool = pair[0].flinch(away, 1.0, knock)
					var fb: bool = pair[1].flinch(away, 1.0, knock)
					assert_eq(fa, fb, "the same flinch decision")
					flinched += 1 if fa else 0
					if f % 9 == 4:
						pair[0].hold(0.06)
						pair[1].hold(0.06)
						held += 1
				if f % 11 == 0:
					for v: ActorViews in [a, b]:
						v.set_tint(id, Color(0.3, 1.0, 0.4), 0.8)
		await get_tree().process_frame  # A real frame: the fraction and the physics frames move on
		_frame(a)
		_frame(b)
		var diff := _drawn_difference(_drawn(a), _drawn(b))
		if diff != "":
			ViewPrefs.reduced_motion = calm_was
			fail_test("frame %d: %s" % [f, diff])
			return
		compared += 1
	ViewPrefs.reduced_motion = calm_was
	assert_true(a.batch.avatars.on, "the native avatars ran")
	assert_false(b.batch.avatars.on, "the reference ran in GDScript")
	assert_eq(compared, FRAMES, "every frame alike")
	assert_gt(flinched, 10, "flinches compared")
	assert_gt(held, 3, "holds compared")
	assert_gt(dazed, 0, "a dazed Charger")
	assert_gt(fell, 0, "a body fell")
	assert_gt(a.vat_crowd.drawn, 30, "a crowd drawn")


func test_an_avatar_read_during_native_play_has_the_latest_numbers() -> void:
	if not ClassDB.class_exists(EnemyBatch.NATIVE_CLASS):
		pending("the native library is not loaded")
		return
	var w := CombatLab.world()
	var id := w.add_enemy(CH, Vector2(2.0, 1.0))
	var a := _hand_views(w, true)
	var b := _hand_views(w, false)
	_ripen(w)
	for f in 30:
		a.sync(WorldReader.new(w))
		b.sync(WorldReader.new(w))
		await get_tree().process_frame
		_frame(a)
		_frame(b)
	var pair := _both(a, b, id)
	var na: ChargerAvatar = pair[0]
	var nb: ChargerAvatar = pair[1]
	assert_eq(na.native_owner, a.batch.avatars, "the batch's rows hold it")
	assert_eq(na.glow_energy(), nb.glow_energy(), "its glow, read back")
	assert_eq(na.get(&"_t"), nb.get(&"_t"), "its clock, read back")
	assert_eq(na.vat_drives(), nb.vat_drives(), "its drives, read back")
	assert_eq(na.flinch(Vector2.LEFT), nb.flinch(Vector2.LEFT), "a flinch on the latest state")
	await get_tree().process_frame
	_frame(a)
	_frame(b)
	assert_eq(na.flinch_amount(), nb.flinch_amount(), "the flinch stepped natively")
	a.batch.native_override = false  # Its switch off (the dev panel's): the objects take the state back
	await get_tree().process_frame
	_frame(a)
	assert_null(na.native_owner, "switched off: the object holds its state")
	assert_eq(na.get(&"_t"), nb.get(&"_t") + DT, "and steps on from it")
