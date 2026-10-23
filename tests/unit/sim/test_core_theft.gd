extends GutTest
## v0.6.0 CU core theft (PLAN v0.5.5 X2; SIGNATURE.md): elites and bosses carry a core drawn on `ai:elite`; a boss's
## stagger opens the steal window and a kill inside it drops the core as a free pick (through the pick); a boss's core
## is from the legendary tier. v0.9.0 EL (owner Q25: "you have a 30% chance of dropping the core"; no stagger window):
## an elite (an archetype) never staggers and has no window; killed, it drops its core's card 30 % of the time (on
## `ai:elite`). Real floors (EventLab, built as Main).

const SEED := 717


func _world() -> World:
	var w := EventLab.world(SEED, 1, &"blade")
	if w.elite_rules == null:
		w.elite_rules = EliteRules.new()
	return w


## A fresh elite `m` metres from the player (a Breaker: spawned in, not acting yet), as its actor index.
func _elite(w: World, m: float = 3.0) -> int:
	var id := Elites.spawn(
		w, ActorStore.Kind.BREAKER, w.player_pos() + Vector2(m, 0), Elites.Source.DEV
	)
	var i := w.actors.index_of(id)
	w.actors.invuln[i] = 0
	return i


func _hit(w: World, i: int, amount: int) -> void:
	var a := w.actors
	Damage.hit(w, i, amount, a.ids[0], a.ids[0], w.take_root(), 0, a.pos(i), a.pos(i))


func _drops(w: World, kind: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for r in w.rewards.size():
		if CoreTheft.drop_kind(w, w.rewards.ids[r]) == kind:
			out.append(r)
	return out


func test_an_elite_carries_a_deterministic_core() -> void:
	var cards := []
	for k in 2:
		var w := _world()
		var i := _elite(w)
		assert_true(CoreTheft.has_core(w, i), "the elite carries a core")
		var card := w.cores.card[CoreTheft.entry_of(w, w.actors.ids[i])]
		var type := Offers.type_of(card)
		assert_true(type == Offers.MOD or type == Offers.STAT, "a mod or a stat card")
		if type == Offers.STAT:
			assert_eq(Offers.rarity_of(card), Stats.Rarity.RARE, "a rare stat card")
		else:
			assert_false(ItemPool.available(w).has(card), "a mod in a core is out of the pool")
		cards.append(card)
	assert_eq(cards[0], cards[1], "the same seed, the same core")
	var v := _world()
	var id := v.add_enemy(ActorStore.Kind.WARDEN, v.player_pos() + Vector2(3, 0))
	assert_false(CoreTheft.has_core(v, v.actors.index_of(id)), "a plain enemy carries none")


func test_an_elite_never_staggers_and_opens_no_window() -> void:
	var w := _world()
	var i := _elite(w)
	_hit(w, i, w.actors.max_hp[i] * 400 / 1000)
	assert_false(CoreTheft.staggered(w, i), "no stagger (Q25)")
	assert_false(CoreTheft.window_open(w, i), "no steal window")


func test_a_kill_drops_the_core_as_a_free_pick_when_the_chance_hits() -> void:
	var w := _world()
	w.elite_rules.core_drop_permille = 1000  # test setup: the 30 % made certain
	var i := _elite(w)
	var card := w.cores.card[CoreTheft.entry_of(w, w.actors.ids[i])]
	_hit(w, i, w.actors.max_hp[i] * 10)
	w.step(InputFrame.new())
	var drops := _drops(w, CoreState.Drop.CORE)
	assert_eq(drops.size(), 1, "the core dropped")
	var r := drops[0]
	assert_eq(w.rewards.offer_of(r), PackedInt32Array([card]), "holding the core's card")
	assert_eq(w.rewards.price[r], 0, "free")
	assert_eq(w.cores.steal_card, card)
	assert_eq(w.elites.kill_dropped, 1, "the views know it dropped")
	var hash_before := w.state_hash()
	w.actors.set_pos(0, w.rewards.pos(r))
	w.vel = Vector2.ZERO
	var f := InputFrame.new()
	f.pressed = InputFrame.INTERACT
	w.step(f)
	assert_eq(w.choosing, w.rewards.ids[r], "it opens like an altar")
	assert_ne(w.state_hash(), hash_before)
	var values := w.stat_values.duplicate()
	EventLab.pick(w, 1)
	assert_eq(w.choosing, -1, "taken")
	if Offers.type_of(card) == Offers.MOD:
		assert_true(w.items_owned.has(card), "the mod is yours")
	else:
		assert_ne(w.stat_values, values, "the stat moved")
	assert_true(_drops(w, CoreState.Drop.CORE).is_empty(), "the drop is gone")


func test_a_kill_without_the_chance_gives_the_normal_drop() -> void:
	var w := _world()
	w.elite_rules.core_drop_permille = 0
	var i := _elite(w)
	var rewards := w.rewards.size()
	var shards := w.shards
	_hit(w, i, w.actors.max_hp[i] * 10)
	w.step(InputFrame.new())
	assert_eq(w.rewards.size(), rewards, "no core")
	assert_gt(w.shards, shards, "the shards, as any kill")


## Q25: a 30 % chance. Over KILLS elites killed in one floor, the drops land within 25-35 %.
func test_the_core_drops_30_percent_of_the_time() -> void:
	const KILLS := 600
	var w := _world()
	assert_eq(w.elite_rules.core_drop_permille, 300, "the data's chance")
	w.actors.invuln[0] = 1 << 20
	var dropped := 0
	for k in KILLS:
		var i := _elite(w)
		_hit(w, i, w.actors.max_hp[i] * 10)
		w.step(InputFrame.new())
		dropped += w.elites.kill_dropped
	var rate := float(dropped) / KILLS
	gut.p("EL_CORE_DROP| kills=%d dropped=%d rate=%.3f" % [KILLS, dropped, rate])
	assert_between(rate, 0.25, 0.35, "about 30 %")


func test_a_boss_core_is_legendary_and_its_own_stagger_opens_the_window() -> void:
	var w := _world()
	assert_not_null(w.legendary_table)
	var id := w.spawn_boss(0, w.player_pos() + Vector2(5, 0))
	var i := w.actors.index_of(id)
	assert_true(CoreTheft.has_core(w, i), "the boss carries a core")
	var k := CoreTheft.entry_of(w, id)
	var card := w.cores.card[k]
	assert_eq(w.cores.boss[k], 1)
	if Offers.type_of(card) == Offers.STAT:
		assert_eq(Offers.rarity_of(card), Offers.LEGENDARY, "a legendary stat card")
		assert_true(w.legendary_table.stats.has(Offers.stat_of(card)))
	else:
		assert_true(w.legendary_table.mods.has(card), "a legendary-tier mod")
	w.actors.invuln[0] = 1 << 20
	CombatLab.idle(w, BossAi.INTRO_TICKS + 2)  # it rises (no stagger while rising)
	i = w.actors.index_of(id)
	w.actors.invuln[i] = 0
	var t := BossAi.table_of(w, i)
	var b := w.bosses.index_of(id)
	var guard := 0
	while w.bosses.stagger_t[b] == 0 and guard < 200:
		guard += 1
		w.actors.hp[i] = w.actors.max_hp[i]  # test setup: keep it away from its phase gates
		_hit(w, i, maxi(1, t.stagger_size_milli / 1000 / 4))
	assert_gt(w.bosses.stagger_t[b], 0, "the boss staggered by its own meter")
	assert_true(CoreTheft.window_open(w, i), "the window opened with it")
	# Killed inside the window (owner 0, as the dev panel's kill: past the phase gates).
	var at := w.actors.pos(i)
	Damage.hit(w, i, w.actors.hp[i] * 10, 0, 0, w.take_root(), 0, at, at)
	w.step(InputFrame.new())
	var drops := _drops(w, CoreState.Drop.BOSS_CORE)
	assert_eq(drops.size(), 1, "the boss's core dropped")
	assert_eq(w.rewards.offer_of(drops[0]), PackedInt32Array([card]))
	assert_true(WorldReader.new(w).reward_is_legendary(drops[0]), "the pick shows it legendary")


## Audit G-6: a core whose mod stopped working with the build (its ability is gone) is redrawn, by the shop's rule.
func test_a_core_mod_that_no_longer_works_is_redrawn() -> void:
	var w := _world()
	var i := _elite(w)
	var dead := -1
	for k in w.item_tables.size():
		if not ItemPool.usable(w, k) and CardLevels.can_take(w, k):
			dead = k
			break
	assert_gte(dead, 0, "a mod this build can't use (e.g. its ability was sold)")
	w.cores.card[CoreTheft.entry_of(w, w.actors.ids[i])] = dead  # test setup: e.g. its ability was sold since
	assert_false(Shop.can_apply(w, dead))
	w.elite_rules.core_drop_permille = 1000  # test setup: the 30 % made certain
	_hit(w, i, w.actors.max_hp[i] * 10)
	w.step(InputFrame.new())
	var drops := _drops(w, CoreState.Drop.CORE)
	assert_eq(drops.size(), 1, "a core still drops")
	if drops.size() == 1:
		assert_false(dead in w.rewards.offer_of(drops[0]), "not the inert mod")
