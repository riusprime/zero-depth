extends SceneTree
## v0.10.5 O15: how often each enemy duo appears per floor. For each of floors 1-4 and SEEDS seeds, builds the real
## floor, leaves the hero standing (invulnerable), clears the enemies every 120 ticks and runs TICKS ticks of floor
## time; counts the seeds in which each duo fired at least once. Writes nothing; paste the output into evidence.
##   godot --headless --path . -s scripts/checks/pairing_counts.gd

const SEEDS := 100
const TICKS := 5400  # 90 s of floor time
const FLOORS := [1, 2, 3, 4]


func _initialize() -> void:
	NavField.skip_build = true
	var repo := ContentRepository.load_all()
	var names: Array[StringName] = []
	var counts := {}  # floor -> PackedInt32Array per row
	for floor_i: int in FLOORS:
		for s in range(1, SEEDS + 1):
			var run := SaveLab.run_state(s, floor_i, &"blade", 0, repo)
			var w := SaveLab.build_floor(run, &"", repo)
			if w.spawner == null or w.spawner.pairings == null:
				continue
			names = w.spawner.pairings.name_keys
			if not counts.has(floor_i):
				counts[floor_i] = PackedInt32Array()
				counts[floor_i].resize(names.size())
			w.actors.invuln[0] = 1 << 24
			for t in TICKS:
				w.step(InputFrame.new())
				if t % 120 == 119:
					_clear(w)
			for r in w.pairs_seen:
				counts[floor_i][r] += 1
	print(
		(
			"seeds with the duo at least once in %d ticks, of %d (hero standing, enemies cleared every 120 ticks)"
			% [TICKS, SEEDS]
		)
	)
	for floor_i: int in FLOORS:
		if counts.has(floor_i):
			print("floor %d: %s" % [floor_i, ", ".join(_row(names, counts[floor_i]))])
	NavField.skip_build = false
	quit()


func _row(names: Array[StringName], c: PackedInt32Array) -> PackedStringArray:
	var out := PackedStringArray()
	for r in names.size():
		out.append("%s %d" % [names[r], c[r]])
	return out


func _clear(w: World) -> void:
	for i in range(1, w.actors.size()):
		if w.actors.teams[i] == ActorStore.TEAM_ENEMY and w.actors.dead[i] == 0:
			w.actors.invuln[i] = 0
			Damage.hit(w, i, 99999, 1, 1, 1, 0, w.actors.pos(i), w.actors.pos(i))
