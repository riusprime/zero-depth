extends GutTest
## Shard drops on the floor are instances of shapes built before the fight: a drop that lands builds no node and
## no shape, its instance sits at its sim place with its turn, and a taken one is pulled into the hero and gone.
## A headless run keeps no multimesh instance data, so the transforms are read from drawn_transform() (what the
## view writes) and the batches' drawn counts show the instances are there.


func _view() -> ShardViews:
	var s := ShardViews.new()
	add_child_autofree(s)
	s.prepare()
	return s


static func _nodes(n: Node) -> int:
	var count := 1
	for c in n.get_children(true):
		count += _nodes(c)
	return count


## Whether drop `seq`'s crystal, outline and glow instances are among the ones its batches draw.
static func _drawn(s: ShardViews, seq: int) -> bool:
	var at := s.drop_instance(seq)
	if at.is_empty():
		return false
	var slot: int = at[1]
	var g: int = at[4]
	return (
		(at[0] as MultiMesh).visible_instance_count > slot
		and (at[2] as MultiMesh).visible_instance_count > slot
		and (at[3] as MultiMesh).visible_instance_count > g
	)


func test_forty_drops_landing_in_one_frame_add_no_node_and_build_no_shape() -> void:
	var w := CombatLab.world()
	var r := WorldReader.new(w)
	var s := _view()
	s.sync(r)
	var nodes := _nodes(s)
	var built := ShardViews.shapes_built()
	assert_eq(built, ShardViews.DROP_SIZES * ShardViews.DROP_SHAPES, "every shape built before")
	for k in 40:  # More than the floor keeps: the cap merges the rest
		ShardDrops.drop(w, Vector2(-9 + (k % 8) * 2.5, -6 + (k / 8) * 2.5), 1 + (k % 3) * 4)
	s.sync(r)
	assert_eq(s.drop_count(), ShardDrops.MAX_ON_FLOOR, "the floor's drops lie there")
	assert_eq(_nodes(s), nodes, "no node added")
	assert_eq(ShardViews.shapes_built(), built, "no shape built")
	for seq: int in r.shard_drop_seqs():
		assert_true(_drawn(s, seq), "drop %d drawn" % seq)
	for k in 60:
		s._process(1.0 / 60.0)
	assert_eq(ShardViews.shapes_built(), built, "nor while they turn")
	assert_eq(_nodes(s), nodes)


func test_a_drop_instance_sits_at_its_sim_place_with_its_turn() -> void:
	var w := CombatLab.world()
	var r := WorldReader.new(w)
	var s := _view()
	s.sync(r)
	ShardDrops.drop(w, Vector2(5, -3), 8)
	s.sync(r)
	var seq: int = r.shard_drop_seqs()[0]
	var at := SimPlane.to_3d(r.shard_drops()[0])
	var inst := s.drop_instance(seq)
	assert_true(_drawn(s, seq))
	var xf := s.drawn_transform(inst[4])
	assert_eq(xf.origin, at, "at its place in the sim")
	assert_eq(xf.basis, Basis.from_euler(Vector3(0, float(seq % 7), 0)), "turned by its number")
	assert_eq(
		(inst[0] as MultiMesh).mesh, ShardViews.drop_meshes(4, seq)[0], "a four-gem shape's crystal"
	)
	assert_eq((inst[2] as MultiMesh).mesh, ShardViews.drop_meshes(4, seq)[1], "and its outline")
	for k in 30:
		s._process(1.0 / 60.0)
	var turned := s.drawn_transform(inst[4])
	assert_eq(turned.origin, at, "it stays")
	var turn := float(seq % 7)
	for k in 30:
		turn = _f32(turn + 1.0 / 60.0 * ShardViews.DROP_SPIN)
	assert_eq(turned.basis, Basis.from_euler(Vector3(0, turn, 0)), "and turns slowly")


func test_a_taken_drop_is_pulled_into_the_hero_and_its_instance_goes() -> void:
	var w := CombatLab.world()
	var r := WorldReader.new(w)
	var s := _view()
	s.sync(r)
	ShardDrops.drop(w, Vector2(4, 0), 4)
	s.sync(r)
	var seq: int = r.shard_drop_seqs()[0]
	var g: int = s.drop_instance(seq)[4]
	var from := s.drawn_transform(g).origin
	w.actors.set_pos(0, Vector2(4.5, 0.5))
	w.step(InputFrame.new())
	s.sync(r)
	assert_eq(s.drop_count(), 0)
	assert_eq(s.pulled_count(), 1, "taken: pulled into the hero")
	var target := SimPlane.to_3d(r.player_pos()) + Vector3(0, ShardViews.HEIGHT, 0)
	for k in 5:
		s._process(1.0 / 60.0)
	var mid := s.drawn_transform(g)
	var t := 5.0 / 60.0 / ShardViews.PULL_S
	assert_almost_eq(mid.origin, from.lerp(target, t * t), Vector3.ONE * 1e-4, "on its way in")
	assert_almost_eq(mid.basis.get_scale().x, 1.0 - 0.6 * t, 1e-4, "shrinking")
	var shown := 0
	for b in s.drop_batches():
		shown += int(b.visible)
	assert_eq(shown, 3, "still drawn: its crystals, outline and glow")
	for k in 5:
		s._process(1.0 / 60.0)
	assert_eq(s.pulled_count(), 0, "gone after PULL_S")
	for b in s.drop_batches():
		assert_eq(b.multimesh.visible_instance_count, 0, "nothing drawn")
		assert_false(b.visible)


static func _f32(x: float) -> float:
	var a := PackedFloat32Array([x])
	return a[0]
