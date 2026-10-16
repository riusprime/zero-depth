extends SceneTree
## The Ascension loop's scaling (v0.8.0 LS, owner Q6), computed by the real code: for loops 1..5, the loop factors
## RunState.loop_permille gives for the run data's enemy and boss HP and damage steps, and what scale_enemies /
## scale_bosses make of the first enemy and the first boss on each loop's floor 1.
## v0.8.0 P3 (owner O35): then floor 2 of loops 1-3, normal and Deep (the Purple Portal's route), the same samples:
## the Deep floor past loop 1 is eased by the data's loop_deep_ease_permille.
## Prints the report and writes build/loop_scaling.txt; paste it into evidence by hand.
##   godot --headless --path . -s scripts/checks/loop_scaling.gd

const LOOPS := 5
const HEADER := "loop | enemy hp pm | enemy dmg pm | boss hp pm | boss dmg pm | enemy | e dmg | boss | b dmg"


func _initialize() -> void:
	var repo := ContentRepository.load_all()
	var table := ContentCompiler.compile_run(repo.get_def(&"run", &"three_floors"))
	var base_e := ContentCompiler.compile_enemies(repo)
	var base_b := ContentCompiler.compile_bosses(repo)
	var steps := [
		table.loop_enemy_hp_permille,
		table.loop_enemy_damage_permille,
		table.loop_boss_hp_permille,
		table.loop_boss_damage_permille,
		table.loop_scale_cap_permille,
	]
	var sample := [
		base_e[0].name_key,
		base_e[0].hp,
		base_e[0].damage,
		base_b[0].name_key,
		base_b[0].hp,
		base_b[0].attacks[0].damage,
	]
	var lines := PackedStringArray()
	lines.append("steps (per mille): enemy hp %d dmg %d, boss hp %d dmg %d, cap %d" % steps)
	lines.append(
		"floor-1 sample: enemy %s (hp %d, dmg %d), boss %s (hp %d, attack 0 dmg %d)" % sample
	)
	lines.append(HEADER)
	var r := RunState.start(1, table)
	for l in range(1, LOOPS + 1):
		r.loop = l
		r.loop_floors = table.floors * (l - 1)
		var e := ContentCompiler.compile_enemies(repo)
		r.scale_enemies(e, 1)
		var b := ContentCompiler.compile_bosses(repo)
		r.scale_bosses(b, 1)
		var row := [l]
		for s: int in steps.slice(0, 4):
			row.append(r.loop_permille(s))
		row.append_array([e[0].hp, e[0].damage, b[0].hp, b[0].attacks[0].damage])
		lines.append("%d | %d | %d | %d | %d | %d | %d | %d | %d" % row)
	lines.append("loop_deep_ease_permille %d" % table.loop_deep_ease_permille)
	lines.append("floor 2: loop | route | enemy | e dmg | boss | b dmg")
	for l in range(1, 4):
		for route in [Routes.Route.NORMAL, Routes.Route.DEEP]:
			var rr := RunState.start(1, table)
			rr.loop = l
			rr.loop_floors = table.floors * (l - 1)
			rr.floor_index = 2
			rr.routes.resize(rr.run_floor())
			for k in rr.routes.size():
				rr.routes[k] = Routes.Route.NORMAL
			rr.routes[rr.run_floor() - 1] = route
			var e := ContentCompiler.compile_enemies(repo)
			rr.scale_enemies(e)
			var b := ContentCompiler.compile_bosses(repo)
			rr.scale_bosses(b)
			lines.append(
				(
					"%d | %s | %d | %d | %d | %d"
					% [
						l,
						"deep" if route == Routes.Route.DEEP else "normal",
						e[0].hp,
						e[0].damage,
						b[0].hp,
						b[0].attacks[0].damage
					]
				)
			)
	DirAccess.make_dir_recursive_absolute("res://build")
	var f := FileAccess.open("res://build/loop_scaling.txt", FileAccess.WRITE)
	for line in lines:
		print(line)
		if f != null:
			f.store_line(line)
	quit(0)
