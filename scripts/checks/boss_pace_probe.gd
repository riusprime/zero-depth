extends SceneTree
## v0.10.5 O2b (owner D38 (a): "bosses be oneshoted on very very rare ocassions … but fights should last 1-2 minutes"):
## how long each floor boss's fight lasts against scripted heroes at four power levels, through the real hidden
## catch-up (CatchUp.read_boss at the door, CatchUp.on_boss at the spawn). Prints the table and writes
## build/boss_pace.txt; paste into evidence by hand (this tool never writes outside build/).
##   godot --headless --path . -s scripts/checks/boss_pace_probe.gd
##   godot --headless --path . -s scripts/checks/boss_pace_probe.gd -- floors=1 seeds=1 levels=1000 cap=600
## The world: test_boss_pace.gd's open plane (the base Blade build, the real compiled enemies and bosses, the heat on)
## with the run's floor scaling (RunState.scale_bosses for floor f, loop 1, no Deep route), floor_index = f and the
## catch-up table from data/scaling/catch_up.tres; no threat. The hero's power: its damage stat set to `level` per
## mille of the floor's boss expected power E (data: boss_expected_power_permille), so P = level × E / 1000 (the
## build's other terms stay fresh; the printed P is CatchUp.power). Levels (per mille of E): weak 500, expected
## 1000, strong 2000, extreme 6000. The boss is read at its door (CatchUp.read_boss), spawned past its rise
## (BossLab.ready_boss) with the hero 6 m east, and fought by test_boss_pace.gd's BladeRun hero (melee, a swing every
## 4 ticks while the boss can be hurt, dashes the big attacks, healed to full every tick: this measures the fight's
## length, not survival). The fight ends when the boss dies or at cap= seconds (default 600). Per fight: seconds,
## the boss's spawned max HP, the HP multiplier (spawned HP / table HP, per mille), P, and whether it died.
## Determinism: the first fight runs twice; the world hashes must match (MATCH/MISMATCH).

const BP := preload("res://tests/unit/sim/test_boss_pace.gd")
const POOLS := {
	1: [&"gatekeeper", &"warlord"],
	2: [&"brood_mother", &"hive_lens"],
	3: [&"siege_engine", &"foundry"]
}
const LEVEL_NAMES := {500: "weak", 1000: "expected", 2000: "strong", 6000: "extreme"}

var _lines := PackedStringArray()
var _repo: ContentRepository
var _bigs := {}


func _initialize() -> void:
	var args := ScriptArgs.parse()
	_repo = ContentRepository.load_all()
	for def: BossDefinition in _repo.all_of(&"bosses"):
		for a in def.attacks:
			if a.hit_class == &"big":
				_bigs[a.id] = true
	var floors := _ints(String(args.get("floors", "1,2,3")))
	var seeds := _ints(String(args.get("seeds", "1,2,3")))
	var levels := _ints(String(args.get("levels", "500,1000,2000,6000")))
	var cap := int(float(args.get("cap", 600)) * SimTick.TICKS_PER_SECOND)
	_line(
		(
			"boss_pace_probe: BladeRun hero, damage stat = level x E, seeds %s, cap %d ticks, 60 Hz headless"
			% [seeds, cap]
		)
	)
	_line("columns: floor boss level seed | seconds | max HP | HP mult | P | dead")
	for f in floors:
		for id: StringName in POOLS[f]:
			for lv in levels:
				var secs := []
				for s in seeds:
					var r := _fight(f, id, lv, s, cap)
					secs.append(r["seconds"])
					_line(
						(
							"F%d %s %s %d | %.1f | %d | %d | %d | %s"
							% [
								f,
								id,
								LEVEL_NAMES.get(lv, str(lv)),
								s,
								r["seconds"],
								r["hp"],
								r["mult"],
								r["p"],
								r["dead"]
							]
						)
					)
				var lo: float = secs.min()
				var hi: float = secs.max()
				var mean := 0.0
				for x: float in secs:
					mean += x / secs.size()
				_line(
					(
						"F%d %s %s ALL | mean %.1f s, min %.1f, max %.1f"
						% [f, id, LEVEL_NAMES.get(lv, str(lv)), mean, lo, hi]
					)
				)
	var a := _fight(floors[0], POOLS[floors[0]][0], levels[0], seeds[0], cap)
	var b := _fight(floors[0], POOLS[floors[0]][0], levels[0], seeds[0], cap)
	_line("determinism: %s" % ("MATCH" if a["hash"] == b["hash"] else "MISMATCH"))
	_write("res://build/boss_pace.txt")
	quit(0)


func _ints(s: String) -> Array[int]:
	var out: Array[int] = []
	for x in s.split(",", false):
		out.append(int(x))
	return out


## test_boss_pace.gd's open plane, scaled for floor f, with the catch-up on.
func _world(f: int, seed_value: int) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(seed_value, t)
	w.set_enemy_tables(ContentCompiler.compile_enemies(_repo))
	var bosses := ContentCompiler.compile_bosses(_repo)
	var run := SaveLab.run_state(seed_value, f, &"blade", 0, _repo)
	run.scale_bosses(bosses, f)
	w.set_boss_tables(bosses)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.wand_table = WandCompiler.from_repo(_repo)
	w.blade_table = BladeCompiler.from_repo(_repo)
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	Heat.enable(w, ContentCompiler.compile_heat(_repo.get_def(&"heat", &"overclock")))
	w.tuning = RunContentCompiler.compile_sim_tuning(_repo.get_def(&"tuning", &"sim"))
	w.floor_index = f
	w.catch_up_table = ContentCompiler.compile_catch_up(_repo.get_def(&"scaling", &"catch_up"))
	return w


func _fight(f: int, id: StringName, level: int, seed_value: int, cap: int) -> Dictionary:
	var w := _world(f, seed_value)
	var e := CatchUpTable.at_floor(w.catch_up_table.boss_expected_permille, f)
	if w.stat_values.size() < Stats.COUNT:
		w.stat_values = PackedInt32Array(Stats.BASE)
	w.stat_values[Stats.Stat.DAMAGE] = maxi(1, level * e / 1000)
	CatchUp.start_floor(w)
	CatchUp.read_boss(w)  # the door starts to open (BossFlow.interact)
	var k := BossLab.table_index(w, id)
	var table_hp := w.boss_tables[k].hp
	var i := BossLab.ready_boss(w, id)
	var aid := w.actors.ids[i]
	var hp := w.actors.max_hp[i]
	w.actors.set_pos(0, Vector2(6, 0))
	var bot := BP.BladeRun.new(aid, _bigs)
	var n := bot.fight(w, cap, func(_w: World) -> bool: return bot.boss_dead(w))
	return {
		"seconds": n / 60.0,
		"hp": hp,
		"mult": hp * 1000 / maxi(1, table_hp),
		"p": w.catch_up.boss_power,
		"dead": bot.boss_dead(w),
		"hash": w.state_hash(),
	}


func _line(s: String) -> void:
	print(s)
	_lines.append(s)


func _write(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa == null:
		push_error("cannot write %s" % path)
		return
	fa.store_string("\n".join(_lines) + "\n")
