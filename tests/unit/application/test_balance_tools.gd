extends GutTest
## v0.8.0 BV (owner O91; docs/roadmap/v0.8.0/BALANCE_PASS.md "BV: validation"): the balance tools' cores stay runnable
## (scripts/checks/loot_sample.gd over LootSampler, scripts/checks/build_fights.gd over BuildFight): one seed's
## floors of loot and 2-second fights, each deterministic. No balance target is asserted here (the evidence holds the
## measured numbers: docs/roadmap/v0.8.0/evidence/BALANCE_BV.md).

var _repo: ContentRepository


func before_all() -> void:
	_repo = AttackScenario.repo()


func test_loot_sampler_walks_three_floors_and_repeats_itself() -> void:
	var s := LootSampler.new(_repo)
	var run := s.run(1, &"gun", 1)
	assert_eq(run.size(), 3, "floors 1-3 of loop 1")
	var opened := 0
	for r in run:
		for k: String in r["offers"]:
			opened += int(r["offers"][k])
	assert_gt(opened, 0, "the floors offered cards (altars, chests, the shop, the boss)")
	assert_ne(String(run[2]["wand"]), "", "the run ends with a wand")
	var again := s.run(1, &"gun", 1)
	for k in run.size():
		assert_eq(
			again[k]["hash"], run[k]["hash"], "floor %d: the same seed, the same world" % (k + 1)
		)


func test_loot_sampler_blade_runs() -> void:
	var run := LootSampler.new(_repo).run(2, &"blade", 1)
	assert_eq(run.size(), 3)
	assert_gt(int(run[0]["p_entry"]), 0, "the catch-up read P")


func test_the_pick_never_takes_a_curse_or_a_capped_stat() -> void:
	var w := CardPoolSurvey.world(_repo, 1, &"gun", [])
	assert_eq(LootSampler.rank(w, Offers.curse_code(0)), LootSampler.NEVER)
	assert_eq(LootSampler.rank(w, -1), LootSampler.NEVER)


func test_a_named_fight_counts_damage_casts_and_projectiles_deterministically() -> void:
	var f := BuildFight.new(_repo)
	var toks := BuildFight.named_tokens("gun_multiplication", 1)
	var a := f.fight(&"gun", toks, BuildFight.Mode.PACK, 2.0)
	assert_eq(
		(a["missing"] as PackedStringArray).size(), 0, "every card granted: %s" % a["missing"]
	)
	assert_eq(a["placed"], 12, "the pack stands")
	assert_gt(a["damage"], 0, "the pack took damage")
	assert_gt(a["casts"], 0, "the Gun fired")
	assert_true(a["projectiles"] >= a["casts"], "Twin, Spread and Halo: more bolts than casts")
	assert_gt(a["p"], 1000, "three cards raise P over a fresh build")
	var b := f.fight(&"gun", toks, BuildFight.Mode.PACK, 2.0)
	assert_eq(b["hash"], a["hash"], "the same fight, the same world")


func test_a_blade_boss_fight_and_a_sampled_token_line_run() -> void:
	var f := BuildFight.new(_repo)
	var r := f.fight(&"blade", PackedStringArray(), BuildFight.Mode.BOSS, 2.0)
	assert_eq(r["placed"], 1)
	assert_gt(r["casts"], 0, "the Blade swung")
	assert_gt(r["damage"], 0, "the boss dummy took damage")
	var run := LootSampler.new(_repo).run(3, &"blade", 1)
	var toks := String(run[0]["tokens"]).split(",", false)
	var s := f.fight(&"blade", toks, BuildFight.Mode.PACK, 2.0)
	assert_eq(
		(s["missing"] as PackedStringArray).size(),
		0,
		"a sampled build grants back: %s" % s["missing"]
	)
