extends GutTest
## The Gravity Nodes' native avatars (ZdCrowd, native/src/zd_avatar_gravity_node.cpp) against their GDScript
## (GravityNodeAvatar), bit for bit, through the batch (EnemyBatch): the hover, the draw on the hero (the rings spun up
## and tightened, the core's beats), the turn toward the hero, a hit's wobble (its HP lost), kills, hits, flinches,
## holds, rise-ins, reduced motion, far-off slots and frames of no, one and two ticks; their ground discs (kept in the
## tree by BatchGravityNode) shown, placed and sized alike.

const GN := ActorStore.Kind.GRAVITY_NODE
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


## Every node's avatar in both views by id, kept through its fall after the sim dropped it (until it is freed).
static func _note_pairs(a: ActorViews, b: ActorViews, pairs: Dictionary) -> void:
	for id: int in pairs.keys():
		var p: Array = pairs[id]
		if not is_instance_valid(p[0]) or not is_instance_valid(p[1]) or not a.batch.has(id):
			pairs.erase(id)
	for id in a.batch.ids():
		var pair := CrowdTwins.both(a, b, id)
		if not pair.is_empty() and pair[0] is GravityNodeAvatar:
			pairs[id] = pair


## Where two views' node ground discs first differ (in the tree, shown, placed and sized), or "".
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


func test_the_native_gravity_nodes_draw_the_script_ones_bodies() -> void:
	if not ClassDB.class_exists(EnemyBatch.NATIVE_CLASS):
		pending("the native library is not loaded")
		return
	var calm_was := ViewPrefs.reduced_motion
	var w := CombatLab.world()
	w.actors.invuln[0] = 1 << 24
	for k in 12:  # A half ring on one side (the hero drifts in: their turns), in and out of reach; two far out
		var r := 2.0 + (k % 4) * 1.8 + (30.0 if k % 6 == 3 else 0.0)
		var a0 := PI * k / 11.0
		w.add_enemy(GN, Vector2(cos(a0), sin(a0)) * r)
	var a := CrowdTwins.hand_views(self, w, true)
	var b := CrowdTwins.hand_views(self, w, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6523
	var seen := {}  # Node states seen (actor-frames)
	var pairs := {}  # id -> [native avatar, script avatar], falling ones too
	var counts := {
		"flinched": 0,
		"held": 0,
		"killed": 0,
		"spawned": 0,
		"hurt": 0,
		"drawing": 0,
		"beating": 0,
		"turning": 0,
		"rising": 0,
		"dying": 0,
	}
	for f in FRAMES:
		ViewPrefs.reduced_motion = f >= 200 and f < 230  # A stretch of reduced motion (calm)
		for t in [0, 1, 1, 2][f % 4]:  # Frames with no tick, one and two
			w.step(InputFrame.new())
		var orbit := 0.06 * f  # The hero walked round the crowd's middle, the nodes turned to face it
		w.actors.set_pos(0, Vector2(cos(orbit), sin(orbit)) * 2.5)
		for i in w.actors.size():
			if w.actors.kinds[i] == GN and w.actors.dead[i] == 0:
				seen[w.actors.state[i]] = seen.get(w.actors.state[i], 0) + 1
				w.actors.facing[i] = Kin.angle_of(w.player_pos() - w.actors.pos(i))
		if f % 7 == 3:  # Hurt someone (the bar; a node's wobble reads its HP)
			var i := rng.randi_range(0, w.actors.size() - 1)
			if w.actors.teams[i] != 0 and w.actors.hp[i] > 1:
				w.actors.hp[i] = maxi(1, w.actors.hp[i] - maxi(1, w.actors.max_hp[i] / 5))
		if f == 90 or f == 190:  # Spawns (one rises in on screen)
			w.add_enemy(GN, Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0)))
			counts["spawned"] += 1
		if f % 40 == 20 and f > 60:  # A kill
			for i in w.actors.size():
				if w.actors.teams[i] != 0 and w.actors.kinds[i] == GN and w.actors.dead[i] == 0:
					counts["killed"] += 1
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
			var d: GravityNodeAvatar = pairs[id][0]
			d.drives()  # (a read: the native row into the object)
			counts["drawing"] += 1 if d._draw > 0.2 else 0
			counts["beating"] += 1 if d._beat > 0.0 else 0
			counts["turning"] += 1 if absf(d._omega) > 0.2 else 0
			counts["rising"] += 1 if d._rise < 1.0 and d._die_t < 0.0 else 0
			counts["hurt"] += 1 if d._hurt_t >= 0.0 else 0
			counts["dying"] += 1 if d._die_t >= 0.0 else 0
	ViewPrefs.reduced_motion = calm_was
	assert_true(a.batch.avatars.on, "the native avatars ran")
	assert_false(b.batch.avatars.on, "the reference ran in GDScript")
	gut.p("gravity node states seen (actor-frames): %s, %s" % [seen, counts])
	assert_gt(counts["drawing"], 0, "draws on the hero compared")
	assert_gt(counts["beating"], 0, "the core's beats compared")
	assert_gt(counts["turning"], 0, "turns compared")
	assert_gt(counts["rising"], 0, "rise-ins compared")
	assert_gt(counts["hurt"], 0, "hit wobbles compared")
	assert_gt(counts["dying"], 0, "deaths compared")
	assert_gt(counts["flinched"], 10, "flinches compared")
	assert_gt(counts["held"], 3, "holds compared")
	assert_gt(counts["killed"], 1, "kills compared")
	assert_eq(counts["spawned"], 2, "spawns compared")
	assert_gt(a.vat_crowd.drawn, 8, "a crowd drawn")
