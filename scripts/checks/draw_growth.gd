extends "res://scripts/checks/draw_census.gd"
## v0.10.5 W3-V2 (PERF_PLAYLOG_4: the objects drawn climb within each floor and from floor to floor, the nodes flat):
## draw_census's split, read again and again as a floor is played. Boots main.tscn, starts a run (seed 4404), every
## floor the biome given with --biome, and plays it the way a run does, through the real game's systems: the hero
## (invulnerable, as the dev panel's God) is put in each room in turn (nearest the start first, by the floor's hops;
## never the boss room), stays DWELL sim ticks there while every enemy within KILL_RADIUS_M is killed through Damage
## (as the dev panel's Kill boss: the kills, drops and room events are the sim's), stepping onto the shards and heal
## orbs lying in reach every few ticks (a player picks them up), and stays on while an arena or a Lockdown holds.
## At CHECKPOINTS (arrival, then 25 / 50 / 75 / 100 % of the rooms visited) the hero goes back to the start room's
## centre (the same camera spot each time, so a growth is what piled up, not where it is read), the enemies there are
## killed, the floor runs SETTLE ticks, the sim pauses, and draw_census's per-source split is read, with a node
## census: every class under the world view and the HUD, the visible geometry per view, the MultiMesh instances shown,
## the lights and particles. Then the next floor through Main._next_floor (what the portal calls: the floor finished,
## the old view freed, the next floor built behind the cover; the boss fight and the portal walk are skipped).
## Counts, not timings. Needs a renderer, off screen:
##   "$G" --path . --fixed-fps 60 --position -10000,-10000 --resolution 1920x1080 --windowed \
##     -s scripts/checks/draw_growth.gd -- --biome=red_canyon [--floors=3] [--tag=x] [--dwell=240]
## Writes only under build/ (build/perf/draw_growth_<biome>[_<tag>].txt) and prints the same report. Quits on every
## path.

const DWELL := 240
const KILL_RADIUS_M := 16.0
## A room that holds the hero (a sealed arena, a Lockdown) is stayed in up to this many ticks more.
const HOLD_CAP := 1500
const MARKS: Array[int] = [0, 25, 50, 75, 100]

var _floors := 3
var _dwell := DWELL
var _visit: Array[int] = []
var _visited := 0
var _held := 0
var _mark := 0
var _floor_no := 1
var _world_was: World
var _cp_label := ""
## checkpoint label -> {"base": row, "src": {source: delta row}, "nodes": {...}}
var _cps := {}
var _cp_order: PackedStringArray = []
var _src_order: PackedStringArray = []
var _cp_src := {}
var _cp_bases: Array = []
var _g_phase := 0
var _g_frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("floors="):
			_floors = int(s.trim_prefix("floors="))
		elif s.begins_with("dwell="):
			_dwell = int(s.trim_prefix("dwell="))
	super._initialize()
	_fight = -1


func _process(_delta: float) -> bool:
	_g_frame += 1
	match _g_phase:
		0:
			if _g_frame == 3:
				_main._stage_seed = SEED
				_main.start_stage()
				_main._run_biomes.fill(_biome)
				_main._restart_floor()
				_g_phase = 1
				_g_frame = 0
		1:  # a floor is up: wait for its cover to open and its arrival to play
			if _ready_to_play():
				_begin_floor()
		2:  # in a room
			_play_room()
		3:  # settling at the start room before a checkpoint
			var w := _main.driver.world
			_kill_near(w, KILL_RADIUS_M)
			if _g_frame >= MIN_FRAMES and w.tick >= _placed_at + SETTLE:
				_main.driver.paused = true
				_kill_near(w, KILL_RADIUS_M)
				_main.view.rig.snap_to(SimPlane.to_3d(w.player_pos()))
				_groups = _make_groups()
				_cp_src = {}
				_cp_bases = []
				_cps[_cp_label] = {"nodes": _node_census()}
				_step = 0
				_wait = WAIT
				_reads = []
				_g_phase = 4
		4:
			if _measure_cp():
				_after_checkpoint()
		5:  # the next floor is loading
			if _main.driver != null and _main.driver.world != _world_was:
				_g_phase = 1
				_g_frame = 0
	return _g_phase == 99


func _ready_to_play() -> bool:
	if _main.driver == null or _main.view == null or _g_frame < 10:
		return false
	if _main.loads.busy() or _main.loads.cover.showing():
		return false
	return not _main.driver.reader.transit_holds()


func _begin_floor() -> void:
	var w := _main.driver.world
	_world_was = w
	var f := w.floor_layout
	_visit = []
	for r in f.rooms.size():
		if r != f.boss_room:
			_visit.append(r)
	_visit.sort_custom(
		func(a: int, b: int) -> bool:
			var ha := f.hops[a] if a < f.hops.size() else 999
			var hb := f.hops[b] if b < f.hops.size() else 999
			return ha < hb if ha != hb else a < b
	)
	_visited = 0
	_mark = 0
	print(
		(
			"draw_growth: floor %d (run floor_index %d, loop %d) biome=%s, %d rooms to visit"
			% [_floor_no, _main.run.floor_index, _main.run.loop, _biome, _visit.size()]
		)
	)
	_checkpoint()


## Goes back to the start room's centre and settles there before reading (phase 3).
func _checkpoint() -> void:
	_cp_label = "f%d %3d%%" % [_floor_no, MARKS[_mark]]
	_cp_order.append(_cp_label)
	var w := _main.driver.world
	_put(w, w.floor_layout.rooms[w.floor_layout.start_room].get_center())
	_g_phase = 3
	_g_frame = 0


func _after_checkpoint() -> void:
	_main.driver.paused = false
	_mark += 1
	if _mark < MARKS.size():
		_enter_next_room()
		return
	if _floor_no >= _floors:
		_report_growth()
		_g_phase = 99
		return
	_floor_no += 1
	_main.driver.world.actors.invuln[0] = 1 << 24
	_main._next_floor()  # what the portal calls once the hero went in
	_g_phase = 5
	_g_frame = 0


func _enter_next_room() -> void:
	var w := _main.driver.world
	if _visited >= _visit.size():
		_checkpoint()
		return
	_put(w, w.floor_layout.rooms[_visit[_visited]].get_center())
	_held = 0
	_g_phase = 2
	_g_frame = 0


func _play_room() -> void:
	var w := _main.driver.world
	w.actors.invuln[0] = 1 << 24
	_kill_near(w, KILL_RADIUS_M)
	if _g_frame % 20 == 10:
		_step_onto_drop(w)
	if w.tick < _placed_at + _dwell:
		return
	var holds := (w.arenas != null and w.arenas.sealed()) or Lockdowns.holds_spawns(w)
	if holds and _held < HOLD_CAP:
		_held += 1
		return
	_visited += 1
	if _mark < MARKS.size() and _visited * 100 >= MARKS[_mark] * _visit.size() and MARKS[_mark] > 0:
		_checkpoint()
		return
	_enter_next_room()


## draw_census's reading, with the 2D canvas pass's objects and primitives after it (columns 8 and 9).
func _read() -> Array:
	var row := super._read()
	var vp := root.get_viewport_rid()
	var rs := RenderingServer
	row.append(
		rs.viewport_get_render_info(
			vp, rs.VIEWPORT_RENDER_INFO_TYPE_CANVAS, rs.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME
		)
	)
	row.append(
		rs.viewport_get_render_info(
			vp, rs.VIEWPORT_RENDER_INFO_TYPE_CANVAS, rs.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME
		)
	)
	return row


func _put(w: World, p: Vector2) -> void:
	w.actors.invuln[0] = 1 << 24
	w.actors.set_pos(0, p)
	w.vel = Vector2.ZERO
	_placed_at = w.tick
	_main.view.rig.snap_to(SimPlane.to_3d(p))


## Between ticks, as DebugApi's Kill boss / Clear wave: every living enemy within r of the hero, through Damage.
func _kill_near(w: World, r: float) -> void:
	var p := w.player_pos()
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] != 0 or w.actors.hp[i] <= 0:
			continue
		if (
			not EnemyAi.is_enemy_kind(w.actors.kinds[i])
			or w.actors.teams[i] != ActorStore.TEAM_ENEMY
		):
			continue
		var at := w.actors.pos(i)
		if at.distance_to(p) > r:
			continue
		w.actors.invuln[i] = 0
		Damage.hit(w, i, w.actors.hp[i] * 10, 0, 0, w.take_root(), 0, at, at)


## The nearest shard or heal orb within reach: the hero steps onto it (a player picks them up).
func _step_onto_drop(w: World) -> void:
	var p := w.player_pos()
	var best := Vector2.INF
	for k in w.shard_drops.size():
		var q := w.shard_drops.pos(k)
		if q.distance_to(p) < KILL_RADIUS_M and q.distance_to(p) < best.distance_to(p):
			best = q
	for k in w.orbs.size():
		var q := w.orbs.pos(k)
		if q.distance_to(p) < KILL_RADIUS_M and q.distance_to(p) < best.distance_to(p):
			best = q
	if best != Vector2.INF:
		w.actors.set_pos(0, best)
		w.vel = Vector2.ZERO


## draw_census's _measure, for one checkpoint: everything shown, then each source hidden against the reading before.
func _measure_cp() -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	_reads.append(_read())
	if _reads.size() < READ:
		return false
	var row := _median_row(_reads)
	if _step % 2 == 0:
		_last_base = row
		_cp_bases.append(row)
	else:
		var k := _step / 2
		(_groups[k][1] as Callable).call(true)
		var name := String(_groups[k][0]).get_slice(" (", 0)
		var d := []
		for c in row.size():
			d.append(int(_last_base[c]) - int(row[c]))
		_cp_src[name] = d
		if not _src_order.has(name):
			_src_order.append(name)
	_step += 1
	_reads = []
	_wait = WAIT
	if _step < _groups.size() * 2 + 1:
		if _step % 2 == 1:
			(_groups[_step / 2][1] as Callable).call(false)
		return false
	_cps[_cp_label]["base"] = _median_row(_cp_bases)
	_cps[_cp_label]["src"] = _cp_src
	var b: Array = _cps[_cp_label]["base"]
	print("draw_growth: %s objects=%d draws=%d" % [_cp_label, b[1], b[0]])
	return true


## Counts that could grow: nodes by class (the view, the HUD), and per view child the geometry shown, the MultiMesh
## instances shown, the shadow casters shown; the lights shown and casting; the particles emitting; the sim's stores.
func _node_census() -> Dictionary:
	var out := {}
	var v: Node = _main.view
	var all := v.find_children("*", "", true, false)
	out["nodes: under the view"] = all.size()
	out["nodes: under the UI"] = _main.ui.find_children("*", "", true, false).size()
	out["nodes: whole tree"] = root.find_children("*", "", true, false).size()
	for n in all:
		var k := "class: " + n.get_class()
		out[k] = int(out.get(k, 0)) + 1
		if n is Node3D and (n as Node3D).is_visible_in_tree():
			out["shown class: " + n.get_class()] = (
				int(out.get("shown class: " + n.get_class(), 0)) + 1
			)
		if n is OmniLight3D or n is SpotLight3D:
			if (n as Node3D).is_visible_in_tree():
				out["lights: shown"] = int(out.get("lights: shown", 0)) + 1
				if n.shadow_enabled:
					out["lights: shown, shadow on"] = (
						int(out.get("lights: shown, shadow on", 0)) + 1
					)
		if (n is GPUParticles3D or n is CPUParticles3D) and n.emitting:
			if (n as Node3D).is_visible_in_tree():
				out["particles: emitting, shown"] = (
					int(out.get("particles: emitting, shown", 0)) + 1
				)
	for c in v.get_children():
		var lbl := _label(c)
		var geo := 0
		var cast := 0
		var mm := 0
		for g in c.find_children("*", "GeometryInstance3D", true, false):
			if not (g as Node3D).is_visible_in_tree():
				continue
			geo += 1
			if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				cast += 1
			if g is MultiMeshInstance3D and g.multimesh != null:
				var m: MultiMesh = g.multimesh
				mm += (
					m.visible_instance_count if m.visible_instance_count >= 0 else m.instance_count
				)
		if c is GeometryInstance3D and (c as Node3D).visible:
			geo += 1
		out["view geometry shown: " + lbl] = int(out.get("view geometry shown: " + lbl, 0)) + geo
		out["view casters shown: " + lbl] = int(out.get("view casters shown: " + lbl, 0)) + cast
		out["view mm instances shown: " + lbl] = (
			int(out.get("view mm instances shown: " + lbl, 0)) + mm
		)
		out["view nodes: " + lbl] = (
			int(out.get("view nodes: " + lbl, 0)) + c.find_children("*", "", true, false).size()
		)
	var w := _main.driver.world
	out["sim: actors (all, dead kept)"] = w.actors.size()
	var dead := 0
	for i in w.actors.size():
		dead += 1 if w.actors.dead[i] != 0 else 0
	out["sim: actors dead"] = dead
	out["sim: shard drops"] = w.shard_drops.size()
	out["sim: heal orbs"] = w.orbs.size()
	out["sim: item pickups"] = w.pickups.size()
	out["sim: kills"] = w.kills
	out["sim: projectiles"] = w.projectiles.size()
	var mm: Minimap = _main._hud.minimap
	out["minimap: rooms discovered"] = mm.state.discovered_count()
	out["minimap: floor rooms"] = _main.driver.reader.floor_room_count()
	out["minimap: floor doors"] = _main.driver.reader.floor_door_count()
	out["minimap: corner redraws so far"] = mm.corner.draw_count()
	# W3-V3: what MinimapState holds (a floor's rooms only, or anything kept from the floors before?)
	out["minimap: state rooms held"] = mm.state.discovered.size()
	out["minimap: state hidden rooms"] = mm.state.hidden.size()
	out["minimap: state revision"] = mm.state.revision
	if mm.corner.has_method(&"layer_draw_count"):  # W3-V3: the cached map layer's re-renders
		out["minimap: corner layer renders so far"] = mm.corner.call(&"layer_draw_count")
	return out


func _report_growth() -> void:
	var lines := PackedStringArray()
	lines.append(
		(
			"draw_growth  sha=%s  biome=%s  floors=%d  dwell=%d  tag=%s"
			% [_sha(), _biome, _floors, _dwell, _tag]
		)
	)
	(
		lines
		. append(
			(
				"machine: renderer=%s adapter=%s window=%s"
				% [
					str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
					RenderingServer.get_video_adapter_name(),
					str(root.size),
				]
			)
		)
	)
	(
		lines
		. append(
			(
				"run seed %d, every floor %s; each checkpoint read at the start room's centre, %d ticks settled, sim paused"
				% [SEED, _biome, SETTLE]
			)
		)
	)
	var head := "%-44s" % "checkpoint"
	for cp in _cp_order:
		head += " %8s" % cp.replace(" ", "")
	lines.append("")
	lines.append(
		"== everything shown (median of the readings): objects / draws / cam_obj / shd_obj =="
	)
	lines.append(head)
	for spec: Array in [
		["objects (total)", 1],
		["draws (total)", 0],
		["prims (total)", 2],
		["cam_obj (3D camera pass)", 4],
		["shd_obj (3D shadow passes)", 6],
		["cv_obj (2D canvas)", 8],
		["cv_dc (2D canvas)", 7],
		["cv_prims (2D canvas)", 9],
	]:
		var s := "%-44s" % spec[0]
		for cp in _cp_order:
			s += " %8d" % int((_cps[cp]["base"] as Array)[spec[1]])
		lines.append(s)
	for col: Array in [["objects", 1], ["shd_obj", 6], ["cv_obj", 8], ["draws", 0], ["prims", 2]]:
		lines.append("")
		(
			lines
			. append(
				(
					"== %s each source removes when hidden (sources moving it by >= 3 at any checkpoint) =="
					% col[0]
				)
			)
		)
		lines.append(head)
		for name in _src_order:
			var vals: Array = []
			var big := false
			for cp in _cp_order:
				var src: Dictionary = _cps[cp]["src"]
				var v: int = int((src[name] as Array)[col[1]]) if src.has(name) else 0
				vals.append(v)
				big = big or absi(v) >= 3
			if not big:
				continue
			var s := "%-44s" % name.left(44)
			for v: int in vals:
				s += " %8d" % v
			lines.append(s)
	lines.append("")
	lines.append("== node census (rows that change between checkpoints) ==")
	lines.append(head)
	var keys := {}
	for cp in _cp_order:
		for k: String in _cps[cp]["nodes"]:
			keys[k] = true
	var sorted := keys.keys()
	sorted.sort()
	for k: String in sorted:
		var vals: Array = []
		var lo := 1 << 30
		var hi := -(1 << 30)
		for cp in _cp_order:
			var v := int((_cps[cp]["nodes"] as Dictionary).get(k, 0))
			vals.append(v)
			lo = mini(lo, v)
			hi = maxi(hi, v)
		if lo == hi:
			continue
		var s := "%-44s" % k.left(44)
		for v: int in vals:
			s += " %8d" % v
		lines.append(s)
	var text := "\n".join(lines)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var f := FileAccess.open(
		"%sdraw_growth_%s%s.txt" % [OUT_DIR, _biome, "_" + _tag if not _tag.is_empty() else ""],
		FileAccess.WRITE
	)
	if f != null:
		f.store_string(text + "\n")
