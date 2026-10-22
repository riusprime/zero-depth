extends GutTest
## v0.7.5 EF (owner N16): the Arc Caster's plasma balls, the Lens Drone's orbs and the Bomb Drone's cinders are drawn
## by FireballViews in their own looks (never as ActorViews' plain shots), the Bomb Drone's fireball is drawn in the
## air while it flies, and none of the three draws anything on the ground (TelegraphViews); since v0.8.0 TG the
## Needle doesn't either.

const S := EnemyAi.State
const K := ActorStore.Kind


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _world(kind: int, at: Vector2) -> Array:
	var w := CombatLab.world()
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	var id := w.add_enemy(kind, at)
	return [w, id]


func _views() -> Array:
	var fb := FireballViews.new()
	add_child_autofree(fb)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var tv := TelegraphViews.new()
	add_child_autofree(tv)
	return [fb, actors, tv]


func test_each_enemys_fireballs_draw_in_its_own_look_and_nothing_on_the_ground() -> void:
	for spec in [
		[K.ARC_CASTER, Vector2(8, 0), "arc_plasma"],
		[K.LENS_DRONE, Vector2(7, 0), "lens_orb"],
		[K.BOMB_DRONE, Vector2(7, 0), "bomb_cinder"],
	]:
		var s := _world(spec[0], spec[1])
		var w: World = s[0]
		var v := _views()
		var fb: FireballViews = v[0]
		var actors: ActorViews = v[1]
		var tv: TelegraphViews = v[2]
		var reader := WorldReader.new(w)
		var seen := 0
		for k in 900:
			w.step(InputFrame.new())
			w.actors.hp[0] = w.actors.max_hp[0]
			var e := w.actors.index_of(s[1])
			if e >= 0 and spec[0] == K.BOMB_DRONE and w.actors.state[e] == S.ACTIVE:
				# out of the landing after the lock, so its X of cinders bursts
				w.actors.set_pos(0, Vector2(w.actors.lock_x[e], w.actors.lock_y[e] + 2.5))
			fb.sync(reader)
			actors.sync(reader)
			tv.sync(reader)
			assert_eq(tv.count(), 0, "kind %d draws nothing on the ground" % spec[0])
			var mine := 0
			for j in reader.projectile_count():
				if reader.projectile_look(j) == spec[2]:
					mine += 1
					assert_null(actors.projectile_node(reader.projectile_id(j)), "not a plain shot")
			assert_eq(fb.ball_count(spec[2]) - fb.lob_count(), mine, "in its look")
			seen = maxi(seen, mine)
		assert_gt(seen, 0, "%s flew" % spec[2])


func test_the_bomb_drones_fireball_is_drawn_in_the_air_while_it_flies() -> void:
	var s := _world(K.BOMB_DRONE, Vector2(7, 0))
	var w: World = s[0]
	var id: int = s[1]
	var fb: FireballViews = _views()[0]
	var reader := WorldReader.new(w)
	var flying := 0
	for k in 600:
		w.step(InputFrame.new())
		w.actors.hp[0] = w.actors.max_hp[0]
		fb.sync(reader)
		var i := w.actors.index_of(id)
		var lob: bool = EnemyAi.telegraph(w, i).get("shape", &"") == &"lob"
		assert_eq(fb.lob_count(), 1 if lob else 0)
		if lob:
			flying += 1
			assert_gte(fb.ball_count(&"bomb_cinder"), 1, "drawn as a ball of its look")
	assert_gt(flying, 30, "seen in the air for its flight")


## v0.8.0 TG (owner O4, Q3): the Needle's lines are gone from the ground too; it still telegraphs (its body tells it).
func test_the_needle_draws_no_lines_on_the_ground() -> void:
	var s := _world(K.NEEDLE, Vector2(8, 0))
	var w: World = s[0]
	var tv: TelegraphViews = _views()[2]
	var reader := WorldReader.new(w)
	var told := false
	for k in 300:
		w.step(InputFrame.new())
		tv.sync(reader)
		assert_eq(tv.count(), 0, "no trajectory lines on the ground")
		var i := w.actors.index_of(s[1])
		told = told or EnemyAi.telegraph(w, i).get("shape", &"") == &"lanes"
	assert_true(told, "the turret still telegraphs its burst")


func test_the_enemy_looks_differ_from_each_other_and_the_bosses() -> void:
	var mine := [&"arc_plasma", &"lens_orb", &"bomb_cinder"]
	for key: StringName in mine:
		assert_true(FireballViews.LOOKS.has(key), "%s has its own look" % key)
		for other: StringName in FireballViews.LOOKS:
			if other == key:
				continue
			var a: Dictionary = FireballViews.LOOKS[key]
			var b: Dictionary = FireballViews.LOOKS[other]
			var d := _dist(a["core"], b["core"]) + _dist(a["trail"], b["trail"])
			assert_gt(d, 0.3, "%s and %s read apart" % [key, other])
