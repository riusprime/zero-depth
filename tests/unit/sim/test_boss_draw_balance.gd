extends GutTest
## v0.10.5 W3-S1 (owner: "Warlord appears on Floor 1 in practically every run"): floor 1's boss draw is measured over
## 300 run seeds made the way a real run makes them (RunSeeds.next(): 1 + randi() % 0x7FFFFFFE, here from a fixed-seed
## RandomNumberGenerator so the test is repeatable) and over the consecutive seeds 1..300. Each boss of the pool must
## come up in 40-60 % of them.

const RUNS := 300


func _counts(seeds: Array) -> Dictionary:
	var repo := ContentRepository.load_all()
	var ids := BossLab.tables().map(func(x: BossTable) -> StringName: return x.id)
	var counts := {}
	for s in seeds:
		var lab := RunLab.new(repo, s, &"blade")
		var pools := RunContentCompiler.compile_boss_pools(repo, lab.run.table.floors)
		var id: StringName = ids[FloorShape.boss(lab.run, pools, 1)]
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


func _check(label: String, seeds: Array) -> void:
	var counts := _counts(seeds)
	print("BOSS DRAW %s: %s of %d" % [label, counts, seeds.size()])
	for id in [&"gatekeeper", &"warlord"]:
		var share := float(counts.get(id, 0)) / seeds.size()
		assert_between(
			share, 0.40, 0.60, "%s: floor 1 draws %s in %.1f %%" % [label, id, share * 100.0]
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
