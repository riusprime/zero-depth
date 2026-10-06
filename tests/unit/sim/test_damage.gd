extends GutTest
## The damage pipeline (PLAN v0.1.0 Step 1): HIT -> DAMAGE -> one KILL, invulnerability, provenance.


func _world() -> World:
	var w := World.new(7, PlayerTable.starting_values())
	w.add_dummy(Vector2(5, 0), 0.35, 10)
	return w


func _kinds(w: World) -> Array:
	return w.events_since(0).map(func(e: SimEvent) -> int: return e.kind)


func test_lethal_hits_kill_once_and_hp_stops_at_zero() -> void:
	var w := _world()
	var applied := Damage.hit(w, 1, 25, 99, 1, 99, 0, Vector2.ZERO, Vector2(5, 0))
	assert_eq(applied, 10, "only the HP that was there")
	assert_eq(w.actors.hp[1], 0)
	assert_eq(
		Damage.hit(w, 1, 25, 99, 1, 99, 0, Vector2.ZERO, Vector2(5, 0)), 0, "dead takes nothing"
	)
	assert_eq(_kinds(w).count(SimEvent.Kind.KILL), 1, "exactly one KILL")
	w.step(InputFrame.new())
	assert_eq(w.actors.size(), 1, "the dead enemy leaves in phase 9")


func test_provenance_chain() -> void:
	var w := _world()
	Damage.hit(w, 1, 25, 99, 1, 77, SimEvent.TAG_MELEE, Vector2.ZERO, Vector2(5, 0))
	var ev := w.events_since(1)  # after the dummy's SPAWN
	assert_eq(ev.size(), 3)
	assert_eq(
		[ev[0].kind, ev[1].kind, ev[2].kind],
		[SimEvent.Kind.HIT, SimEvent.Kind.DAMAGE, SimEvent.Kind.KILL]
	)
	assert_eq(ev[1].parent_seq, ev[0].seq)
	assert_eq(ev[2].parent_seq, ev[1].seq)
	assert_eq([ev[0].depth, ev[1].depth, ev[2].depth], [0, 1, 2])
	for e in ev:
		assert_eq(e.root_id, 77)
	assert_eq(ev[1].amount, 25)
	assert_eq(ev[1].amount_applied, 10)


func test_player_is_invulnerable_after_a_hit_and_frozen() -> void:
	var w := _world()
	assert_eq(Damage.hit(w, 0, 10, 5, 2, 5, 0, Vector2(5, 0), Vector2.ZERO), 10)
	assert_eq(w.freeze_ticks, w.player.hurt_freeze_ticks, "hit-stop on taking a hit")
	assert_eq(
		Damage.hit(w, 0, 10, 6, 2, 6, 0, Vector2(5, 0), Vector2.ZERO), 0, "still invulnerable"
	)
	for i in w.player.hurt_freeze_ticks + w.player.hurt_iframe_ticks:
		w.step(InputFrame.new())
	assert_eq(
		Damage.hit(w, 0, 10, 7, 2, 7, 0, Vector2(5, 0), Vector2.ZERO), 10, "invulnerability ran out"
	)


func test_dash_is_invulnerable() -> void:
	var w := _world()
	w.step(InputFrame.make(Vector2i(127, 0), 0, 500, 0, InputFrame.DASH))
	assert_true(w.is_dashing())
	assert_eq(Damage.hit(w, 0, 10, 5, 2, 5, 0, Vector2(5, 0), Vector2.ZERO), 0)
	assert_eq(w.actors.hp[0], 100)


func test_a_dead_player_ignores_input() -> void:
	var w := _world()
	Damage.hit(w, 0, 500, 5, 2, 5, 0, Vector2(5, 0), Vector2.ZERO)
	assert_true(w.player_dead())
	var before := w.player_pos()
	for i in 10:
		w.step(InputFrame.make(Vector2i(127, 0), 0, 500, 0, 0))
	assert_eq(w.player_pos(), before)
	assert_eq(w.actors.size(), 2, "the player is never removed")


func test_projectiles_deal_their_damage() -> void:
	var w := World.new(7, PlayerTable.starting_values())
	var id := w.add_dummy(Vector2(3, 0), 0.35, 30)
	w.queue_projectile(
		1,
		ActorStore.TEAM_PLAYER,
		Vector2(1, 0),
		Vector2(0.3, 0),
		12,
		0.1,
		60,
		SimEvent.TAG_PROJECTILE
	)
	for i in 20:
		w.step(InputFrame.new())
	assert_eq(w.actors.hp[w.actors.index_of(id)], 18)
