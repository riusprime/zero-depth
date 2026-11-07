extends SceneTree
## v0.10.5 O2a (owner L3: "some of them are invulnerable for too long, almost unhittable": the Lantern Shade and the
## Clockwork Judge): the share of fight time in which no player hit can land on a boss, from scripted fights.
## Prints the table and writes build/boss_invulnerable.txt; paste into evidence by hand (this tool never writes
## outside build/).
##   godot --headless --path . -s scripts/checks/boss_invulnerable.gd
##   godot --headless --path . -s scripts/checks/boss_invulnerable.gd -- bosses=lantern_shade seeds=1,2,3 cap=240
## The fight: BossLab's world (the real compiled bosses from data/, no sealed room: the Shade's lanterns stand round
## where it rose), the boss spawned at the origin through its rise (World.spawn_boss: the intro counts), the hero
## spawned 6 m east, never dying (its HP refilled each tick). Each tick the hero stands on a circle round the boss's
## centre, walking round it at 3 m/s, and hits it every HIT_EVERY ticks for HIT_AMOUNT (Damage.hit, as a projectile
## would). The fight ends when the boss dies or at cap= seconds. Heroes:
## - close: 3.0 m from the boss's centre.
## - ranged: 6.5 m; while a Shade's room is dark it closes to 4.0 m (it brings its own light, as the fight asks).
## - ranged_naive (informative, no target): 6.5 m always, even in the dark.
## A tick is "blocked" when Damage would refuse a player hit: the actor's invuln ticks (the rise), the signature's
## shield (BossDodge.shielded). v0.11.0 O4: "dim" counts the ticks a Shade stands in the dark (its hits cut to 40 %,
## not blocked: BossShade.light_permille). A phase gate (BossAi.GATE) is counted
## apart: Damage lets the hit land but the HP floor holds (v0.9.5 BH1), so it is not in the blocked share.
## Per fight: ticks, blocked share, then the ticks and number of windows of each cause, and whether the boss died.

const HIT_EVERY := 6
const HIT_AMOUNT := 4
const WALK_MPS := 3.0
const HEROES: Array[String] = ["close", "ranged", "ranged_naive"]

var _lines := PackedStringArray()


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var bosses := String(args.get("bosses", "lantern_shade,clockwork_judge")).split(",", false)
	var seeds := PackedInt32Array()
	for s in String(args.get("seeds", "1,2,3")).split(",", false):
		seeds.append(int(s))
	var cap := int(float(args.get("cap", 240)) * SimTick.TICKS_PER_SECOND)
	_line(
		(
			"boss_invulnerable: hit %d every %d ticks, walk %.1f m/s, cap %d ticks, seeds %s, 60 Hz headless"
			% [HIT_AMOUNT, HIT_EVERY, WALK_MPS, cap, seeds]
		)
	)
	_line(
		"columns: boss hero seed | ticks | blocked % | rise t/n | shield t/n | dim t/n | gate t/n | dead"
	)
	for id in bosses:
		for hero in HEROES:
			var tot := 0
			var blk := 0
			for s in seeds:
				var r := _fight(StringName(id), hero, s, cap)
				tot += int(r["ticks"])
				blk += int(r["blocked"])
				_line(_row(id, hero, s, r))
			_line("%s %s ALL | %d | %.1f %%" % [id, hero, tot, 100.0 * blk / maxf(1.0, tot)])
	var again := _fight(StringName(bosses[0]), HEROES[0], seeds[0], cap)
	var first := _fight(StringName(bosses[0]), HEROES[0], seeds[0], cap)
	_line("determinism: %s" % ("MATCH" if again["hash"] == first["hash"] else "MISMATCH"))
	_write("res://build/boss_invulnerable.txt")
	quit(0)


func _fight(id: StringName, hero: String, seed_value: int, cap: int) -> Dictionary:
	var w := BossLab.world(seed_value)
	w.actors.set_pos(0, Vector2(6.0, 0.0))
	var aid := w.spawn_boss(BossLab.table_index(w, id), Vector2.ZERO)
	var me := w.actors.ids[0]
	var counts := {"rise": [0, 0], "shield": [0, 0], "dim": [0, 0], "gate": [0, 0]}
	var was := {"rise": false, "shield": false, "dim": false, "gate": false}
	var ang := 0.0
	var blocked := 0
	var ticks := 0
	var dead := false
	for k in cap:
		var i := w.actors.index_of(aid)
		if i < 0 or w.actors.dead[i] == 1:
			dead = true
			break
		var c := w.actors.pos(i)
		var d := 3.0
		if hero != "close":
			d = 6.5
			if hero == "ranged" and BossShade.dark(w):
				d = 4.0
		ang += WALK_MPS / d / SimTick.TICKS_PER_SECOND
		w.actors.set_pos(0, c + Vector2(cos(ang), sin(ang)) * d)
		w.actors.hp[0] = w.actors.max_hp[0]
		w.actors.invuln[0] = 0
		var now := {
			"rise": w.actors.invuln[i] > 0,
			"shield": BossDodge.shielded(w, i),
			"dim": BossShade.light_permille(w, i) < 1000,  # v0.11.0 O4: cut, never blocked
			"gate": w.actors.state[i] == BossAi.GATE,
		}
		for key: String in now:
			if now[key]:
				counts[key][0] += 1
				if not was[key]:
					counts[key][1] += 1
			was[key] = now[key]
		if now["rise"] or now["shield"]:
			blocked += 1
		if k % HIT_EVERY == 0:
			Damage.hit(w, i, HIT_AMOUNT, me, me, w.take_root(), 0, w.player_pos(), c)
		w.step(InputFrame.new())
		ticks += 1
	return {
		"ticks": ticks,
		"blocked": blocked,
		"counts": counts,
		"dead": dead,
		"hash": w.state_hash(),
	}


func _row(id: String, hero: String, s: int, r: Dictionary) -> String:
	var c: Dictionary = r["counts"]
	return (
		"%s %s %d | %d | %.1f %% | %d/%d | %d/%d | %d/%d | %d/%d | %s"
		% [
			id,
			hero,
			s,
			r["ticks"],
			100.0 * int(r["blocked"]) / maxf(1.0, int(r["ticks"])),
			c["rise"][0],
			c["rise"][1],
			c["shield"][0],
			c["shield"][1],
			c["dim"][0],
			c["dim"][1],
			c["gate"][0],
			c["gate"][1],
			"yes" if r["dead"] else "no",
		]
	)


func _line(s: String) -> void:
	print(s)
	_lines.append(s)


func _write(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s" % path)
		return
	f.store_string("\n".join(_lines) + "\n")
	f.close()
