extends SceneTree
## v0.8.0 N5 (owner O58): the intensity director's curve on real floors, a scripted measurement (not the bot suite).
## For each run seed: floor 1 of the run as Main builds it (SaveLab.floor_world, blade build), a scripted hero that
## fights (FightBot's input, kept within LEASH_M of where it started so it holds its room instead of walking into an
## arena or the boss room) for `seconds` of floor time, topped up to full HP between ticks whenever it falls under
## HEAL_BELOW of max (a poke, so it lives the whole time; the same for both runs). Each seed runs twice: with the
## director (as shipped) and with it off (SpawnTable.intensity = null: today's spawning). Prints per seed the
## once-a-second curve (intensity, state, enemies alive) as a table, the peaks (start s), the quiet gaps (seconds in
## QUIET and with no packs sent, counted in director ticks: the hit-stop freeze ticks, where the world stands still,
## are left out; the peaks' start in floor ticks), and kills per minute on and off; writes the same to
## build/intensity_curve.txt. Paste into evidence by hand.
##   godot --headless --path . -s scripts/checks/intensity_curve.gd -- seeds=11,12,13 seconds=300 curve=11

const OUT := "res://build/intensity_curve.txt"
const LEASH_M := 5.0
const HEAL_BELOW := 350
const MODE_NAMES := ["BUILD", "PEAK", "PULL", "QUIET"]

var _lines := PackedStringArray()


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var seeds := PackedInt32Array()
	for s in String(args.get("seeds", "11,12,13")).split(","):
		seeds.append(int(s))
	var seconds := int(args.get("seconds", "300"))
	var curve_seeds := String(args.get("curve", str(seeds[0]))).split(",")
	_out("intensity_curve: seeds=%s seconds=%d build=blade floor=1" % [seeds, seconds])
	var sum_on := 0.0
	var sum_off := 0.0
	for s in seeds:
		var on := _run(s, seconds, true, curve_seeds.has(str(s)))
		var off := _run(s, seconds, false, curve_seeds.has("off%d" % s))
		var kpm_on: float = on["kills"] * 60.0 / seconds
		var kpm_off: float = off["kills"] * 60.0 / seconds
		sum_on += kpm_on
		sum_off += kpm_off
		_out(
			(
				"SEED %d | peaks at s %s | quiet lengths s %s | no-pack gaps s %s | kills/min on %.1f off %.1f (%+.1f %%)"
				% [
					s,
					on["peaks"],
					on["quiets"],
					on["gaps"],
					kpm_on,
					kpm_off,
					(kpm_on - kpm_off) * 100.0 / maxf(0.001, kpm_off)
				]
			)
		)
		_out(
			(
				"SEED %d | on: kills %d, heals %d, director ticks %d/%d | off: kills %d, heals %d"
				% [s, on["kills"], on["heals"], on["ran"], seconds * 60, off["kills"], off["heals"]]
			)
		)
	_out(
		(
			"MEAN kills/min on %.1f off %.1f (%+.1f %%)"
			% [
				sum_on / seeds.size(),
				sum_off / seeds.size(),
				(sum_on - sum_off) * 100.0 / maxf(0.001, sum_off)
			]
		)
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	quit(0)


func _run(run_seed: int, seconds: int, director: bool, print_curve: bool) -> Dictionary:
	var w := SaveLab.floor_world(run_seed, 1, &"blade")
	if not director:
		w.spawner.intensity = null
	var bot := FightBot.new(run_seed)
	var home := w.player_pos()
	var heals := 0
	var ran := 0
	var peaks := []
	var quiets := []
	var gaps := []
	var last_mode := IntensityState.Mode.BUILD_UP
	var mode_from := 0
	var last_send := 0
	var r := WorldReader.new(w)
	if print_curve:
		_out(
			(
				"CURVE seed %d %s | s | intensity | state | alive/cap | near 3 m | kills | ascii (intensity / 25)"
				% [run_seed, "on" if director else "off"]
			)
		)
	for t in seconds * 60:
		var f := bot.frame(w)
		var away := home - w.player_pos()
		if Kin.length(away) > LEASH_M:
			var d := away / Kin.length(away)
			f.move = Vector2i(int(d.x * 127.0), int(d.y * 127.0))
		var seen := w.intensity.seen_tick
		var spawns_before := w.actors.size()
		w.step(f)
		if w.intensity.seen_tick != seen:
			ran += 1
		if w.actors.hp[0] * 1000 < w.actors.max_hp[0] * HEAL_BELOW:
			w.actors.hp[0] = w.actors.max_hp[0]
			w.intensity.last_hp = w.actors.hp[0]  # the poke isn't play: the next tick's drop counts from full
			heals += 1
		if w.actors.size() > spawns_before:
			if director and (ran - last_send) >= 600:
				gaps.append(snappedf((ran - last_send) / 60.0, 0.1))
			last_send = ran
		var m := w.intensity.mode
		if director and m != last_mode:
			if m == IntensityState.Mode.PEAK:
				peaks.append(snappedf(t / 60.0, 0.1))
			if last_mode == IntensityState.Mode.QUIET:
				quiets.append(snappedf((ran - mode_from) / 60.0, 0.1))
			last_mode = m
			mode_from = ran
		if print_curve and t % 60 == 59:
			var lv := r.intensity()
			_out(
				(
					"CURVE %d | %3d | %4d | %-5s | %3d/%3d | %2d | %4d | %s"
					% [
						run_seed,
						(t + 1) / 60,
						lv,
						MODE_NAMES[r.intensity_mode()],
						WaveDirector.enemies_alive(w),
						w.spawner.cap_now(w.floor_index, w.run_ticks),
						Intensity.near(w, 3.0),
						w.kills,
						"#".repeat(lv / 25)
					]
				)
			)
	return {
		"kills": w.kills,
		"heals": heals,
		"ran": ran,
		"peaks": peaks,
		"quiets": quiets,
		"gaps": gaps,
	}


func _out(s: String) -> void:
	print(s)
	_lines.append(s)
