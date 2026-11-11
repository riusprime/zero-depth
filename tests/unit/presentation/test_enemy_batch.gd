extends GutTest
## EnemyBatch: the VAT crowd's horde kinds, the Charger and the Hatchling drawn with no node of theirs in the tree
## (their contact disc, team ring, dazed ring, health bar and blob as instances written in one pass a frame), each
## where its sim place says, its bar showing its health, gone the frame it is killed, and looking as its node did (a
## view of nodes built beside it on the same world draws the same instances).

const SW := ActorStore.Kind.SWARMER
const SN := ActorStore.Kind.SNIPER
const SB := ActorStore.Kind.SHIELD_BEARER
const CH := ActorStore.Kind.CHARGER
const DT := 1.0 / 60.0

var _vat := false


func before_each() -> void:
	_vat = ViewPrefs.enemy_vat
	ViewPrefs.enemy_vat = true


func after_each() -> void:
	ViewPrefs.enemy_vat = _vat


func _views(w: World, batching: Variant = null) -> ActorViews:
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.batching = batching
	views.set_process(false)
	views.sync(WorldReader.new(w))
	return views


func _ripen(w: World) -> void:
	for t in w.tuning.spawn_in_ticks + 1:  # Past the spawn's rise-in
		w.step(InputFrame.new())


func _nodes_under(n: Node) -> int:
	var total := 0
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		stack.append_array(c.get_children())
		total += 1
	return total


func test_200_enemies_make_no_node_of_their_own() -> void:
	var w := CombatLab.world()
	var ids: Array[int] = []
	for k in 200:
		ids.append(w.add_enemy(SW, Vector2(-20.0 + (k % 20) * 2.0, -10.0 + (k / 20) * 2.0)))
	var views := _views(w)
	assert_eq(views.batched_count(), 200, "every Swarmer is batched")
	views.batch.advance(DT)
	views.vat_crowd._process(DT)
	assert_eq(views.vat_crowd.drawn, 200, "their bodies, one instance each")
	assert_eq(views.batch.drawn[EnemyBatch.Part.DISC], 200, "their discs")
	assert_eq(views.batch.drawn[EnemyBatch.Part.RING], 200, "their rings")
	for id in ids:
		var root := views.actor_node(id)
		assert_not_null(root, "its root holds its avatar")
		assert_false(root.is_inside_tree(), "outside the tree")
	# The hero's node, the crowds' and the batch's draw sets, the bar chunks: as many as with one Swarmer.
	var one := CombatLab.world()
	one.add_enemy(SW, Vector2(1.0, 1.0))
	var single := _views(one)
	single.batch.advance(DT)
	single.vat_crowd._process(DT)
	assert_eq(_nodes_under(views), _nodes_under(single), "no node per enemy")


func test_an_instance_sits_where_its_sim_place_says() -> void:
	var w := CombatLab.world()
	var id := w.add_enemy(SW, Vector2(3.5, -2.25))
	var views := _views(w)
	views.batch.advance(DT)
	views.vat_crowd._process(DT)
	var want := SimPlane.to_3d(Vector2(3.5, -2.25))
	var disc: Array[Transform3D] = views.batch.parts_of(id, EnemyBatch.Part.DISC)
	assert_eq(disc.size(), 1, "its disc")
	assert_almost_eq(disc[0].origin, want + Vector3(0, EnemyBatch.DISC_Y, 0), Vector3.ONE * 1e-5)
	var ring: Array[Transform3D] = views.batch.parts_of(id, EnemyBatch.Part.RING)
	assert_almost_eq(ring[0].origin, want + Vector3(0, EnemyBatch.RING_Y, 0), Vector3.ONE * 1e-5)
	assert_almost_eq(ring[0].basis.y.y, 1.0, 1e-6, "not scaled: the flattening is in its mesh")
	var torus := views.shared_parts.ring_mesh(w.actors.radius[w.actors.index_of(id)])
	var flat := EnemyBatch.flattened(torus, EnemyBatch.RING_FLAT)
	assert_almost_eq(
		flat.get_aabb().size.y,
		torus.get_aabb().size.y * EnemyBatch.RING_FLAT.y,
		1e-4,
		"flattened as the node was"
	)
	var body: Dictionary = views.vat_crowd.instance_of(
		views.actor_node(id).get_meta(&"enemy_avatar")
	)
	var at: Vector3 = (body["xf"] as Transform3D).origin
	assert_almost_eq(Vector2(at.x, at.z), Vector2(want.x, want.z), Vector2.ONE * 1e-4, "its body")
	# It moves: the next sync places it again.
	var i := w.actors.index_of(id)
	w.actors.pos_x[i] = 6.0
	views.sync(WorldReader.new(w))
	views.batch.set_interpolated(id, false)  # Drawn at the latest place (no fraction in a test)
	views.batch.advance(DT)
	disc = views.batch.parts_of(id, EnemyBatch.Part.DISC)
	assert_almost_eq(disc[0].origin.x, 6.0, 1e-5, "where the sim moved it")


func test_its_bar_shows_its_health() -> void:
	var fti := get_tree().physics_interpolation
	get_tree().physics_interpolation = false  # The bar at its latest fill (no frames run in a test)
	var w := CombatLab.world()
	var id := w.add_enemy(SN, Vector2(2.0, 2.0))
	var views := _views(w)
	_ripen(w)
	views.sync(WorldReader.new(w))
	views.batch.advance(DT)
	assert_true(views.batch.parts_of(id, EnemyBatch.Part.BAR).is_empty(), "none at full health")
	var i := w.actors.index_of(id)
	w.actors.hp[i] = w.actors.max_hp[i] / 2
	views.sync(WorldReader.new(w))
	views.bar_chunks.advance(DT)
	views.batch.advance(DT)
	var bar: Array[Transform3D] = views.batch.parts_of(id, EnemyBatch.Part.BAR)
	assert_eq(bar.size(), 1, "hurt: its bar shows")
	var trail := views.bar_chunks.trail_of(id)
	assert_not_null(trail, "its chunk trail")
	assert_almost_eq(bar[0].basis.x.x, maxf(trail.fill, 0.001), 1e-6, "shrunk to the trail's fill")
	assert_lt(bar[0].basis.x.x, 1.0, "less than full")
	var h: float = views.actor_node(id).get_meta(&"bar_y")
	assert_almost_eq(bar[0].origin.y, h, 1e-5, "over its head")
	assert_gt(views.bar_chunks.drawn(), 0, "the chunk shows beside it")
	get_tree().physics_interpolation = fti


func test_a_kill_removes_its_instances_the_same_frame() -> void:
	var w := CombatLab.world()
	var gone := w.add_enemy(SN, Vector2(2.0, 2.0))  # A code body: it goes at once
	var falls := w.add_enemy(SB, Vector2(-2.0, 2.0))  # The owner's model: it falls a moment
	var views := _views(w)
	_ripen(w)
	views.sync(WorldReader.new(w))
	var sniper: AvatarBase = views.actor_node(gone).get_meta(&"enemy_avatar")
	var shield: AvatarBase = views.actor_node(falls).get_meta(&"enemy_avatar")
	for id in [gone, falls]:
		var i := w.actors.index_of(id)
		var at := w.actors.pos(i)
		Damage.hit(w, i, 1 << 20, 0, 0, w.take_root(), 0, at, at)
	for t in 120:
		if w.actors.index_of(gone) < 0 and w.actors.index_of(falls) < 0:
			break
		w.step(InputFrame.new())
	views.sync(WorldReader.new(w))
	views.batch.advance(DT)
	views.vat_crowd._process(DT)
	assert_false(views.batch.has(gone), "its slot went")
	assert_true(views.batch.parts_of(gone, EnemyBatch.Part.DISC).is_empty(), "no disc")
	assert_true(views.vat_crowd.instance_of(sniper).is_empty(), "no body")
	assert_true(views.batch.has(falls), "the falling one stays a moment")
	assert_false(views.vat_crowd.instance_of(shield).is_empty(), "its body falls")
	assert_eq(views.batch.parts_of(falls, EnemyBatch.Part.DISC).size(), 1, "its disc stays")
	assert_true(views.batch.parts_of(falls, EnemyBatch.Part.BAR).is_empty(), "its bar goes")


func test_the_lookups_reach_the_right_enemy() -> void:
	var w := CombatLab.world()
	var a := w.add_enemy(SW, Vector2(1.0, 1.0))
	var b := w.add_enemy(CH, Vector2(-4.0, 3.0))
	var views := _views(w)
	assert_true(views.draws(a) and views.draws(b))
	assert_true(views.actor_node(a).get_meta(&"enemy_avatar") is HordeAvatar, "a's model")
	assert_true(views.actor_node(b).get_meta(&"enemy_avatar") is ChargerAvatar, "b's model")
	assert_almost_eq(
		views.actor_node(b).position, SimPlane.to_3d(Vector2(-4.0, 3.0)), Vector3.ONE * 1e-5
	)
	var anchor := views.anchor_node(b)
	assert_true(anchor.is_inside_tree(), "the anchor is in the tree")
	assert_almost_eq(anchor.position, SimPlane.to_3d(Vector2(-4.0, 3.0)), Vector3.ONE * 1e-5)
	assert_eq(views.anchor_node(b), anchor, "made once")
	assert_almost_eq(
		float(anchor.get_meta(&"bar_y")),
		float(views.actor_node(b).get_meta(&"bar_y")),
		1e-5,
		"status marks sit under its bar"
	)
	# The flash reaches the right instance, and only it.
	views.flash(b)
	views.batch.advance(DT)
	views.vat_crowd._process(DT)
	var lit: Color = (
		views.vat_crowd.instance_of(views.actor_node(b).get_meta(&"enemy_avatar"))["color"]
	)
	var rest: Color = (
		views.vat_crowd.instance_of(views.actor_node(a).get_meta(&"enemy_avatar"))["color"]
	)
	assert_lt(lit.a, 0.0, "b flashes")
	assert_gte(rest.a, 0.0, "a does not")


func test_the_batch_draws_what_a_view_of_nodes_draws() -> void:
	var w := CombatLab.world()
	var ids: Array[int] = []
	for k in 6:
		ids.append(w.add_enemy([SW, SN, SB, CH][k % 4], Vector2(-6.0 + k * 2.5, 1.5)))
	var batched := _views(w)
	var nodes := _views(w, false)
	assert_eq(nodes.batched_count(), 0, "the twin keeps its nodes")
	var fti := get_tree().physics_interpolation
	get_tree().physics_interpolation = false  # Both drawn at the latest tick (no frames run in a test)
	_ripen(w)
	for id in ids.slice(0, 3):
		var i := w.actors.index_of(id)
		w.actors.hp[i] = maxi(1, w.actors.max_hp[i] / 3)
	for v: ActorViews in [batched, nodes]:
		v.sync(WorldReader.new(w))
		v.bar_chunks.advance(DT)
	batched.batch.write_furniture()  # (no frame step: the nodes' avatars take none either)
	batched.vat_crowd._process(DT)
	nodes.vat_crowd._process(DT)
	for id in ids:
		var a: Dictionary = batched.vat_crowd.instance_of(
			batched.actor_node(id).get_meta(&"enemy_avatar")
		)
		var b: Dictionary = nodes.vat_crowd.instance_of(
			nodes.actor_node(id).get_meta(&"enemy_avatar")
		)
		assert_false(a.is_empty() or b.is_empty(), "both draw %d" % id)
		var xa: Transform3D = a["xf"]
		var xb: Transform3D = b["xf"]
		assert_almost_eq(xa.origin, xb.origin, Vector3.ONE * 1e-4, "the body's place, %d" % id)
		assert_true(xa.basis.is_equal_approx(xb.basis), "its turn and pose, %d" % id)
		assert_eq(a["color"], b["color"], "its colour, %d" % id)
		var node := nodes.actor_node(id)
		var bar_node := (node.get_meta(&"bar") as Node3D).get_child(0) as MeshInstance3D
		var bar: Array[Transform3D] = batched.batch.parts_of(id, EnemyBatch.Part.BAR)
		assert_eq(bar.size() == 1, bar_node.is_visible_in_tree(), "the bar shows alike, %d" % id)
		if bar.size() == 1:
			var g := bar_node.global_transform
			assert_almost_eq(
				bar[0].origin, g.origin, Vector3.ONE * 1e-4, "the bar's place, %d" % id
			)
			assert_almost_eq(bar[0].basis.x.x, g.basis.x.x, 1e-5, "the bar's fill, %d" % id)
		var disc: Array[Transform3D] = batched.batch.parts_of(id, EnemyBatch.Part.DISC)
		for c in node.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh:
				var g := (c as MeshInstance3D).global_transform
				assert_almost_eq(
					disc[0].origin, g.origin, Vector3.ONE * 1e-4, "the disc's place, %d" % id
				)
				var mine := batched.shared_parts.disc_mesh(w.actors.radius[w.actors.index_of(id)])
				assert_eq(
					((c as MeshInstance3D).mesh as CylinderMesh).top_radius,
					(mine as CylinderMesh).top_radius,
					"a disc of the same size"
				)
	get_tree().physics_interpolation = fti


func test_freeing_the_view_frees_the_roots_outside_the_tree() -> void:
	var w := CombatLab.world()
	var id := w.add_enemy(SW, Vector2(1.0, 1.0))
	var views := ActorViews.new()
	add_child(views)
	views.sync(WorldReader.new(w))
	var root := views.actor_node(id)
	assert_false(root.is_inside_tree(), "batched: outside the tree")
	views.free()
	assert_false(is_instance_valid(root), "gone with its view (no orphan left behind)")
