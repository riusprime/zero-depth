class_name WaveDirector
extends RefCounted
## Runs the encounter in tick phase 9 (PLAN v0.1.0 Step 5): when no enemy is left, the next wave arrives after
## its delay; when the last wave is cleared, the run is won. Spawn slots are shuffled from the map stream and
## kept at least min_spawn_distance_m from the player.


static func advance(w: World) -> void:
	var enc := w.encounter
	if enc == null or w.player_dead() or w.cleared:
		return
	if w.wave_timer > 0:
		w.wave_timer -= 1
		if w.wave_timer == 0:
			w.wave_index += 1
			w.wave_timer = -1
			_spawn(w, enc.waves[w.wave_index])
		return
	if enemies_alive(w) > 0:
		return
	if w.wave_index + 1 < enc.waves.size():
		w.wave_timer = maxi(1, enc.delays[w.wave_index + 1])
	else:
		w.cleared = true


static func enemies_alive(w: World) -> int:
	var n := 0
	for i in range(1, w.actors.size()):
		if EnemyAi.is_enemy_kind(w.actors.kinds[i]) and w.actors.dead[i] == 0:
			n += 1
	return n


## Slots in shuffled order, the ones far enough from the player first.
static func slots(w: World) -> PackedVector2Array:
	var pts := w.spawn_points.duplicate()
	for k in range(pts.size() - 1, 0, -1):
		var j := w.rng_map.range_int(0, k)
		var tmp := pts[k]
		pts[k] = pts[j]
		pts[j] = tmp
	var far := PackedVector2Array()
	var near := PackedVector2Array()
	var p := w.player_pos()
	for q in pts:
		if Kin.length(q - p) >= w.encounter.min_spawn_distance_m:
			far.append(q)
		else:
			near.append(q)
	far.append_array(near)
	return far


static func _spawn(w: World, kinds: Array) -> void:
	var pts := slots(w)
	for k in kinds.size():
		var at := pts[k % pts.size()]
		if k >= pts.size():
			at += Kin.dir((k * 1024) & 4095) * 0.8
		w.add_enemy(kinds[k], at)
