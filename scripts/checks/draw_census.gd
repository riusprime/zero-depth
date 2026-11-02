extends SceneTree
## v0.10.5 (the owner's logged run, PERF_PLAYLOG_1: 67 % of the frame outside the scripts, the frame time following
## the draw calls): splits the draw calls and the objects drawn by source. Boots the real game (main.tscn), starts a
## run (seed 4404) on its first floor, the biome forced with --biome, and for each of SPOTS rooms (the start room and
## rooms spread over the floor) puts the hero at the room's centre, lets the floor run SETTLE sim ticks once the
## loading cover is gone (enemies wake, the camera arrives), pauses the sim and reads RenderingServer's per-frame totals
## and the root viewport's split (the camera pass, the shadow passes, the 2D) with everything shown, then with each
## source hidden in turn, each against the everything-shown reading just before it (its delta is what that source
## costs). A light is read by hiding it (its light and its shadow passes); the sun's shadow by turning it off.
## Counts, not timings. Needs a renderer, off screen:
##   "$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed -s scripts/checks/draw_census.gd -- \
##     --biome=red_canyon [--spots=5] [--tag=before] [--shot]
## Writes only under build/ (build/perf/draw_census_<biome>[_<tag>].txt; with --shot one shot per spot, everything
## shown, in build/shots/v0.10.5/draw/<biome>_<tag>_<spot>.png) and prints the same report. Quits on every path.

const OUT_DIR := "res://build/perf/"
const SHOT_DIR := "res://build/shots/v0.10.5/draw/"
const SETTLE := 90
const MIN_FRAMES := 30
## Frames after a toggle before reading (the renderer's info is the previous frame's), then frames read.
const WAIT := 4
const READ := 6
const SEED := 4404
## --fight=N: the frame probe's fight (PERF_Q5.md) instead of the floor: the Playground in the biome, the Gun with the
## probe's --heavy cards, god mode, fire held, the aim circling, N enemies kept 7-12 m round the hero; FIGHT_TICKS sim
## ticks, then the sim paused and the same census on that one frame.
const FIGHT_TICKS := 300
const BUILD_KEYS: Array[StringName] = [
	&"ITEM_GUN_GLAIVE", &"ITEM_GUN_RING", &"ITEM_SPLIT_SHOT", &"ITEM_EMBER_CORE", &"ITEM_STORM_CORE"
]
const HEAVY_KEYS: Array[StringName] = [
	&"ITEM_GUN_TWIN",
	&"ITEM_HALO_SHOT",
	&"ITEM_GUN_RAPID_FIRE",
	&"ITEM_WILDFIRE",
	&"ITEM_CHAIN_BLAST",
	&"ITEM_GUN_RUNE_EXPLOSION",
]

var _biome := &"red_canyon"
var _spots := 5
var _tag := ""
var _shot := false
var _fight := -1
var _main: Main
var _frame := 0
var _phase := 0
var _spot := 0
var _rooms: Array[int] = []
var _groups: Array = []  # [name, Callable(on: bool)]
## Steps at a spot: even, everything shown; odd 2k+1, source k hidden (each source against the reading just before).
var _step := 0
var _placed_at := 0
var _last_base: Array = []
## spot -> the everything-shown readings
var _bases := {}
var _wait := 0
var _reads: Array = []
## source -> spot -> what hiding it removed: [draws, objects, prims, cam_dc, cam_obj, shd_dc, shd_obj, canvas_dc]
var _results := {}
var _census := PackedStringArray()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("biome="):
			_biome = StringName(s.trim_prefix("biome="))
		elif s.begins_with("spots="):
			_spots = int(s.trim_prefix("spots="))
		elif s.begins_with("tag="):
			_tag = s.trim_prefix("tag=")
		elif s == "shot":
			_shot = true
		elif s.begins_with("fight="):
			_fight = int(s.trim_prefix("fight="))
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	match _phase:
		0:
			if _frame == 3 and _fight >= 0:
				_main._start_playground(&"gun", _biome)
				_phase = 10
				_frame = 0
			elif _frame == 3:
				_main._stage_seed = SEED
				_main.start_stage()
				_main._run_biomes.fill(_biome)  # every floor of the run this biome, then the floor rebuilt
				_main._restart_floor()
				_phase = 1
				_frame = 0
		1:
			if _frame == 10:
				_pick_rooms()
				_place()
				_phase = 2
				_frame = 0
		2:
			var w := _main.driver.world
			if (
				_frame >= MIN_FRAMES
				and w.tick >= _placed_at + SETTLE
				and not _main.loads.cover.showing()
			):
				_main.driver.paused = true
				_groups = _make_groups()
				if _spot == 0:
					_census_nodes()
				# The camera exactly on the hero (no follow lag), so before/after shots line up.
				_main.view.rig.snap_to(SimPlane.to_3d(_main.driver.world.player_pos()))
				_step = 0
				_wait = WAIT
				_reads = []
				_phase = 3
		3:
			return _measure()
		10:
			if _frame == 10:
				_setup_fight()
		11:
			_aim(Vector2(960, 540) + Vector2(cos(_frame * 0.02), sin(_frame * 0.02)) * 320.0)
			if _frame % 60 == 0:
				_top_up()
			if _main.driver.world.tick >= _placed_at + FIGHT_TICKS:
				_press_fire(false)
				_phase = 2
				_frame = MIN_FRAMES
	return false


func _setup_fight() -> void:
	var api: PlaygroundApi = _main.playground.api
	api.god = true
	for e: Dictionary in api.catalog():
		if BUILD_KEYS.has(e["name_key"]):
			api.grant_now(e["code"], 3)
		elif HEAVY_KEYS.has(e["name_key"]):
			api.grant_now(e["code"], 5)
	_rooms.append(-1)
	_placed_at = _main.driver.world.tick
	_top_up()
	_press_fire(true)
	_phase = 11
	print("draw_census: fight, %d enemies, biome=%s" % [_fight, _biome])


## As the frame probe: keeps _fight live enemies round the hero, 7-12 m out, kinds cycling.
func _top_up() -> void:
	var api: PlaygroundApi = _main.playground.api
	var w := _main.driver.world
	var a := w.actors
	var alive := 0
	for i in a.ids.size():
		if a.teams[i] == ActorStore.TEAM_ENEMY and a.dead[i] == 0 and a.hp[i] > 0:
			alive += 1
	var kinds := api.enemy_choices()
	var p := w.player_pos()
	var tries := 0
	while not kinds.is_empty() and alive < _fight and tries < maxi(80, _fight * 3):
		tries += 1
		var ang := float(tries * 137) * 0.0174533 + float(w.tick) * 0.01
		var dist := 7.0 + float((tries * 53) % 6)
		var kind: int = kinds[(tries + alive) % kinds.size()]["kind"]
		if api.place_enemy_now(kind, p + Vector2(cos(ang), sin(ang)) * dist):
			alive += 1


func _aim(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)


func _press_fire(on: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = on
	ev.position = Vector2(960, 540)
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func _pick_rooms() -> void:
	var f := _main.driver.world.floor_layout
	_rooms.append(f.start_room)
	var n := f.rooms.size()
	for k in range(1, _spots):
		var r := (f.start_room + int(float(k) * float(n) / float(_spots))) % n
		if r != f.boss_room and not _rooms.has(r):
			_rooms.append(r)
	print("draw_census: biome=%s rooms=%s of %d" % [_biome, str(_rooms), n])


func _place() -> void:
	var w := _main.driver.world
	w.actors.invuln[0] = 1 << 24
	_placed_at = w.tick
	var p := w.floor_layout.rooms[_rooms[_spot]].get_center()
	w.actors.set_pos(0, p)
	w.vel = Vector2.ZERO
	_main.view.rig.snap_to(SimPlane.to_3d(p))


func _measure() -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _shot and _step == 0 and _reads.is_empty():
		_save_shot()
	_reads.append(_read())
	if _reads.size() < READ:
		return false
	var row := _median_row(_reads)
	if _step % 2 == 0:  # everything shown: the baseline for the source hidden next
		_last_base = row
		if not _bases.has(_spot):
			_bases[_spot] = []
		_bases[_spot].append(row)
	else:
		var k := _step / 2
		(_groups[k][1] as Callable).call(true)
		var name := String(_groups[k][0]).get_slice(" (", 0)
		if not _results.has(name):
			_results[name] = {}
		var d := []
		for c in row.size():
			d.append(int(_last_base[c]) - int(row[c]))
		_results[name][_spot] = d
	_step += 1
	_reads = []
	_wait = WAIT
	if _step < _groups.size() * 2 + 1:
		if _step % 2 == 1:
			(_groups[_step / 2][1] as Callable).call(false)
		return false
	_spot += 1
	if _spot >= _rooms.size() or _fight >= 0:
		_report()
		return true
	_main.driver.paused = false
	_place()
	_phase = 2
	_frame = 0
	return false


func _read() -> Array:
	var vp := root.get_viewport_rid()
	var rs := RenderingServer
	return [
		rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		rs.viewport_get_render_info(
			vp, rs.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, rs.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
		),
		rs.viewport_get_render_info(
			vp, rs.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, rs.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME
		),
		rs.viewport_get_render_info(
			vp, rs.VIEWPORT_RENDER_INFO_TYPE_SHADOW, rs.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
		),
		rs.viewport_get_render_info(
			vp, rs.VIEWPORT_RENDER_INFO_TYPE_SHADOW, rs.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME
		),
		rs.viewport_get_render_info(
			vp, rs.VIEWPORT_RENDER_INFO_TYPE_CANVAS, rs.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
		),
	]


static func _median_row(rows: Array) -> Array:
	var out := []
	for c in (rows[0] as Array).size():
		var col: Array = []
		for r: Array in rows:
			col.append(r[c])
		col.sort()
		out.append(col[col.size() / 2])
	return out


## The sources, each a name and a setter (false: hidden). Built per spot (enemies come and go).
func _make_groups() -> Array:
	var v: WorldViewRoot = _main.view
	var stage := v.stage
	var kit := stage.kit
	var g: Array = []
	var ground: Array = []
	var stage_other: Array = []
	for c in stage.get_children():
		if c == kit or c == stage.shards or c == stage.atmosphere or c == stage.edge:
			continue
		if c == stage.contact_shadows:
			continue
		if c is Node3D:
			if String(c.name).begins_with("Ground"):
				ground.append(c)
			else:
				stage_other.append(c)
	g.append(["floor: ground tiles", _vis_setter(ground)])
	if kit != null:
		var wall_nodes: Array = []
		var linked := {}
		for arr: Array in kit.wall_pieces:
			for n: Node3D in arr:
				linked[n] = true
		var proc: Array = []
		var pieces: Array = []
		var props: Array = []
		var decor: Array = []
		var flames: Array = []
		for c in kit.get_children():
			if c is OmniLight3D:
				continue
			if String(c.name).begins_with("Decor_"):
				decor.append(c)
			elif String(c.name).begins_with("ProcWall_"):
				proc.append(c)
			elif linked.has(c):
				pieces.append(c)
			elif c is MeshInstance3D and c.get_meta(&"piece", &"") == &"":
				flames.append(c)
			else:
				props.append(c)
		wall_nodes.append_array(proc)
		g.append(["walls: procedural wall meshes (%d)" % proc.size(), _vis_setter(proc)])
		g.append(["walls: kit wall/cover pieces (%d)" % pieces.size(), _vis_setter(pieces)])
		g.append(["props: kit pieces not on a wall (%d)" % props.size(), _vis_setter(props)])
		g.append(
			["decor: kit decoration MultiMeshes (%d kinds)" % decor.size(), _vis_setter(decor)]
		)
		g.append(["lights: torch flames (%d)" % flames.size(), _vis_setter(flames)])
		# The kit's _process fades its lights in and out each frame: held still while one is hidden.
		g.append(["lights: torch OmniLight3D (%d)" % kit.lights.size(), _kit_lights(kit, true)])
		g.append(["lights: torch shadows", _kit_lights(kit, false)])
	if stage.contact_shadows != null:
		g.append(["floor: contact shadows", _vis_setter([stage.contact_shadows])])
	if stage.shards != null:
		g.append(["decor: shard clusters", _vis_setter([stage.shards])])
	if stage.edge != null:
		g.append(["floor: biome edge (past the floor)", _vis_setter([stage.edge])])
	if stage.atmosphere != null:
		g.append(["fx: stage atmosphere (fog, embers, dust)", _vis_setter([stage.atmosphere])])
	g.append(["stage: other children (%d)" % stage_other.size(), _vis_setter(stage_other)])
	if stage.sun != null:
		var sun := stage.sun
		g.append(["lights: sun shadow", func(on: bool) -> void: sun.shadow_enabled = on])
	var hero: Node3D = v.actors._actors.get(_main.driver.reader.actor_id(0))
	var enemies: Array = []
	for id in v.actors._actors:
		if v.actors._actors[id] != hero:
			enemies.append(v.actors._actors[id])
	if hero != null:
		g.append(["hero", _vis_setter([hero])])
	g.append(["enemies (%d)" % enemies.size(), _vis_setter(enemies)])
	var actor_other: Array = []
	for c in v.actors.get_children():
		if c is Node3D and c != hero and not enemies.has(c):
			actor_other.append(c)
	g.append(["actors: other (projectiles, bars)", _vis_setter(actor_other)])
	var fx: Array = []
	for c in v.get_children():
		if c is Node3D and c != stage and c != v.actors and c != v.rig:
			fx.append(c)
	g.append(["fx: the other views (%d)" % fx.size(), _vis_setter(fx)])
	for c: Node3D in fx:  # and each of them alone
		g.append(["  view: %s" % _label(c), _vis_setter([c])])
	# The 2D on top: each of the HUD's parts, the UI layer's other children, the view's own canvas layers.
	var hud: Node = _main._hud
	for c in _main.ui.get_children():
		if c == hud:
			for h in hud.get_children():
				if h is CanvasItem and h.visible:
					g.append(["hud: %s" % _label(h), _vis_setter([h])])
		elif c is CanvasItem and c.visible:
			g.append(["ui: %s" % _label(c), _vis_setter([c])])
	for c in v.find_children("*", "CanvasLayer", true, false):
		var layer := c as CanvasLayer
		g.append(["view canvas layer: %s" % layer.name, _layer_setter(layer)])
	return g


static func _label(n: Node) -> String:
	var script: Script = n.get_script()
	var cls := script.get_global_name() if script != null else StringName()
	return String(cls) if cls != &"" else "%s %s" % [n.get_class(), n.name]


func _layer_setter(layer: CanvasLayer) -> Callable:
	var was := layer.visible
	return func(on: bool) -> void:
		if is_instance_valid(layer):
			layer.visible = was if on else false


## Hides the kit's lights (whole: true) or turns their shadows off, with the kit's light fades held.
func _kit_lights(kit: StageKit, whole: bool) -> Callable:
	var vis := {}
	var shd := {}
	for l: OmniLight3D in kit.lights:
		vis[l] = l.visible
		shd[l] = l.shadow_enabled
	return func(on: bool) -> void:
		kit.set_process(on)
		for l: OmniLight3D in vis:
			if whole:
				l.visible = vis[l] if on else false
			else:
				l.shadow_enabled = shd[l] if on else false


func _vis_setter(nodes: Array) -> Callable:
	var was := {}
	for n in nodes:
		was[n] = n.visible
	return func(on: bool) -> void:
		for n: Node in was:
			if is_instance_valid(n):
				n.visible = was[n] if on else false


func _census_nodes() -> void:
	var v: Node = _main.view
	var counts := {}
	var parts := 0
	var parts_on := 0
	var omni := 0
	var omni_on := 0
	var omni_shadow := 0
	var casters := 0
	for n in v.find_children("*", "", true, false):
		var k := n.get_class()
		counts[k] = int(counts.get(k, 0)) + 1
		if n is GPUParticles3D or n is CPUParticles3D:
			parts += 1
			if n.emitting and (n as Node3D).is_visible_in_tree():
				parts_on += 1
		if n is OmniLight3D:
			omni += 1
			if (n as Node3D).is_visible_in_tree():
				omni_on += 1
			if n.shadow_enabled:
				omni_shadow += 1
		if (
			n is GeometryInstance3D
			and n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and (n as Node3D).is_visible_in_tree()
		):
			casters += 1
	var vps := PackedStringArray()
	for n in root.find_children("*", "SubViewport", true, false):
		var sv := n as SubViewport
		vps.append(
			"%s %s update=%d" % [sv.get_parent().name, str(sv.size), sv.render_target_update_mode]
		)
	_census.append("SubViewports in the tree: %d %s" % [vps.size(), str(vps)])
	var keys := counts.keys()
	keys.sort_custom(func(a, b) -> bool: return counts[a] > counts[b])
	_census.append("nodes under the view: %d" % v.find_children("*", "", true, false).size())
	var top := PackedStringArray()
	for k in keys.slice(0, 10):
		top.append("%s %d" % [k, counts[k]])
	_census.append("  by class: " + ", ".join(top))
	_census.append("  particles: %d (emitting and shown: %d)" % [parts, parts_on])
	_census.append("  drawn but empty (shown, nothing to draw), by view: " + str(_idle_drawn(v)))
	_census.append(
		(
			"  OmniLight3D: %d (shown %d, shadow on %d)  shadow-casting geometry shown: %d"
			% [omni, omni_on, omni_shadow, casters]
		)
	)


## Geometry that is shown but has nothing to draw: a MultiMesh with no visible instance, particles not emitting.
func _idle_drawn(v: Node) -> Dictionary:
	var out := {}
	var culled := 0
	for c in v.get_children():
		var n := 0
		for g in c.find_children("*", "GeometryInstance3D", true, false):
			if not (g as Node3D).is_visible_in_tree():
				continue
			if g is MultiMeshInstance3D:
				var mm: MultiMesh = g.multimesh
				var shown := mm.visible_instance_count if mm != null else 0
				if mm == null or shown == 0 or (shown < 0 and mm.instance_count == 0):
					n += 1
					if g.has_meta(&"empty_draw_cull"):  # v0.10.5: kept out of the renderer
						culled += 1
			elif g is GPUParticles3D and not g.emitting:
				n += 1
		if n > 0:
			out[_label(c)] = n
	out["(of which EmptyDrawCull keeps out of the renderer)"] = culled
	return out


func _save_shot() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var path := (
		"%s%s%s_%s_%d.png"
		% [
			SHOT_DIR,
			_biome,
			"_fight%d" % _fight if _fight >= 0 else "",
			_tag if not _tag.is_empty() else "shot",
			_spot
		]
	)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("shot: ", ProjectSettings.globalize_path(path))


func _sha() -> String:
	var out: Array = []
	OS.execute("git", ["rev-parse", "--short=8", "HEAD"], out)
	return String(out[0]).strip_edges() if not out.is_empty() else "?"


static func _mean_col(rows: Dictionary, c: int) -> float:
	var s := 0.0
	for k: int in rows:
		s += float(rows[k][c])
	return s / maxf(1.0, float(rows.size()))


func _report() -> void:
	var lines := PackedStringArray()
	lines.append("draw_census  sha=%s  biome=%s  fight=%d  tag=%s" % [_sha(), _biome, _fight, _tag])
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
				(
					"run seed %d, first floor, rooms %s, %d sim ticks settle, sim paused while read"
					% [SEED, str(_rooms), SETTLE]
				)
				if _fight < 0
				else (
					"fight: Playground, Gun + the frame probe's --heavy cards, %d enemies kept, %d sim ticks, then paused"
					% [_fight, FIGHT_TICKS]
				)
			)
		)
	)
	lines.append_array(_census)
	lines.append(
		"mean over the spots; a source's row is what hiding it removes (all shown minus hidden)"
	)
	var base := {}
	for k: int in _bases:
		base[k] = _median_row(_bases[k])
	lines.append(
		(
			"%-44s %7s %7s %9s | %6s %7s | %6s %7s | %6s"
			% [
				"source",
				"draws",
				"objects",
				"prims",
				"cam_dc",
				"cam_obj",
				"shd_dc",
				"shd_obj",
				"cv_dc"
			]
		)
	)
	var row := func(label: String, vals: Array) -> String:
		return "%-44s %7.0f %7.0f %9.0f | %6.0f %7.0f | %6.0f %7.0f | %6.0f" % ([label] + vals)
	var b := []
	for c in 8:
		b.append(_mean_col(base, c))
	lines.append(row.call("all shown (total)", b))
	var skipped := 0
	for name: String in _results:
		var rows: Dictionary = _results[name]
		var d := []
		for c in 8:
			d.append(_mean_col(rows, c))
		if absf(d[0]) < 1.5 and absf(d[1]) < 1.5:
			skipped += 1
			continue
		lines.append(row.call(name, d))
	lines.append("(%d sources that move draws and objects by under 1.5 not listed)" % skipped)
	(
		lines
		. append(
			(
				"per spot, all shown (draws objects prims cam_dc cam_obj shd_dc shd_obj cv_dc), median of %d readings:"
				% (_groups.size() + 1)
			)
		)
	)
	for k: int in base:
		var bs: Array = _bases[k]
		var lo: Array = bs.reduce(func(m, r) -> Array: return r if r[0] < m[0] else m, bs[0])
		var hi: Array = bs.reduce(func(m, r) -> Array: return r if r[0] > m[0] else m, bs[0])
		lines.append(
			(
				"  room %d: %s  (draws over the readings %d..%d)"
				% [_rooms[k], str(base[k]), lo[0], hi[0]]
			)
		)
	var text := "\n".join(lines)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var f := FileAccess.open(
		(
			"%sdraw_census_%s%s%s.txt"
			% [
				OUT_DIR,
				_biome,
				"_fight%d" % _fight if _fight >= 0 else "",
				"_" + _tag if not _tag.is_empty() else ""
			]
		),
		FileAccess.WRITE
	)
	if f != null:
		f.store_string(text + "\n")
