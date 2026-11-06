extends SceneTree
## v0.9.5 PF5: proves a merged enemy rig (RigMerge) animates the way the old one did. For each enemy kind it builds one
## enemy through the real ActorViews._make_actor in a lit empty room with a fixed camera, plays a fixed scripted
## sequence (spawn rise, idle, walk, wind-up, attack, recover, a hit flash with a flinch, a burning tint, death) tick by
## tick, and saves the frame at CAPTURE_TICKS. It runs the sequence twice, with RigMerge.enabled false (the old rig)
## and true (the merged one), then compares the frames pixel by pixel and prints a table: the mean absolute
## difference per channel (0..255) and the share of pixels any channel of which differs by more than THRESHOLD.
## Frames go to build/shots/v0.9.5/pf5/<kind>/<old|new>_<tick>.png (untracked). Needs a renderer (NOT --headless):
##   APPDATA=$TEMP/zd-pf5 godot --language en --path . --resolution 480x480 --windowed -s scripts/checks/rig_compare.gd
##   ... -- [--kinds=needle,warden] [--skip=elite_breaker] [--no-shots] [--diffs]
## --kinds=a,b  only these (names from _kinds)   --skip=a,b  leave these out   --no-shots  do not write the PNGs
## --diffs  also write diff_<tick>.png (x4 amplified; slow).
## Accept rule (docs/roadmap/v0.9.5/PLAN.md PF5): mean < 0.5 and over-threshold share < 0.5 %; else the kind stays
## unmerged (RigMerge.skip_kinds).

const OUT_DIR := "res://build/shots/v0.9.5/pf5/"
const SIZE := 480
const THRESHOLD := 8
const MEAN_LIMIT := 0.5
const PCT_LIMIT := 0.5
const TICKS := 232
const CAPTURE_TICKS: Array[int] = [10, 30, 60, 90, 115, 126, 138, 148, 160, 167, 175, 185, 215]
const DT := 1.0 / 60.0
const SPAWN_END := 20
const WALK_FROM := 40
const WALK_TO := 100
const WINDUP_TO := 130
const ACTIVE_TO := 150
const RECOVER_TO := 170
const HIT_TICK := 165
const TINT_FROM := 178
const TINT_TO := 188
const DIE_TICK := 190
const WALK_SPEED := 2.0

var _views: ActorViews
var _cam: Camera3D
var _opts := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_run.call_deferred()


func _kinds() -> Array:
	var out := [
		["charger", WorldReader.KIND_CHARGER, 3.0],
		["hatchling", WorldReader.KIND_HATCHLING, 3.0],
		["warden", WorldReader.KIND_WARDEN, 4.2],
		["needle", WorldReader.KIND_NEEDLE, 3.0],
		["arc_caster", WorldReader.KIND_ARC_CASTER, 3.4],
		["bomb_drone", WorldReader.KIND_BOMB_DRONE, 3.0],
		["lens_drone", WorldReader.KIND_LENS_DRONE, 3.0],
		["swarmer", WorldReader.KIND_SWARMER, 3.0],
		["splitter", WorldReader.KIND_SPLITTER, 3.4],
		["splitling", WorldReader.KIND_SPLITLING, 3.0],
		["shield_bearer", WorldReader.KIND_SHIELD_BEARER, 3.4],
		["mender", WorldReader.KIND_MENDER, 3.6],
		["mine_layer", WorldReader.KIND_MINE_LAYER, 3.0],
		["sniper", WorldReader.KIND_SNIPER, 3.4],
		["elite_breaker", WorldReader.KIND_BREAKER, 5.0],
		["elite_rift_hunter", WorldReader.KIND_RIFT_HUNTER, 4.6],
		["elite_conduit", WorldReader.KIND_CONDUIT, 4.8],
	]
	var only: PackedStringArray = String(_opts.get("kinds", "")).split(",", false)
	var skip: PackedStringArray = String(_opts.get("skip", "")).split(",", false)
	return out.filter(
		func(k: Array) -> bool: return (only.is_empty() or only.has(k[0])) and not skip.has(k[0])
	)


func _run() -> void:
	root.size = Vector2i(SIZE, SIZE)
	_build_room()
	var lines: PackedStringArray = []
	var worst_ok := true
	var report := []
	for k: Array in _kinds():
		RigMerge.enabled = false
		var old_info := {}
		var old_frames := await _play(k, old_info)
		RigMerge.enabled = true
		_prime(k)
		var info := {}
		var new_frames := await _play(k, info)
		var row := _compare(String(k[0]), old_frames, new_frames, info)
		row["draws_old"] = old_info["draws"]
		row["draws_new"] = info["draws"]
		row["make_us"] = [old_info["make_us"], info["make_us"]]
		report.append(row)
		if not row["ok"]:
			worst_ok = false
		if not _opts.has("no-shots"):
			_save(String(k[0]), old_frames, new_frames)
	print("")
	print(
		(
			"rig_compare (mean abs diff per channel 0..255 | %% pixels > %d | accept: mean < %s, pct < %s)"
			% [THRESHOLD, MEAN_LIMIT, PCT_LIMIT]
		)
	)
	print(
		(
			"%-18s %7s %7s %6s %-8s %-26s %s"
			% ["kind", "mean", "pct>8", "tick", "verdict", "draws old -> new (casters)", "merged"]
		)
	)
	for r: Dictionary in report:
		print(
			(
				"%-18s %7.3f %7.3f %6d %-8s %-26s %s"
				% [
					r["name"],
					r["mean"],
					r["pct"],
					r["tick"],
					"OK" if r["ok"] else "DIFFERS",
					(
						"%d -> %d (%d -> %d)"
						% [
							r["draws_old"][1],
							r["draws_new"][1],
							r["draws_old"][2],
							r["draws_new"][2]
						]
					),
					r["info"]
				]
			)
		)
	print("")
	print(
		"build time of one enemy (_make_actor incl. the merge, microseconds, first build of a session is slower):"
	)
	for r: Dictionary in report:
		print("  %-18s old %6d  new %6d" % [r["name"], r["make_us"][0], r["make_us"][1]])
	print("")
	for r: Dictionary in report:
		print("  %s per-frame (tick: mean/pct/max channel diff): %s" % [r["name"], r["frames"]])
	print("ALL OK" if worst_ok else "SOME DIFFER")
	quit(0 if worst_ok else 1)


## Builds and drops one merged enemy of the kind, so the one that is compared takes its meshes from the cache, as every
## spawn after the first does in the game (the first build is checked by the unit tests and the first kind of a run).
func _prime(k: Array) -> void:
	var views := ActorViews.new()
	var actor: Node3D = views._make_actor(k[1], false, 0.5)
	actor.free()
	views.free()


func _build_room() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.18, 0.2, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.65)
	e.ambient_light_energy = 0.7
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 135, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 14.0
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.45, 0.4, 0.36)
	fm.roughness = 1.0
	floor_mi.material_override = fm
	root.add_child(floor_mi)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(_cam)
	_cam.current = true


## Plays the sequence for one kind; returns {tick: Image}. `info` gets the merge stats when the rig was merged.
func _play(k: Array, info := {}) -> Dictionary:
	_views = ActorViews.new()
	root.add_child(_views)
	var kind: int = k[1]
	var t0 := Time.get_ticks_usec()
	var actor: Node3D = _views._make_actor(kind, false, 0.5)
	info["make_us"] = Time.get_ticks_usec() - t0
	_views.add_child(actor)
	ActorViews.tint_greys(actor, _views.enemy_tint)
	ActorViews.role_glow(actor, kind, ActorViews.role_glow_energy)
	var avatar := actor.get_meta(&"enemy_avatar") as AvatarBase
	avatar.set_process(false)
	var rig := avatar.get_node_or_null("MergedRig") as MergedRig
	if rig != null:
		var st: Dictionary = rig.get_meta(&"stats", {})
		info["text"] = (
			"%d pieces, %d bones, %d surfaces, %d meshes"
			% [st["pieces"], st["bones"], st["surfaces"], st["instances"]]
		)
	_cam.size = k[2]
	var frames := {}
	var pos := Vector2.ZERO
	for tick in TICKS + 1:
		var state := WorldReader.STATE_MOVE
		var windup := 0.0
		if tick < SPAWN_END:
			state = WorldReader.STATE_SPAWN
		elif tick >= WALK_TO and tick < WINDUP_TO:
			state = WorldReader.STATE_WINDUP
			windup = float(tick - WALK_TO) / float(WINDUP_TO - WALK_TO)
		elif tick >= WINDUP_TO and tick < ACTIVE_TO:
			state = WorldReader.STATE_ACTIVE
		elif tick >= ACTIVE_TO and tick < RECOVER_TO:
			state = WorldReader.STATE_RECOVER
		if state == WorldReader.STATE_MOVE and tick >= WALK_FROM and tick < WALK_TO:
			pos.x += WALK_SPEED * DT
		actor.position = Vector3(pos.x, 0, pos.y)
		(
			avatar
			. apply_state(
				{
					"tick": tick,
					"pos": pos,
					"state": state,
					"windup": windup,
					"radius": 0.5,
					"pick": WorldReader.ELITE_BASIC,
					"vanished": false,
					"vulnerable": false,
					"healing": false,
				}
			)
		)
		if tick == HIT_TICK:
			avatar.flinch(Vector2.RIGHT, 1.0, 0.0)
			_views._set_flash(actor, true)
		elif tick == HIT_TICK + 3:
			_views._set_flash(actor, false)
		if tick == TINT_FROM:  # a status tint (burning) on the body
			_views._tint[7] = [Color(1.0, 0.45, 0.1), 0.9]
			_views._set_flash(actor, false, 7)
		elif tick == TINT_TO:
			_views._tint.erase(7)
			_views._set_flash(actor, false, 7)
		if tick == DIE_TICK and avatar.has_method("die"):
			avatar.call("die")
		avatar._process(DT)
		if CAPTURE_TICKS.has(tick):
			var offset := Vector3(5.0, 5.4, 5.0)
			_cam.position = actor.position + Vector3(0, 0.8, 0) + offset
			_cam.look_at(actor.position + Vector3(0, 0.8, 0))
			for _w in 3:  # a few frames so a pipeline compiled in the background is the one drawn
				await process_frame
				await RenderingServer.frame_post_draw
			if tick == 60:
				info["draws"] = _draws(avatar)
			var img := root.get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			frames[tick] = img
	actor.queue_free()
	_views.queue_free()
	await process_frame
	return frames


## [mesh instances, surfaces drawn, surfaces drawn into a shadow cascade] in the avatar's tree (what is submitted).
func _draws(n: Node) -> Array[int]:
	var out: Array[int] = [0, 0, 0]
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null and mi.is_visible_in_tree():
		var s := mi.mesh.get_surface_count()
		out[0] += 1
		out[1] += s
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			out[2] += s
	for c in n.get_children():
		var sub := _draws(c)
		for k in 3:
			out[k] += sub[k]
	return out


func _compare(name: String, a: Dictionary, b: Dictionary, info: Dictionary) -> Dictionary:
	var worst_mean := 0.0
	var worst_pct := 0.0
	var worst_tick := -1
	var per := []
	for tick: int in a:
		var da: PackedByteArray = (a[tick] as Image).get_data()
		var db: PackedByteArray = (b[tick] as Image).get_data()
		var sum := 0
		var over := 0
		var maxd := 0
		var n := da.size()
		var px := 0
		while px < n:
			var d0 := absi(da[px] - db[px])
			var d1 := absi(da[px + 1] - db[px + 1])
			var d2 := absi(da[px + 2] - db[px + 2])
			sum += d0 + d1 + d2
			maxd = maxi(maxd, maxi(d0, maxi(d1, d2)))
			if d0 > THRESHOLD or d1 > THRESHOLD or d2 > THRESHOLD:
				over += 1
			px += 3
		var mean := float(sum) / float(n)
		var pct := 100.0 * float(over) / float(n / 3)
		per.append("%d: %.3f/%.2f/max%d" % [tick, mean, pct, maxd])
		if mean > worst_mean or (mean == worst_mean and pct > worst_pct):
			worst_mean = mean
			worst_tick = tick
		worst_pct = maxf(worst_pct, pct)
	return {
		"name": name,
		"mean": worst_mean,
		"pct": worst_pct,
		"tick": worst_tick,
		"ok": worst_mean < MEAN_LIMIT and worst_pct < PCT_LIMIT,
		"frames": ", ".join(per),
		"info": info.get("text", "-"),
	}


func _save(name: String, a: Dictionary, b: Dictionary) -> void:
	var dir := ProjectSettings.globalize_path(OUT_DIR + name)
	DirAccess.make_dir_recursive_absolute(dir)
	for tick: int in a:
		(a[tick] as Image).save_png("%s/old_%d.png" % [dir, tick])
		(b[tick] as Image).save_png("%s/new_%d.png" % [dir, tick])
		if not _opts.has("diffs"):
			continue
		var d := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		var ia: Image = a[tick]
		var ib: Image = b[tick]
		var any := false
		for y in SIZE:
			for x in SIZE:
				var ca := ia.get_pixel(x, y)
				var cb := ib.get_pixel(x, y)
				var dr := absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
				if dr > 0.02:
					any = true
				d.set_pixel(x, y, Color(minf(dr * 4.0, 1.0), 0, 0))
		if any:
			d.save_png("%s/diff_%d.png" % [dir, tick])
