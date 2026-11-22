extends GutTest
## The Bomb Drones' native avatars (ZdCrowd, native/src/zd_avatar_bomb_drone.cpp) against their GDScript
## (BombDroneAvatar), bit for bit, through the batch (EnemyBatch): the hover, glides, turns, lobs, hurts, kills
## mid-lob, hits, flinches (about the hull), holds, spawns, reduced motion and far-off slots; their ground discs (kept
## in the tree by BatchBombDrone) shown and placed alike.

const BD := ActorStore.Kind.BOMB_DRONE
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


## Every drone's avatar in both views by id, kept through its fall after the sim dropped it (until it is freed).
static func _note_pairs(a: ActorViews, b: ActorViews, pairs: Dictionary) -> void:
	for id: int in pairs.keys():
		var p: Array = pairs[id]
		if not is_instance_valid(p[0]) or not is_instance_valid(p[1]) or not a.batch.has(id):
			pairs.erase(id)
	for id in a.batch.ids():
		var pair := CrowdTwins.both(a, b, id)
		if not pair.is_empty() and pair[0] is BombDroneAvatar:
			pairs[id] = pair


## Where two views' drone ground discs first differ (in the tree, shown, placed), or "".
static func _disc_difference(pairs: Dictionary) -> String:
	for id: int in pairs:
		var pair: Array = pairs[id]
		var da: MeshInstance3D = pair[0].shadow
		var db: MeshInstance3D = pair[1].shadow
		if not da.is_inside_tree() or not db.is_inside_tree():
			return "id %d disc out of the tree" % id
		if da.is_visible_in_tree() != db.is_visible_in_tree():
			return (
				"id %d disc shown %s vs %s" % [id, da.is_visible_in_tree(), db.is_visible_in_tree()]
			)
		if da.global_transform != db.global_transform:
			return "id %d disc at %s vs %s" % [id, da.global_transform, db.global_transform]
	return ""


func test_the_native_bomb_drones_draw_the_script_ones_bodies() -> void:
	if not ClassDB.class_exists(EnemyBatch.NATIVE_CLASS):
		pending("the native library is not loaded")
		return
	var calm_was := ViewPrefs.reduced_motion
	var w := CombatLab.world()
	w.actors.invuln[0] = 1 << 24
	for k in 12:  # A ring round the hero, in range; two far out (they come on screen: the catch-up)
		var r := 4.0 + (k % 4) * 1.6 + (30.0 if k % 6 == 3 else 0.0)
		var a0 := TAU * k / 12.0
		w.add_enemy(BD, Vector2(cos(a0), sin(a0)) * r)
	var a := CrowdTwins.hand_views(self, w, true)
	var b := CrowdTwins.hand_views(self, w, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5816
	var seen := {}  # Drone states seen (actor-frames)
	var pairs := {}  # id -> [native avatar, script avatar], falling ones too
	var counts := {
		"flinched": 0,
		"held": 0,
		"killed": 0,
		"killed_lobbing": 0,
		"spawned": 0,
		"hurt": 0,
		"gliding": 0,
		"turning": 0,
		"lobbing": 0,
		"dying": 0,
	}
	for f in FRAMES:
		ViewPrefs.reduced_motion = f >= 200 and f < 230  # A stretch of reduced motion (calm)
		for t in [0, 1, 1, 2][f % 4]:  # Frames with no tick, one and two
			w.step(InputFrame.new())
		for i in w.actors.size():
			if w.actors.kinds[i] == BD and w.actors.dead[i] == 0:
				seen[w.actors.state[i]] = seen.get(w.actors.state[i], 0) + 1
		if f % 7 == 3:  # Hurt someone (the bar; a drone's sag reads its HP)
			var i := rng.randi_range(0, w.actors.size() - 1)
			if w.actors.teams[i] != 0 and w.actors.hp[i] > 1:
				w.actors.hp[i] = maxi(1, w.actors.hp[i] - maxi(1, w.actors.max_hp[i] / 5))
		if f == 90 or f == 190:  # Spawns (one rises in on screen)
			w.add_enemy(BD, Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0)))
			counts["spawned"] += 1
		if f % 40 == 20 and f > 60:  # A kill, mid-lob (its windup or its throw) when one is
			var pick := -1
			for i in w.actors.size():
				if w.actors.teams[i] == 0 or w.actors.kinds[i] != BD or w.actors.dead[i] != 0:
					continue
				if w.actors.state[i] >= WorldReader.STATE_WINDUP:
					pick = i
					counts["killed_lobbing"] += 1
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
		_note_pairs(a, b, pairs)
		if diff == "":
			diff = _disc_difference(pairs)
		if diff != "":
			ViewPrefs.reduced_motion = calm_was
			fail_test("frame %d: %s" % [f, diff])
			return
		for id: int in pairs:
			var d: BombDroneAvatar = pairs[id][0]
			d.drives()  # (a read: the native row into the object)
			counts["gliding"] += 1 if d._glide > 0.2 else 0
			counts["turning"] += 1 if absf(d._omega) > 0.2 else 0
			counts["lobbing"] += 1 if d._lob_s >= 0.0 else 0
			counts["hurt"] += 1 if d._hurt_t >= 0.0 else 0
			counts["dying"] += 1 if d._die_t >= 0.0 else 0
	ViewPrefs.reduced_motion = calm_was
	assert_true(a.batch.avatars.on, "the native avatars ran")
	assert_false(b.batch.avatars.on, "the reference ran in GDScript")
	gut.p("bomb drone states seen (actor-frames): %s, %s" % [seen, counts])
	assert_gt(seen.get(WorldReader.STATE_WINDUP, 0), 0, "lobs' windups compared")
	assert_gt(counts["lobbing"], 0, "throws compared")
	assert_gt(counts["gliding"], 0, "glides compared")
	assert_gt(counts["turning"], 0, "turns compared")
	assert_gt(counts["hurt"], 0, "hurt sags compared")
	assert_gt(counts["dying"], 0, "deaths compared")
	assert_gt(counts["flinched"], 10, "flinches compared")
	assert_gt(counts["held"], 3, "holds compared")
	assert_gt(counts["killed_lobbing"], 0, "a kill mid-lob")
	assert_gt(counts["killed"], 1, "kills compared")
	assert_eq(counts["spawned"], 2, "spawns compared")
	assert_gt(a.vat_crowd.drawn, 8, "a crowd drawn")
