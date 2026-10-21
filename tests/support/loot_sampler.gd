class_name LootSampler
extends RefCounted
## v0.8.0 BV (owner O91: "Measure actual offers, purchases and rerolls; weights are not run-completion
## probabilities"; docs/roadmap/v0.8.0/BALANCE_PASS.md "BV: validation"): one seeded run's loot, floor by floor, over
## the game's own reward code. Shared by scripts/checks/loot_sample.gd (the survey) and
## tests/unit/application/test_balance_tools.gd (the tool doesn't rot). No fight is simulated and no tick runs.
##
## The run: FloorPlan builds every floor as Main does (FloorPlan.new_run, then FloorPlan.next_floor after
## RunState.finish_floor: the real carry, slots 4 → 6 → 8, the catch-up, the shop's cadence, the events, the pacing
## table, the floor's guarantee and jackpots). Always the normal route (no Deep gate is taken). Per floor, in order:
## 1. Every altar and chest the floor placed (Rewards.place: its real counts and kinds), in placement order: rolled as
##    Rewards.interact rolls them (Offers.roll, Curses.on_offer_rolled, a chest's card dealt) and taken through
##    Rewards._take (the price paid, the curse of a cursed card). A chest the shards can't pay is left shut. Arena
##    locks are taken as cleared. Overrun's and an ambush's extra altars/chests are not modelled.
## 2. Every event pedestal the floor placed (Events.roll): the best card choice whose Events.block is OK, through
##    Events.take (its cost and curse); a FIGHT or DEFEND choice is taken as won (its curse, then its card). Choices
##    that give no card (shards, Overclock, a cleanse) are never taken.
## 3. `cores` elite cores stolen (a representative rate, an assumption: CoreTheft.draw_card on the elite stream at a
##    rare stat rarity, as on_elite draws one). Boss cores, Marked's card and the gamble shrine are not modelled.
## 4. The shop on the floors its cadence puts it (FloorScenario.add_shop): its stock (Shop.restock), purchases by the
##    pick rank (rank <= shop_rank) while the shards and the buy limit allow (Shop.buy), and a reroll (Shop.reroll)
##    when no unsold card ranks <= 2 ("nothing fits"), at most `rerolls` a shop.
## 5. The boss's altar (as BossReward.advance places it), every pick it gives (BossReward.another_pick).
## Shards: the carry (RunCarry, the run's shard_carry share) plus `income` shards added at each floor's entry: an
## assumption (kills are not simulated), not a measurement; the economy itself is unchanged.
##
## The pick (deterministic, the same for both weapons; lower rank first, then the offer's order; rank NEVER = pass):
## 0 a held wand card's level-up (a jackpot past the ceiling too); 1 a new wand card that LootPacing.compatible
## accepts, a mutation, or the weapon's own level-up; 2 a trigger card; 3 a stat card, another ability, a new wand
## card that isn't compatible where it lands; 4 a passive (an item outside the wand). A new wand card with every slot
## full is passed over (no swap: the slots fill to 4 / 6 / 8 as the run grows them).

const NEVER := 99
const CAT_NAMES: Array[String] = ["other", "form", "element", "advanced", "trigger", "mutation"]
const SOURCES: Array[String] = ["altar", "chest", "event", "core", "shop", "reroll", "boss"]

## Assumptions (scripts/checks/loot_sample.gd prints them).
var income := 200
var cores := 1
var rerolls := 2
var shop_rank := 3
var run_id := &"three_floors"

var _repo: ContentRepository


func _init(repo: ContentRepository) -> void:
	_repo = repo


## One run of `weapon` from `seed_value` over `loops` loops (3 floors each). One record per floor (see _floor_record).
func run(seed_value: int, weapon: StringName, loops: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var plan := FloorPlan.new_run(run_id, seed_value, weapon, false)
	plan.repo = _repo
	plan.build()
	var biomes := plan.run_biomes
	var r := plan.run
	var w := plan.world
	var state := {"jackpot_taken": 0, "early": 0}
	var floors := loops * r.table.floors
	for n in floors:
		if w == null:
			break
		out.append(_floor(w, state))
		if n == floors - 1:
			break
		if w.floor_index >= r.table.floors and w.boss_flow != null:  # the Loop device, not the run's end
			w.boss_flow.ascension = true
			w.boss_flow.ascend_choice = Ascension.Choice.LOOP
		r.finish_floor(w)
		var next := FloorPlan.next_floor(r, biomes, {}, false)
		next.repo = _repo
		next.build()
		w = next.world
	return out


## The floor's sources in order (class doc), then its record.
func _floor(w: World, state: Dictionary) -> Dictionary:
	var rec := {
		"loop": w.loop,
		"floor": w.floor_index,
		"seen": {},
		"taken": {},
		"offers": {},
		"level_ups": 0,
		"purchases": 0,
		"spent": 0,
		"rerolls": 0,
		"chests_shut": 0,
		"jackpots_seen": 0,
		"jackpots_taken": 0,
		"mutations_seen": 0,
		"mutations_taken": 0,
		"p_entry": w.catch_up.power,
		"m_entry": w.catch_up.enemy,
	}
	var shards_in := w.shards
	w.shards += income
	rec["shards_in"] = w.shards
	_rewards(w, rec, state)
	_events(w, rec, state)
	_cores(w, rec, state)
	_shop(w, rec, state)
	_boss(w, rec, state)
	rec["shards_carried_in"] = shards_in
	rec["shards_end"] = w.shards
	rec["p_end"] = CatchUp.power(w)
	rec["m_boss"] = boss_multiplier(w)
	rec["levels"] = levels(w)
	rec["wand"] = wand_text(w)
	rec["tokens"] = tokens(w)
	rec["jackpot_ever"] = state["jackpot_taken"]
	rec["early"] = state["early"]
	rec["hash"] = w.state_hash()
	return rec


func _rewards(w: World, rec: Dictionary, state: Dictionary) -> void:
	var ids := PackedInt32Array()
	for i in w.rewards.size():
		var k := w.rewards.kind[i]
		if k == RewardStore.Kind.ALTAR or k == RewardStore.Kind.CHEST:
			ids.append(w.rewards.ids[i])
	for id in ids:
		var i := w.rewards.index_of(id)
		if i < 0:
			continue
		var src := "chest" if w.rewards.kind[i] == RewardStore.Kind.CHEST else "altar"
		if not Rewards.can_afford(w, i):
			rec["chests_shut"] += 1
			continue
		_open_reward(w, i, src, rec, state)


## Rewards.interact's roll, then the pick through Rewards._take (and the boss altar's further picks).
func _open_reward(w: World, i: int, src: String, rec: Dictionary, state: Dictionary) -> void:
	var id := w.rewards.ids[i]
	if w.rewards.rolled[i] == 0:
		w.rewards.set_offer(i, Offers.roll(w, i))
		Curses.on_offer_rolled(w, i)
	var offer := w.rewards.offer_of(i)
	if offer.is_empty():
		w.rewards.remove_at(i)
		return
	if Rewards.deals(w, i):
		Rewards.deal(w, i)
		offer = w.rewards.offer_of(i)
	_count_offer(w, rec, src, offer, id)
	var k := best(w, offer)
	if k < 0:
		w.rewards.remove_at(i)
		return
	var code := offer[k]
	_count_take(w, rec, state, code, LootPacing.is_jackpot(w, id, code))
	Rewards._take(w, i, k, -1)
	if not BossReward.another_pick(w, i):
		w.rewards.remove_at(i)


func _events(w: World, rec: Dictionary, state: Dictionary) -> void:
	for k in w.ev.size():
		if w.ev.state[k] != Events.State.READY:
			continue
		if w.ev.rolled[k] == 0:
			Events.roll(w, k)
		var t := Events.table(w, k)
		var cards := PackedInt32Array()
		var choice := PackedInt32Array()
		for c in t.choice_count():
			var code := w.ev.roll_card[k * Events.MAX_CHOICES + c]
			if code < 0:
				continue
			_count_offer(w, rec, "event", PackedInt32Array([code]), -1)
			if Events.block(w, k, c) == Events.OK:
				cards.append(code)
				choice.append(c)
		var j := best(w, cards)
		if j < 0:
			continue
		var c := choice[j]
		_count_take(w, rec, state, cards[j], false)
		if t.cost[c] == Events.Cost.FIGHT or t.cost[c] == Events.Cost.DEFEND:
			w.ev.state[k] = Events.State.DONE  # taken as won: its curse, then its card
			var curse := w.ev.roll_curse[k * Events.MAX_CHOICES + c]
			if curse >= 0:
				Curses.add(w, curse)
			Offers.apply(w, cards[j])
		else:
			Events.take(w, k, c)


func _cores(w: World, rec: Dictionary, state: Dictionary) -> void:
	if not CoreTheft.enabled(w):
		return
	for n in cores:
		var code := CoreTheft.draw_card(w, w.ev.rng_elite, Stats.Rarity.RARE)
		if code < 0:
			continue
		_count_offer(w, rec, "core", PackedInt32Array([code]), -1)
		if rank(w, code) < NEVER and Shop.can_apply(w, code):
			_count_take(w, rec, state, code, false)
			Offers.apply(w, code)


func _shop(w: World, rec: Dictionary, state: Dictionary) -> void:
	if w.shop_table == null or not Shop.present(w):
		return
	Shop.restock(w)
	_count_offer(w, rec, "shop", _unsold(w), -1)
	var used := 0
	var guard := 0
	while guard < 32:
		guard += 1
		if Shop.buys_left(w) == 0:
			break
		var k := _shop_pick(w)
		if k >= 0:
			var code := w.shop.offer[k]
			var cost := Shop.price(w, code)
			if Shop.buy(w, k):
				rec["purchases"] += 1
				rec["spent"] += cost
				_count_take(w, rec, state, code, false)
				continue
		if used >= rerolls or _fits_any(w) or Shop.unsold(w) == 0:
			break
		if w.shards < Shop.reroll_price(w):
			break
		var reroll_cost := Shop.reroll_price(w)
		if not Shop.reroll(w):
			break
		used += 1
		rec["rerolls"] += 1
		rec["spent"] += reroll_cost
		_count_offer(w, rec, "reroll", _unsold(w), -1)


## The best unsold stock slot the policy buys now (rank <= shop_rank, can apply, affordable), or -1.
func _shop_pick(w: World) -> int:
	var best_k := -1
	var best_r := shop_rank + 1
	for k in w.shop.offer.size():
		var code := w.shop.offer[k]
		if code == ShopState.SOLD or not Shop.can_apply(w, code) or w.shards < Shop.price(w, code):
			continue
		var r := rank(w, code)
		if r < best_r:
			best_r = r
			best_k = k
	return best_k


## Some unsold card ranks <= 2 (a wand card that fits or the weapon's level): no reroll then.
func _fits_any(w: World) -> bool:
	for code in _unsold(w):
		if Shop.can_apply(w, code) and rank(w, code) <= 2:
			return true
	return false


static func _unsold(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for code in w.shop.offer:
		if code != ShopState.SOLD:
			out.append(code)
	return out


func _boss(w: World, rec: Dictionary, state: Dictionary) -> void:
	if w.legendary_table == null or w.floor_layout == null or w.floor_layout.boss_room < 0:
		return
	if w.legendary_id == -1:  # BossReward.advance, without the fight
		w.legendary_id = w.add_reward(RewardStore.Kind.LEGENDARY, w.floor_layout.boss_spawn, 0)
		w.legendary_picks = w.legendary_table.extra_picks(w.loop)
	var guard := 0
	while guard < 16:
		guard += 1
		var i := w.rewards.index_of(w.legendary_id)
		if i < 0:
			break
		_open_reward(w, i, "boss", rec, state)


## The index in `offer` the policy takes (lowest rank, then first), or -1 when every card is NEVER.
static func best(w: World, offer: PackedInt32Array) -> int:
	var out := -1
	var r := NEVER
	for k in offer.size():
		var c := rank(w, offer[k])
		if c < r:
			r = c
			out = k
	return out


## The pick rank of card `code` now (class doc).
static func rank(w: World, code: int) -> int:
	if code < 0:
		return NEVER
	match Offers.type_of(code):
		Offers.ABILITY:
			var a := Offers.ability_of(code)
			var weapon := w.ability_tables[a].start_weapon != 0
			return NEVER if not Abilities.can_take(w, a) else (1 if weapon else 3)
		Offers.STAT:
			return NEVER if Stats.at_cap(w, Offers.stat_of(code)) else 3
		Offers.MOD:
			return _mod_rank(w, code) if code < w.item_tables.size() else NEVER
	return NEVER  # a curse card


static func _mod_rank(w: World, code: int) -> int:
	var held := w.items_owned.has(code)
	var r := 3
	if not CardLevels.is_card(w, code):
		r = NEVER if held or BuildSlots.needs_swap(w, code) else 4
	elif held:
		r = 0 if CardLevels.level(w, code) < CardLevels.MAX_LEVEL else NEVER
	elif BuildSlots.needs_swap(w, code):
		r = NEVER
	else:
		var cat := LootPacing.category(w, code)
		if cat == LootPacing.Category.MUTATION or LootPacing.compatible(w, code):
			r = 1
		elif cat == LootPacing.Category.TRIGGER:
			r = 2
	return r


## A card's survey category: ability, stat, curse, passive, or the pacing category of a wand card.
static func category_key(w: World, code: int) -> String:
	var key := "?"
	match Offers.type_of(code):
		Offers.ABILITY:
			key = "ability"
		Offers.STAT:
			key = "stat"
		Offers.CURSE:
			key = "curse"
		Offers.MOD:
			if code >= 0 and code < w.item_tables.size():
				key = "passive"
				if CardLevels.is_card(w, code):
					var cat := clampi(LootPacing.category(w, code), 0, CAT_NAMES.size() - 1)
					key = CAT_NAMES[cat]
	return key


func _count_offer(
	w: World, rec: Dictionary, src: String, offer: PackedInt32Array, reward_id: int
) -> void:
	rec["offers"][src] = int(rec["offers"].get(src, 0)) + 1
	for code in offer:
		var key := category_key(w, code)
		rec["seen"][key] = int(rec["seen"].get(key, 0)) + 1
		if key == "mutation":
			rec["mutations_seen"] += 1
		if reward_id >= 0 and LootPacing.is_jackpot(w, reward_id, code):
			rec["jackpots_seen"] += 1


## Counted before the take (the level-up test reads the card as held or not).
func _count_take(w: World, rec: Dictionary, state: Dictionary, code: int, jackpot: bool) -> void:
	var key := category_key(w, code)
	rec["taken"][key] = int(rec["taken"].get(key, 0)) + 1
	if Offers.type_of(code) == Offers.MOD and w.items_owned.has(code):
		rec["level_ups"] += 1
	if key == "mutation":
		rec["mutations_taken"] += 1
	if jackpot:
		rec["jackpots_taken"] += 1
		state["jackpot_taken"] = 1
	# "Early": a jackpot or a mutation taken on the first loop's floor 1.
	if w.loop == 1 and w.floor_index == 1 and (jackpot or key == "mutation"):
		state["early"] = 1


## The boss's catch-up multiplier for the build now (CatchUp.on_boss's numbers, without a boss).
static func boss_multiplier(w: World) -> int:
	var t := w.catch_up_table
	if t == null:
		return 1000
	var e := CatchUpTable.at_floor(t.boss_expected_permille, w.floor_index)
	var cap := (
		CatchUp.cap_at(t.boss_cap_permille, t, w.floor_index, Curses.threat(w))
		+ w.loop_cap_permille
	)
	return CatchUp.multiplier(CatchUp.power(w), e, cap)


## Wand card levels held, [L1, L2, L3, L4, L5] counts.
static func levels(w: World) -> PackedInt32Array:
	var out := PackedInt32Array([0, 0, 0, 0, 0])
	for code in w.mod_slots:
		if Offers.type_of(code) == Offers.MOD and code < w.item_tables.size():
			if CardLevels.is_card(w, code):
				out[clampi(CardLevels.level(w, code), 1, 5) - 1] += 1
	return out


## The wand left to right, "id:level" each.
static func wand_text(w: World) -> String:
	var parts := PackedStringArray()
	for code in w.mod_slots:
		parts.append(_slot_token(w, code).trim_prefix("m:").trim_prefix("a:"))
	return " ".join(parts)


## The build as BuildFight.grant_tokens reads it: the wand's slots in order, the abilities outside it (with levels),
## the passives, then the stat cards in the order taken ("s:<code>"). Gamble stacks are left out.
static func tokens(w: World) -> String:
	var parts := PackedStringArray()
	for code in w.mod_slots:
		parts.append(_slot_token(w, code))
	for s in w.ability_owned.size():
		var a := w.ability_owned[s]
		if w.mod_slots.has(Offers.ability_code(a)):
			continue
		parts.append("a:%s:%d" % [w.ability_tables[a].id, w.ability_levels[s]])
	for idx in w.items_owned:
		if not w.mod_slots.has(idx):
			parts.append("m:%s:%d" % [w.item_tables[idx].id, CardLevels.level(w, idx)])
	for code in w.stat_cards:
		parts.append("s:%d" % code)
	return ",".join(parts)


static func _slot_token(w: World, code: int) -> String:
	match Offers.type_of(code):
		Offers.ABILITY:
			var a := Offers.ability_of(code)
			return "a:%s:%d" % [w.ability_tables[a].id, Abilities.level_of(w, a)]
		Offers.MOD:
			if code < w.item_tables.size():
				return "m:%s:%d" % [w.item_tables[code].id, CardLevels.level(w, code)]
	return "?:%d" % code
