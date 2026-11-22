extends GutTest
## The Scrap Hounds' native avatars (ZdCrowd, native/src/zd_avatar_scrap_hound.cpp) against their GDScript
## (ScrapHoundAvatar), bit for bit in every drawn buffer: the trot and gallop, the circling turn and bank, the tell,
## the dart, the bite, the yelp, kills mid-attack, hits, flinches, holds, spawns, reduced motion, far-off slots and
## frames of no, one and two ticks.

const SH := ActorStore.Kind.SCRAP_HOUND
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


func test_the_native_scrap_hounds_draw_the_script_ones_bodies() -> void:
	if not ClassDB.class_exists(EnemyBatch.NATIVE_CLASS):
		pending("the native library is not loaded")
		return
	var calm_was := ViewPrefs.reduced_motion
	var w := CombatLab.world()
	w.actors.invuln[0] = 1 << 24
	for k in 12:  # A ring round the hero, near and in range; two far out (they come on screen: the catch-up)
		var r: float = [3.0, 5.0, 7.0, 9.0][k % 4] + (30.0 if k % 7 == 3 else 0.0)
		var a0 := TAU * k / 12.0
		_add(w, Vector2(cos(a0), sin(a0)) * r)
	var a := CrowdTwins.hand_views(self, w, true)
	var b := CrowdTwins.hand_views(self, w, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6018
	var compared := 0
	var flinched := 0
	var held := 0
	var seen := {}
	var yelps := 0
	var bites := 0
	var killed_attacking := 0
	var killed := 0
	var spawned := 0
	var was := {}
	for f in FRAMES:
		ViewPrefs.reduced_motion = f >= 200 and f < 230  # A stretch of reduced motion (calm)
		for t in [0, 1, 1, 2][f % 4]:  # Frames with no tick, one and two
			var input := InputFrame.new()
			input.held = InputFrame.PRIMARY if f % 50 < 30 else 0  # The hero swings: the hounds go for its back
			input.aim_angle = (f * 23) & 4095
			w.step(input)
		for i in w.actors.size():
			if w.actors.kinds[i] == SH and w.actors.dead[i] == 0:
				var st: int = w.actors.state[i]
				seen[st] = int(seen.get(st, 0)) + 1
				var id := w.actors.ids[i]
				if st == WorldReader.STATE_RECOVER and was.get(id, -1) != WorldReader.STATE_RECOVER:
					if RuinsRocks.yelped(w, i):
						yelps += 1
					elif was.get(id, -1) == WorldReader.STATE_ACTIVE:
						bites += 1
				was[id] = st
		if f % 7 == 3:  # Hurt someone (a hound's flinch clip; one winding up or darting yelps)
			var i := rng.randi_range(0, w.actors.size() - 1)
			if w.actors.teams[i] != 0 and w.actors.hp[i] > 1:
				w.actors.hp[i] = maxi(1, w.actors.hp[i] - maxi(1, w.actors.max_hp[i] / 5))
		if f == 90 or f == 190:  # Spawns (one rises in on screen)
			_add(w, Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0)))
			spawned += 1
		if f % 40 == 20 and f > 60:  # A kill, mid-attack (its tell or its dart) when one is
			var pick := -1
			for i in w.actors.size():
				if w.actors.teams[i] == 0 or w.actors.kinds[i] != SH or w.actors.dead[i] != 0:
					continue
				var st: int = w.actors.state[i]
				if st == WorldReader.STATE_WINDUP or st == WorldReader.STATE_ACTIVE:
					pick = i
					killed_attacking += 1
					break
				if pick < 0:
					pick = i
			if pick >= 0:
				killed += 1
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
				var knock := 1.0 if f % 6 == 1 else 0.0
				var pair := CrowdTwins.both(a, b, id)
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
		CrowdTwins.frame(a)
		CrowdTwins.frame(b)
		var diff := CrowdTwins.drawn_difference(CrowdTwins.drawn(a), CrowdTwins.drawn(b))
		if diff != "":
			ViewPrefs.reduced_motion = calm_was
			fail_test("frame %d: %s" % [f, diff])
			return
		compared += 1
	ViewPrefs.reduced_motion = calm_was
	gut.p(
		(
			"hound states seen (actor-frames): %s; yelps %d, bites %d; kills %d (%d mid-attack)"
			% [seen, yelps, bites, killed, killed_attacking]
		)
	)
	assert_true(a.batch.avatars.on, "the native avatars ran")
	assert_false(b.batch.avatars.on, "the reference ran in GDScript")
	assert_eq(compared, FRAMES, "every frame alike")
	assert_gt(flinched, 10, "flinches compared")
	assert_gt(held, 3, "holds compared")
	assert_gt(int(seen.get(WorldReader.STATE_MOVE, 0)), 0, "runs compared")
	assert_gt(int(seen.get(WorldReader.STATE_WINDUP, 0)), 0, "tells compared")
	assert_gt(int(seen.get(WorldReader.STATE_ACTIVE, 0)), 0, "darts compared")
	assert_gt(yelps, 0, "a yelp compared")
	assert_gt(bites, 0, "a bite compared")
	assert_gt(killed_attacking, 0, "a kill mid-attack")
	assert_gt(killed, 1, "kills compared")
	assert_eq(spawned, 2, "spawns compared")
	assert_gt(a.vat_crowd.drawn, 8, "a crowd drawn")


## A hound at `at`, open to the hero's swings (a hit on its tell or dart is a yelp).
func _add(w: World, at: Vector2) -> void:
	var id := w.add_enemy(SH, at)
	w.actors.invuln[w.actors.index_of(id)] = 0
