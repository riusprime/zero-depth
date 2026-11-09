extends SceneTree
## v0.10.5 W3-O19 (owner 2026-11-04 night: every UI element in Astral): the Build page, the Codex (cards, enemies,
## lore, achievements, collectibles), an event's panel, the hub's prompt and its station panels (Wardrobe, Progression,
## the Training terminal) and the small parts (the input chips, the depths tag, a banner plaque, the Runic Stone's
## bubble) in the Astral style. The real main.tscn boots to the hub on a memory-only profile (its frame is what the
## pages blur); the hero is placed by the Portal Machine for the prompt (a tool, not a test: it moves the hero in the
## hub's World directly). The Wardrobe and Progression open through the hub's own session; the other pages are built
## over the hub as their sessions build them, from fixed data: the Build page holds the eight-card Blade wand of the
## wand-view tests (WorldReader of that World, its forecast too); the event panel is Blood Price on EventLab's floor
## (seed 4242); the Codex has a few entries met. A tool, not a test; it quits on every path. Needs a renderer:
##   godot --path . --audio-driver Dummy --position -10000,-10000 --resolution 1920x1080 \
##     -s scripts/shots/w3o19_astral_pages.gd -- lang=en
## Writes build/shots/v0.10.5/w3o19/<lang>_<screen>.png (lang=es: the three longest only: codex_cards, event, training).

const OUT := "res://build/shots/v0.10.5/w3o19/"
const SETTLE := 40
const EIGHT: Array = [
	&"heavy",
	&"chain_blast",
	&"whirl",
	&"flurry",
	&"shared_bleed",
	&"parry_edge",
	&"frost_core",
	&"echo_slash",
]
const ES_ONLY := ["codex_cards", "event", "training"]

var main: Main
var _lang := "en"
var _frame := 0
var _wait := 0
var _step := 0
var _layer: CanvasLayer
var _shown: Control
var _repo: ContentRepository
var _steps: Array[String] = [
	"boot",
	"hub_prompt",
	"build",
	"codex_cards",
	"codex_enemies",
	"codex_lore",
	"codex_achievements",
	"codex_collectibles",
	"event",
	"wardrobe",
	"gap",
	"progression",
	"gap",
	"training",
	"parts",
]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("lang="):
			_lang = arg.trim_prefix("lang=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	TranslationServer.set_locale(_lang)
	_repo = ContentRepository.load_all()
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = _lang
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_layer = CanvasLayer.new()
	_layer.layer = 60
	root.add_child(_layer)
	_wait = 90


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 6000:
		print("w3o19: gave up")
		quit(1)
		return true
	if _wait > 0:
		_wait -= 1
		return false
	if _step > 0 and _step <= _steps.size():
		var done := _steps[_step - 1]
		if done != "boot" and done != "gap" and (_lang == "en" or ES_ONLY.has(done)):
			_grab(done)
		_clear()
	if _step >= _steps.size():
		print("w3o19: done")
		quit(0)
		return true
	var s := _steps[_step]
	_step += 1
	if _lang != "en" and s != "boot" and not ES_ONLY.has(s):
		return false
	if s == "gap":  # a few frames for the Esc that closed the hub's panel
		_wait = 6
		return false
	_wait = SETTLE
	match s:
		"boot":
			_key(KEY_ENTER)  # Play: to the hub
			_wait = 120
		"hub_prompt":
			var w := main.hub.driver.world
			w.actors.set_pos(0, HubLayout.to_sim(Vector2(0.0, -3.2)))
			w.vel = Vector2.ZERO
			_wait = 70
		"build":
			_show_build()
		"codex_cards":
			_show_codex(&"cards", &"gun_twin")
		"codex_enemies":
			_show_codex(&"enemies", &"charger")
		"codex_lore":
			_show_codex(&"lore", &"")
		"codex_achievements":
			_show_codex(CodexView.ACHIEVEMENTS, &"")
		"codex_collectibles":
			_show_codex(CodexView.COLLECTIBLES, &"")
		"event":
			_show_event()
		"wardrobe":
			main.hub.open_wardrobe()
		"progression":
			main.hub.open_progression()
		"training":
			_show_training()
		"parts":
			_show_parts()
	return false


func _grab(shot: String) -> void:
	var path := OUT + "%s_%s.png" % [_lang, shot]
	root.get_texture().get_image().save_png(path)
	print("w3o19: ", path)


func _clear() -> void:
	if _shown != null:
		_shown.queue_free()
		_shown = null
	if main.hub != null and (_steps[_step - 1] in ["wardrobe", "progression"]):
		_key(KEY_ESCAPE)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _put(c: Control) -> void:
	var screen := Control.new()
	screen.size = Vector2(1920, 1080)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(screen)
	screen.add_child(c)
	_shown = screen


func _wand_world() -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(5, t)
	w.floor_index = 5
	w.dummy_speed = 0.0
	w.wand_table = WandCompiler.from_repo(_repo)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.set_combo_tables(ContentCompiler.compile_combos(_repo))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	for id: StringName in EIGHT:
		BuildSlots.take(w, WandLab.code(w, id))
	return w


func _show_build() -> void:
	var r := WorldReader.new(_wand_world())
	var page := BuildPage.new()
	_put(page)
	page.open(r.wand(), 8, r)
	page.row.focus = 2
	page.row.refresh_marks()


func _codex_store() -> CodexStore:
	var store := CodexStore.new(ProfileStore.new(""))
	for id: StringName in [&"gun_twin", &"gun_pierce", &"ember_core", &"heavy", &"whirl", &"blink"]:
		store.add(&"cards", id, &"taken", 2)
	store.raise_to(&"cards", &"gun_twin", &"level", 3)
	for id: StringName in [&"charger", &"sniper", &"splitter"]:
		store.add(&"enemies", id, &"kills", 14)
	store.add(&"biomes", &"ruins", &"visits", 3)
	return store


func _show_codex(p: StringName, focus_id: StringName) -> void:
	var store := _codex_store()
	var catalog := CodexCatalog.build(_repo)
	for s: StringName in catalog.sections(&"lore"):
		for e: Dictionary in catalog.section_entries(&"lore", s).slice(0, 2):
			store.unlock(&"lore", e["id"])
	var book := AchievementBook.build(
		_repo, AchievementStore.new(ProfileStore.new("")), store, catalog
	)
	var v := CodexView.new(catalog, store, book)
	_put(v)
	v.open(p)
	if focus_id != &"" and v.tile(focus_id) != null:
		v.tile(focus_id).grab_focus()


func _show_event() -> void:
	var w := EventLab.world(4242, 1, &"blade", [&"heavy_hands"])
	Stats.add_card(w, Stats.Stat.DAMAGE, 0)
	EventLab.set_event(w, &"blood_price")
	EventLab.open(w)
	var panel := EventPanel.new()
	_put(panel)
	panel.sync(WorldReader.new(w))


func _show_training() -> void:
	var catalog := CodexCatalog.build(_repo)
	var enemies: Array[Dictionary] = []
	for e: Dictionary in catalog.section_entries(&"enemies", catalog.sections(&"enemies")[0]).slice(
		0, 3
	):
		enemies.append({"kind": 0, "name_key": e["name_key"]})
	var cards: Array[Dictionary] = []
	for e: Dictionary in catalog.section_entries(&"cards", catalog.sections(&"cards")[0]).slice(
		0, 4
	):
		cards.append({"code": 0, "name_key": e["name_key"]})
	var weapons: Array = []
	for id: StringName in [&"blade", &"gun"]:
		weapons.append({"id": id, "name_key": _repo.get_def(&"build", id).name_key})
	var p := TrainingPanel.new(enemies, [1, 3, 8], weapons, &"blade", cards, 5)
	_put(p)
	p.show_status("UI_TRAINING_SPAWNED", "")
	p.focus_first()


## The small parts on one frame: the interact chips (key, Xbox, PlayStation), the depths tag, a banner plaque and an
## event plaque focused and not, the Runic Stone's bubble.
func _show_parts() -> void:
	var c := Control.new()
	c.size = Vector2(1920, 1080)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.08, 0.55)
	bg.size = c.size
	c.add_child(bg)
	var x := 200.0
	for spec in [
		InteractPrompt.glyph_spec(&"interact", false, ""),
		InteractPrompt.glyph_spec(&"interact", true, "Xbox Controller"),
		InteractPrompt.glyph_spec(&"interact", true, "PS5 Controller"),
	]:
		var g := InteractPrompt.GlyphView.new()
		g.spec = spec
		g.custom_minimum_size = Vector2(40, 40)
		g.position = Vector2(x, 160)
		g.size = g.get_combined_minimum_size()
		c.add_child(g)
		x += 90.0
	var tag := DepthsTag.new()
	tag.position = Vector2(200, 260)
	c.add_child(tag)
	tag.visible = true
	tag.set_multiplier(1400)
	var y := 340.0
	for spec: Array in [[&"gold", false], [&"blue", true], [&"blue", false]]:
		var p := PanelContainer.new()
		var box := Plaques.box(spec[0], 72.0, 6.0)
		if spec[1] or spec[0] != &"gold":
			box.set_focused(spec[1])
		p.add_theme_stylebox_override("panel", box)
		p.position = Vector2(200, y)
		p.custom_minimum_size = Vector2(620, 72)
		var l := HudStyle.label(22, true)
		l.text = tr("UI_EVENT_LEAVE")
		p.add_child(l)
		c.add_child(p)
		y += 110.0
	var bubble := RuneBubble.new()
	bubble.anchor_px = Vector2(1200, 420)
	c.add_child(bubble)
	bubble.show_line([1, 2, 3, 4, 0, 5, 6, 7] as Array[int])
	_put(c)
