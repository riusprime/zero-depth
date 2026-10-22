extends GutTest
## v0.6.5 WN5a (docs/design/WAND.md, the shared pool S1–S7, owner "Approve all"): each shared card on both weapons:
## a wand card offered in Blade and Gun runs, its element in the spell's core (Explosive: its blast at the end), its
## effect in a scripted scene (standing dummies, scripted input, crit off), and a level's step. Order and the
## triggers: test_wand_shared_order.gd. Mechanics only: no bot, no balance (owner P1).

const W := preload("res://tests/support/mx4_world.gd")
const TRIG := AttackSpec.Trigger
const FORM := AttackSpec.Form
const WEAPONS: Array[StringName] = [&"blade", &"gun"]
## S1–S7 in WAND.md's order: the card (its id), the element it puts in the spell ("": S7 shows a blast), its name.
const CARDS: Array = [
	[&"ember_core", "ember", "Fire"],
	[&"storm_core", "storm", "Lightning"],
	[&"frost_core", "frost", "Frost"],
	[&"venom_core", "venom", "Venom"],
	[&"shared_bleed", "bleed", "Bleed"],
]  # v0.9.0 XP (owner Q11): S7 Explosive is retired (never offered; test_s7 keeps its mechanics for old builds);
# v0.9.0 VP (owner C §6.4): S6 Void (gravity_well) is retired, its floor black hole deleted (test_void.gd)


## Where the scenes stand their first enemy: in the slash's arc, or in the bolt's line.
func _target(weapon: StringName) -> Vector2:
	return Vector2(1.0, 0.0) if weapon == &"blade" else Vector2(2.5, 0.0)


## One attack straight ahead (a slash, or a shot), then `after` quiet ticks.
func _attack(w: World, weapon: StringName, after: int = 30) -> void:
	if weapon == &"blade":
		W.run(w, 1, W.P)
	else:
		W.run(w, 1, 0, W.S)
	W.run(w, after)


## The ids of the enemies killed so far (the store drops a dead actor).
func _killed(w: World) -> Array:
	var out := []
	for e in W.events(w, SimEvent.Kind.KILL):
		out.append(e.target_id)
	return out


## The spell you fire: the Blade's first slash or the Gun's bolt.
func _spell(w: World, weapon: StringName) -> AttackSpec:
	return Modifiers.step(w, 0) if weapon == &"blade" else Modifiers.bolt(w)


func _name_en(key: StringName) -> String:
	var was := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var out := TranslationServer.translate(key)
	TranslationServer.set_locale(was)
	return out


func test_the_seven_are_shared_wand_cards_offered_on_both_weapons() -> void:
	for weapon in WEAPONS:
		var w := W.world(weapon)
		var open := ItemPool.available(w)
		for c: Array in CARDS:
			var k := W.item(w, c[0])
			assert_gte(k, 0, "%s shipped" % c[0])
			var t := w.item_tables[k]
			assert_true(CardLevels.is_card(w, k), "%s levels up (tag wand)" % c[0])
			assert_eq(t.requires_weapon, 0, "%s: the shared pool" % c[0])
			assert_true(BuildSlots.is_slot_item(t), "%s takes a wand slot" % c[0])
			assert_true(open.has(k), "%s is offered in a %s run" % [c[0], weapon])
			assert_eq(_name_en(t.name_key), String(c[2]), "%s is named %s" % [c[0], c[2]])
		assert_false(
			open.has(W.item(w, &"shared_explosive")), "v0.9.0 XP: Explosive is never offered"
		)


func test_each_card_shows_on_the_spell_of_both_weapons() -> void:
	for weapon in WEAPONS:
		for c: Array in CARDS:
			var s := _spell(W.world(weapon, [c[0]]), weapon)
			if String(c[1]) != "":
				assert_has(
					s.elements, String(c[1]), "%s: its element in the %s's core" % [c[0], weapon]
				)
			else:
				var k := W.hook_of(s, c[0])
				assert_not_null(k, "%s: a hook on the %s" % [c[0], weapon])
				if k != null:
					assert_eq(
						[k.trigger, k.child.form], [TRIG.ON_END, FORM.BURST], "a blast at the end"
					)
			assert_has(s.modifier_ids, String(c[0]), "%s rewrote the %s" % [c[0], weapon])


# --- S1–S7, each on both weapons ----------------------------------------------------------------------------
func test_s1_fire_burns_and_a_kill_leaves_burning_ground() -> void:
	for weapon in WEAPONS:
		var t := _target(weapon)
		var w := W.world(weapon, [&"ember_core"], [[t, 2000]])
		_attack(w, weapon)
		assert_gt(w.actors.burn_stacks[1], 0, "%s: the hit burns" % weapon)
		var k := W.world(weapon, [&"ember_core"], [[t, 1], [t + Vector2(0.4, 1.0), 2000]])
		var first := k.actors.ids[1]
		_attack(k, weapon)
		assert_has(_killed(k), first, "%s: the first enemy dies" % weapon)
		var patch := W.damage(k, &"ember_core")  # v0.9.0 XP: burning ground, no blast
		assert_gt(patch.size(), 0, "%s: its death leaves burning ground" % weapon)
		assert_true(
			_killed(k).size() == 1 and k.ab.fire_pos.size() > 0, "%s: a patch, no burst" % weapon
		)


func test_s2_lightning_chains_to_two_more_enemies() -> void:
	for weapon in WEAPONS:
		var t := _target(weapon)
		var w := W.world(
			weapon,
			[&"storm_core"],
			[[t, 2000], [t + Vector2(2.0, 0.0), 2000], [t + Vector2(2.0, 2.0), 2000]]
		)
		_attack(w, weapon)
		var arcs := W.targets(W.damage(w, &"storm_core"))
		assert_eq(arcs.size(), 2, "%s: the hit arcs to 2 more enemies" % weapon)
		assert_false(arcs.has(w.actors.ids[1]), "%s: not back to the one hit" % weapon)


func test_s3_frost_slows_and_the_third_hit_freezes_for_a_second() -> void:
	for weapon in WEAPONS:
		var w := W.world(weapon, [&"frost_core"], [[_target(weapon), 5000]])
		_attack(w, weapon)
		assert_gt(w.actors.slow_t[1], 0, "%s: the first hit slows" % weapon)
		assert_eq(w.actors.frozen_t[1], 0, "%s: not frozen yet" % weapon)
		var most := 0
		for n in 2:
			if weapon == &"blade":
				W.run(w, 1, W.P)
			else:
				W.run(w, 1, 0, W.S)
			for k in 30:
				W.run(w, 1)
				most = maxi(most, w.actors.frozen_t[1])
		assert_gt(most, 0, "%s: the 3rd hit freezes" % weapon)
		assert_lte(most, SimTick.seconds_to_ticks(1.0), "%s: for 1 s" % weapon)


func test_s4_venom_stacks_poison_that_spreads_on_death() -> void:
	for weapon in WEAPONS:
		var t := _target(weapon)
		var w := W.world(weapon, [&"venom_core"], [[t, 60], [t + Vector2(1.5, 0.0), 2000]])
		var first := w.actors.ids[1]
		var behind := w.actors.ids[2]
		_attack(w, weapon, 10)
		assert_gt(w.actors.poison_stacks[1], 0, "%s: the hit stacks poison" % weapon)
		assert_eq(w.actors.poison_stacks[2], 0, "%s: the one behind is untouched" % weapon)
		for n in 20:
			if _killed(w).has(first):
				break
			_attack(w, weapon, 20)
		assert_has(_killed(w), first, "%s: the first enemy dies" % weapon)
		var j := w.actors.index_of(behind)
		assert_gt(w.actors.poison_stacks[j], 0, "%s: its poison spreads to the next" % weapon)


func test_s5_bleed_stacks_and_ticks_faster_while_you_move() -> void:
	for weapon in WEAPONS:
		var still := W.world(weapon, [&"shared_bleed"], [[_target(weapon), 5000]])
		var moving := W.world(weapon, [&"shared_bleed"], [[_target(weapon), 5000]])
		for w: World in [still, moving]:
			_attack(w, weapon, 15)
			assert_gt(w.actors.bleed_stacks[1], 0, "%s: the hit bleeds" % weapon)
		var n0 := W.damage(still, Engines.EFFECT_BLEED).size()
		W.run(still, 60)
		W.run(moving, 60, 0, 0, 0, Vector2i(0, 1))
		var a := W.damage(still, Engines.EFFECT_BLEED).size() - n0
		var b := W.damage(moving, Engines.EFFECT_BLEED).size() - n0
		assert_gt(a, 0, "%s: the bleed ticks standing" % weapon)
		assert_gt(b, a, "%s: and faster moving (%d vs %d ticks in 1 s)" % [weapon, b, a])


func test_s5_the_moving_period_is_the_cards() -> void:
	var w := W.world(&"blade", [&"shared_bleed"])
	var standing := w.item_mods.bleed_period_ticks
	assert_eq(Engines.bleed_period(w), standing, "standing: the bleed's own period")
	w.move_intent = Vector2i(1, 0)
	assert_eq(Engines.bleed_period(w), SimTick.seconds_to_ticks(0.25), "moving: the card's period")
	assert_lt(Engines.bleed_period(w), standing)
	var plain := W.world(&"blade", [&"serrated_edge"])
	plain.move_intent = Vector2i(1, 0)
	assert_eq(
		Engines.bleed_period(plain), plain.item_mods.bleed_period_ticks, "no card: v0.5's bleed"
	)


func test_s7_explosive_blasts_where_the_spell_ends() -> void:
	# The Blade: the slash's tip, with nothing hit; an enemy just past the reach takes the blast.
	var b := W.world(&"blade", [&"shared_explosive"])
	var tip := b.player.radius_m + Attacks.arc_reach_m(b, Modifiers.step(b, 0))
	var past := W.world(&"blade", [&"shared_explosive"], [[Vector2(tip + 0.9, 0.0), 2000]])
	_attack(past, &"blade")
	var blast := W.damage(past, &"shared_explosive")
	assert_gt(blast.size(), 0, "blade: the slash explodes at its tip")
	assert_eq(W.damage(past, &"*").size(), blast.size(), "blade: the slash itself never reached it")
	# The Gun: the bolt's end (the hit that stopped it); its neighbour is in the blast too.
	var t := _target(&"gun")
	var g := W.world(&"gun", [&"shared_explosive"], [[t, 2000], [t + Vector2(0.0, 1.0), 2000]])
	_attack(g, &"gun")
	assert_has(
		W.targets(W.damage(g, &"shared_explosive")),
		g.actors.ids[2],
		"gun: the neighbour is blasted"
	)
	var marks := WandCasts.read(g)
	assert_gt(marks.size(), 0, "the view gets the blast")
	if not marks.is_empty():
		var s := Modifiers.book(g).find(marks[0]["key"])
		assert_eq(s.form, FORM.BURST)
		assert_false(marks[0]["cast"], "a card's blast, not a trigger's cast")


# --- Levels (WAND.md rule 6) ---------------------------------------------------------------------------------
func test_each_shared_card_levels_up_without_a_slot_and_grows() -> void:
	for c: Array in CARDS:
		var w := W.world(&"gun", [c[0]])
		var k := W.item(w, c[0])
		var slots := w.mod_slots.size()
		var digest := Modifiers.book(w).digest
		var damage := Modifiers.bolt(w).damage
		var hook := W.hook_of(Modifiers.bolt(w), c[0])
		var share := hook.damage_permille if hook != null else 0
		assert_true(CardLevels.can_take(w, k), "%s: offered again below level 5" % c[0])
		Offers.apply(w, k)
		assert_eq(CardLevels.level(w, k), 2, "%s: a duplicate is level 2" % c[0])
		assert_eq(w.mod_slots.size(), slots, "%s: no new slot" % c[0])
		assert_ne(Modifiers.book(w).digest, digest, "%s: the spell changed" % c[0])
		var up := W.hook_of(Modifiers.bolt(w), c[0])
		if c[0] == &"ember_core":  # v0.9.0 XP: Fire's burning patch, +5 % a level
			assert_eq(up.damage_permille, share + 50, "Fire: its patch +5 %%")
		elif hook != null:
			assert_eq(up.damage_permille, share + 100, "%s: its hook +10 %%" % c[0])
		else:
			assert_eq(Modifiers.bolt(w).damage, damage * 1050 / 1000, "%s: +5 %% damage" % c[0])
