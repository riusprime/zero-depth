extends SceneTree
## v0.4.0 SV: what a run save costs. For worlds from a floor start to a crowd and a boss fight (built by the tests'
## SaveLab, as Main builds a floor): the snapshot on the frame (RunSaver's entry save: WorldSnapshot.take), the encode
## and write that run on a worker thread, the read and the restore, the sizes, and whether the restore hashes equal.
##   godot --headless --path . -s scripts/bench/save_bench.gd
## Writes build/save_bench.json and prints it; paste the output into evidence by hand.

const REPS := 20
const A := AbilityTable.Kind
const K := ActorStore.Kind
const DIR := "res://build/save_bench"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var rows := []
	rows.append(_measure("floor_start", SaveLab.floor_world(20261006, 1), _plain.bind(1)))
	var mid := _rich(20261006, 2)
	SaveLab.run(mid, FightBot.new(5), 1500)
	rows.append(_measure("floor_2_mid_run", mid, _rich.bind(20261006, 2)))
	var crowd := _rich(9, 3)
	crowd.actors.hp[0] = 1000000
	crowd.actors.max_hp[0] = 1000000
	SaveLab.run(crowd, FightBot.new(2), 1800)
	var kinds := [K.SWARMER, K.CHARGER, K.NEEDLE, K.SPLITTER, K.ARC_CASTER, K.SNIPER]
	for i in 110:
		var at := crowd.player_pos() + Kin.dir((i * 4096 / 110) & 4095) * (5.0 + float(i % 6))
		crowd.add_enemy(kinds[i % kinds.size()], at)
	SaveLab.run(crowd, FightBot.new(2), 60)
	rows.append(_measure("floor_3_crowd", crowd, _rich.bind(9, 3)))
	var boss := _rich(503, 3)
	boss.actors.hp[0] = 1000000
	FightLab.enter_boss_room(boss)
	SaveLab.run(boss, FightBot.new(3), 400)
	rows.append(_measure("floor_3_boss_fight", boss, _rich.bind(503, 3)))
	var doc := {
		"godot": Engine.get_version_info()["string"],
		"reps": REPS,
		"save_version": RunSaveStore.SAVE_VERSION,
		"rows": rows,
	}
	var f := FileAccess.open("res://build/save_bench.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t", true))
	f.close()
	print(JSON.stringify(doc, "\t", true))
	quit(0 if rows.all(func(r: Dictionary) -> bool: return r["restored_hash_equal"]) else 1)


func _plain(floor_index: int) -> World:
	return SaveLab.floor_world(20261006, floor_index)


func _rich(run_seed: int, floor_index: int) -> World:
	var w := SaveLab.floor_world(run_seed, floor_index)
	SaveLab.grant_abilities(w, [A.BOMB_LOBBER, A.DRONE_BUDDY, A.ORBIT_BLADES], 3)
	SaveLab.add_stats(w, [Stats.Stat.DAMAGE, Stats.Stat.CRIT_CHANCE, Stats.Stat.MAX_HP], 2)
	return w


func _stats(us: PackedFloat64Array) -> Dictionary:
	var total := 0.0
	var top := 0.0
	for v in us:
		total += v
		top = maxf(top, v)
	return {
		"mean_ms": snappedf(total / us.size() / 1000.0, 0.001),
		"max_ms": snappedf(top / 1000.0, 0.001)
	}


func _measure(label: String, w: World, make_base: Callable) -> Dictionary:
	var payload := RunSaver.payload_of(w, SaveLab.run_state(1, w.floor_index), 1, PackedByteArray())
	var take := PackedFloat64Array()
	var enc := PackedFloat64Array()
	var write := PackedFloat64Array()
	var read := PackedFloat64Array()
	var bytes := PackedByteArray()
	var store := RunSaveStore.new(DIR.path_join("run.save"))
	for r in REPS:
		var t0 := Time.get_ticks_usec()
		payload["world"] = w.to_snapshot()
		take.append(Time.get_ticks_usec() - t0)
		t0 = Time.get_ticks_usec()
		bytes = RunSaveStore.encode(payload)
		enc.append(Time.get_ticks_usec() - t0)
		t0 = Time.get_ticks_usec()
		store.write(payload)
		write.append(Time.get_ticks_usec() - t0)
		t0 = Time.get_ticks_usec()
		store.read()
		read.append(Time.get_ticks_usec() - t0)
	var apply := PackedFloat64Array()
	var equal := true
	for r in 5:
		var base: World = make_base.call()
		var t0 := Time.get_ticks_usec()
		var err := WorldSnapshot.apply(base, store.read()["world"])
		apply.append(Time.get_ticks_usec() - t0)
		equal = equal and err == "" and base.state_hash() == w.state_hash()
	var hash := PackedFloat64Array()
	for r in 5:
		var t0 := Time.get_ticks_usec()
		w.state_hash()
		hash.append(Time.get_ticks_usec() - t0)
	return {
		"label": label,
		"tick": w.tick,
		"actors": w.actors.size(),
		"projectiles": w.projectiles.size(),
		"walls": w.walls.size(),
		"raw_bytes": var_to_bytes(payload).size(),
		"file_bytes": bytes.size(),
		"on_frame_snapshot": _stats(take),
		"worker_encode": _stats(enc),
		"sync_encode_and_write": _stats(write),
		"read_and_decode": _stats(read),
		"restore_apply": _stats(apply),
		"state_hash_for_scale": _stats(hash),
		"restored_hash_equal": equal,
	}
