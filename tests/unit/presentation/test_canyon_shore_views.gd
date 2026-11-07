extends GutTest
## v0.11.0 O13c (ENEMIES.md R5-R8): the signature enemies' stand-in bodies (CanyonShoreBodies on HordeAvatar) and what
## they leave on the floor (CanyonShoreViews), read from a real World: the Kiln Beetle glows brighter as its HP drops,
## the Cinder Priest's staff rises with its vent's pulse, the Glacier Turtle's shell goes when it breaks; the bursts,
## vents, arcs and chunks are drawn while the sim has them.

const KINDS: Array[int] = [
	WorldReader.KIND_KILN_BEETLE,
	WorldReader.KIND_CINDER_PRIEST,
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
	a.setup(kind, Color.BLACK)
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
	assert_gt(sizes.size(), 2, "the bodies differ")


func test_the_beetle_glows_brighter_as_its_hp_drops() -> void:
	var w := _world()
	w.add_enemy(ActorStore.Kind.KILN_BEETLE, Vector2(4, 0))
	_risen(w)
	var reader := WorldReader.new(w)
	var a := _avatar(WorldReader.KIND_KILN_BEETLE)
	ViewPrefs.reduced_motion = true
	_show(a, reader)
	var full := a.glow_energy()
	w.actors.hp[1] = w.actors.max_hp[1] / 5
	_show(a, reader)
	ViewPrefs.reduced_motion = false
	assert_gt(a.glow_energy(), full + 2.0, "hotter at a fifth of its HP")


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
