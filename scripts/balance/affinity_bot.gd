extends SceneTree
## v0.9.0 RB K1-K2 (owner, PLAN "Owner decisions" RB: "The balance checks K1-K3 run as proposed: numbers reported,
## nothing retuned blind"; docs/roadmap/v0.9.0/AFFINITIES.md K1, K2): every Gun form x every affinity (10 x 6) played
## by the bot over a fixed seed set, five floors a run, built the way Main builds them (FloorPlan: the affinity locked
## into the run, its state on every floor, the carry between floors).
## The bot is FightBot (the readable-cause and bench bot; SaveLab.frame adds Skill and Vent now and then) on a Gun run:
## floor 1 starts with the form's card (none for the Orbs); at each floor's start it takes PICKS cards, each the first
## of an altar's draw (ItemPool.draw_weighted: the affinity's offer bias applies) that the wand takes
## (BuildSlots.take); FLOOR_TICKS on the floor's spawning, then into the boss room for at most BOSS_TICKS. A floor is
## cleared when its boss falls; the run ends at a death, a boss not beaten in time, or after floor 5.
## Per form x affinity: the floor reached (mean of the last floor entered, 1-5) and the clear rate (floors cleared over
## the floors a run could clear, 5 a seed, in %). K2 (starting values): no affinity is the best for more than 4 of the
## 10 forms, and every affinity's mean clear rate is within 5 points of None's. Prints the tables and writes
## build/balance/affinity_k1.txt; copy the printed output into evidence by hand. Retunes nothing.
##   godot --headless --path . -s scripts/balance/affinity_bot.gd -- seeds=5

const FORMS: Array = [
	[&"orbs", &""],
	[&"laser", &"gun_laser"],
	[&"bomb", &"gun_bomb"],
	[&"void", &"gun_void"],
	[&"lance", &"gun_lance"],
	[&"rune_explosion", &"gun_rune_explosion"],  # v0.9.5 FC0: replaces the Scatter
	[&"glaive", &"gun_glaive"],
	[&"seekers", &"gun_seekers"],
	[&"wave", &"gun_wave"],
	[&"wisps", &"gun_wisps"],
]
const AFFINITIES: Array[StringName] = [
	&"none", &"ember", &"storm", &"venom", &"astral", &"guardian"
]
## The fixed seed set (the first `seeds` of them).
const SEEDS: Array[int] = [1101, 2202, 3303, 4404, 5505, 6606, 7707, 8808, 9909, 10010]
const FLOORS := 5
const FLOOR_TICKS := 2400
const BOSS_TICKS := 3600
const PICKS := 2

var _repo: ContentRepository
## Per form x affinity, summed over its seeds: ticks survived, kills, deaths in a boss room.
var _ticks := 0
var _kills := 0
var _died_boss := 0


func _initialize() -> void:
	var seeds := 5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = clampi(int(a.trim_prefix("seeds=")), 1, SEEDS.size())
	var t0 := Time.get_ticks_msec()
	_repo = ContentRepository.load_all()
	var lines := PackedStringArray()
	(
		lines
		. append(
			(
				"K1: %d forms x %d affinities x %d seeds %s, %d floors, floor %d ticks + boss %d ticks, %d picks a floor"
				% [
					FORMS.size(),
					AFFINITIES.size(),
					seeds,
					str(SEEDS.slice(0, seeds)),
					FLOORS,
					FLOOR_TICKS,
					BOSS_TICKS,
					PICKS
				]
			)
		)
	)
	(
		lines
		. append(
			(
				"form | affinity | floor reached (mean) | clear rate % | floors cleared / possible | deaths"
				+ " (in a boss room) | seconds survived (mean) | kills (mean)"
			)
		)
	)
	var clear := {}  # form -> affinity -> clear rate
	for f: Array in FORMS:
		clear[f[0]] = {}
		for aff: StringName in AFFINITIES:
			var reached := 0
			var cleared := 0
			var deaths := 0
			_ticks = 0
			_kills = 0
			_died_boss = 0
			for k in seeds:
				var r := _run(SEEDS[k], f[1], aff)
				reached += r[0]
				cleared += r[1]
				deaths += r[2]
			var rate := 100.0 * float(cleared) / float(seeds * FLOORS)
			clear[f[0]][aff] = rate
			(
				lines
				. append(
					(
						"%s | %s | %.2f | %.1f | %d / %d | %d (%d) | %.1f | %.1f"
						% [
							f[0],
							aff,
							float(reached) / float(seeds),
							rate,
							cleared,
							seeds * FLOORS,
							deaths,
							_died_boss,
							float(_ticks) / 60.0 / float(seeds),
							float(_kills) / float(seeds),
						]
					)
				)
			)
			print(lines[lines.size() - 1])
	lines.append_array(_k2(clear))
	lines.append("time %d s" % ((Time.get_ticks_msec() - t0) / 1000))
	var text := "\n".join(lines)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/balance"))
	var out := FileAccess.open("res://build/balance/affinity_k1.txt", FileAccess.WRITE)
	if out != null:
		out.store_string(text + "\n")
		out.close()
	quit(0)


## One run: [the last floor entered, floors cleared, 1 if it ended in a death].
func _run(seed_value: int, form: StringName, aff: StringName) -> Array:
	var plan := FloorPlan.new_run(RunSaver.RUN_ID, seed_value, &"gun", true, aff)
	plan.repo = _repo
	plan.build()
	var run := plan.run
	var biomes := plan.run_biomes
	var w := plan.world
	if form != &"":
		BuildSlots.take(w, AttackScenario.item_index(w.item_tables, form))
	var bot := FightBot.new(seed_value * 31)  # the same bot stream for every affinity
	var cleared := 0
	for f in range(1, FLOORS + 1):
		if f > 1:
			run.finish_floor(w)
			var next := FloorPlan.next_floor(run, biomes, {}, true)
			next.repo = _repo
			next.build()
			w = next.world
		_pick(w)
		var out := _floor(w, bot)
		if out == 1:
			cleared += 1
			continue
		return [f, cleared, 1 if out == -1 else 0]
	return [FLOORS, cleared, 0]


## PICKS cards at the floor's start, each the first of a 3-card altar draw the wand takes.
func _pick(w: World) -> void:
	for k in PICKS:
		var offer := ItemPool.draw_weighted(w, 3, w.reward_table.rare_weight_altar)
		for idx in offer:
			if BuildSlots.take(w, idx):
				break
	w.refresh_build(false)


## The floor then its boss: 1 cleared, -1 the hero died, 0 the boss outlasted the bot.
## Also counts the ticks survived, the kills, and where a death came (_died_boss).
func _floor(w: World, bot: FightBot) -> int:
	var out := _play(w, bot)
	_ticks += w.tick
	_kills += w.kills
	return out


func _play(w: World, bot: FightBot) -> int:
	for t in FLOOR_TICKS:
		w.step(SaveLab.frame(w, bot))
		if w.player_dead():
			return -1
	FightLab.enter_boss_room(w)
	var seen := false
	for t in BOSS_TICKS:
		w.step(SaveLab.frame(w, bot))
		if w.player_dead():
			_died_boss += 1
			return -1
		seen = seen or w.boss_id >= 0
		if seen and not w.boss_alive():
			return 1
	return 0


## K2: the best affinity per form (a unique top clear rate; ties are listed and count for no one), and each
## affinity's mean clear rate against None's.
func _k2(clear: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var best := {}
	for aff: StringName in AFFINITIES:
		best[aff] = 0
	out.append("K2 best affinity per form:")
	for f: Array in FORMS:
		var top := -1.0
		var who: Array = []
		for aff: StringName in AFFINITIES:
			var r: float = clear[f[0]][aff]
			if r > top + 0.0001:
				top = r
				who = [aff]
			elif absf(r - top) <= 0.0001:
				who.append(aff)
		if who.size() == 1:
			best[who[0]] += 1
		out.append(
			"  %s: %s (%.1f %%)%s" % [f[0], ", ".join(who), top, "" if who.size() == 1 else " tie"]
		)
	var means := {}
	for aff: StringName in AFFINITIES:
		var s := 0.0
		for f: Array in FORMS:
			s += clear[f[0]][aff]
		means[aff] = s / float(FORMS.size())
	out.append(
		"K2 affinity | forms where it is the unique best | mean clear rate % | vs None (points)"
	)
	var pass_best := true
	var pass_mean := true
	for aff: StringName in AFFINITIES:
		var d: float = means[aff] - means[&"none"]
		out.append("  %s | %d | %.1f | %+.1f" % [aff, best[aff], means[aff], d])
		pass_best = pass_best and best[aff] <= 4
		pass_mean = pass_mean and absf(d) <= 5.0
	out.append(
		(
			"K2: best for more than 4 of 10 forms: %s; every mean within 5 points of None: %s"
			% ["none over 4 (pass)" if pass_best else "FAIL", "pass" if pass_mean else "FAIL"]
		)
	)
	return out
