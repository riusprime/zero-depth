extends GutTest
## v0.6.0 MX4 (docs/design/MODIFIER_ENGINE.md §7, "Tests without bots"): the combinatorial smoke test over the cards
## as the player holds them (the items, so each brings its engine numbers: burn, shock, poison...), on the Blade and
## the Gun with heat on and the AttackScenario script (shooting, a swing every 9 ticks, a dash every 97, the Skill,
## a vent, a walk): every modifier card alone (also with the six ability modifiers), every pair, and the M-list all at
## once. Each run: no crash, the launches per tick under the cap, a bounded number of live projectiles and queued
## launches; alone and all at once also the same digest and state hash when replayed. And a save's snapshot taken
## mid-fight (queued launches, poison, projectile behaviours in flight) restores to the same hash and plays on the
## same. Mechanics only: no bot, no balance (owner P1).

const SOLO_TICKS := 300
const PAIR_TICKS := 90
const MAX_LIVE_PROJECTILES := 400
const MAX_QUEUED := 64
const ABILITY_MODS: Array = [
	&"bomb_lobber", &"drone_buddy", &"orbit_blades", &"arc_field", &"frost_nova", &"flame_trail"
]

var _cards: Array[StringName] = []
var _m_list: Array[StringName] = []


func before_all() -> void:
	var w := AttackScenario.world(&"blade", [], true, [])
	for t in w.item_tables:
		if BuildSlots.is_slot_item(t):
			_cards.append(t.id)
		if t.kind == ItemTable.Kind.MODIFIER and t.rarity != ItemTable.LEGENDARY:
			_m_list.append(t.id)
	_m_list.append(&"frost_core")


## The scenario world holding `cards` (items; an ability merge's ability is granted too) on `weapon`.
func _world(weapon: StringName, cards: Array, abilities: Array = []) -> World:
	var need := abilities.duplicate()
	var base := AttackScenario.world(weapon, [], true, [])
	for id: StringName in cards:
		var t := base.item_tables[AttackScenario.item_index(base.item_tables, id)]
		if t.requires_ability >= 0:
			var kind := String(AbilityTable.Kind.keys()[t.requires_ability]).to_lower()
			if not need.has(StringName(kind)):
				need.append(StringName(kind))
	var w := AttackScenario.world(weapon, cards, true, need)
	return w


func _run(w: World, ticks: int) -> Dictionary:
	var h := StateHasher.new()
	var seen := 0
	var max_launches := 0
	var max_projectiles := 0
	var max_queued := 0
	for t in ticks:
		w.step(AttackScenario.frame(t))
		if w.launch_tick == w.tick - 1:
			max_launches = maxi(max_launches, w.launch_count)
		max_projectiles = maxi(max_projectiles, w.projectiles.size())
		max_queued = maxi(max_queued, w.mx.q_key.size())
		for e in w.events_since(seen):
			seen = e.seq
			h.add_int(e.kind)
			h.add_int(e.target_id)
			h.add_int(e.amount_applied)
			h.add_string(String(e.effect_id))
	return {
		"digest": h.finish_hex(),
		"hash": w.state_hash(),
		"max_launches": max_launches,
		"max_projectiles": max_projectiles,
		"max_queued": max_queued,
	}


func _check(label: String, r: Dictionary) -> void:
	assert_lte(
		r["max_launches"], Attacks.MAX_LAUNCHES_PER_TICK + 1, "%s: launches per tick" % label
	)
	assert_lte(r["max_projectiles"], MAX_LIVE_PROJECTILES, "%s: live projectiles" % label)
	assert_lte(r["max_queued"], MAX_QUEUED, "%s: queued launches" % label)


func test_every_card_is_a_modifier_and_the_m_list_is_shipped() -> void:
	assert_eq(_m_list.size(), 30, "M1–M30")
	for id: StringName in _m_list:
		assert_has(_cards, id, "%s takes a slot" % id)


func test_every_card_alone_on_each_weapon_runs_and_replays() -> void:
	for weapon: StringName in [&"blade", &"gun"]:
		for id: StringName in _cards:
			var label := "%s + %s" % [weapon, id]
			var a := _run(_world(weapon, [id]), SOLO_TICKS)
			_check(label, a)
			var b := _run(_world(weapon, [id]), SOLO_TICKS)
			assert_eq([b["digest"], b["hash"]], [a["digest"], a["hash"]], "%s: replays" % label)


func test_every_card_with_the_six_ability_modifiers_runs() -> void:
	for weapon: StringName in [&"blade", &"gun"]:
		for id: StringName in _cards:
			_check(
				"%s + six abilities + %s" % [weapon, id],
				_run(_world(weapon, [id], ABILITY_MODS), PAIR_TICKS)
			)


func test_every_pair_of_cards_runs() -> void:
	for weapon: StringName in [&"blade", &"gun"]:
		for i in _cards.size():
			for j in range(i + 1, _cards.size()):
				var pair := [_cards[i], _cards[j]]
				_check(
					"%s + %s + %s" % [weapon, pair[0], pair[1]],
					_run(_world(weapon, pair), PAIR_TICKS)
				)


func test_the_m_list_all_at_once_runs_and_replays() -> void:
	for weapon: StringName in [&"blade", &"gun"]:
		var a := _run(_world(weapon, _m_list), SOLO_TICKS)
		_check("%s + M1–M30" % weapon, a)
		var b := _run(_world(weapon, _m_list), SOLO_TICKS)
		assert_eq(
			[b["digest"], b["hash"]], [a["digest"], a["hash"]], "%s + M1–M30: replays" % weapon
		)


## A save mid-fight: the snapshot restores into a fresh world with the same hash, and both play on the same.
func test_a_snapshot_with_the_new_modifiers_round_trips() -> void:
	var cards := [
		&"venom_core", &"twin_cast", &"boomerang", &"long_shadow", &"edge_rounds", &"ascension"
	]
	for weapon: StringName in [&"gun", &"blade"]:
		var w := _world(weapon, cards)
		var mid := 0
		for t in 400:
			w.step(AttackScenario.frame(t))
			var busy := not w.mx.q_key.is_empty() and w.projectiles.moves
			if t > 150 and busy and mid == 0:
				mid = t + 1
				break
		if mid == 0:
			mid = 400
		var snap := w.to_snapshot()
		var base := _world(weapon, cards)
		assert_eq(WorldSnapshot.apply(base, snap), "", "%s: restores" % weapon)
		assert_eq(base.state_hash(), w.state_hash(), "%s: the same hash" % weapon)
		assert_eq(base.mx.q_key, w.mx.q_key, "%s: the queued launches" % weapon)
		assert_eq(base.actors.poison_stacks, w.actors.poison_stacks, "%s: the poison" % weapon)
		for t in range(mid, mid + 120):
			w.step(AttackScenario.frame(t))
			base.step(AttackScenario.frame(t))
		assert_eq(base.state_hash(), w.state_hash(), "%s: plays on the same" % weapon)
