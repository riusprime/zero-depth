extends SceneTree
## v0.11.1 Step 13 (owner 2026-11-10: "Astral current one live should be the only HUD style for all elements
## throughout the game"): one shot per panel moved to the Astral look, each opened in the real main.tscn (a tool, not a
## test: it calls the sessions' own open functions and poses the run's Constellation offer directly):
## - the hub: the Wardrobe's panel (HubSession.open_wardrobe), the Progression Station's (open_progression) and the
##   stand-in station panel (HubStationPanel, shown as HubSession shows its overlays; no station opens it any more);
## - the Training Room: the terminal's panel (TrainingSession.open_panel), the Codex knowing a Charger and a card;
## - a run: the new loop's Constellation pick (ConstellationPanel in the run's HUD), the offer posed on the World.
## Needs a renderer (off screen):
##   godot --path . --position -10000,-10000 -s scripts/shots/menus_astral.gd -- lang=en
## Writes one PNG per panel to build/shots/<config/version>/menus_astral/<lang>/ (`out=<dir>` under build/ instead).
## Evidence copies are made by hand.

const SETTLE := 40
## The run's shot waits for the hero to land (the HUD is hidden until then), up to this many frames.
const LAND_MAX := 1200
## The Constellation pick: frames from the offer to the shot (the deal and the flip done).
const PICK_WAIT := 360

var main: Main
var _lang := "en"
var _out := ""
var _step := 0
var _frames := 0
var _landed_at := -1


func _initialize() -> void:
	var args := ScriptArgs.parse()
	_lang = args.get("lang", _lang)
	_out = "res://build/shots/%s/menus_astral/%s/" % [GameVersion.label(), _lang]
	if args.has("out"):
		_out = "res://build/%s/%s/" % [String(args["out"]), _lang]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	print(
		(
			"menus_astral: renderer=%s device=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = _lang
	var codex := CodexStore.new(profile)
	codex.unlock(&"enemies", &"charger")
	codex.unlock(&"cards", _first_card())
	ProfileStore.use_shared(profile)
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


## The Training Room's first wand card (so the terminal lists a card).
func _first_card() -> StringName:
	var repo := ContentRepository.load_all()
	var w := TrainingScenario.build(repo, &"gun", repo.get_def(&"biomes", HubSession.BIOME))
	for e in PlaygroundApi.new(w).catalog():
		if e["group"] == PlaygroundApi.GROUP_WAND:
			return w.item_tables[int(e["code"])].id
	return &""


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames == 3:
				HubFlow.open(main)
				_next()
		1:
			if _frames == 90:
				main.hub.open_wardrobe()
				_next()
		2:
			if _frames == SETTLE:
				_shot("wardrobe")
				main.hub.close_overlay()
				main.hub.open_progression()
				_next()
		3:
			if _frames == SETTLE:
				_shot("progression")
				main.hub.close_overlay()
				var p := HubStationPanel.new(&"wardrobe", "HUB_WARDROBE", "HUB_WARDROBE_SOON")
				p.back_pressed.connect(main.hub.close_overlay)
				main.hub._show_overlay(p)
				_next()
		4:
			if _frames == SETTLE:
				_shot("hub_station")
				main.hub.close_overlay()
				TrainingFlow.start(main, &"gun")
				_next()
		5:
			if _frames == 120:
				main.training.open_panel()
				_next()
		6:
			if _frames == SETTLE:
				_shot("training")
				main.training.close_panel()
				main._end_stage()
				main.start_stage()
				_next()
		7:
			_run_shot()
	if _frames > 4000:
		push_error("menus_astral: stuck at step %d" % _step)
		quit(1)
	return false


## The run: once the hero has landed, the Constellation offer is posed and the pick opens in the HUD.
func _run_shot() -> void:
	var hud := main.get_node_or_null("UI/Hud") as Hud
	var landed := _frames > 10 and hud != null and hud.visible and not main.driver.reader.arriving()
	if _landed_at < 0 and (landed or _frames >= LAND_MAX):
		_landed_at = _frames
		if not landed:
			push_error("menus_astral: the hero did not land")
		var w := main.driver.world
		w.actors.invuln[0] = 1 << 24
		w.constellation_offer = Constellations.offer(w.seed_value, 2, PackedInt32Array())
	if _landed_at >= 0 and _frames == _landed_at + PICK_WAIT:
		if not hud.constellation.visible:
			push_error("menus_astral: the Constellation pick did not open")
		_shot("constellation")
		quit(0)


func _next() -> void:
	_step += 1
	_frames = 0


func _shot(shot_name: String) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(_out + shot_name + ".png")
	print("menus_astral: ", _out + shot_name + ".png")
