class_name TuningRun
extends RefCounted
## One tuning run (v0.4.0 TU): a whole run (RunLab) played by the expected-build bot (RunBot), floor after floor,
## until it dies, wins, or a floor runs out of time. Per floor it records what evidence/TUNING.md reports:
## - door_s: seconds from the floor's start to the boss door sealing (-1: never reached);
## - floor_s: seconds on the floor in all; result: "next", "won", "died_floor", "died_boss" or "timeout";
## - kills (before the door), cards by 2 min, 5 min and at the floor's end; shards at the door;
## - peak_alive: the most enemies alive at once (spawner and summons, not the boss);
## - ttk: [minute, ticks] for every normal enemy killed (first hit by the player's side to its death; Swarmers,
##   Splitlings, boss summons and bosses excluded), so medians over time can be taken;
## - first_chest_s: when the first chest was opened (-1: none).
## The bot's world is never written to: what happens is what the game does.

## A floor that runs this long is called a timeout (20 min, past M-FLOOR's 15 plus a boss fight).
const FLOOR_LIMIT_TICKS := 20 * 60 * 60
## Kinds left out of the time-to-kill (one-hit chaff and summons).
const TTK_EXCLUDED: Array[int] = [
	ActorStore.Kind.SWARMER, ActorStore.Kind.SPLITLING, ActorStore.Kind.HATCHLING,
	ActorStore.Kind.LENS_DRONE
]


static func run(
	repo: ContentRepository,
	run_seed: int,
	build: StringName,
	floors: int = 3,
	floor_limit_ticks: int = FLOOR_LIMIT_TICKS,
	god: bool = false
) -> Dictionary:
	var lab := RunLab.new(repo, run_seed, build)
	var bot := RunBot.new(run_seed * 977 + (1 if build == &"gun" else 0))
	var out := {"seed": run_seed, "build": String(build), "floors": []}
	for f in floors:
		var w := lab.floor_world()
		bot.start_floor(w)
		var rec := play_floor(w, bot, floor_limit_ticks, god)
		rec["floor"] = lab.run.floor_index
		out["floors"].append(rec)
		if rec["result"] != "next":
			break
		lab.next_floor(w)
	return out


## `god`: the player's HP is topped up after every tick (a test-side write: only to check the bot's route, never
## for evidence of difficulty).
static func play_floor(w: World, bot: RunBot, limit: int, god: bool = false) -> Dictionary:
	var start := w.tick
	var cards0 := bot.cards_taken
	var rec := {
		"door_s": -1.0,
		"kills": 0,
		"cards_2m": -1,
		"cards_5m": -1,
		"cards_end": 0,
		"shards_door": 0,
		"peak_alive": 0,
		"ttk": [],
		"first_chest_s": -1.0,
		"died_s": -1.0,
		"result": "timeout",
	}
	var first_hit := {}
	var kinds := {}
	var seq := w.last_event_seq()
	var me := w.actors.ids[0]
	var chest_ids := {}
	for i in w.rewards.size():
		if w.rewards.kind[i] == RewardStore.Kind.CHEST:
			chest_ids[w.rewards.ids[i]] = true
	for t in limit:
		w.step(bot.frame(w))
		var el := w.tick - start
		if god and not w.player_dead():
			w.actors.hp[0] = w.actors.max_hp[0]
		if el == 2 * 3600:
			rec["cards_2m"] = bot.cards_taken - cards0
		if el == 5 * 3600:
			rec["cards_5m"] = bot.cards_taken - cards0
		if w.last_event_seq() != seq:
			for e in w.events_since(seq):
				match e.kind:
					SimEvent.Kind.DAMAGE:
						if e.target_id != me and not first_hit.has(e.target_id):
							first_hit[e.target_id] = e.tick
							var i := w.actors.index_of(e.target_id)
							kinds[e.target_id] = w.actors.kinds[i] if i >= 0 else -1
					SimEvent.Kind.KILL:
						var k: int = kinds.get(e.target_id, -1)
						if (
							first_hit.has(e.target_id)
							and EnemyAi.is_enemy_kind(k)
							and not TTK_EXCLUDED.has(k)
						):
							rec["ttk"].append(
								[(e.tick - start) / 3600, e.tick - int(first_hit[e.target_id])]
							)
					SimEvent.Kind.PICKUP:
						if chest_ids.has(e.source_id) and rec["first_chest_s"] < 0.0:
							rec["first_chest_s"] = el / 60.0
			seq = w.last_event_seq()
		if w.tick % 30 == 0:
			rec["peak_alive"] = maxi(rec["peak_alive"], WaveDirector.enemies_alive(w))
		if rec["door_s"] < 0.0 and w.boss_flow != null and w.boss_flow.door_sealed():
			rec["door_s"] = el / 60.0
			rec["kills"] = w.kills
			rec["shards_door"] = w.shards
		if w.player_dead():
			rec["died_s"] = el / 60.0
			rec["result"] = "died_boss" if rec["door_s"] >= 0.0 else "died_floor"
			break
		var reader_outcome := 0
		if w.boss_flow != null and w.boss_flow.exited():
			reader_outcome = 1 if w.floor_index >= w.floor_count else 3
		if reader_outcome != 0:
			rec["result"] = "won" if reader_outcome == 1 else "next"
			break
	if rec["door_s"] < 0.0:
		rec["kills"] = w.kills
	rec["cards_end"] = bot.cards_taken - cards0
	rec["floor_s"] = (w.tick - start) / 60.0
	rec["chests_on_floor"] = chest_ids.size()
	return rec


## The median of `values` (0 when empty).
static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var v := values.duplicate()
	v.sort()
	var n := v.size()
	return float(v[n / 2]) if n % 2 == 1 else (float(v[n / 2 - 1]) + float(v[n / 2])) * 0.5
