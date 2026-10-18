extends SceneTree
## v0.8.0 N18 shots (owner O76; needs a renderer, not --headless): the views the step changed, drawn by the game's own
## presentation nodes over a plain dark backdrop, in one language. Shot setup only (a tool, not a test): the worlds are
## built by the test labs (the final arena stepped by the sim to The Fallen's mirror); the real input paths are the e2e
## tests.
##   1_wand_row  - the wand row (the Build page's and the Swap panel's tiles) holding Arc Field first: in Spanish
##                 "Electromagnetismo", drawn smaller so the word fits its tile (TextFit.word_fit_size);
##   2_boss_bars - a boss bar on The Warlord and the final fight's bar on its last body, The Fallen, mid-mirror;
##   3_codex_boss - the Codex's Bosses page, every boss met, The Warlord shown (its one look line).
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/text_n18.gd -- lang=es
## Writes build/shots/<version>/n18/<lang>/<n>_<label>.png. Quits on every path.

const SETTLE := 12
const CARDS: Array[StringName] = [&"arc_field", &"frost_nova", &"orbit_blades", &"drone_buddy"]

var _lang := "es"
var _dir := ""
var _layer: CanvasLayer
var _frame := 0
var _wait := 0
var _step := -1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("lang="):
			_lang = a.trim_prefix("lang=")
	TranslationServer.set_locale(_lang)
	_dir = "res://build/shots/%s/n18/%s/" % [GameVersion.label(), _lang]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	print("n18: renderer=%s lang=%s" % [RenderingServer.get_current_rendering_method(), _lang])


func _fresh() -> Control:
	if _layer != null:
		_layer.queue_free()
	_layer = CanvasLayer.new()
	root.add_child(_layer)
	var screen := Control.new()
	screen.size = Vector2(1920, 1080)
	_layer.add_child(screen)
	var bg := ColorRect.new()
	bg.color = Color("#14161C")
	bg.size = screen.size
	screen.add_child(bg)
	return screen


func _wand_row() -> void:
	var screen := _fresh()
	var w := WandLab.fight(&"blade", CARDS)
	var row := WandRow.new()
	screen.add_child(row)
	row.position = Vector2(200, 380)
	row.show_wand(WorldReader.new(w).wand(), 6)
	for k in row.card_count():
		print("n18: tile %d '%s' at %d px" % [k, row.card_name(k), row.name_size(k)])


func _boss_bars() -> void:
	var screen := _fresh()
	var w := BossLab.world()
	BossLab.ready_boss(w, &"warlord", Vector2(4, 0))
	var bar := BossBar.new()
	screen.add_child(bar)
	bar.sync(WorldReader.new(w))
	var f := FinalLab.arena(FinalLab.run_state(4646, &"blade"))
	FinalLab.past_rise(f)
	for k in 2:  # the Colossus, then the Prism, fall: The Fallen rises
		FinalLab.end_segment(f)
		FinalLab.through_shatter(f)
		FinalLab.past_rise(f)
	var fr := WorldReader.new(f)
	for t in 2400:  # to its first mirror window (the sim's own clock)
		if int(fr.final_pace().get("window", WorldReader.FALLEN_OFF)) == WorldReader.FALLEN_ON:
			break
		f.step(InputFrame.new())
	var fb := BossBar.new()
	screen.add_child(fb)
	fb.sync(fr)
	fb.position.y += 260
	print("n18: bars '%s' / '%s'" % [bar.boss_name(), fb.boss_name()])


func _codex(page: StringName, id: StringName) -> void:
	var screen := _fresh()
	var repo := ContentRepository.load_all()
	var catalog := CodexCatalog.build(repo)
	var store := CodexStore.new(ProfileStore.new(""))
	for p: StringName in [&"bosses", &"cards"]:
		for e: Dictionary in catalog.entries(p):
			store.unlock(p, e["id"])
	var v := CodexView.new(catalog, store)
	screen.add_child(v)
	v.open(page)
	var t := v.tile(id)
	if t != null:
		t.grab_focus()
		print(
			(
				"n18: codex %s/%s name '%s' at %d px"
				% [page, id, t.name_label.text, t.name_label.get_theme_font_size("font_size")]
			)
		)


func _shot(shot_name: String) -> bool:
	var path := _dir + "%s.png" % shot_name
	var img := root.get_texture().get_image()
	if img == null or img.save_png(path) != OK:
		push_error("n18: could not save %s" % path)
		quit(1)
		return false
	print("n18: wrote ", ProjectSettings.globalize_path(path))
	return true


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 600:
		quit(1)
	elif _wait > 0:
		_wait -= 1
	else:
		_step += 1
		_advance()
	return false


func _advance() -> void:
	match _step:
		0:
			_wand_row()
			_wait = SETTLE
		1:
			if _shot("1_wand_row"):
				_boss_bars()
				_wait = SETTLE
		2:
			if _shot("2_boss_bars"):
				_codex(&"bosses", &"warlord")
				_wait = SETTLE
		3:
			if _shot("3_codex_boss"):
				quit(0)
