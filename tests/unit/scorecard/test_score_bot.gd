extends GutTest
## The scorecard's bot policies (v0.5.0 SCD; SCORECARD §3; ScoreBot): each is deterministic (same seed and world,
## same inputs), the policy names parse into their knobs, specialists prefer their focus's cards, and the exploit
## bots do what their case says.

const SEED := 20261003

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


## The first `n` input frames policy `policy` gives on a fresh floor 1 of SEED (the world stepped with them).
func _frames(policy: String, build: StringName, n: int, skill: String = "average") -> Array:
	var r := ScoreRun.setup(_repo, SEED, policy, build, skill)
	var w := r.floor_world()
	r.bot.start_floor(w)
	var out := []
	for t in n:
		var f := r.bot.frame(w)
		out.append(f.to_array())
		w.step(f)
	out.append(w.state_hash())
	return out


func test_every_policy_is_deterministic() -> void:
	for p in [
		["idle", &"blade"],
		["novice", &"gun"],
		["competent", &"blade"],
		["competent", &"gun"],
		["element", &"gun"],
		["ordnance", &"blade"],
		["guard", &"blade"],
		["competent+t", &"gun"],
		["exploit:salvage", &"blade"],
	]:
		var a := _frames(p[0], p[1], 600)
		var b := _frames(p[0], p[1], 600)
		assert_eq(a, b, "%s on %s: same seed, same inputs and world" % p)


func test_policy_names_set_the_knobs() -> void:
	var c := ScoreBot.new(1, "competent")
	assert_eq(
		[c.moves, c.picks_mode, c.focus, c.threat, c.exploit], ["competent", "best", "", false, ""]
	)
	assert_eq([c.reaction_ticks, c.dodge_permille, c.greed], [14, 650, 500], "the average preset")
	var e := ScoreBot.new(1, "competent", "expert")
	assert_eq([e.reaction_ticks, e.dodge_permille, e.aim_error], [8, 900, 2 * 4096 / 360])
	var n := ScoreBot.new(1, "novice")
	assert_eq(
		[n.moves, n.picks_mode, n.preset, n.reaction_ticks], ["novice", "random", "novice", 24]
	)
	assert_eq(ScoreBot.new(1, "idle").picks_mode, "none")
	assert_eq(ScoreBot.new(1, "element").focus, "element")
	var t := ScoreBot.new(1, "competent+t")
	assert_true(t.threat and t.focus.is_empty())
	var x := ScoreBot.new(1, "exploit:chain")
	assert_eq([x.exploit, x.moves], ["chain", "competent"])


func test_idle_never_moves_or_presses() -> void:
	for f: Variant in _frames("idle", &"blade", 120).slice(0, 120):
		assert_eq(f, [0, 0, 0, 0, 0, 0, 0])


func test_specialists_prefer_their_focus_cards() -> void:
	var r := ScoreRun.setup(_repo, SEED, "element", &"blade")
	var w := r.floor_world()
	var arc := Offers.ability_code(Abilities.index_of_kind(w, AbilityTable.Kind.ARC_FIELD))
	var bomb := Offers.ability_code(Abilities.index_of_kind(w, AbilityTable.Kind.BOMB_LOBBER))
	var aegis := Offers.ability_code(Abilities.index_of_kind(w, AbilityTable.Kind.AEGIS))
	var offer := PackedInt32Array([bomb, arc, aegis])
	assert_eq(ScoreBot.new(1, "element").choose_card(w, offer), 1, "element takes Arc Field")
	assert_eq(ScoreBot.new(1, "ordnance").choose_card(w, offer), 0, "ordnance takes Bomb Lobber")
	assert_eq(ScoreBot.new(1, "guard").choose_card(w, offer), 2, "guard takes the Aegis")
	assert_eq(
		ScoreBot.new(1, "competent").choose_card(w, offer), 0, "competent: the first best (no bias)"
	)
	assert_true(ScoreBot.in_focus(w, arc, "element"))
	assert_false(ScoreBot.in_focus(w, arc, "ordnance"))
	var ember := -1
	for k in w.item_tables.size():
		if w.item_tables[k].id == &"ember_edge":
			ember = k
	assert_true(ScoreBot.in_focus(w, ember, "element"), "a fire mod is an element card")
	assert_false(ScoreBot.in_focus(w, ember, ""), "no focus: nothing is a focus card")


func test_novice_picks_from_its_own_stream() -> void:
	var r := ScoreRun.setup(_repo, SEED, "novice", &"gun")
	var w := r.floor_world()
	var offer := PackedInt32Array()
	for k in 3:
		offer.append(Offers.stat_code(k, 0))
	var a := ScoreBot.new(7, "novice")
	var b := ScoreBot.new(7, "novice")
	var picks_a := []
	var picks_b := []
	for k in 30:
		picks_a.append(a.choose_card(w, offer))
		picks_b.append(b.choose_card(w, offer))
	assert_eq(picks_a, picks_b, "same seed, same picks")
	var seen := {}
	for p: int in picks_a:
		seen[p] = true
	assert_eq(seen.size(), 3, "random over the offer")


## exploit:salvage at an open shop: it buys the first card it can, then sells that card straight back.
func test_salvage_exploit_buys_and_sells_back() -> void:
	var r := ScoreRun.setup(_repo, SEED, "exploit:salvage", &"blade")
	var w := r.floor_world()
	r.bot.start_floor(w)
	assert_true(Shop.present(w), "the floor has a shop")
	w.shards = 500
	w.actors.set_pos(0, w.shop.pos + Vector2(0.9, 0.0))
	var opened := false
	for t in 8:
		var f := InputFrame.new()
		f.pressed = InputFrame.INTERACT
		w.step(f)
		if w.shop.open:
			opened = true
			break
	assert_true(opened, "the shop opened")
	for t in 20:
		w.step(r.bot.frame(w))
		if not w.shop.open:
			break
	var log := r.bot.salvage_log
	assert_gt(log.size(), 0, "at least one trade")
	for e: Array in log:
		assert_gt(int(e[1]), 0, "a price was paid")
		assert_lt(int(e[2]), int(e[1]), "sold back for less than it cost: no loop (%s)" % str(e))
	assert_false(w.shop.open, "it closes the shop when done")


## The route (so M-FLOOR and M-RUN can be measured once bots survive): with its HP topped up after every tick (a
## test-side write, never in the scorecard), competent walks floor 1's rooms, opens rewards, shops, seals the boss
## door, kills the boss and takes the portal.
func test_competent_can_finish_a_floor() -> void:
	var r := ScoreRun.play(_repo, 20261001, "competent", &"gun", "average", 1, 20 * 3600, true)
	var f: Dictionary = r["floors"][0]
	assert_eq(f["result"], "next", "the portal was taken")
	assert_gt(int(f["door_tick"]), 0, "the boss door sealed")
	assert_gt(int(f["boss_ticks"]), 0, "the boss died")
	assert_gte((r["rooms"] as Array).size(), 8, "it walked the floor")
	assert_gte((r["offers"] as Array).size(), 3, "it opened rewards")
	var shop := false
	for o: Dictionary in r["offers"]:
		shop = shop or o["source"] == "shop"
	assert_true(shop, "it used the shop")


func test_chain_exploit_starts_with_every_combo_item() -> void:
	var r := ScoreRun.setup(_repo, SEED, "exploit:chain", &"blade")
	var w := r.floor_world()
	for c in w.combo_tables:
		for k in [c.item_a, c.item_b]:
			if k >= 0:
				assert_true(w.items_owned.has(k), "owns %s" % w.item_tables[k].id)
	var plain := ScoreRun.setup(_repo, SEED, "competent", &"blade").floor_world()
	assert_eq(plain.items_owned.size(), 0, "other policies start with nothing")
