extends GutTest
## v0.10.5 W3-P10e (owner W7: "Starfall ... evolves into a every 5 attack a meteor falls from the sky into the
## enemies"; Q5 "fire lv3 ok"): every 5th crit drops a star for 100 % on the nearest other enemy (no crit, no count);
## with Fire at Lv 3 the star is replaced by a meteor on every 5th root attack (densest group within 8 m, 24 ticks
## later, 300 % in 2.5 m, burning). Deterministic and hashed.

const W := preload("res://tests/support/mx4_world.gd")
const BIG := 9000000


func _world(
	build: StringName, items: Array, enemies: Array, fire_lv: int = 1, held := true
) -> World:
	var w := W.world(build, items, enemies)
	if held:
		w.constellations = PackedInt32Array([Constellations.STARFALL])
	for id: StringName in items:
		CardLevels.set_level(w, W.item(w, id), fire_lv)
	return w


## Hits enemy `i` until one crits (the chance caps below 100 %); returns the HP that crit removed. With Meteor on the
## crits do not count, so the first hit is the one.
func _crit_hit(w: World, i: int) -> int:
	var a := w.actors
	for k in 200:
		var counted := w.starfall_crits
		var seen := w.events_since(0).size()
		var before: int = a.hp[i]
		Damage.hit(
			w,
			i,
			100,
			a.ids[0],
			a.ids[0],
			w.take_root(),
			SimEvent.TAG_PROJECTILE,
			a.pos(0),
			a.pos(i)
		)
		var crit := false
		for e in w.events_since(0).slice(seen):
			crit = crit or (e.kind == SimEvent.Kind.HIT and e.tags & SimEvent.TAG_CRIT != 0)
		if crit or not Starfall.held(w) or Starfall.meteor_on(w):
			return before - a.hp[i]
		assert_eq(w.starfall_crits, counted, "a hit that did not crit does not count")
	return 0


func _ids(w: World) -> Array:
	return [w.actors.ids[1], w.actors.ids[2], w.actors.ids[3]]


func test_the_fifth_crit_strikes_the_nearest_other_enemy_for_the_crit() -> void:
	var w := _world(&"gun", [], [[Vector2(3, 0), BIG], [Vector2(6, 0), BIG], [Vector2(3, 2), BIG]])
	w.player.crit_chance_permille = 1000
	var a := w.actors
	var dealt := 0
	for k in 4:
		dealt = _crit_hit(w, 1)
	assert_eq(W.events(w, SimEvent.Kind.STAR).size(), 0, "no star before the fifth crit")
	assert_eq(a.hp[2], BIG)
	assert_eq(a.hp[3], BIG)
	dealt = _crit_hit(w, 1)
	var stars := W.events(w, SimEvent.Kind.STAR)
	assert_eq(stars.size(), 1, "the fifth crit calls one star")
	assert_eq(stars[0].target_id, a.ids[3], "the nearest other enemy (2 m), not the crit's target")
	assert_eq(BIG - a.hp[3], dealt, "for 100 % of what the crit dealt")
	assert_eq(a.hp[2], BIG, "the farther one is untouched")
	assert_eq(w.starfall_crits, 5, "the star did not count (and did not crit)")
	for e in W.events(w, SimEvent.Kind.HIT):
		if e.effect_id == SimEvent.EFFECT_STAR:
			assert_eq(e.tags & SimEvent.TAG_CRIT, 0, "the star never crits")
	for k in 4:
		_crit_hit(w, 1)
	assert_eq(W.events(w, SimEvent.Kind.STAR).size(), 1, "four more crits: still one")
	_crit_hit(w, 1)
	assert_eq(W.events(w, SimEvent.Kind.STAR).size(), 2, "the tenth crit calls the next")


func test_a_tie_takes_the_lowest_index_and_no_other_enemy_does_nothing() -> void:
	var w := _world(&"gun", [], [[Vector2(0, 5), BIG], [Vector2(2, 5), BIG], [Vector2(-2, 5), BIG]])
	w.player.crit_chance_permille = 1000
	for k in 5:
		_crit_hit(w, 1)
	assert_eq(
		W.events(w, SimEvent.Kind.STAR)[0].target_id, w.actors.ids[2], "a tie: the lowest index"
	)
	var solo := _world(&"gun", [], [[Vector2(3, 0), BIG]])
	solo.player.crit_chance_permille = 1000
	for k in 10:
		_crit_hit(solo, 1)
	assert_eq(W.events(solo, SimEvent.Kind.STAR).size(), 0, "no other enemy: nothing")


func test_without_starfall_nothing_counts() -> void:
	var w := _world(&"gun", [], [[Vector2(3, 0), BIG], [Vector2(6, 0), BIG]], 1, false)
	w.player.crit_chance_permille = 1000
	for k in 10:
		_crit_hit(w, 1)
	assert_eq(w.starfall_crits, 0)
	assert_eq(W.events(w, SimEvent.Kind.STAR).size(), 0)
	assert_eq(w.actors.hp[2], BIG)


func test_meteor_needs_fire_at_level_3() -> void:
	for lv in [1, 2]:
		var w := _world(&"gun", [&"ember_core"], [[Vector2(4, 0), BIG]], lv)
		assert_false(Starfall.meteor_on(w), "Fire Lv %d: Starfall's star" % lv)
		for k in 10:
			Starfall.on_root_attack(w, 100)
		assert_eq(w.meteor_attacks, 0)
	var w3 := _world(&"gun", [&"ember_core"], [[Vector2(4, 0), BIG]], 3)
	assert_true(Starfall.meteor_on(w3), "Fire Lv 3: Meteor")
	var nofire := _world(&"gun", [], [[Vector2(4, 0), BIG]], 3)
	assert_false(Starfall.meteor_on(nofire), "no Fire: no Meteor")
	var nostar := _world(&"gun", [&"ember_core"], [[Vector2(4, 0), BIG]], 3, false)
	assert_false(Starfall.meteor_on(nostar), "no Starfall: no Meteor")
	# Meteor replaces the star: crits no longer count
	w3.player.crit_chance_permille = 1000
	for k in 10:
		_crit_hit(w3, 1)
	assert_eq(w3.starfall_crits, 0)


func _meteor_world() -> World:
	# 1: a lone enemy near; 2, 3, 4: a group of three (5.0..6.0, 5) at about 7.1 to 7.8 m; 5: out of range
	return _world(
		&"gun",
		[&"ember_core"],
		[
			[Vector2(4, 0), BIG],
			[Vector2(5, 5), BIG],
			[Vector2(5.5, 5), BIG],
			[Vector2(6, 5), BIG],
			[Vector2(12, 0), BIG],
		],
		3
	)


func test_the_fifth_attack_calls_a_meteor_on_the_densest_group() -> void:
	var w := _meteor_world()
	var a := w.actors
	W.run(w, 1)  # the enemy grid fills on a step
	for k in 4:
		Starfall.on_root_attack(w, 100)
	assert_eq(w.meteors.size(), 0, "none before the fifth attack")
	Starfall.on_root_attack(w, 100)
	assert_eq(w.meteors.size(), Starfall.METEOR_FIELDS, "the fifth calls one")
	assert_eq(
		w.meteors[2], int(round(a.pos(2).x * 1000.0)), "on the densest group's lowest index (x mm)"
	)
	assert_eq(w.meteors[3], int(round(a.pos(2).y * 1000.0)), "(y mm)")
	var launch := W.events(w, SimEvent.Kind.METEOR_LAUNCH)
	assert_eq(launch.size(), 1)
	assert_eq(launch[0].amount, 24)
	var t0 := w.tick
	for k in 23:
		w.step(W.frame())
	assert_eq(a.hp[2], BIG, "nothing before the 24th tick")
	assert_eq(W.events(w, SimEvent.Kind.METEOR_LAND).size(), 0)
	for k in 3:
		w.step(W.frame())
	assert_eq(
		W.events(w, SimEvent.Kind.METEOR_LAND).size(), 1, "it lands (tick %d to %d)" % [t0, w.tick]
	)
	assert_eq(w.meteors.size(), 0)
	for i in [2, 3, 4]:
		assert_eq(BIG - a.hp[i], 300, "3x the base hit on enemy %d" % i)
		assert_gt(a.burn_stacks[i], 0, "burning")
	assert_eq(a.hp[1], BIG, "the lone enemy is outside 2.5 m")
	assert_eq(a.hp[5], BIG)


func test_a_shooting_gun_launches_a_meteor_every_fifth_shot() -> void:
	var w := _meteor_world()
	W.run(w, 400, 0, W.S, 0)
	assert_gt(w.meteor_attacks, 5, "shots counted: %d" % w.meteor_attacks)
	assert_eq(
		W.events(w, SimEvent.Kind.METEOR_LAUNCH).size(), w.meteor_attacks / 5, "one per five shots"
	)


func test_a_swinging_blade_counts_its_swings() -> void:
	var w := _world(&"blade", [&"ember_core"], [[Vector2(1.5, 0), BIG]], 3)
	for k in 6:
		W.run(w, 40, W.P, 0, 0)
	assert_gt(w.meteor_attacks, 0, "swings counted")


func test_deterministic_and_hashed() -> void:
	var a := _meteor_world()
	var b := _meteor_world()
	a.player.crit_chance_permille = 500
	b.player.crit_chance_permille = 500
	W.run(a, 300, 0, W.S, 0)
	W.run(b, 300, 0, W.S, 0)
	assert_gt(a.meteor_attacks, 0)
	assert_eq(a.state_hash(), b.state_hash(), "same seed, same hash")
	var plain := _world(&"gun", [&"ember_core"], [[Vector2(4, 0), BIG]], 3, false)
	var before := plain.state_hash()
	plain.meteor_attacks = 1
	assert_ne(plain.state_hash(), before, "the counter is hashed once non-zero")
	plain.meteor_attacks = 0
	assert_eq(plain.state_hash(), before, "and not before")
	plain.meteors = PackedInt32Array([10, 100, 1000, 1000])
	assert_ne(plain.state_hash(), before, "a pending meteor is hashed")


## v0.10.5 W3-P10k: the star is sized from the crit before its target's own multipliers (Hunter's Sky on an elite),
## and the star's target applies its own once.
func test_the_star_carries_no_bonus_of_the_crit_target_and_applies_its_own() -> void:
	for elite_first in [true, false]:
		var w := _world(
			&"gun", [], [[Vector2(3, 0), BIG], [Vector2(6, 0), BIG], [Vector2(3, 2), BIG]]
		)
		w.constellations.append(Constellations.HUNTERS_SKY)
		w.player.crit_chance_permille = 1000
		var a := w.actors
		a.kinds[1 if elite_first else 3] = ActorStore.Kind.BREAKER
		var dealt := 0
		for k in 5:
			dealt = _crit_hit(w, 1)
		var star := BIG - a.hp[3]
		assert_eq(W.events(w, SimEvent.Kind.STAR).size(), 1)
		if elite_first:
			assert_eq(
				Constellations.scale(star, 1500), dealt, "the elite's x 1.5 stays on the elite"
			)
			assert_lt(star, dealt)
		else:
			assert_eq(star, Constellations.scale(dealt, 1500), "the elite star target: x 1.5 once")
