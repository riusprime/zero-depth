extends SceneTree
## The same fights with the enemy kernels in GDScript and native (NATIVE_CORE.md §7.6, the side-by-side; owner L16:
## not the same bits, the same game). For each seed: horde_phases' floor-3 world (its horde spots: the start hall and
## its neighbours), --enemies of the horde kinds placed at once and none after, FightBot playing (its own seed), the
## hero too tough to die. Per run: the tick half and all of the enemies are dead (or "-" within --ticks), the damage
## the hero took, and the enemies alive every 600 ticks. Then the means over the seeds and the largest difference
## between the two runs of one seed. Writes nothing tracked; paste the output into evidence by hand.
##   godot --headless --path . -s scripts/checks/native_compare.gd -- [--seeds=20] [--enemies=40] [--ticks=3600]
##     [--native=move,ai]   (the kernels of the native run; it stops if the library is missing)

const BENCH := preload("res://scripts/bench/sim_bench.gd")
const FIRST_SEED := 20261101
const HERO_HP := 1000000
const SAMPLE := 600
const KINDS: Array[int] = [
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.NEEDLE,
	ActorStore.Kind.WARDEN,
	ActorStore.Kind.ARC_CASTER,
	ActorStore.Kind.BOMB_DRONE,
	ActorStore.Kind.SWARMER,
	ActorStore.Kind.SPLITTER,
	ActorStore.Kind.SHIELD_BEARER,
	ActorStore.Kind.MENDER,
	ActorStore.Kind.MINE_LAYER,
	ActorStore.Kind.SNIPER,
	ActorStore.Kind.DUST_MITE,
]


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var seeds := int(args.get("--seeds", 20))
	var enemies := int(args.get("--enemies", 40))
	var ticks := int(args.get("--ticks", 3600))
	var native := NativeSwitch.parse(String(args.get("--native", "move,ai")))
	if native <= 0 or NativeSwitch.install(native) != native:
		push_error("native_compare: --native names no kernel, or the native library is not loaded")
		quit(1)
		return
	NativeSwitch.install(0)
	print(
		(
			"native_compare seeds=%d enemies=%d ticks=%d native=%s"
			% [seeds, enemies, ticks, NativeWorld.names_of(native)]
		)
	)
	var repo := ContentRepository.load_all()
	var rows := {0: [], native: []}
	for s in seeds:
		for mode: int in [0, native]:
			NativeSwitch.install(mode)
			var r := _fight(repo, FIRST_SEED + s, enemies, ticks)
			(rows[mode] as Array).append(r)
			print(
				(
					"seed %d %-7s half %5s  all %5s  damage %6d  alive %s"
					% [
						FIRST_SEED + s,
						"off" if mode == 0 else "native",
						_tick(r["half"]),
						_tick(r["all"]),
						r["damage"],
						str(r["alive"])
					]
				)
			)
	NativeSwitch.install(0)
	_summary(rows[0], rows[native])
	quit(0)


func _fight(repo: ContentRepository, run_seed: int, enemies: int, ticks: int) -> Dictionary:
	var w: World = BENCH._floor_world(repo, run_seed, 3)
	w.spawner = null
	var spots: PackedVector2Array = BENCH._horde_spots(w)
	var placed := 0
	var k := 0
	while placed < enemies and k < enemies * KINDS.size():
		var kind := KINDS[k % KINDS.size()]
		if w.enemy_table(kind) != null:
			w.add_enemy(kind, spots[(k * 7) % spots.size()])
			placed += 1
		k += 1
	w.actors.hp[0] = HERO_HP
	w.actors.max_hp[0] = HERO_HP
	var bot := FightBot.new(run_seed + 3)
	var damage := 0
	var half := -1
	var all := -1
	var alive_at := PackedInt32Array()
	for t in ticks:
		var hp := w.actors.hp[0]
		w.step(bot.frame(w))
		damage += maxi(0, hp - w.actors.hp[0])
		var alive := _alive(w)
		if half < 0 and alive <= placed / 2:
			half = t + 1
		if all < 0 and alive == 0:
			all = t + 1
		if t % SAMPLE == SAMPLE - 1:
			alive_at.append(alive)
	return {"half": half, "all": all, "damage": damage, "alive": alive_at}


static func _alive(w: World) -> int:
	var n := 0
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 0 and EnemyAi.is_enemy_kind(w.actors.kinds[i]):
			n += 1
	return n


static func _tick(t: int) -> String:
	return "-" if t < 0 else str(t)


func _summary(off: Array, on: Array) -> void:
	for key: String in ["half", "all", "damage"]:
		var a := _mean(off, key)
		var b := _mean(on, key)
		var worst := 0
		var worst_seed := -1
		var reached := [0, 0]
		for s in off.size():
			var x: int = off[s][key]
			var y: int = on[s][key]
			reached[0] += 1 if x >= 0 else 0
			reached[1] += 1 if y >= 0 else 0
			if x >= 0 and y >= 0 and absi(x - y) > worst:
				worst = absi(x - y)
				worst_seed = FIRST_SEED + s
		print(
			(
				"mean %-6s off %9.1f  native %9.1f  (runs that reached it: off %d, native %d)  largest diff %d (seed %d)"
				% [key, a, b, reached[0], reached[1], worst, worst_seed]
			)
		)
	var samples: int = (off[0]["alive"] as PackedInt32Array).size() if not off.is_empty() else 0
	for j in samples:
		var sa := 0.0
		var sb := 0.0
		var worst := 0
		for s in off.size():
			var x: int = (off[s]["alive"] as PackedInt32Array)[j]
			var y: int = (on[s]["alive"] as PackedInt32Array)[j]
			sa += x
			sb += y
			worst = maxi(worst, absi(x - y))
		print(
			(
				"mean alive at tick %5d  off %6.2f  native %6.2f  largest diff %d"
				% [(j + 1) * SAMPLE, sa / off.size(), sb / off.size(), worst]
			)
		)


## The mean of `key` over the runs that reached it (a tick of -1 is a run that didn't).
static func _mean(runs: Array, key: String) -> float:
	var sum := 0.0
	var n := 0
	for r: Dictionary in runs:
		if int(r[key]) >= 0:
			sum += int(r[key])
			n += 1
	return sum / n if n > 0 else -1.0
