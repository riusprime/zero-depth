extends SceneTree
## v0.10.5 PD: the play check for the AI cadence change. The horde_phases setup (floor 3, horde spots, FightBot,
## hero HP topped up, N horde enemies kept alive) over a few seeds for 1800 ticks (30 s). Prints attacks started
## (entries into WINDUP), the mean enemy distance to the hero, and "far idle" enemy-ticks: in MOVE, farther than its
## attack range + 1 m, moved < 0.01 m that tick (plus the longest such run of one enemy).
##   godot --headless --path . -s scripts/checks/horde_play_check.gd
## Writes nothing tracked; paste the output into evidence by hand.

const BENCH := preload("res://scripts/bench/sim_bench.gd")
const SEEDS: Array[int] = [20261007, 11, 777]
const N := 20
const TICKS := 1800
const KINDS: Array[int] = [
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.NEEDLE,
	ActorStore.Kind.WARDEN,
	ActorStore.Kind.ARC_CASTER,
	ActorStore.Kind.BOMB_DRONE
]


func _initialize() -> void:
	var repo := ContentRepository.load_all()
	for s in SEEDS:
		_run(repo, s)
	quit(0)


func _run(repo: ContentRepository, run_seed: int) -> void:
	var w: World = BENCH._floor_world(repo, run_seed, 3)
	w.spawner = null
	var spots: PackedVector2Array = BENCH._horde_spots(w)
	var bot := FightBot.new(run_seed + 3)
	var next := 0
	var attacks := 0
	var dist_sum := 0.0
	var dist_n := 0
	var idle := 0
	var longest := 0
	var prev_state := {}
	var prev_pos := {}
	var run := {}
	for t in TICKS:
		var alive := 0
		for i in range(1, w.actors.size()):
			if w.actors.dead[i] == 0 and EnemyAi.is_enemy_kind(w.actors.kinds[i]):
				alive += 1
		while alive < N:
			w.add_enemy(KINDS[next % KINDS.size()], spots[(next * 7) % spots.size()])
			next += 1
			alive += 1
		if not w.player_dead():
			w.actors.hp[0] = w.actors.max_hp[0]
		w.step(bot.frame(w))
		var hero := w.player_pos()
		for i in range(1, w.actors.size()):
			var a := w.actors
			if a.dead[i] != 0 or not EnemyAi.is_enemy_kind(a.kinds[i]):
				continue
			var id: int = a.ids[i]
			var st: int = a.state[i]
			if st == EnemyAi.State.WINDUP and prev_state.get(id, -1) != EnemyAi.State.WINDUP:
				attacks += 1
			prev_state[id] = st
			var p := a.pos(i)
			var d := (hero - p).length()
			dist_sum += d
			dist_n += 1
			var moved := (p - prev_pos.get(id, p) as Vector2).length() if prev_pos.has(id) else 1.0
			prev_pos[id] = p
			var far := d > w.enemy_table(a.kinds[i]).attack_range_m + 1.0
			if st == EnemyAi.State.MOVE and far and moved < 0.01:
				idle += 1
				run[id] = int(run.get(id, 0)) + 1
				longest = maxi(longest, run[id])
			else:
				run[id] = 0
	print(
		(
			"PLAY| seed=%d spawned=%d attacks_started=%d mean_dist=%.3f m far_idle_ticks=%d longest_idle=%d final=%s"
			% [run_seed, next, attacks, dist_sum / dist_n, idle, longest, w.state_hash()]
		)
	)
