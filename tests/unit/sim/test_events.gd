# gdlint: disable=max-public-methods
extends GutTest
## v0.5.0 EV (PLAN R3): each of the eight events, through the sim's own interact and pick: the panel opens and the
## world waits; every choice pays its cost, gives its reward (and its curse) and closes the event; a refused choice
## changes nothing; Leave keeps the event and its rolled cards; the same seed and inputs give the same outcomes.
## Each test turns pedestal 0 of a real floor into the event under test (EventLab.set_event, labelled test setup).

const SEED := 4242


func _world(id: StringName, curses: Array = []) -> World:
	var w := EventLab.world(SEED, 1, &"blade", curses)
	EventLab.set_event(w, id)
	return w


func _kill(w: World, id: int) -> void:
	var i := w.actors.index_of(id)
	w.actors.invuln[i] = 0
	var at := w.actors.pos(i)
	Damage.hit(w, i, w.actors.hp[i] * 10, 0, 0, w.take_root(), 0, at, at)


func test_the_panel_opens_waits_and_leave_keeps_the_event() -> void:
	var w := _world(&"unstable_core")
	EventLab.open(w)
	assert_eq(w.ev.open, 0, "the panel is open")
	assert_eq(w.ev.rolled[0], 1, "its cards were rolled")
	var cards := w.ev.roll_card.slice(0, 2)
	var run := w.run_ticks
	var hp := w.actors.hp[0]
	EventLab.idle(w, 30)
	assert_eq(w.run_ticks, run, "the world waits while the panel is open")
	assert_eq(w.ev.open, 0)
	EventLab.pick(w, InputFrame.PICK_CANCEL)
	assert_eq(w.ev.open, -1, "Leave closes it")
	assert_eq(w.ev.state[0], Events.State.READY, "and keeps the event")
	assert_eq(w.actors.hp[0], hp, "nothing paid")
	EventLab.open(w)
	assert_eq(w.ev.roll_card.slice(0, 2), cards, "reopening shows the same cards")


func test_unstable_core_trades_hp_or_a_curse_for_an_epic_stat_card() -> void:
	var w := _world(&"unstable_core")
	EventLab.open(w)
	var code := w.ev.roll_card[0]
	assert_eq(Offers.type_of(code), Offers.STAT)
	assert_eq(Offers.rarity_of(code), Stats.Rarity.EPIC, "an epic stat card")
	var stat := Offers.stat_of(code)
	var before := Stats.value(w, stat)
	var max_hp := w.actors.max_hp[0]
	var hp := w.actors.hp[0]
	EventLab.pick(w, 1)
	assert_eq(w.ev.open, -1)
	assert_eq(w.ev.state[0], Events.State.DONE, "the pedestal goes dark")
	assert_ne(Stats.value(w, stat), before, "the card applied")
	if stat != Stats.Stat.MAX_HP and stat != Stats.Stat.GLASS_CANNON:
		assert_eq(hp - w.actors.hp[0], max_hp * 250 / 1000, "25 % of max HP")
	assert_true(w.curses_owned.is_empty(), "no curse on that choice")
	var v := _world(&"unstable_core")
	EventLab.open(v)
	var curse := v.ev.roll_curse[1]
	assert_gte(curse, 0, "Embrace shows its curse before you take it")
	EventLab.pick(v, 2)
	assert_eq(v.curses_owned, PackedInt32Array([curse]), "Embrace takes the curse")
	assert_eq(Curses.threat(v), 1, "T rises by 1")


func test_echo_mirror_needs_a_raised_stat_and_repeats_it_with_a_curse() -> void:
	var w := _world(&"echo_mirror")
	EventLab.open(w)
	assert_eq(Events.block(w, 0, 0), Events.NEED_NOTHING_TO_GAIN, "nothing to echo yet")
	EventLab.pick(w, 1)
	assert_eq(w.ev.open, 0, "a refused pick keeps the panel open")
	assert_gt(w.ev.denied_tick, -1)
	var v := _world(&"echo_mirror")
	Stats.add_card(v, Stats.Stat.DAMAGE, Stats.Rarity.COMMON)  # test setup: a raised stat
	EventLab.open(v)
	assert_eq(v.ev.roll_card[0], Offers.stat_code(Stats.Stat.DAMAGE, Stats.Rarity.RARE))
	var before := Stats.value(v, Stats.Stat.DAMAGE)
	EventLab.pick(v, 1)
	assert_gt(Stats.value(v, Stats.Stat.DAMAGE), before, "a rare damage card")
	assert_eq(v.curses_owned.size(), 1, "and a curse")
	var u := _world(&"echo_mirror")
	EventLab.open(u)
	var hp := u.actors.hp[0]
	EventLab.pick(u, 2)
	assert_eq(u.shards, 30, "Shatter pays 30 shards on floor 1")
	assert_eq(hp - u.actors.hp[0], u.actors.max_hp[0] / 10, "for 10 % HP")


func test_scrap_heap_buys_or_digs_up_a_mod() -> void:
	var w := _world(&"scrap_heap")
	EventLab.open(w)
	assert_eq(Events.block(w, 0, 0), Events.NEED_SHARDS, "35 shards needed")
	EventLab.pick(w, 1)
	assert_eq(w.ev.state[0], Events.State.READY, "refused: nothing changed")
	EventLab.pick(w, InputFrame.PICK_CANCEL)
	w.shards = 50  # test setup
	EventLab.open(w)
	var mod := w.ev.roll_card[0]
	assert_eq(Offers.type_of(mod), Offers.MOD)
	EventLab.pick(w, 1)
	assert_eq(w.shards, 15, "paid 35")
	assert_true(w.items_owned.has(mod), "the mod is yours")
	var v := _world(&"scrap_heap")
	EventLab.open(v)
	var dug := v.ev.roll_card[1]
	var hp := v.actors.hp[0]
	EventLab.pick(v, 2)
	assert_true(v.items_owned.has(dug))
	assert_eq(hp - v.actors.hp[0], v.actors.max_hp[0] * 150 / 1000, "Dig costs 15 % HP")


func test_ambush_cache_brings_an_elite_pack_and_a_chest_once_it_falls() -> void:
	var w := _world(&"ambush_cache")
	EventLab.open(w)
	var rewards := w.rewards.size()
	EventLab.pick(w, 1)
	assert_eq(w.ev.state[0], Events.State.ACTIVE, "the fight is on")
	assert_eq(w.ev.ambush_ids.size(), 3, "three elites")
	for id in w.ev.ambush_ids:
		var i := w.actors.index_of(id)
		assert_true(Curses.is_elite(w, id))
		assert_gt(w.actors.invuln[i], 0, "each spawns in like any enemy (readable)")
		assert_eq(w.floor_layout.room_of(w.actors.pos(i)), w.ev.room[0], "in the event room")
		var base := w.enemy_table(w.actors.kinds[i]).hp
		assert_gte(w.actors.max_hp[i], base * 2, "elite HP")
	assert_eq(Events.block(w, 0, 0), Events.NEED_BUSY, "one ambush at a time")
	for id in w.ev.ambush_ids:
		_kill(w, id)
	EventLab.idle(w, 1)
	assert_eq(w.ev.state[0], Events.State.DONE)
	assert_eq(w.ev.ambush, -1)
	assert_eq(w.rewards.size(), rewards + 1, "a chest appeared")
	var c := w.rewards.size() - 1
	assert_eq(w.rewards.kind[c], RewardStore.Kind.CHEST)
	assert_eq(w.rewards.price[c], 0, "free")
	assert_almost_eq(w.rewards.pos(c).distance_to(w.ev.pos(0)), Events.CHEST_OFFSET_M, 0.01)


func test_overclock_vent_overheats_now_for_more_overclock_damage() -> void:
	var w := _world(&"overclock_vent")
	EventLab.open(w)
	EventLab.pick(w, 1)
	assert_true(Heat.stalled(w), "the stall: you can't attack for a moment")
	assert_eq(w.ev.overclock_bonus, 300, "+30 % Overclock damage this floor")
	EventLab.idle(w, w.heat.table.stall_ticks + 2)
	w.heat.milli = w.heat.table.overclock_threshold * HeatTable.MILLI  # test setup: back at Overclock
	Heat._retier(w)
	var mult := Heat.attacker_mult(w, 1, w.actors.ids[0], SimEvent.TAG_MELEE, &"")
	assert_eq(mult, 1000 + w.heat.table.overclock_damage_permille + 300)


func test_blood_price_costs_max_hp_for_the_run_and_levels_an_ability() -> void:
	var w := _world(&"blood_price")
	var weapon := w.ability_owned[0]
	var max_hp := w.actors.max_hp[0]
	EventLab.open(w)
	assert_eq(w.ev.roll_card[0], Offers.ability_code(weapon), "the only ability: the weapon")
	EventLab.pick(w, 1)
	assert_eq(Abilities.level_of(w, weapon), 2, "it levels up")
	assert_almost_eq(w.actors.max_hp[0], max_hp * 880 / 1000, 1, "12 % less max HP")
	var carry := RunCarry.take(w, 0)
	assert_eq(carry[&"stat_values"][Stats.Stat.MAX_HP], 880, "for the run")


func test_wandering_drone_pays_once_you_held_the_ring_for_20_seconds() -> void:
	var w := _world(&"wandering_drone")
	w.spawner = null  # test setup: no spawns in the way of the count
	EventLab.open(w)
	EventLab.pick(w, 1)
	assert_eq(w.ev.defend, 0)
	assert_eq(Events.spawn_haste(w), 1, "spawns come twice as fast meanwhile")
	w.actors.set_pos(0, w.ev.pos(0) + Vector2(w.ev.rules.defend_radius_m + 2.0, 0))
	EventLab.idle(w, 120)
	assert_eq(w.ev.defend_ticks, 0, "out of the ring: no progress")
	w.actors.set_pos(0, w.ev.pos(0))
	EventLab.idle(w, 20 * 60 - 1)
	assert_eq(w.shards, 0, "not yet")
	EventLab.idle(w, 2)
	assert_eq(w.shards, 45, "45 shards on floor 1")
	assert_eq(w.ev.state[0], Events.State.DONE)
	assert_eq(Events.spawn_haste(w), 0)


func test_cleansing_font_lifts_the_latest_curse() -> void:
	var w := _world(&"cleansing_font", [&"swift_foes", &"withering"])
	assert_eq(Curses.threat(w), 2)
	EventLab.open(w)
	assert_eq(Events.block(w, 0, 0), Events.NEED_SHARDS)
	var hp := w.actors.hp[0]
	EventLab.pick(w, 2)
	assert_eq(hp - w.actors.hp[0], w.actors.max_hp[0] / 5, "20 % HP")
	assert_eq(w.curses_owned, PackedInt32Array([EventLab.curse_index(w, &"swift_foes")]))
	assert_eq(Curses.threat(w), 1, "T falls")
	assert_eq(w.threat_peak, 2, "the peak stays")
	var v := _world(&"cleansing_font")
	EventLab.open(v)
	assert_eq(Events.block(v, 0, 1), Events.NEED_NOTHING_TO_GAIN, "nothing to cleanse")


func test_hp_costs_never_kill() -> void:
	var w := _world(&"unstable_core")
	w.actors.hp[0] = 3  # test setup
	EventLab.open(w)
	EventLab.pick(w, 1)
	assert_eq(w.actors.hp[0], 1, "at most down to 1 HP")
	assert_false(w.player_dead())


func test_same_seed_same_events_rolls_and_hash() -> void:
	var a := EventLab.world(99)
	var b := EventLab.world(99)
	assert_eq(a.ev.event, b.ev.event)
	assert_eq(a.state_hash(), b.state_hash())
	for w in [a, b]:
		EventLab.set_event(w, &"unstable_core")
		EventLab.open(w)
		EventLab.pick(w, 2)
	assert_eq(a.ev.roll_card, b.ev.roll_card, "same cards")
	assert_eq(a.curses_owned, b.curses_owned, "same curse")
	assert_eq(a.state_hash(), b.state_hash(), "same state")
	var c := EventLab.world(100)
	EventLab.set_event(c, &"unstable_core")
	EventLab.open(c)
	var differ := c.ev.roll_card != a.ev.roll_card or c.ev.roll_curse != a.ev.roll_curse
	var d := EventLab.world(101)
	EventLab.set_event(d, &"unstable_core")
	EventLab.open(d)
	differ = differ or d.ev.roll_card != a.ev.roll_card
	assert_true(differ, "other seeds roll other outcomes")


func test_events_and_curses_are_in_the_hash() -> void:
	var a := EventLab.world(7)
	var b := EventLab.world(7)
	b.ev.defend_ticks = 5
	assert_ne(a.state_hash(), b.state_hash(), "event state is hashed")
	var c := EventLab.world(7)
	Curses.add(c, 0)
	assert_ne(a.state_hash(), c.state_hash(), "curses are hashed")
	var plain := World.new(7, PlayerTable.starting_values())
	var plain2 := World.new(7, PlayerTable.starting_values())
	Events.setup(plain2, [] as Array[EventTable], [] as Array[CurseTable], null)
	assert_eq(plain.state_hash(), plain2.state_hash(), "a world without events hashes as before")


func test_the_press_goes_to_an_altar_or_chest_first() -> void:
	var w := _world(&"unstable_core")
	w.add_reward(RewardStore.Kind.ALTAR, w.ev.pos(0) + Vector2(0.3, 0), 0)  # test setup
	EventLab.open(w)
	assert_eq(w.ev.open, -1, "the altar took the press")
	assert_gte(w.choosing, 0)
