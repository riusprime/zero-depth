extends GutTest
## The Lens Drones' native avatars (ZdCrowd, native/src/zd_avatar_lens.cpp) against their GDScript (LensDroneAvatar),
## bit for bit, through the batch (EnemyBatch): the hover and bob, the eye's charge through windups and shots, kills
## mid-attack, hits, flinches (about the pod's height), holds, spawns, reduced motion and far-off slots; and the ground
## shadow each keeps in the tree (BatchLensDrone), its size and place.

const LD := ActorStore.Kind.LENS_DRONE
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


func test_the_native_lens_drones_draw_the_script_ones_bodies() -> void:
	if not ClassDB.class_exists(EnemyBatch.NATIVE_CLASS):
		pending("the native library is not loaded")
		return
	var calm_was := ViewPrefs.reduced_motion
	var w := CombatLab.world()
	w.actors.invuln[0] = 1 << 24
	for k in 12:  # A ring round the hero, in range; two far out (they come on screen: the catch-up)
		var r := 4.0 + (k % 4) * 1.8 + (30.0 if k % 6 == 3 else 0.0)
		var a0 := TAU * k / 12.0
		w.add_enemy(LD, Vector2(cos(a0), sin(a0)) * r)
	var a := CrowdTwins.hand_views(self, w, true)
	var b := CrowdTwins.hand_views(self, w, false)
	assert_true(a.batch.has(w.actors.ids[1]), "a Lens Drone is batched")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5917
	var seen := {}  # Lens Drone states seen (frames): its windup, pulse and recovery
	var counts := {"flinched": 0, "held": 0, "killed": 0, "killed_attacking": 0, "shadows": 0}
	for f in FRAMES:
		ViewPrefs.reduced_motion = f >= 200 and f < 230  # A stretch of reduced motion (calm)
		for t in [0, 1, 1, 2][f % 4]:  # Frames with no tick, one and two
			w.step(InputFrame.new())
		for i in w.actors.size():
			if w.actors.kinds[i] == LD and w.actors.dead[i] == 0:
				seen[w.actors.state[i]] = seen.get(w.actors.state[i], 0) + 1
		if f % 7 == 3:  # Hurt someone (the bar)
			var i := rng.randi_range(0, w.actors.size() - 1)
			if w.actors.teams[i] != 0 and w.actors.hp[i] > 1:
				w.actors.hp[i] = maxi(1, w.actors.hp[i] - maxi(1, w.actors.max_hp[i] / 5))
		if f == 90 or f == 190:  # Spawns (one rises in on screen)
			w.add_enemy(LD, Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0)))
		if f % 40 == 20 and f > 60:  # A kill, mid-attack (its windup, pulse or recovery) when one is
			var pick := -1
			for i in w.actors.size():
				if w.actors.teams[i] == 0 or w.actors.kinds[i] != LD or w.actors.dead[i] != 0:
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
		if diff == "":
			diff = _shadow_difference(a, b, counts)
		if diff != "":
			ViewPrefs.reduced_motion = calm_was
			fail_test("frame %d: %s" % [f, diff])
			return
	ViewPrefs.reduced_motion = calm_was
	assert_true(a.batch.avatars.on, "the native avatars ran")
	assert_false(b.batch.avatars.on, "the reference ran in GDScript")
	gut.p("lens drone states seen (frames): %s, %s" % [seen, counts])
	assert_gt(seen.get(WorldReader.STATE_WINDUP, 0), 0, "windups compared")
	assert_gt(seen.get(WorldReader.STATE_RECOVER, 0), 0, "pulses and recoveries compared")
	assert_gt(seen.get(WorldReader.STATE_SPAWN, 0), 0, "rises compared")
	assert_gt(counts["flinched"], 10, "flinches compared")
	assert_gt(counts["held"], 3, "holds compared")
	assert_gt(counts["killed_attacking"], 0, "a kill mid-attack")
	assert_gt(counts["killed"], 1, "kills compared")
	assert_gt(a.vat_crowd.drawn, 8, "a crowd drawn")


## Each batched drone's ground shadow in both views: in the tree, the same size, the same holder transforms and shown
## alike; "" when they are.
func _shadow_difference(a: ActorViews, b: ActorViews, counts: Dictionary) -> String:
	for id in a.batch.ids():
		var pair := CrowdTwins.both(a, b, id)
		if pair.is_empty():
			return "drone %d missing in one view" % id
		var looks: Array = []
		for d: LensDroneAvatar in pair:
			var sh := d.shadow
			if not sh.is_inside_tree():
				return "drone %d's shadow is not in the tree" % id
			var body := sh.get_parent() as Node3D
			var turn := body.get_parent() as Node3D
			looks.append(
				[
					sh.transform,
					body.transform,
					turn.transform,
					turn.get_parent().position,
					sh.is_visible_in_tree()
				]
			)
		if looks[0] != looks[1]:
			return "drone %d's shadow %s vs %s" % [id, looks[0], looks[1]]
		counts["shadows"] += 1
	return ""


## The batched drones' shadows stand where a view of nodes stands its drones' (the same world, both stepped by hand):
## the same global transform (its hover's size, its flinch's lean) and shown alike.
func test_the_batched_shadows_stand_where_the_nodes_ones_do() -> void:
	if not ClassDB.class_exists(EnemyBatch.NATIVE_CLASS):
		pending("the native library is not loaded")
		return
	var w := CombatLab.world()
	w.actors.invuln[0] = 1 << 24
	for k in 6:
		w.add_enemy(LD, Vector2(cos(TAU * k / 6.0), sin(TAU * k / 6.0)) * (4.0 + k))
	var a := CrowdTwins.hand_views(self, w, true)
	var nodes: ActorViews = add_child_autofree(ActorViews.new())
	nodes.batching = false
	nodes.set_process(false)
	nodes.sync(WorldReader.new(w))
	assert_eq(nodes.batched_count(), 0, "the twin keeps its nodes")
	var drones: Array[LensDroneAvatar] = []
	for id in a.batch.ids():
		drones.append(nodes.actor_node(id).get_meta(&"enemy_avatar"))
	var stepped := _hand_stepped(drones)
	await get_tree().process_frame
	var compared := 0
	for f in 120:
		w.step(InputFrame.new())
		if f % 2 == 0:
			a.sync(WorldReader.new(w))
			nodes.sync(WorldReader.new(w))
			stepped = _hand_stepped(drones)
		if f % 5 == 2:  # A flinch on one drone in both
			var id := a.batch.ids()[f % a.batch.ids().size()]
			var away := Vector2(1.0, float(f % 3) - 1.0)
			(a.actor_node(id).get_meta(&"enemy_avatar") as AvatarBase).flinch(away)
			(nodes.actor_node(id).get_meta(&"enemy_avatar") as AvatarBase).flinch(away)
		await get_tree().process_frame
		CrowdTwins.frame(a)
		for d in drones:
			if stepped.has(d):
				d._process(CrowdTwins.DT)
		for id in a.batch.ids():
			var sa := (a.actor_node(id).get_meta(&"enemy_avatar") as LensDroneAvatar).shadow
			var sb := (nodes.actor_node(id).get_meta(&"enemy_avatar") as LensDroneAvatar).shadow
			var ga := [sa.global_transform, sa.is_visible_in_tree()]
			var gb := [sb.global_transform, sb.is_visible_in_tree()]
			if ga != gb:
				fail_test("frame %d: drone %d's shadow %s vs the node's %s" % [f, id, ga, gb])
				return
			compared += 1
	gut.p("lens drone shadows compared: %d" % compared)
	assert_gt(compared, 500, "shadows compared")


## The drones ActorViews set processing (its on-screen test), each then stepped by hand rather than by the tree (the
## batch steps its own by the same switch).
func _hand_stepped(drones: Array[LensDroneAvatar]) -> Dictionary:
	var out := {}
	for d in drones:
		if d.is_processing():
			out[d] = true
			d.set_process(false)
	return out
