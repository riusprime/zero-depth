extends GutTest
## v0.10.5 W3-S1 (owner: "Warlord appears on Floor 1 in practically every run"): floor 1's boss draw is measured over
## 300 run seeds made the way a real run makes them (RunSeeds.next(): 1 + randi() % 0x7FFFFFFE, here from a fixed-seed
## RandomNumberGenerator so the test is repeatable) and over the consecutive seeds 1..300.
## v0.10.5 W3-O11 (owner F21, "Add a third boss", "Share one, scaled", "Brood Mother"): floor 1's pool is the
## Gatekeeper, the Warlord and the Brood Mother; each must come up in 25-42 % of the runs, and no run of those seeds
## meets a boss twice on floors 1-5.

const RUNS := 300
const FLOOR_1: Array[StringName] = [&"gatekeeper", &"warlord", &"brood_mother"]


## {floor 1 boss id: runs}; asserts every run's floors 1-5 meet five different bosses.
func _counts(label: String, seeds: Array) -> Dictionary:
	var repo := ContentRepository.load_all()
	var ids := BossLab.tables().map(func(x: BossTable) -> StringName: return x.id)
	var counts := {}
	var twice := 0
	var on_two := {}
	for s in seeds:
		var lab := RunLab.new(repo, s, &"blade")
		var pools := RunContentCompiler.compile_boss_pools(repo, lab.run.table.floors)
		var met := []
		for f in range(1, 6):
			met.append(ids[FloorShape.boss(lab.run, pools, f)])
		counts[met[0]] = int(counts.get(met[0], 0)) + 1
		on_two[met[1]] = int(on_two.get(met[1], 0)) + 1
		for k in met.size():
			if met.find(met[k]) != k:
				twice += 1
				assert_true(false, "%s: seed %d meets %s twice: %s" % [label, s, met[k], met])
	print(
		(
			"BOSS DRAW %s: floor 1 %s, floor 2 %s of %d; runs meeting a boss twice on floors 1-5: %d"
			% [label, counts, on_two, seeds.size(), twice]
		)
	)
	return counts


func _check(label: String, seeds: Array) -> void:
	var counts := _counts(label, seeds)
	assert_eq(
		counts.size(), FLOOR_1.size(), "%s: floor 1 draws only its three: %s" % [label, counts]
	)
	for id in FLOOR_1:
		var share := float(counts.get(id, 0)) / seeds.size()
		assert_between(
			share, 0.25, 0.42, "%s: floor 1 draws %s in %.1f %%" % [label, id, share * 100.0]
		)


func test_floor_1_boss_with_real_run_seeds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261104
	var seeds := []
	for i in RUNS:
		seeds.append(1 + int(rng.randi() % 0x7FFFFFFE))
	_check("random seeds", seeds)


func test_floor_1_boss_with_consecutive_seeds() -> void:
	var seeds := []
	for i in RUNS:
		seeds.append(i + 1)
	_check("seeds 1..300", seeds)
