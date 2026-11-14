extends GutTest
## v0.10.5 O10 (owner P3 "yes"; docs/roadmap/v0.10.5/O10_STRESS_MATRIX.md): every enemy kind is weak to one form or
## element (x1.25) and resists another (x0.75), per mille in Damage.hit (armed by the direct-hit callers) and in
## Damage.tick_dot (by the tick's element); the matrix is intransitive (the views: test_matchup_views.gd).

const WEAK := SimEvent.TAG_WEAK_TO
const RESISTED := SimEvent.TAG_RESISTED

var _repo := ContentRepository.load_all()


## A world with kind `kind` placed past its spawn-in, out of reach. Returns [world, index].
func _lab(kind: int) -> Array:
	var w := CombatLab.world()
	var id := w.add_enemy(kind, Vector2(9, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 1)
	var i := w.actors.index_of(id)
	w.actors.hp[i] = 1000  # room for every hit below (a Sniper has 30)
	w.actors.max_hp[i] = 1000
	return [w, i]


func _spec(mods: Array, elements: Array = []) -> AttackSpec:
	var s := AttackSpec.new()
	s.modifier_ids = PackedStringArray(mods)
	s.elements = PackedStringArray(elements)
	return s


## The player's direct hit of `amount` on actor i, armed with `spec`'s matchup; returns [HP removed, DAMAGE tags].
func _hit(w: World, i: int, amount: int, spec: AttackSpec) -> Array:
	var pid := w.actors.ids[0]
	Matchups.arm(w, i, spec)
	var at := w.actors.pos(i)
	var got := Damage.hit(w, i, amount, pid, pid, w.take_root(), 0, at + Vector2(0, 2), at)
	return [got, _last_damage_tags(w)]


func _last_damage_tags(w: World) -> int:
	var tags := -1
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.DAMAGE:
			tags = e.tags
	return tags


func test_every_kind_has_a_weakness_and_a_resistance_in_data() -> void:
	var defs := _repo.all_of(&"enemies")
	assert_eq(
		defs.size(), 34, "every enemy kind in data/enemies (test_enemy_validation counts them)"
	)
	for def: EnemyDefinition in defs:
		assert_ne(def.weak_to, &"", "%s weak_to" % def.id)
		assert_ne(def.resists, &"", "%s resists" % def.id)
		assert_ne(def.weak_to, def.resists, "%s: two different ids" % def.id)
		assert_eq(def.weak_permille, 1250, "%s: x1.25 (starting value)" % def.id)
		assert_eq(def.resist_permille, 750, "%s: x0.75 (starting value)" % def.id)
	var t := CombatLab.world().enemy_table(ActorStore.Kind.SNIPER)
	assert_eq(
		[t.weak_to, t.resists, t.weak_permille, t.resist_permille],
		[&"gun_laser", &"gun_wave", 1250, 750]
	)


## v0.11.0 (owner, 2026-11-08: "Spread them out"): 34 kinds; bounds scaled from the 14-kind 2-3 / 1-2.
func test_the_matrix_is_intransitive() -> void:
	var weak := {}
	var resists := {}
	for def: EnemyDefinition in _repo.all_of(&"enemies"):
		weak[def.weak_to] = int(weak.get(def.weak_to, 0)) + 1
		resists[def.resists] = int(resists.get(def.resists, 0)) + 1
	for id: StringName in weak:
		assert_between(int(weak[id]), 2, 5, "%s is good against 2-5 kinds" % id)
		assert_between(int(resists.get(id, 0)), 1, 5, "%s is bad against 1-5 kinds" % id)
	for id: StringName in resists:
		assert_true(weak.has(id), "%s, resisted somewhere, is someone's weakness too" % id)


func test_a_weak_hit_takes_125_percent_and_is_flagged() -> void:
	var lab := _lab(ActorStore.Kind.SNIPER)
	var r := _hit(lab[0], lab[1], 40, _spec(["gun_laser"]))
	assert_eq(r[0], 50, "40 x 1250 / 1000")
	assert_ne(r[1] & WEAK, 0, "the DAMAGE carries WEAK_TO")
	assert_eq(r[1] & RESISTED, 0)


func test_a_resisted_hit_takes_75_percent_and_is_flagged() -> void:
	var lab := _lab(ActorStore.Kind.ARC_CASTER)
	var r := _hit(lab[0], lab[1], 40, _spec([], ["storm"]))
	assert_eq(r[0], 30, "40 x 750 / 1000: an element on the spec counts")
	assert_ne(r[1] & RESISTED, 0)
	var one := _hit(lab[0], lab[1], 1, _spec([], ["storm"]))
	assert_eq(one[0], 1, "a resisted hit that had damage keeps 1")


func test_a_neutral_hit_and_a_both_ways_hit_are_unchanged() -> void:
	var lab := _lab(ActorStore.Kind.SNIPER)
	var r := _hit(lab[0], lab[1], 40, _spec(["gun_glaive"], ["ember"]))
	assert_eq(r[0], 40, "neither its weakness nor its resistance")
	assert_eq(r[1] & (WEAK | RESISTED), 0)
	var both := _hit(lab[0], lab[1], 40, _spec(["gun_laser", "gun_wave"]))
	assert_eq(both[0], 40, "weak and resisted at once cancel")
	assert_eq(both[1] & (WEAK | RESISTED), 0)


func test_the_matchup_is_taken_by_one_hit_only() -> void:
	var lab := _lab(ActorStore.Kind.SNIPER)
	var w: World = lab[0]
	var i: int = lab[1]
	Matchups.arm(w, i, _spec(["gun_laser"]))
	assert_eq(w.matchup_permille, 1250)
	var pid := w.actors.ids[0]
	var at := w.actors.pos(i)
	Damage.hit(w, i, 8, pid, pid, w.take_root(), 0, at + Vector2(0, 2), at)
	assert_eq([w.matchup_permille, w.matchup_tags], [1000, 0], "reset by the hit")
	var got := Damage.hit(w, i, 8, pid, pid, w.take_root(), 0, at + Vector2(0, 2), at)
	assert_eq(got, 8, "an unarmed hit (an item's proc, a nested hit) is neutral")


func test_the_launch_spec_counts_too() -> void:
	var lab := _lab(ActorStore.Kind.CHARGER)
	assert_eq(
		Matchups.hit_mult(lab[0], lab[1], _spec([]), _spec(["gun_lance"])),
		[1250, WEAK],
		"a bare landing spec inside a Lance launch"
	)


func test_enemy_hits_dummies_and_bosses_have_no_matchup() -> void:
	var w := CombatLab.world()
	var d := w.actors.index_of(w.add_dummy(Vector2(3, 0), 0.35, 100))
	assert_eq(Matchups.hit_mult(w, d, _spec(["gun_laser"])), [1000, 0], "a dummy")
	assert_eq(Matchups.hit_mult(w, 0, _spec(["gun_laser"])), [1000, 0], "the hero")
	var lab := _lab(ActorStore.Kind.SNIPER)
	var sw: World = lab[0]
	var i: int = lab[1]
	Matchups.arm(sw, i, _spec(["gun_laser"]))
	var at := sw.actors.pos(i)
	var got := Damage.hit(sw, i, 40, 999, 999, sw.take_root(), 0, at + Vector2(0, 2), at)
	assert_eq(got, 40, "a hit the player doesn't own ignores it")


func test_dot_ticks_take_their_elements_matchup() -> void:
	var lab := _lab(ActorStore.Kind.BOMB_DRONE)  # weak to ember, resists venom
	var w: World = lab[0]
	var i: int = lab[1]
	var pid := w.actors.ids[0]
	assert_eq(Damage.tick_dot(w, i, 4, pid, pid, &"burn", &"ember"), 5, "4 x 1.25 = 5")
	assert_ne(_last_damage_tags(w) & WEAK, 0)
	assert_ne(_last_damage_tags(w) & SimEvent.TAG_DOT, 0, "still a DoT tick")
	assert_eq(Damage.tick_dot(w, i, 4, pid, pid, &"poison", &"venom"), 3, "4 x 0.75 = 3")
	assert_ne(_last_damage_tags(w) & RESISTED, 0)
	assert_eq(Damage.tick_dot(w, i, 4, pid, pid, &"x"), 4, "no element: neutral")


func test_a_landed_attack_reads_its_spec() -> void:
	var lab := _lab(ActorStore.Kind.SHIELD_BEARER)  # weak to the Laser; its front blocks, so hit its back
	var w: World = lab[0]
	var i: int = lab[1]
	var ctx := AttackContext.make(w.player_pos(), 0, 20, w.take_root(), 0, &"")
	var at := w.actors.pos(i)
	var back := at - Kin.dir(w.actors.facing[i]) * 2.0
	assert_eq(
		Attacks.land(w, _spec(["gun_laser"]), ctx, i, back, at),
		25,
		"20 x 1.25 through Attacks.land"
	)
