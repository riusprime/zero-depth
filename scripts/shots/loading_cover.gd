extends SceneTree
## v0.8.0 N3 (owner O45; docs/roadmap/v0.8.0/evidence/N3_RING_AND_LOADING.md): shots of the loading cover in the real
## main.tscn, posed by a script (a tool, not a test: it calls Main's own load, moves the player and kills the boss
## directly, as scripts/shots/portal_transit.gd does). 1: a new run's black cover with the corner mark, before the floor
## is built. Then the hero walks into floor 1's gate (or with --deep its Deep gate, when the floor has one): 2: the
## iris mid-way as the hero goes in, 3: closed while floor 2 loads, 4: opening on floor 2. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1600x900x24" \
##     godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/loading_cover.gd \
##     [-- --deep]
## Writes build/shots/<version>/loading/<gate|deep>_<n>_<moment>.png and prints each with the cover's state.

const SETTLE := 40

var main: Main
var _step := 0
var _frames := 0
var _deep := false
var _tag := "gate"
var _out := ""
var _mid := false


func _initialize() -> void:
	_deep = OS.get_cmdline_user_args().has("--deep")
	_tag = "deep" if _deep else "gate"
	_out = "res://build/shots/%s/loading/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	print(
		(
			"loading_cover: renderer=%s device=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	Main.fixed_seed = Main.STAGE_SEED
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _world() -> World:
	return main.driver.world


func _put(p: Vector2) -> void:
	var w := _world()
	w.actors.set_pos(0, p)
	w.vel = Vector2.ZERO
	main.view.rig.snap_to(SimPlane.to_3d(p))


func _shot(n: int, moment: String) -> void:
	var img := root.get_texture().get_image()
	var path := _out + "%s_%d_%s.png" % [_tag, n, moment]
	img.save_png(path)
	var c := main.loads.cover
	print(
		(
			"loading_cover: %s phase=%d style=%d amount=%.2f mark=%s floor=%s"
			% [
				path,
				c.phase,
				c.style,
				c.amount,
				c.mark.visible,
				str(main.run.floor_index) if main.run != null else "-"
			]
		)
	)


func _process(_delta: float) -> bool:
	_frames += 1
	var c := main.loads.cover
	match _step:
		0:
			if _frames == 3:
				main.loads.behind(self, main.ui, main.start_stage, Main.FADE_SECONDS)
				_next()
		1:
			if _frames == 1:
				_shot(1, "new_run_black")
			if main.driver != null and not c.showing():
				_world().actors.invuln[0] = 1 << 24
				_put(_world().floor_layout.boss_door_inside(2.5))
				_next()
		2:
			if _frames == SETTLE:
				var w := _world()
				var i := w.actors.index_of(w.boss_id)
				if i >= 0:
					w.actors.invuln[i] = 0
					Damage.hit(
						w, i, 999999, 0, 0, w.take_root(), 0, w.actors.pos(i), w.actors.pos(i)
					)
				_next()
		3:
			if _frames == SETTLE:
				var f := _world().floor_layout
				var deep := _deep and main.driver.reader.has_deep_portal()
				if _deep and not deep:
					print("loading_cover: floor 1 has no Deep gate; the plain gate instead")
					_tag = "gate"
				var pos := f.deep_portal_pos if deep else f.portal_pos
				var n := Kin.dir(f.deep_portal_angle if deep else f.portal_angle)
				_put(pos + n * (FloorLayout.GATE_HALF_DEPTH + 0.6))
				_next()
		4:
			if c.amount > 0.45 and c.amount < 0.75 and not _mid:
				_shot(2, "iris_closing")
				_mid = true
			if c.is_covered() and main.run.floor_index == 1:
				_shot(3, "closed_loading")
				_next()
		5:
			if (
				main.run.floor_index == 2
				and c.phase == LoadingCover.Phase.UNVEILING
				and c.amount < 0.6
			):
				_shot(4, "opening_floor_2")
				quit(0)
	if _frames > 3000:
		push_error("loading_cover: stuck at step %d" % _step)
		quit(1)
	return false


func _next() -> void:
	_step += 1
	_frames = 0
