extends GutTest
## v0.6.5 WN1 (docs/design/WAND.md "How it's built" 1; MODIFIER_ENGINE §7 "Tests without bots"): the combinatorial
## smoke test over the wand. Every card that takes a slot (the items of rewrites, the trigger cards, the six ability
## modifiers) in every slot position of a full eight-card wand, on the Blade and the Gun, heat on, through the
## AttackScenario script. Each run: no crash, the launches per tick under the cap (the one LIMIT tick aside), a bounded
## number of live projectiles and queued launches, the card in its slot, and the same event digest and state hash
## when replayed; v0.8.0 RM: the remnants alive under their cap. Mechanics only: no bot, no balance (owner P1).

const TICKS := 60
const POSITIONS := 8
const MAX_LIVE_PROJECTILES := 400
const MAX_QUEUED := 64
const ABILITY_MODS: Array = [
	&"bomb_lobber", &"drone_buddy", &"orbit_blades", &"arc_field", &"frost_nova", &"flame_trail"
]
## The other seven cards of the wand (two triggers among them, so every position sits before, between and after
## cuts); a card that is one of them takes the next spare's place.
const FILLER: Array = [
	&"split_shot",
	&"trigger_on_hit",
	&"ember_core",
	&"echo_slash",
	&"trigger_on_kill",
	&"halo_shot",
	&"twin_cast",
	&"seeker",
	&"aftershock",
]

var _cards: Array[StringName] = []


func before_all() -> void:
	var w := AttackScenario.world(&"blade", [], true, [])
	for t in w.item_tables:
		if BuildSlots.is_slot_item(t):
			_cards.append(t.id)
	for id: StringName in ABILITY_MODS:
		_cards.append(id)


func _wand(card: StringName, at: int) -> Array:
	var out: Array = []
	for id: StringName in FILLER:
		if id != card and out.size() < POSITIONS - 1:
			out.append(id)
	out.insert(at, card)
	return out


func _run(w: World) -> Dictionary:
	var h := StateHasher.new()
	var seen := 0
	var max_launches := 0
	var max_projectiles := 0
	var max_queued := 0
	var max_remnants := 0  # v0.8.0 RM: the remnant store under its cap
	for t in TICKS:
		w.step(AttackScenario.frame(t))
		if w.launch_tick == w.tick - 1:
			max_launches = maxi(max_launches, w.launch_count)
		max_projectiles = maxi(max_projectiles, w.projectiles.size())
		max_queued = maxi(max_queued, w.mx.q_key.size())
		max_remnants = maxi(max_remnants, w.mx.rem_uid.size())
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
		"max_remnants": max_remnants,
	}


func test_the_cards_include_the_triggers_and_the_ability_modifiers() -> void:
	for id: StringName in [
		&"trigger_on_hit",
		&"trigger_on_kill",
		&"trigger_on_end",
		&"trigger_on_finisher",
		&"bomb_lobber"
	]:
		assert_has(_cards, id)
	assert_gt(_cards.size(), 50)


func test_every_card_in_every_slot_on_both_weapons_runs_and_replays() -> void:
	var runs := 0
	var bad := []
	for weapon: StringName in [&"blade", &"gun"]:
		for card: StringName in _cards:
			for at in POSITIONS:
				var order := _wand(card, at)
				var w := WandLab.fight(weapon, order)
				var label := "%s, %s in slot %d" % [weapon, card, at]
				if w.mod_slots.size() <= at or w.mod_slots[at] != WandLab.code(w, card):
					bad.append("%s: not in its slot" % label)
					continue
				var a := _run(w)
				var b := _run(WandLab.fight(weapon, order))
				runs += 1
				if a["max_launches"] > Attacks.MAX_LAUNCHES_PER_TICK + 1:
					bad.append("%s: launches %d" % [label, a["max_launches"]])
				if a["max_projectiles"] > MAX_LIVE_PROJECTILES:
					bad.append("%s: projectiles %d" % [label, a["max_projectiles"]])
				if a["max_queued"] > MAX_QUEUED:
					bad.append("%s: queued %d" % [label, a["max_queued"]])
				if a["max_remnants"] > Remnants.table(w).remnant_max:
					bad.append("%s: remnants %d" % [label, a["max_remnants"]])
				if [b["digest"], b["hash"]] != [a["digest"], a["hash"]]:
					bad.append("%s: the replay differs" % label)
	gut.p(
		"wand smoke: %d runs (%d cards × %d slots × 2 weapons)" % [runs, _cards.size(), POSITIONS]
	)
	assert_eq(bad, [], "every card in every slot")
	assert_eq(runs, _cards.size() * POSITIONS * 2)
