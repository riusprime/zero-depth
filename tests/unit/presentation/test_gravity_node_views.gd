extends GutTest
## The Gravity Node's tells of its pull on the hero, read from a real World (EI-07): the faint ring of its reach on the
## floor (StarfallViews' swirl) shows only while the hero is inside it, and the orb's core shows the draw
## (StarfallAvatar.draw_pose), stronger nearer, none outside.

var _tables: Array[EnemyTable] = []


func before_all() -> void:
	_tables = CombatLab.tables()


## A node at (0, 0), spawned in, and the hero `d` metres from it (held there: no drift between reads).
func _world(d: float) -> World:
	var w := World.new(3, PlayerTable.starting_values())
	w.set_enemy_tables(_tables)
	w.actors.invuln[0] = 1 << 24
	w.add_enemy(ActorStore.Kind.GRAVITY_NODE, Vector2.ZERO)
	for _t in w.tuning.spawn_in_ticks + 2:
		w.step(InputFrame.new())
	w.actors.set_pos(0, Vector2(d, 0))
	return w


func _views() -> StarfallViews:
	var v := StarfallViews.new()
	v.pack_fx = add_child_autofree(PackFx.new())
	add_child_autofree(v)
	return v


func _avatar() -> StarfallAvatar:
	var a := StarfallAvatar.new()
	a.setup(WorldReader.KIND_GRAVITY_NODE)
	add_child_autofree(a)
	return a


## Syncs and advances `a` for two seconds of frame time.
func _show(a: StarfallAvatar, reader: WorldReader) -> void:
	for _k in 40:
		a.sync(reader, 1)
		a.advance(0.05)


func test_the_ring_shows_only_while_the_hero_is_inside_its_reach() -> void:
	var w := _world(8.0)
	var v := _views()
	v.sync(WorldReader.new(w))
	assert_eq(v.swirl_count(), 0, "outside its reach: no ring")
	w.actors.set_pos(0, Vector2(3.0, 0))
	v.sync(WorldReader.new(w))
	assert_eq(v.swirl_count(), 1, "inside: one ring")
	v.sync(WorldReader.new(w))
	assert_eq(v.swirl_count(), 1, "held, not spawned again")
	w.actors.set_pos(0, Vector2(6.0, 0))
	v.sync(WorldReader.new(w))
	assert_eq(v.swirl_count(), 0, "walked out: the ring goes")


func test_the_ring_is_the_size_of_its_reach_on_the_hero() -> void:
	var w := _world(3.0)
	var v := _views()
	v.sync(WorldReader.new(w))
	var ring := v._swirls.values()[0] as Node3D
	assert_not_null(ring)
	var reach := WorldReader.new(w).gravity_hero_reach(1)
	assert_eq(reach, 5.0)
	assert_almost_eq(ring.scale.x, reach * StarfallViews.RING_PER_M, 0.001, "its 5 m reach")


func test_a_dead_node_shows_no_ring() -> void:
	var w := _world(3.0)
	var v := _views()
	v.sync(WorldReader.new(w))
	Damage.hit(w, 1, 99999, 1, 1, 1, 0, w.actors.pos(1), w.actors.pos(1))
	w.step(InputFrame.new())
	v.sync(WorldReader.new(w))
	assert_eq(v.swirl_count(), 0, "dead: no ring")


func test_the_core_shows_the_draw_stronger_nearer() -> void:
	var far := _avatar()
	_show(far, WorldReader.new(_world(8.0)))
	assert_eq(far.draw_pose(), 0.0, "outside: at rest")
	var mid := _avatar()
	_show(mid, WorldReader.new(_world(3.5)))
	var near := _avatar()
	_show(near, WorldReader.new(_world(1.5)))
	assert_gt(mid.draw_pose(), 0.0, "inside: it draws")
	assert_gt(near.draw_pose(), mid.draw_pose(), "stronger nearer")
	assert_lt(near._core.scale.x, 1.0 + 0.0001, "the core sinks into itself")
