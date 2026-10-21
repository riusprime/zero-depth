extends SceneTree
## v0.8.0 RR (owner O33: "Game-breaking combinations should occur approximately once every 10–15 runs"): the odds of a
## complete broken build, by Monte Carlo over the game's own reward draws (Offers.draw for altars, chests and the
## shop; Offers.roll_legendary for the boss's altar, LegendaryTable.extra_picks per loop), on worlds built from the
## shipped content. Not the bot balance suite: no fight is simulated, only what the cards offer and a build-seeking
## pick. Prints the tables and writes build/rarity_odds.txt; paste it into evidence by hand.
##   godot --headless --path . -s scripts/checks/rarity_odds.gd -- runs=4000 loops=5
## Optional overrides to try other numbers without editing the data (the shipped data is the default):
##   boss=0.15 boss_loop=0.1 altar=0.02 chest=0.05
##   pacing=0 (v0.8.0 FL: without the floor pacing table, data/rewards/pacing.tres; the boss's altar still has FL's
##   choices, since the level-5 grant is gone from the code)
##
## v0.8.0 FL: the floor's pacing (LootPacing) weighs every draw and caps the levels; the floor's guaranteed altars
## replace a card as Offers.roll does. The jackpot is left out (it needs a placed reward; BV's loot_sample has it).
##
## The run model (docs/roadmap/v0.8.0/evidence/RARITY.md "Model"): a loop is 3 floors; each floor has the shipped
## reward counts (altars_min..altars_max altars, capped at altars_cap with the rest chests, plus chests_min..chests_max
## chests), every altar and chest opened (shards are not modelled: an upper bound), the shop's stock on the floors
## FloorCadence puts it (every card the player wants bought, up to max_buys), and the boss's altar with its picks.
## Events, elites' and bosses' cores, Deep floors' epic altars and rerolls are left out: none of them offers a
## Legendary card (ItemPool.available without `legendary`).
##
## The player: takes a Legendary card whenever one is offered; else a piece of a broken build it doesn't hold; else
## a card that takes no wand slot (a stat card, an ability); else the first card. A wand card it can't fit (slots full)
## replaces a slot holding no broken-build piece, or is passed over.

const BUILDS: Array[StringName] = [&"blade", &"gun"]
## A broken build (RARITY.md "What counts as broken"): every group of a recipe has one card held. Groups are lists of
## item ids (any one of them).
const RECIPES := {
	&"gun":
	[
		[
			"chain_blast + split + spread|twin",
			[["chain_blast"], ["split_shot"], ["gun_spread", "gun_twin"]]
		],
		[
			"on_hit_x2 + explosive|chain + spread|twin|split",
			[
				["trigger_on_hit_twice"],
				["shared_explosive", "chain_blast"],
				["gun_spread", "gun_twin", "split_shot"]
			]
		],
		[
			"on_kill_x2 + explosive|chain",
			[["trigger_on_kill_twice"], ["shared_explosive", "chain_blast"]]
		],
		[
			"on_end_x2 + explosive|chain + spread|twin",
			[
				["trigger_on_end_twice"],
				["shared_explosive", "chain_blast"],
				["gun_spread", "gun_twin"]
			]
		],
	],
	&"blade":
	[
		[
			"chain_blast + double_slash + on_hit|on_hit_x2",
			[["chain_blast"], ["double_slash"], ["trigger_on_hit", "trigger_on_hit_twice"]]
		],
		[
			"on_hit_x2 + explosive|chain + double_slash",
			[["trigger_on_hit_twice"], ["shared_explosive", "chain_blast"], ["double_slash"]]
		],
		[
			"on_kill_x2 + explosive|chain",
			[["trigger_on_kill_twice"], ["shared_explosive", "chain_blast"]]
		],
		[
			"on_end_x2 + explosive|chain + split_wave|double_slash",
			[
				["trigger_on_end_twice"],
				["shared_explosive", "chain_blast"],
				["split_wave", "double_slash"]
			]
		],
	],
}

var runs := 4000
var loops := 5
var _over := {}
var _repo: ContentRepository
var _ids := {}  # item id -> index, per world (the same content: one map)


func _initialize() -> void:
	var args := ScriptArgs.parse()
	runs = int(args.get("runs", runs))
	loops = int(args.get("loops", loops))
	for k in ["boss", "boss_loop", "altar", "chest", "pacing"]:
		if args.has(k):
			_over[k] = float(args[k])
	_repo = ContentRepository.load_all()
	var lines := PackedStringArray()
	lines.append("rarity_odds: runs=%d loops=%d overrides=%s" % [runs, loops, _over])
	var probe := _world(1, &"gun")
	lines.append(_tables_line(probe))
	for b in BUILDS:
		lines.append_array(_survey(b))
	DirAccess.make_dir_recursive_absolute("res://build")
	var f := FileAccess.open("res://build/rarity_odds.txt", FileAccess.WRITE)
	for l in lines:
		print(l)
		if f != null:
			f.store_line(l)
	quit(0)


func _tables_line(w: World) -> String:
	var r := w.reward_table
	var t := w.legendary_table
	return (
		(
			"weights per mille of a common card: altar rare %d epic %d legendary %d; chest/shop rare %d epic %d"
			+ " legendary %d; boss Legendary chance loop1..5 %s; boss picks loop1..5 %s"
		)
		% [
			r.rare_weight_altar * 1000,
			r.epic_permille_altar,
			r.legendary_permille_altar,
			r.rare_weight_chest * 1000,
			r.epic_permille_chest,
			r.legendary_permille_chest,
			[t.chance(1), t.chance(2), t.chance(3), t.chance(4), t.chance(5)],
			[
				1 + t.extra_picks(1),
				1 + t.extra_picks(2),
				1 + t.extra_picks(3),
				1 + t.extra_picks(4),
				1 + t.extra_picks(5)
			]
		]
	)


## A run's world for `build`, as main.gd builds its card state (items, abilities, stat cards, rewards, heat, the
## wand, the legendary tier), with the overrides applied.
func _world(seed_value: int, build: StringName) -> World:
	var w := CardPoolSurvey.world(_repo, seed_value, build, [])
	w.wand_table = WandCompiler.from_repo(_repo)
	w.legendary_table = RunContentCompiler.compile_legendary(
		_repo.get_def(&"legendary", &"boss"), w.stat_tables, w.item_tables
	)
	if _over.has("boss"):
		w.legendary_table.card_permille = int(round(_over["boss"] * 1000.0))
	if _over.has("boss_loop"):
		w.legendary_table.card_loop_permille = int(round(_over["boss_loop"] * 1000.0))
	if _over.has("altar"):
		w.reward_table.legendary_permille_altar = int(round(_over["altar"] * 1000.0))
	if _over.has("chest"):
		w.reward_table.legendary_permille_chest = int(round(_over["chest"] * 1000.0))
	if not (_over.has("pacing") and _over["pacing"] == 0.0):  # v0.8.0 FL
		w.loot_pacing = RunContentCompiler.compile_loot_pacing(
			_repo.get_def(&"loot_pacing", &"pacing")
		)
	if _ids.is_empty():
		for k in w.item_tables.size():
			_ids[String(w.item_tables[k].id)] = k
	return w


func _survey(build: StringName) -> PackedStringArray:
	var sdef: ShopDefinition = _repo.get_def(&"shop", &"terminal")
	var every := sdef.every_floors
	var first := sdef.first_floor
	var max_buys := sdef.max_buys
	var stock := sdef.offer_size
	var recipes: Array = RECIPES[build]
	var broken_by_floor := PackedInt32Array()
	broken_by_floor.resize(loops * 3)
	var legend_by_loop := PackedFloat64Array()
	legend_by_loop.resize(loops)
	var from_boss := 0
	var from_other := 0
	var by_recipe := PackedInt32Array()
	by_recipe.resize(recipes.size())
	var offered_l1 := 0  # runs offered at least one Legendary card in loop 1
	for r in runs:
		var w := _world(90001 + r, build)
		var layout := RngStream.new(777000 + r)  # the reward counts (the game draws them from the loot stream)
		var seen := false
		var done := false
		for loop in range(1, loops + 1):
			w.loop = loop
			for fl in range(1, 4):
				var run_floor := (loop - 1) * 3 + fl
				w.floor_index = fl
				w.run_floor = run_floor
				w.loot_guaranteed = 0  # v0.8.0 FL: a new floor's guarantee
				var t := w.reward_table
				var altars := layout.range_int(t.altars_min, t.altars_max)
				var chests := layout.range_int(t.chests_min, t.chests_max)
				if t.altars_cap > 0 and altars > t.altars_cap:
					chests += altars - t.altars_cap
					altars = t.altars_cap
				for a in altars:
					var o := LootPacing.guarantee(w, Offers.draw(w, false, t.offer_size))  # v0.8.0 FL
					seen = seen or (loop == 1 and _has_legend(w, o))
					from_other += _take(w, build, o, false)
				for c in chests:
					var o := Offers.draw(w, true, Offers.CHEST_CARDS)  # v0.8.0 N7: one card, no choice
					seen = seen or (loop == 1 and _has_legend(w, o))
					from_other += _take(w, build, o, false)
				if FloorCadence.on(run_floor, first, every):
					var o := Offers.draw(w, true, stock)
					seen = seen or (loop == 1 and _has_legend(w, o))
					for k in max_buys:
						var got := _take(w, build, o, false, true)
						if got < 0:
							break
						from_other += got
						o = _without_held(w, o)
				for p in 1 + w.legendary_table.extra_picks(loop):
					var o := Offers.roll_legendary(w)
					seen = seen or (loop == 1 and _has_legend(w, o))
					from_boss += _take(w, build, o, true)
				var k := _broken(w, recipes)
				if k >= 0:
					broken_by_floor[run_floor - 1] += 1
					if not done:
						by_recipe[k] += 1
					done = true
			legend_by_loop[loop - 1] += _legends_held(w)
		if seen:
			offered_l1 += 1
	var out := PackedStringArray()
	out.append("== %s: %d runs ==" % [build, runs])
	out.append(
		(
			"runs offered >= 1 Legendary card in loop 1: %d (%.2f %%)"
			% [offered_l1, 100.0 * offered_l1 / runs]
		)
	)
	for fl in broken_by_floor.size():
		out.append(
			(
				"broken build held by loop %d floor %d (run floor %d): %d (%.2f %%)"
				% [
					fl / 3 + 1,
					fl % 3 + 1,
					fl + 1,
					broken_by_floor[fl],
					100.0 * broken_by_floor[fl] / runs
				]
			)
		)
	for l in loops:
		out.append(
			(
				"expected Legendary cards held at the end of loop %d: %.3f"
				% [l + 1, legend_by_loop[l] / runs]
			)
		)
	var total := maxi(1, from_boss + from_other)
	(
		out
		. append(
			(
				"Legendary cards taken over %d loops: %d from bosses (%.1f %%), %d from altars/chests/shop"
				% [loops, from_boss, 100.0 * from_boss / total, from_other]
			)
		)
	)
	for k in recipes.size():
		out.append("first broken recipe: %s: %d" % [recipes[k][0], by_recipe[k]])
	return out


func _has_legend(w: World, offer: PackedInt32Array) -> bool:
	for c in offer:
		if Offers.type_of(c) == Offers.MOD and w.item_tables[c].rarity == ItemTable.LEGENDARY:
			return true
	return false


func _without_held(w: World, offer: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in offer:
		if (
			Offers.type_of(c) == Offers.MOD
			and w.items_owned.has(c)
			and not CardLevels.can_take(w, c)
		):
			continue
		out.append(c)
	return out


## Takes one card of `offer` by the player's rule (class doc). Returns 1 when it took a Legendary card, 0 otherwise,
## and (with `optional`, the shop) -1 when nothing in the offer is worth buying.
func _take(
	w: World, build: StringName, offer: PackedInt32Array, _boss: bool, optional: bool = false
) -> int:
	if offer.is_empty():
		return -1 if optional else 0
	var wanted := _wanted(w, build)
	var best := -1
	var rank := 99
	for k in offer.size():
		var c := offer[k]
		var r := 4
		if Offers.type_of(c) == Offers.MOD:
			var t := w.item_tables[c]
			if t.rarity == ItemTable.LEGENDARY and not w.items_owned.has(c):
				r = 0
			elif wanted.has(String(t.id)) and not w.items_owned.has(c):
				r = 1
			elif not BuildSlots.is_slot_item(t):
				r = 2
		else:
			r = 2 if not BuildSlots.is_modifier(w, c) else 3
		if r < rank and _fits(w, c, wanted):
			rank = r
			best = k
	if optional and rank > 1:
		return -1
	if best < 0:
		best = 0
	var code := offer[best]
	if not _fits(w, code, wanted):
		return -1 if optional else 0
	var legend := (
		Offers.type_of(code) == Offers.MOD and w.item_tables[code].rarity == ItemTable.LEGENDARY
	)
	BuildSlots.take(w, code, _replace(w, code, wanted))  # v0.8.0 FL: no level-5 grant at the boss's altar
	return 1 if legend else 0


func _fits(w: World, code: int, wanted: Dictionary) -> bool:
	return not BuildSlots.needs_swap(w, code) or _replace(w, code, wanted) >= 0


## The slot a new modifier replaces when the slots are full: the first holding no broken-build piece and no Legendary
## card; -1 when every slot holds one (or no swap is needed).
func _replace(w: World, code: int, wanted: Dictionary) -> int:
	if not BuildSlots.needs_swap(w, code):
		return -1
	for s in w.mod_slots.size():
		var c := w.mod_slots[s]
		if Offers.type_of(c) == Offers.MOD and c < w.item_tables.size():
			var t := w.item_tables[c]
			if wanted.has(String(t.id)) or t.rarity == ItemTable.LEGENDARY:
				continue
		return s
	return -1


## The item ids of every broken recipe's pieces for `build` (a set).
func _wanted(_w: World, build: StringName) -> Dictionary:
	var out := {}
	for rec: Array in RECIPES[build]:
		for group: Array in rec[1]:
			for id: String in group:
				out[id] = true
	return out


## The first recipe of `recipes` the build holds whole, or -1.
func _broken(w: World, recipes: Array) -> int:
	for k in recipes.size():
		var whole := true
		for group: Array in recipes[k][1]:
			var any := false
			for id: String in group:
				any = any or (_ids.has(id) and w.items_owned.has(_ids[id]))
			whole = whole and any
		if whole:
			return k
	return -1


func _legends_held(w: World) -> int:
	var n := 0
	for idx in w.items_owned:
		if w.item_tables[idx].rarity == ItemTable.LEGENDARY:
			n += 1
	return n
