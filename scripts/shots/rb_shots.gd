extends SceneTree
## v0.9.0 RB (owner, PLAN "Owner decisions" RB): the Wardrobe and the hero's rune affinities, in the real main.tscn on
## a memory-only profile, en then es. A tool, not a test: it places the hero in the hub's World and opens the panel
## directly. Per language: the Wardrobe panel over the hub (Ash and Ember picked). Then (en only: no text) the hero in
## the hub, the camera zoomed 3x on it (IsoRig.flourish_zoom), facing away so the rune on the robe's back shows with the
## circle under the feet, once per affinity (each in its robe colour: Ember Cream, Storm Ash, Venom Cream, Astral Ash,
## Guardian Cream), and Ember at Effects density Low.
## Needs a renderer (the GPU on the owner's PC):
##   godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/rb_shots.gd
## Writes build/shots/v0.9.0/rb/<lang>_<shot>.png (copy the ones the owner looks at into the evidence by hand).

const OUT := "res://build/shots/v0.9.0/rb/"
const LANGS: Array[String] = ["en", "es"]
const SETTLE := 70
const HEROES: Array = [
	[&"ember", &"cream", "high"],
	[&"storm", &"ash", "high"],
	[&"venom", &"cream", "high"],
	[&"astral", &"ash", "high"],
	[&"guardian", &"cream", "high"],
	[&"ember", &"cream", "low"],
]
## Facing away from the camera (up the screen): sim (-1, +1), 135 degrees in 4096ths of a turn.
const AWAY := 1536

var main: Main
var _lang := 0
var _step := 0
var _frames := 0
var _hero := 0
var _repo: ContentRepository


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_repo = ContentRepository.load_all()
	_boot()


func _boot() -> void:
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = LANGS[_lang]
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _shot(shot_name: String) -> void:
	var path := OUT + "%s_%s.png" % [LANGS[_lang], shot_name]
	root.get_texture().get_image().save_png(path)
	print("rb_shots: ", path)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames == SETTLE:
				_key(KEY_ENTER)  # Play
				_next()
		1:
			if _frames == SETTLE:
				var w := main.hub.driver.world
				var at := main.hub.layout.station(&"wardrobe").at
				w.actors.set_pos(0, HubLayout.to_sim(at + Vector2(1.9, 0.6)))
				w.vel = Vector2.ZERO
				_next()
		2:
			if _frames == 20:
				main.hub.open_wardrobe()
				var p := main.get_node("UI/WardrobePanel") as WardrobePanel
				p.robe_cycler.step(1)
				p.affinity_cycler.step(1)
			if _frames == SETTLE:
				_shot("1_wardrobe_panel")
				main.hub.close_overlay()
				_next()
				if _lang > 0:
					_step = 5
		3:
			if _frames == 2:
				_dress(HEROES[_hero])
			if _frames == SETTLE:
				var h: Array = HEROES[_hero]
				_shot("2_hero_%s_%s%s" % [h[0], h[1], "_low" if h[2] == "low" else ""])
				_hero += 1
				_frames = 0
				if _hero >= HEROES.size():
					ViewPrefs.effects_density = "high"
					_next()
		4:
			_next()
		5:
			main.queue_free()
			_lang += 1
			if _lang >= LANGS.size():
				return true
			TranslationServer.set_locale(LANGS[_lang])
			_step = 6
			_frames = 0
		6:
			if _frames == 2:
				_boot()
				_step = 0
				_frames = 0
	return false


## The hero in the hub wearing robe `h[1]` and affinity `h[0]` at density `h[2]`, held facing away, the camera close.
func _dress(h: Array) -> void:
	ViewPrefs.effects_density = h[2]
	var hub := main.hub
	hub.driver.paused = true
	var w := hub.driver.world
	w.actors.set_pos(0, hub.layout.spawn() + Vector2(0.0, 1.2))
	w.aim_angle = AWAY
	w.actors.facing[0] = AWAY
	hub.view.set_look(Wardrobe.look(_repo, _repo.get_def(&"robe", h[1]), h[0]))
	hub.view.sync()
	var at := SimPlane.to_3d(w.player_pos())
	hub.view.rig.flourish_zoom = 3.0
	hub.view.rig.snap_to(at)
	hub.hud.visible = false


func _next() -> void:
	_step += 1
	_frames = 0
