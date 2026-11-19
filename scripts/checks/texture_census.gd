extends SceneTree
## What the video memory's textures are, in the real game: it boots main.tscn, starts a run (Play, Blade), waits for
## the floor to settle and lists every texture the renderer holds (RenderingServer.texture_debug_usage): the total, the
## total by format, by folder and by kind (the renderer's own targets, imported files, ones made in code), and the
## biggest ones with their size, format and mipmaps. Counts, not timings; the game is unchanged.
## Needs a renderer (not --headless); run it off screen:
##   godot --path . --position -10000,-10000 --resolution 2560x1440 --windowed -s scripts/checks/texture_census.gd \
##     [-- --top=40] [-- --wait=600]
## Report on stdout and in build/perf/texture_census_<sha>.txt (never into docs).

var _main: Main
var _frame := 0
## Frames since the run's driver exists.
var _since := 0
var _top := 40
var _wait := 600
var _lines := PackedStringArray()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--top="):
			_top = int(a.trim_prefix("--top="))
		elif a.begins_with("--wait="):
			_wait = int(a.trim_prefix("--wait="))
	Main.quick_start = true  # Play opens the build screen, the pick starts the run (no hub walk)
	Main.fixed_seed = Main.STAGE_SEED
	ProfileStore.use_shared(ProfileStore.new(""))
	SwordLock.grant(ProfileStore.shared())
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _main.driver != null and _main.driver.world != null:
		_main.driver.world.actors.invuln[0] = 2  # probe setup: the hero can't be hurt
	if _frame in [10, 20]:
		_tap(KEY_ENTER)  # Play, then Blade
	if _main.driver == null or _main.driver.world == null or _frame < 300:
		return false
	_since += 1
	if _since == _wait:
		_census()
		_finish()
	return false


func _census() -> void:
	var seen := {}
	var stack: Array[Node] = [root]
	var walked := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		walked += 1
		stack.append_array(n.get_children(true))
		for t in _textures_of(n):
			if t != null:
				seen[t.get_rid()] = t
	var total := 0.0
	var by_dir := {}
	var by_mode := {}
	var rows: Array = []
	for rid: RID in seen:
		var t: Texture = seen[rid]
		var est := _estimate(t)
		total += est[0]
		var path := t.resource_path
		var dir := path.get_base_dir() if path.begins_with("res://") else "(made in code)"
		by_dir[dir] = float(by_dir.get(dir, 0.0)) + est[0]
		by_mode[est[1]] = float(by_mode.get(est[1], 0.0)) + est[0]
		rows.append([est[0], est[1], t, path])
	_out(
		(
			(
				"textures the scene's nodes use: %d, about %.1f MB (estimated from their size, import and mipmaps); "
				+ "the renderer's texture_mem_used: %.1f MB (all textures, render targets included)"
			)
			% [
				rows.size(),
				total / 1048576.0,
				(
					RenderingServer.get_rendering_info(
						RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED
					)
					/ 1048576.0
				)
			]
		)
	)
	_out("nodes walked: %d" % walked)
	_out("by import: " + _top_of(by_mode, 12))
	_out("by folder: " + _top_of(by_dir, 30))
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	_out("the %d biggest (MB est., w x h, import, path):" % _top)
	for k in mini(_top, rows.size()):
		var r: Array = rows[k]
		var t: Texture = r[2]
		var wh := "%dx%d" % [t.get_width(), t.get_height()] if t is Texture2D else t.get_class()
		_out("  %7.2f  %s  %s  %s" % [float(r[0]) / 1048576.0, wh, r[1], r[3]])


## Every texture node `n` draws with: its materials' (and its mesh's) texture parameters, a decal's, a sprite's or a
## control's own texture.
static func _textures_of(n: Node) -> Array:
	var out: Array = []
	var mats: Array = []
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		mats.append(g.material_override)
		mats.append(g.material_overlay)
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				mats.append(mi.get_active_material(s))
	if n is MultiMeshInstance3D:
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm != null and mm.mesh != null:
			for s in mm.mesh.get_surface_count():
				mats.append(mm.mesh.surface_get_material(s))
	if n is GPUParticles3D:
		var gp := n as GPUParticles3D
		for k in gp.draw_passes:
			var m := gp.get_draw_pass_mesh(k)
			if m != null:
				for s in m.get_surface_count():
					mats.append(m.surface_get_material(s))
	if n is Decal:
		var d := n as Decal
		for k in [
			Decal.TEXTURE_ALBEDO, Decal.TEXTURE_NORMAL, Decal.TEXTURE_ORM, Decal.TEXTURE_EMISSION
		]:
			out.append(d.get_texture(k))
	if n is SpriteBase3D and n.get(&"texture") != null:
		out.append(n.get(&"texture"))
	if n is TextureRect:
		out.append((n as TextureRect).texture)
	if n is NinePatchRect:
		out.append((n as NinePatchRect).texture)
	if n is WorldEnvironment:
		var e := (n as WorldEnvironment).environment
		if e != null and e.sky != null:
			mats.append(e.sky.sky_material)
	for m: Variant in mats:
		if m is BaseMaterial3D:
			for k in BaseMaterial3D.TEXTURE_MAX:
				out.append((m as BaseMaterial3D).get_texture(k))
		elif m is ShaderMaterial and (m as ShaderMaterial).shader != null:
			var sm := m as ShaderMaterial
			for u: Dictionary in sm.shader.get_shader_uniform_list():
				var v: Variant = sm.get_shader_parameter(u["name"])
				if v is Texture:
					out.append(v)
		elif m is ParticleProcessMaterial or m is PanoramaSkyMaterial:
			pass
	var kept: Array = []
	for t: Variant in out:
		if t is Texture:
			kept.append(t)
	return kept


## [bytes, import] of texture `t`, estimated: width x height (x layers) x bytes a pixel by its import (a VRAM-compressed
## file 1 byte, BC1 0.5 for an opaque one is not told apart; lossless and lossy files decode to 4), a third more with
## mipmaps. A texture made in code: its image's own size.
static func _estimate(t: Texture) -> Array:
	var w := 0
	var h := 0
	var layers := 1
	if t is Texture2D:
		w = (t as Texture2D).get_width()
		h = (t as Texture2D).get_height()
	elif t is Texture3D:
		w = (t as Texture3D).get_width()
		h = (t as Texture3D).get_height()
		layers = (t as Texture3D).get_depth()
	elif t is TextureLayered:
		w = (t as TextureLayered).get_width()
		h = (t as TextureLayered).get_height()
		layers = (t as TextureLayered).get_layers()
	var path := t.resource_path
	var mode := "code"
	var bpp := 4.0
	var mips := false
	if path.begins_with("res://") and FileAccess.file_exists(path + ".import"):
		var cfg := ConfigFile.new()
		if cfg.load(path + ".import") == OK:
			var m := int(cfg.get_value("params", "compress/mode", 0))
			mode = ["lossless", "lossy", "vram", "vram_uncompressed", "basis"][clampi(m, 0, 4)]
			bpp = 1.0 if m == 2 or m == 4 else 4.0
			mips = bool(cfg.get_value("params", "mipmaps/generate", false)) or m == 2
			mode += "+mips" if mips else ""
	elif t is ImageTexture:
		var img := (t as ImageTexture).get_image()
		if img != null:
			return [float(img.get_data_size()), "code (%s)" % img.get_format()]
	return [w * h * layers * bpp * (4.0 / 3.0 if mips else 1.0), mode]


static func _top_of(d: Dictionary, n: int) -> String:
	var keys := d.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return d[a] > d[b])
	var parts := PackedStringArray()
	for k in mini(n, keys.size()):
		parts.append("%s %.1f MB" % [keys[k], int(d[keys[k]]) / 1048576.0])
	return ", ".join(parts)


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _out(line: String) -> void:
	print(line)
	_lines.append(line)


func _finish() -> void:
	var out := []
	OS.execute("git", ["rev-parse", "--short", "HEAD"], out)
	var tag := String(out[0]).strip_edges() if not out.is_empty() else "nosha"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/perf"))
	var f := FileAccess.open("res://build/perf/texture_census_%s.txt" % tag, FileAccess.WRITE)
	if f != null:
		f.store_string(
			"texture_census sha=%s adapter=%s\n" % [tag, RenderingServer.get_video_adapter_name()]
		)
		f.store_string("\n".join(_lines) + "\n")
	quit(0)
