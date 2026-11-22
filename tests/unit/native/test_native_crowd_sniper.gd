extends GutTest
## The Snipers' native avatars (ZdCrowd, native/src/zd_avatar_sniper.cpp) against their GDScript (SniperAvatar), bit
## for bit, through the batch (EnemyBatch): aims, shots, the second kick, vents, kills mid-attack, hits, flinches,
## holds, spawns, reduced motion and far-off slots.

const SN := ActorStore.Kind.SNIPER
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


func test_the_native_snipers_draw_the_script_ones_bodies() -> void:
	if not ClassDB.class_exists(EnemyBatch.NATIVE_CLASS):
		pending("the native library is not loaded")
		return
	var calm_was := ViewPrefs.reduced_motion
	var w := CombatLab.world()
	w.actors.invuln[0] = 1 << 24
	for k in 12:  # A ring round the hero, in range; two far out (they come on screen: the catch-up)
		var r := 5.0 + (k % 4) * 1.8 + (30.0 if k % 6 == 3 else 0.0)
		var a0 := TAU * k / 12.0
		w.add_enemy(SN, Vector2(cos(a0), sin(a0)) * r)
	var a := CrowdTwins.hand_views(self, w, true)
	var b := CrowdTwins.hand_views(self, w, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5609
	var seen := {}  # Sniper states seen (frames): its aim, shot and recovery's vent
	var counts := {"flinched": 0, "held": 0, "killed": 0, "killed_attacking": 0}
	for f in FRAMES:
		ViewPrefs.reduced_motion = f >= 200 and f < 230  # A stretch of reduced motion (calm)
		for t in [0, 1, 1, 2][f % 4]:  # Frames with no tick, one and two
			w.step(InputFrame.new())
		for i in w.actors.size():
			if w.actors.kinds[i] == SN and w.actors.dead[i] == 0:
				seen[w.actors.state[i]] = seen.get(w.actors.state[i], 0) + 1
		if f % 7 == 3:  # Hurt someone (the bar; a Sniper's flinch reads its HP)
			var i := rng.randi_range(0, w.actors.size() - 1)
			if w.actors.teams[i] != 0 and w.actors.hp[i] > 1:
				w.actors.hp[i] = maxi(1, w.actors.hp[i] - maxi(1, w.actors.max_hp[i] / 5))
		if f == 90 or f == 190:  # Spawns (one rises in on screen)
			w.add_enemy(SN, Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0)))
		if f % 40 == 20 and f > 60:  # A kill, mid-attack (its aim, shot or vent) when one is
			var pick := -1
			for i in w.actors.size():
				if w.actors.teams[i] == 0 or w.actors.kinds[i] != SN or w.actors.dead[i] != 0:
					continue
				if w.actors.state[i] >= WorldReader.STATE_WINDUP:
					pick = i
					counts["killed_attacking"] += 1
					break
				if pick < 0:
					pick = i
			if pick >= 0:
				counts["killed"] += 1
				var at := w.actors.pos(pick)
				Damage.hit(w, pick, 1 << 20, 0, 0, w.take_root(), 0, at, at)
		if f % 2 == 0:
			a.sync(WorldReader.new(w))
			b.sync(WorldReader.new(w))
		if f % 3 == 1:  # Hits: the flash, a flinch (a Blade's knock now and then), a hold, a tint
			var ids := a.batch.ids()
			if ids.size() > 0:
				var id := ids[rng.randi_range(0, ids.size() - 1)]
				var away := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
				var pair := CrowdTwins.both(a, b, id)
				for v: ActorViews in [a, b]:
					v.flash(id)
				if not pair.is_empty():
					var fa: bool = pair[0].flinch(away, 1.0, 1.0 if f % 6 == 1 else 0.0)
					var fb: bool = pair[1].flinch(away, 1.0, 1.0 if f % 6 == 1 else 0.0)
					assert_eq(fa, fb, "the same flinch decision")
					counts["flinched"] += 1 if fa else 0
					if f < 150:  # The Split Sniper's second kick on the same avatar (its look is not batched)
						pair[0]._touch()  # (its row takes the field back before the next native call)
						pair[0]._double = true
						pair[1]._double = true
					if f % 9 == 4:
						pair[0].hold(0.06)
						pair[1].hold(0.06)
						counts["held"] += 1
				if f % 11 == 0:
					for v: ActorViews in [a, b]:
						v.set_tint(id, Color(0.3, 1.0, 0.4), 0.8)
		await get_tree().process_frame  # A real frame: the fraction and the physics frames move on
		CrowdTwins.frame(a)
		CrowdTwins.frame(b)
		var diff := CrowdTwins.drawn_difference(CrowdTwins.drawn(a), CrowdTwins.drawn(b))
		if diff != "":
			ViewPrefs.reduced_motion = calm_was
			fail_test("frame %d: %s" % [f, diff])
			return
	ViewPrefs.reduced_motion = calm_was
	assert_true(a.batch.avatars.on, "the native avatars ran")
	assert_false(b.batch.avatars.on, "the reference ran in GDScript")
	gut.p("sniper states seen (frames): %s, %s" % [seen, counts])
	assert_gt(seen.get(WorldReader.STATE_WINDUP, 0), 0, "aims compared")
	assert_gt(seen.get(WorldReader.STATE_RECOVER, 0), 0, "shots and vents compared")
	assert_gt(counts["flinched"], 10, "flinches compared")
	assert_gt(counts["held"], 3, "holds compared")
	assert_gt(counts["killed_attacking"], 0, "a kill mid-attack")
	assert_gt(counts["killed"], 1, "kills compared")
	assert_gt(a.vat_crowd.drawn, 8, "a crowd drawn")
