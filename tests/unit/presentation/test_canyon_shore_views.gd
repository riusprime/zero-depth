extends GutTest
## v0.11.0 O13c (ENEMIES.md R5-R8): the signature enemies' stand-in bodies (CanyonShoreBodies on HordeAvatar) and what
## they leave on the floor (CanyonShoreViews), read from a real World: the Glacier Turtle's shell goes when it breaks;
## the bursts, vents, arcs and chunks are drawn while the sim has them. (v0.11.0 O17d: the Cinder Priest has its own
## avatar: test_cinder_priest_avatar.gd; O17e: the Kiln Beetle too, test_kiln_beetle_avatar.gd.)

const KINDS: Array[int] = [
	WorldReader.KIND_FROST_SPITTER,
	WorldReader.KIND_GLACIER_TURTLE,
]

var _tables: Array[EnemyTable] = []


func before_all() -> void:
	_tables = CombatLab.tables()


func _world() -> World:
	var w := World.new(3, PlayerTable.starting_values())
	w.set_enemy_tables(_tables)
	w.actors.invuln[0] = 1 << 24
	return w


## Steps `w` past the spawn-in (the bodies risen, the enemies hittable).
func _risen(w: World) -> void:
	for _t in SimTick.SPAWN_IN_TICKS + 2:
		w.step(InputFrame.new())


## Syncs and advances `a` for a second of frame time.
func _show(a: HordeAvatar, reader: WorldReader) -> void:
	for _k in 20:
		a.sync(reader, 1)
		a.advance(0.05)


func _avatar(kind: int) -> HordeAvatar:
	var a := HordeAvatar.new()
	a.setup(kind)
	add_child_autofree(a)
	return a


func test_each_signature_has_a_body_of_its_own() -> void:
	var sizes := {}
	for kind in KINDS:
		assert_true(HordeAvatar.is_horde_kind(kind), "kind %d is drawn as a horde body" % kind)
		assert_false(VatCrowd.supports(kind), "kind %d is no VAT crowd body (yet)" % kind)
		var a := _avatar(kind)
		assert_gt(a.body.get_child_count(), 6, "kind %d has its pieces" % kind)
		var key := "%d" % a.body.get_child_count()
		sizes[key] = int(sizes.get(key, 0)) + 1
		assert_eq(HordeAvatar.height_of(kind), float(CanyonShoreBodies.HEIGHTS[kind]))
	assert_eq(sizes.size(), KINDS.size(), "the bodies differ")


func test_the_turtles_shell_goes_when_it_breaks() -> void:
	var w := _world()
	w.add_enemy(ActorStore.Kind.GLACIER_TURTLE, Vector2(3, 0))
	_risen(w)
	w.actors.facing[1] = Kin.angle_of(Vector2(-1, 0))
	var reader := WorldReader.new(w)
	var a := _avatar(WorldReader.KIND_GLACIER_TURTLE)
	_show(a, reader)
	assert_true((a.parts["shell"] as Node3D).visible, "its shell stands")
	var t := w.enemy_table(ActorStore.Kind.GLACIER_TURTLE)
	var at := w.actors.pos(1)
	Damage.hit(w, 1, t.shell_hp, 1, 1, 1, 0, at + Vector2(-1, 0), at)
	_show(a, reader)
	assert_false((a.parts["shell"] as Node3D).visible, "broken, it is gone")


func test_the_views_draw_what_the_sim_has() -> void:
	var w := _world()
	var s := w.canyon_shore
	s.add_burst(Vector2(2, 0), 2.5, 0, 60, 10, 10)
	var priest := w.add_enemy(ActorStore.Kind.CINDER_PRIEST, Vector2(-3, 0))
	s.add_vent(Vector2(-2, 0), 1.0, priest, 180, 180, 45, 10)
	s.add_blob(Vector2(0, 4), Vector2(0, 1), 1.0, 0, 45, 999, 360, 40)
	s.add_chunk(Vector2(4, 4), Vector2(0.1, 0), 0, 70, 30, 999)
	var v := CanyonShoreViews.new()
	add_child_autofree(v)
	v.sync(WorldReader.new(w))
	assert_eq(v.counts(), {"bursts": 1, "vents": 1, "arcs": 1, "chunks": 1})
	assert_eq(WorldReader.new(w).lava_vents()[0][2], 0, "no pulse at rest")
	for _t in 140:
		w.step(InputFrame.new())
	assert_gt(WorldReader.new(w).lava_vents()[0][2], 0, "the pulse runs before the eruption")
	v.sync(WorldReader.new(w))
	assert_eq(v.counts()["bursts"], 0, "the burst blew")
	assert_eq(v.counts()["arcs"], 0, "the blob landed")


## Counts the pack spawns instead of playing them.
class SpawnLog:
	extends PackFx
	var log: Array = []

	func spawn(
		effect_id: StringName,
		pos: Vector3,
		scale := 1.0,
		_colors := {},
		_life := -1.0,
		_speed := 1.0,
		_hide: Array = []
	) -> Node3D:
		log.append([effect_id, pos, scale])
		return null


## v0.11.0 F1 (owner: the explosion "sometimes plays two or three times"): the bursts go FIFO, which used to shift the
## later ones' array index (their seed), so the view thought they had blown. Three born on different ticks: three
## blasts in all, each once, where its burst stood, at BLAST_SCALE.
func test_each_burst_blows_once_when_earlier_ones_go_first() -> void:
	var w := _world()
	var v := CanyonShoreViews.new()
	var fx := SpawnLog.new()
	v.pack_fx = fx
	add_child_autofree(v)
	add_child_autofree(fx)
	var born := [0, 10, 20]
	var at := [Vector2(2, 0), Vector2(-3, 1), Vector2(0, 4)]
	for t in 120:
		for k in 3:
			if born[k] == t:
				w.canyon_shore.add_burst(at[k], 2.5, w.tick, w.tick + 60, 10, 10)
		w.step(InputFrame.new())
		v.sync(WorldReader.new(w))
	assert_eq(fx.log.size(), 3, "one blast per burst, no repeats")
	for k in 3:
		assert_eq(fx.log[k][1], SimPlane.to_3d(at[k], 0.0), "burst %d blew where it stood" % k)
		assert_eq(fx.log[k][2], CanyonShoreViews.BLAST_SCALE, "and small")
	assert_eq(WorldReader.new(w).kiln_bursts().size(), 0)


## Two born on one tick keep distinct seeds, and a seed does not move when an earlier burst is removed.
func test_a_burst_seed_is_stable_for_its_whole_life() -> void:
	var w := _world()
	w.canyon_shore.add_burst(Vector2(1, 0), 2.5, 5, 65, 1, 1)
	w.canyon_shore.add_burst(Vector2(2, 0), 2.5, 5, 65, 1, 1)
	w.canyon_shore.add_burst(Vector2(3, 0), 2.5, 9, 69, 1, 1)
	var before := WorldReader.new(w).kiln_bursts()
	w.canyon_shore.remove(&"burst", PackedInt32Array([0, 1]))
	var after := WorldReader.new(w).kiln_bursts()
	assert_ne(before[0][3], before[1][3])
	assert_eq(after[0][3], before[2][3], "the survivor keeps its seed")


## The pack's explosion scene has an animation, so PackFx leaves its particles looping; the blast plays them once.
func test_the_blast_particles_play_once() -> void:
	var fx := PackFx.new()
	add_child_autofree(fx)
	var node := fx.spawn(CanyonShoreViews.BLAST_ID, Vector3.ZERO, CanyonShoreViews.BLAST_SCALE)
	assert_not_null(node, "the pack has the blast")
	CanyonShoreViews.blast_once(node)
	var n := 0
	for c in node.get_children():
		if c is GPUParticles3D:
			n += 1
			assert_true((c as GPUParticles3D).one_shot, "%s plays once" % c.name)
	assert_gt(n, 0)
