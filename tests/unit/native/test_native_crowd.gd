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
			return "at %d: %s vs %s" % [k, a[k], b[k]]
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
