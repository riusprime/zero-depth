extends SceneTree
## v0.10.5 O4 (owner D46, 2026-11-01): the intensity director against weak, expected and strong scripted heroes, a
## deterministic measurement (not the bot suite). For each run seed and hero: floor `floor` of the run as Main builds
## it (SaveLab.floor_world, blade build), FightBot's input kept within LEASH_M of where it started (as N5's
## intensity_curve.gd), for `seconds` of floor time. The heroes differ only in their damage stat (WEAK / EXPECTED /
## STRONG per mille, poked into World.stat_values before the first tick); every hero is topped up to full HP between
## ticks when it falls under HEAL_BELOW of max (a poke, so it lives; counted as heals). Prints per run a line every
## 5 s (the state now, alive / cap, kills, HP %, kills in the last 10 s) when `log=1`, then a summary: peaks, each
## QUIET's length and how it ended (drawn: its drawn length with intensity relaxed; over: after its drawn length, still
## under quiet_seconds_max; max: forced at quiet_seconds_max), the build-ups' lengths (QUIET's end to PEAK; "open"
## when the run ends first), PULL_BACK's ends (near / timeout), mean alive while packs may come and overall, and
## kills per minute. Writes the same to build/director_fairness.txt. Paste into evidence by hand.
##   godot --headless --path . -s scripts/checks/director_fairness.gd -- seeds=11,12,13,14,15 seconds=300 log=0

const OUT := "res://build/director_fairness.txt"
const LEASH_M := 5.0
const HEAL_BELOW := 150
const HEROES := {&"weak": 400, &"expected": 1000, &"strong": 2500}
const MODE_NAMES := ["BUILD", "PEAK", "PULL", "QUIET"]

var _lines := PackedStringArray()


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var seeds := PackedInt32Array()
	for s in String(args.get("seeds", "11")).split(","):
		seeds.append(int(s))
	var seconds := int(args.get("seconds", "300"))
	var floor_index := int(args.get("floor", "1"))
	var log_every := String(args.get("log", "0")) == "1"
	var heroes := String(args.get("heroes", "weak,expected,strong")).split(",")
	_out(
		(
			"director_fairness: seeds=%s seconds=%d floor=%d build=blade heroes=%s heal_below=%d permille"
			% [seeds, seconds, floor_index, heroes, HEAL_BELOW]
		)
	)
	var totals := {}
	for h in heroes:
		totals[h] = {"kpm": 0.0, "alive": 0.0, "quiet": 0.0, "nq": 0, "maxq": 0, "neverq": 0}
	for s in seeds:
		for h in heroes:
			var r := _run(s, floor_index, seconds, StringName(h), log_every)
			var tot: Dictionary = totals[h]
			tot["kpm"] += r["kills"] * 60.0 / seconds
			tot["alive"] += r["alive_mean"]
			for q: Array in r["quiets"]:
				tot["quiet"] += q[0]
				tot["nq"] += 1
				if q[1] == "max":
					tot["maxq"] += 1
			if r["quiets"].is_empty():
				tot["neverq"] += 1
	for h in heroes:
		var tot: Dictionary = totals[h]
		_out(
			(
				"MEAN %-8s | kills/min %.1f | alive %.1f | quiet mean s %.1f (%d quiets, %d forced at max) | runs with no quiet %d"
				% [
					h,
					tot["kpm"] / seeds.size(),
					tot["alive"] / seeds.size(),
					tot["quiet"] / maxi(1, tot["nq"]),
					tot["nq"],
					tot["maxq"],
					tot["neverq"]
				]
			)
		)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	quit(0)


func _run(
	run_seed: int, floor_index: int, seconds: int, hero: StringName, log_every: bool
) -> Dictionary:
	var w := SaveLab.floor_world(run_seed, floor_index, &"blade")
	if w.stat_values.size() < Stats.BASE.size():
		w.stat_values = PackedInt32Array(Stats.BASE)
	w.stat_values[Stats.Stat.DAMAGE] = HEROES[hero]
	var bot := FightBot.new(run_seed)
	var home := w.player_pos()
	var heals := 0
	var peaks := []
	var quiets := []
	var builds := []
	var pulls := []
	var build_from := 0
	var quiet_drawn := 0
	var quiet_cap := 0
	var pull_left := 0
	var alive_sum := 0
	var alive_send_sum := 0
	var send_ticks := 0
	var biggest := 0
	var standing := [0, 0, 0]  # director ticks per IntensityState.Standing (v0.10.5 O4)
	var kill_ring := PackedInt32Array()
	kill_ring.resize(10)
	var kills_at_s := 0
	var t_count := seconds * 60
	for t in t_count:
		var f := bot.frame(w)
		var away := home - w.player_pos()
		if Kin.length(away) > LEASH_M:
			var d := away / Kin.length(away)
			f.move = Vector2i(int(d.x * 127.0), int(d.y * 127.0))
		var before := WaveDirector.enemies_alive(w)
		var mode_before := w.intensity.mode
		var quiet_timer := w.intensity.timer
		w.step(f)
		biggest = maxi(biggest, WaveDirector.enemies_alive(w) - before)
		if w.actors.hp[0] * 1000 < w.actors.max_hp[0] * HEAL_BELOW:
			w.actors.hp[0] = w.actors.max_hp[0]
			w.intensity.last_hp = w.actors.hp[0]  # the poke isn't play
			heals += 1
		var alive := WaveDirector.enemies_alive(w)
		alive_sum += alive
		if w.intensity.seen_tick == w.tick - 1:
			standing[w.intensity.standing] += 1
		if Intensity.sending(w):
			alive_send_sum += alive
			send_ticks += 1
		var m := w.intensity.mode
		if m != mode_before:
			if m == IntensityState.Mode.PEAK:
				peaks.append(snappedf(t / 60.0, 0.1))
				builds.append(snappedf((t - build_from) / 60.0, 0.1))
			if m == IntensityState.Mode.QUIET:
				quiet_drawn = w.intensity.timer
				quiet_cap = w.spawner.intensity.quiet_ticks_max
				pull_left = quiet_timer
				pulls.append("near" if pull_left > 1 else "timeout")
			if mode_before == IntensityState.Mode.QUIET:
				var ran := quiet_drawn - (quiet_timer - 1)  # director ticks in QUIET (the freeze ticks left out)
				var how := "drawn"
				if ran >= quiet_cap:
					how = "max"
				elif quiet_timer - 1 < 0:
					how = "over"
				quiets.append([snappedf(ran / 60.0, 0.1), how])
				build_from = t
		if t % 60 == 59:
			kill_ring[(t / 60) % 10] = w.kills - kills_at_s
			kills_at_s = w.kills
		if log_every and t % 300 == 299:
			var k10 := 0
			for v in kill_ring:
				k10 += v
			_out(
				(
					"LOG %d %-8s | %3d s | %-5s %-3s | int %4d | alive %2d/%2d | kills %4d | hp %3d %% | kills 10 s %2d"
					% [
						run_seed,
						hero,
						(t + 1) / 60,
						MODE_NAMES[m],
						["", "STR", "TOP"][w.intensity.standing],
						w.intensity.level / 1000,
						alive,
						w.spawner.cap_now(w.floor_index, w.run_ticks),
						w.kills,
						w.actors.hp[0] * 100 / maxi(1, w.actors.max_hp[0]),
						k10
					]
				)
			)
	var open := snappedf((t_count - build_from) / 60.0, 0.1)
	var r := {
		"kills": w.kills,
		"alive_mean": alive_sum / float(t_count),
		"quiets": quiets,
	}
	var qtext := []
	for q: Array in quiets:
		qtext.append("%.1f %s" % [q[0], q[1]])
	_out(
		(
			"RUN %d %-8s | peaks %d at s %s | quiets [%s] | build-ups s %s, open %.1f | pull back %s"
			% [run_seed, hero, peaks.size(), peaks, ", ".join(qtext), builds, open, pulls]
		)
	)
	var fmt := "RUN %d %-8s | kills %d (%.1f/min) | alive mean %.1f, while sending %.1f | biggest arrival %d"
	fmt += " | heals %d | end %s | standing ticks between/struggling/strong %s"
	_out(
		(
			fmt
			% [
				run_seed,
				hero,
				w.kills,
				w.kills * 60.0 / seconds,
				alive_sum / float(t_count),
				alive_send_sum / float(maxi(1, send_ticks)),
				biggest,
				heals,
				MODE_NAMES[w.intensity.mode],
				standing
			]
		)
	)
	return r


func _out(s: String) -> void:
	print(s)
	_lines.append(s)
